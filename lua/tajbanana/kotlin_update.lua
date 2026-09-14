local M = {}
local busy = false

function M.is_running() return busy end

function M.start()
    if busy then
        vim.notify("A Kotlin LSP update is running or awaiting your response.", vim.log.levels.INFO)
        return
    end
    local script = vim.fn.stdpath("config") .. "/scripts/update-kotlin-lsp.sh"
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
                local cur = vim.fn.expand("~/.local/share/kotlin-lsp/current")
                if vim.uv.fs_stat(cur) then vim.env.KOTLIN_LSP_DIR = cur end
                local status = require("tajbanana.lsp_status")
                status._expired_kotlin = false
                local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
                local current = output:match("UP%-TO%-DATE") ~= nil
                local message = (current and "already current (" .. build .. ")" or "updated to " .. build)
                if not current or #clients == 0 then
                    for _, client in ipairs(clients) do client:stop() end
                    message = message .. " — reattaching"
                    -- Hold the in-editor guard through restart as well.
                    vim.defer_fn(function()
                        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "kotlin" then
                                vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
                            end
                        end
                        busy = false
                    end, 1500)
                else
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

return M
