-- Repo-wide diagnostics (<leader>xr).
--
-- LSP servers only diagnose files that are open, so <leader>xx / <leader>xb can
-- never show problems in files you have not visited. This runs a real
-- project-wide linter/compiler over the whole repo, loads the results into the
-- quickfix list, and browses them in Telescope (same left/right layout).
--
-- The tool is picked by project marker (first match wins). Gradle/Kotlin is
-- intentionally excluded — a full compile is far too slow to bind to a keypress.
-- Add a detector below to support another stack.

local M = {}

local function exists(path)
    return vim.uv.fs_stat(path) ~= nil
end

-- JS/TS: prefer ESLint (lint issues — what "lint" usually means) via the
-- project's local binary; fall back to tsc (type errors). Local node_modules
-- binaries exec node, which nvim has on PATH via the set.lua nvm fix — unlike
-- the interactive-shell `npx`, which is an nvm lazy-load stub that fails here.
local function js_detector(root)
    local eslint = root .. "/node_modules/.bin/eslint"
    if exists(eslint) then
        -- -f unix prints "path:line:col: message [rule]" (absolute paths)
        return { name = "eslint", cmd = { eslint, ".", "-f", "unix" }, efm = "%f:%l:%c: %m" }
    end
    local tsc = root .. "/node_modules/.bin/tsc"
    if exists(tsc) then
        return { name = "tsc", cmd = { tsc, "--noEmit", "--pretty", "false" }, efm = "%f(%l\\,%c): %m" }
    end
    return nil, "node_modules/.bin eslint or tsc not found (run npm/pnpm install)"
end

-- Ordered detectors. `make(root)` returns a spec { name, cmd, efm } or
-- (nil, reason). A spec's cmd[1] that contains "/" is a local binary path;
-- otherwise it is a PATH tool checked with executable().
local detectors = {
    { marker = "go.mod",          make = function() return { name = "go vet", cmd = { "go", "vet", "./..." }, efm = "%f:%l:%c: %m" } end },
    { marker = "Cargo.toml",      make = function() return { name = "cargo check", cmd = { "cargo", "check", "--message-format=short", "-q" }, efm = "%f:%l:%c: %m" } end },
    { marker = "pyproject.toml",  make = function() return { name = "ruff", cmd = { "ruff", "check", "--output-format=concise", "." }, efm = "%f:%l:%c: %m" } end },
    { marker = "requirements.txt", make = function() return { name = "ruff", cmd = { "ruff", "check", "--output-format=concise", "." }, efm = "%f:%l:%c: %m" } end },
    { marker = "package.json",    make = js_detector },
    { marker = "tsconfig.json",   make = js_detector },
}

-- Git repo root of the current file, falling back to its directory.
local function repo_root()
    local dir = vim.fn.expand("%:p:h")
    if dir == "" then
        dir = vim.fn.getcwd()
    end
    local root = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
    if vim.v.shell_error ~= 0 or root == "" then
        return dir
    end
    return root
end

local function detect(root)
    for _, det in ipairs(detectors) do
        if exists(root .. "/" .. det.marker) then
            return det.make(root)
        end
    end
end

function M.run()
    local root = repo_root()
    local d, reason = detect(root)
    if not d then
        vim.notify("repo lint: " .. (reason or "no known linter here (go/cargo/ruff/eslint/tsc)"), vim.log.levels.WARN)
        return
    end
    -- A cmd[1] with a "/" is a local binary path (checked already); otherwise
    -- it is a PATH tool.
    local prog = d.cmd[1]
    if not prog:find("/") and vim.fn.executable(prog) ~= 1 then
        vim.notify("repo lint: '" .. prog .. "' not found on PATH", vim.log.levels.ERROR)
        return
    end
    vim.notify("repo lint: running " .. d.name .. "…", vim.log.levels.INFO)
    vim.system(d.cmd, { cwd = root, text = true }, vim.schedule_wrap(function(out)
        -- A leading %D "Entering dir" line makes the tool's relative paths
        -- resolve against <root> regardless of nvim's cwd (the make/quickfix
        -- directory-tracking trick).
        local lines = { "Entering dir '" .. root .. "'" }
        vim.list_extend(lines, vim.split((out.stdout or "") .. (out.stderr or ""), "\n", { trimempty = true }))
        vim.fn.setqflist({}, " ", {
            title = "repo lint: " .. d.name,
            lines = lines,
            efm = "%DEntering dir '%f'," .. d.efm,
        })
        -- Keep only real file entries. The %D directory marker and any summary
        -- lines parse into entries with no buffer (bufnr 0); left in the list
        -- they make Telescope's open action fail with E939 (buffer 0).
        local items = vim.tbl_filter(function(e)
            return e.valid == 1 and e.bufnr > 0
        end, vim.fn.getqflist())
        vim.fn.setqflist({}, "r", { title = "repo lint: " .. d.name, items = items })
        if #items == 0 then
            vim.notify("repo lint: " .. d.name .. " found no issues ✓", vim.log.levels.INFO)
            return
        end
        require("telescope.builtin").quickfix()
    end))
end

return M
