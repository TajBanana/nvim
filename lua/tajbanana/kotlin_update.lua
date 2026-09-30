local M = {}
local busy = false

function M.is_running() return busy end

-- scripts/update-kotlin-lsp.sh of the checkout this module was loaded from --
-- not stdpath("config"), which is another copy when the config (or a test) runs
-- from a different checkout or worktree.
function M.script_path()
    local here = debug.getinfo(1, "S").source:gsub("^@", "")
    return vim.fs.normalize(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(here, ":p"))))
        .. "/scripts/update-kotlin-lsp.sh")
end

-- The self-managed install root: KOTLIN_LSP_HOME when set (as the updater
-- script honours it), else ~/.local/share/kotlin-lsp. env.lua makes a relative
-- KOTLIN_LSP_HOME absolute at STARTUP (against the directory Neovim started
-- in); this is only a fallback for when that did not run (tests). Either way it
-- is written back, so the updater script, KOTLIN_LSP_DIR and later calls all
-- agree: left relative, KOTLIN_LSP_DIR broke on the first :cd.
function M.install_root()
    local home = vim.env.KOTLIN_LSP_HOME
    if not home or home == "" then
        return vim.fn.expand("~/.local/share/kotlin-lsp")
    end
    if not vim.startswith(home, "/") and not home:match("^%a:[/\\]") then
        home = vim.fs.normalize(vim.fn.fnamemodify(home, ":p"))
        vim.env.KOTLIN_LSP_HOME = home
    end
    return home
end

-- Point kotlin.nvim at the self-managed install: KOTLIN_LSP_DIR = the
-- `current` symlink PATH (never the build it resolves to -- see kotlin.lua),
-- unless the user exported a KOTLIN_LSP_DIR of their own. Called at plugin load
-- and again before every restart: on a machine whose first install happens
-- through :KotlinLspUpdate there is no `current` at load, and without this the
-- new build was not attached until Neovim restarted.
function M.point_at_current()
    local current = M.install_root() .. "/current"
    local env = vim.env.KOTLIN_LSP_DIR
    if env and env ~= current then
        return -- exported by the user
    end
    if vim.uv.fs_lstat(current) then
        vim.env.KOTLIN_LSP_DIR = current
    end
end

-- Point kotlin.nvim at the (re-linked) self-managed build, clear the expiry
-- flag, stop the running client and re-fire FileType on Kotlin buffers so they
-- reattach to the new build. The 1.5 s delay lets the stopped server release
-- its machine-wide analyzer lock first. Releases the in-editor guard when done.
local function restart_clients()
    M.point_at_current()
    require("tajbanana.lsp_status")._expired_kotlin = false
    for _, client in ipairs(vim.lsp.get_clients({ name = "kotlin_lsp" })) do client:stop() end
    vim.defer_fn(function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "kotlin" then
                vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
            end
        end
        busy = false
    end, 1500)
end

M._restart_clients = restart_clients -- exposed for testing

function M.start()
    if busy then
        vim.notify("A Kotlin LSP update is running or awaiting your response.", vim.log.levels.INFO)
        return
    end
    local script = M.script_path()
    if vim.fn.filereadable(script) == 0 then
        vim.notify("KotlinLspUpdate: missing " .. script, vim.log.levels.ERROR)
        return
    end
    busy = true
    local ask = require("tajbanana.kotlin_update_prompt").ask
    pcall(function() require("lazy").load({ plugins = { "fidget.nvim" } }) end)
    local ok_fidget, fidget = pcall(require, "fidget.progress")

    local function run()
        local handle
        if ok_fidget then
            handle = fidget.handle.create({
                title = "kotlin-lsp", message = "checking GitHub…",
                lsp_client = { name = "kotlin-lsp update" }, percentage = 0,
            })
        end
        local function report(message, percentage)
            if handle then handle:report({ message = message, percentage = percentage }) end
        end
        local out, err, pending = {}, {}, ""
        local process
        local finished = false
        local confirming = false
        local function line_received(line)
            if finished then return end
            local github, vsx = line:match("^CONFIRM%-OPEN%-VSX ([%d.]+) ([%d.]+)$")
            if github and not confirming then
                confirming = true
                report("awaiting Open VSX confirmation")
                ask("GitHub Kotlin LSP expired", {
                    "Failed: Kotlin LSP " .. github .. " (GitHub)",
                    "Reason: the server reported that its build expired.",
                    "To install: Kotlin LSP " .. vsx .. " (Open VSX)",
                    "Download and validate this alternative?",
                }, "download Open VSX", function(accepted)
                    if finished then return end
                    confirming = false
                    process:write(accepted and "y\n" or "n\n")
                    process:write(nil)
                end)
            else
                local phase = line:match("^·%s+(.+)")
                if phase then report(phase) end
            end
        end
        local function completed(result)
            vim.schedule(function()
                finished = true
                local output = table.concat(out)
                if result.code ~= 0 then
                    if handle then handle:cancel() end
                    if result.code == 20 then
                        busy = false
                        vim.notify("Kotlin LSP update dismissed; installation unchanged.", vim.log.levels.INFO)
                        return
                    end
                    local detail = vim.trim(table.concat(err)):sub(-1200)
                    if result.code == 75 or result.code == 11 or result.code == 12 then
                        busy = false
                        vim.notify(detail, vim.log.levels.WARN, { title = "KotlinLspUpdate" })
                        return
                    end
                    local reason = "Download or startup validation failed."
                    if detail:find("MISMATCH", 1, true) or detail:find("checksum", 1, true) then
                        reason = "Checksum verification failed."
                    elseif detail:find("curl:", 1, true) then
                        reason = "The download or release lookup failed."
                    elseif detail:find("timed out", 1, true) then
                        reason = "The server did not finish its startup check."
                    end
                    vim.notify(detail, vim.log.levels.ERROR, { title = "KotlinLspUpdate" })
                    ask("Kotlin LSP update failed", {
                        reason,
                        "This does not establish that the build expired.",
                        "Your installation has been preserved.",
                        "Retry the GitHub-first update?",
                    }, "retry", function(retry)
                        if retry then run() else busy = false end
                    end)
                    return
                end
                local build = output:match("[A-Z%-]+ kotlin%-server%-([%d.]+)%s*$") or "?"
                local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
                local current = output:match("UP%-TO%-DATE") ~= nil
                local message = (current and "already current (" .. build .. ")" or "updated to " .. build)
                if not current or #clients == 0 then
                    message = message .. " — reattaching"
                    -- Holds the in-editor guard through the restart as well.
                    restart_clients()
                else
                    require("tajbanana.lsp_status")._expired_kotlin = false
                    busy = false
                end
                if handle then
                    report(message, 100)
                    handle:finish()
                else
                    vim.notify("kotlin-lsp: " .. message, vim.log.levels.INFO)
                end
            end)
        end
        local ok, value = pcall(vim.system, { "bash", script, "--interactive" }, {
            text = true, stdin = true,
            stdout = function(_, data)
                if not data then return end
                out[#out + 1] = data
                -- Markers may be split between pipe reads.
                pending = pending .. data
                while pending:find("\n", 1, true) do
                    local line, rest = pending:match("^([^\n]*)\n(.*)$")
                    pending = rest
                    vim.schedule(function() line_received(line) end)
                end
            end,
            stderr = function(_, data)
                if not data then return end
                err[#err + 1] = data
                local latest
                for pct in data:gmatch("(%d+%.?%d*)%%") do latest = tonumber(pct) end
                if latest then vim.schedule(function() report("downloading…", math.floor(latest + 0.5)) end) end
            end,
        }, completed)
        if ok then
            process = value
        else
            err[#err + 1] = tostring(value)
            completed({ code = 1 })
        end
    end
    run()
end

-- :KotlinLspRollback -- swap back to the build that was current before the last
-- update. The script runs under the same cross-process lock as updates and
-- refuses when the previous build has expired (exit 14) or none exists (13).
function M.rollback()
    if busy then
        vim.notify("A Kotlin LSP update is running or awaiting your response.", vim.log.levels.INFO)
        return
    end
    local script = M.script_path()
    if vim.fn.filereadable(script) == 0 then
        vim.notify("KotlinLspRollback: missing " .. script, vim.log.levels.ERROR)
        return
    end
    busy = true
    vim.notify("kotlin-lsp: checking the previous build…", vim.log.levels.INFO)
    local ok, err = pcall(vim.system, { "bash", script, "rollback" }, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                busy = false
                -- Tail only, like the update path: a failed probe can dump
                -- kilobytes of server log into stderr.
                local detail = vim.trim((result.stderr or "") ~= "" and result.stderr or (result.stdout or "")):sub(-1200)
                -- 13 no previous build, 14 previous expired, 75 lock held: expected refusals.
                local expected = result.code == 13 or result.code == 14 or result.code == 75
                vim.notify(detail ~= "" and detail or ("rollback failed (exit " .. result.code .. ")"),
                    expected and vim.log.levels.WARN or vim.log.levels.ERROR, { title = "KotlinLspRollback" })
                return
            end
            local build = (result.stdout or ""):match("ROLLED%-BACK kotlin%-server%-([%d.]+)") or "?"
            restart_clients()
            vim.notify("kotlin-lsp: rolled back to " .. build .. " — reattaching", vim.log.levels.INFO)
        end)
    end)
    if not ok then
        busy = false
        vim.notify("KotlinLspRollback: " .. tostring(err), vim.log.levels.ERROR)
    end
end

return M
