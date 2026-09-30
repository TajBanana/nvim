-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/kotlin_launch.lua
-- Which kotlin-lsp build ACTUALLY launches, with the real kotlin.nvim: after an
-- update/rollback repoints `current`, the next start (same session, or another
-- project) must run the new build. (A resolved-path design regressed exactly
-- here: Neovim restarted the server from the previous launch's command.)
-- Fake builds log their own version; nothing touches the real install.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo)
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/kotlin.nvim')
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

local tmp = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
tmp = vim.uv.fs_realpath(tmp)
local home, log = tmp .. '/kotlin-lsp', tmp .. '/launches.log'
for _, v in ipairs({ '1.0.0', '2.0.0' }) do
    local b = home .. '/kotlin-server-' .. v
    vim.fn.mkdir(b .. '/bin', 'p')
    vim.fn.mkdir(b .. '/lib', 'p')
    -- A minimal LSP server: answers initialize/shutdown, exits on `exit`, and
    -- logs its build version once at start.
    vim.fn.writefile({
        '#!/usr/bin/env python3',
        'import json, sys',
        'open(' .. vim.inspect(log) .. ', "a").write("' .. v .. '\\n")',
        'inp, out = sys.stdin.buffer, sys.stdout.buffer',
        'while True:',
        '    header = inp.readline()',
        '    if not header: break',
        '    if not header.lower().startswith(b"content-length"): continue',
        '    n = int(header.split(b":")[1]); inp.readline(); msg = json.loads(inp.read(n))',
        '    if msg.get("method") == "exit": break',
        '    if "id" in msg:',
        '        res = {"capabilities": {}} if msg.get("method") == "initialize" else None',
        '        body = json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": res}).encode()',
        '        out.write(b"Content-Length: %d\\r\\n\\r\\n" % len(body) + body); out.flush()',
    }, b .. '/bin/intellij-server')
    vim.fn.setfperm(b .. '/bin/intellij-server', 'rwxr-xr-x')
end
local function point(v)
    vim.fn.delete(home .. '/current')
    vim.uv.fs_symlink(home .. '/kotlin-server-' .. v, home .. '/current')
end
vim.env.KOTLIN_LSP_HOME = home
-- kotlin.nvim puts per-project workspaces under $HOME/.cache: keep them in the
-- sandbox (runs of this test left empty p1/p2 folders in the real ~/.cache).
vim.env.HOME = tmp .. '/home'
vim.env.KOTLIN_LSP_DIR = nil
vim.env.MASON = tmp .. '/no-mason'
for _, p in ipairs({ 'p1', 'p2' }) do
    vim.fn.mkdir(tmp .. '/' .. p .. '/src', 'p')
    vim.fn.writefile({ 'rootProject.name = "' .. p .. '"' }, tmp .. '/' .. p .. '/settings.gradle.kts')
    vim.fn.writefile({ 'fun main() {}' }, tmp .. '/' .. p .. '/src/Main.kt')
end
local function launches() return vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {} end
local function open(p)
    local n = #launches()
    vim.cmd('cd ' .. tmp .. '/' .. p)
    vim.cmd('edit ' .. tmp .. '/' .. p .. '/src/Main.kt')
    vim.wait(5000, function() return #launches() > n end)
    return launches()[#launches()]
end

-- First install through :KotlinLspUpdate, in a FRESH session: no `current`
-- when the plugin loaded, so KOTLIN_LSP_DIR is unset and kotlin.nvim has no
-- config yet (it errors on the first Kotlin buffer). The restart after the
-- update must point it at `current`. This runs first on purpose: once any
-- launch has configured kotlin_lsp, Neovim relaunches from that config and the
-- check would pass even without the fix.
local real_notify = vim.notify
vim.notify = function() end -- kotlin.nvim's "KOTLIN_LSP_DIR is not set" error
dofile(repo .. '/lua/plugins/kotlin.lua').config()
eq(vim.env.KOTLIN_LSP_DIR, nil, 'no install yet: KOTLIN_LSP_DIR stays unset')
vim.cmd('filetype on')
vim.cmd('cd ' .. tmp .. '/p1')
vim.cmd('edit ' .. tmp .. '/p1/src/Main.kt')
vim.wait(1500)
eq(#launches(), 0, 'no install: nothing launches')
point('2.0.0') -- the update creates `current`
require('tajbanana.kotlin_update')._restart_clients()
vim.wait(8000, function() return #launches() > 0 end)
vim.notify = real_notify
eq(vim.env.KOTLIN_LSP_DIR, home .. '/current', 'the restart after a first install points kotlin.nvim at current')
eq(launches()[#launches()], '2.0.0', 'and the freshly installed build attaches without restarting Neovim')

-- Rollback/update in this session: repoint, then restart. restart_clients
-- stops the client and re-fires FileType, which spawns the command kotlin.nvim
-- configured. The regressed design put a RESOLVED build path in that command;
-- it must stay the `current` symlink path so any later spawn runs the new build.
local cmd = vim.lsp.config.kotlin_lsp.cmd
eq(cmd[1], home .. '/current/bin/intellij-server', 'the configured command goes through the current symlink')
point('1.0.0')
local n = #launches()
vim.fn.system({ cmd[1] }, '') -- what a restart spawns (EOF on stdin: it logs and exits)
eq(#launches(), n + 1, 'the configured command starts a server')
eq(launches()[#launches()], '1.0.0', 'after a swap the same command starts the NEW build')

-- Another project opened later spawns a real new client (as another Neovim
-- would): it follows current too.
point('2.0.0')
eq(open('p2'), '2.0.0', 'a later launch follows current again')

-- Through the REAL restart path (restart_clients: stop, 1.5 s, re-fire
-- FileType -- Neovim's own FileType handler runs first, the ordering that broke
-- the resolved-path design): a rollback to 1.0.0 relaunches 1.0.0.
point('1.0.0')
n = #launches()
require('tajbanana.kotlin_update')._restart_clients()
vim.wait(8000, function() return #launches() > n end)
eq(launches()[#launches()], '1.0.0', 'restart_clients after a swap launches the new build')

-- With an install present at load, the plugin points kotlin.nvim at it.
vim.env.KOTLIN_LSP_DIR = nil
dofile(repo .. '/lua/plugins/kotlin.lua').config()
eq(vim.env.KOTLIN_LSP_DIR, home .. '/current', 'kotlin.nvim is pointed at the current symlink path')

-- A user-exported KOTLIN_LSP_DIR is left alone.
vim.env.KOTLIN_LSP_DIR = tmp .. '/manual'
dofile(repo .. '/lua/plugins/kotlin.lua').config()
eq(vim.env.KOTLIN_LSP_DIR, tmp .. '/manual', 'an exported KOTLIN_LSP_DIR is respected')

-- A relative KOTLIN_LSP_HOME is made absolute once (and written back, so the
-- updater script agrees): left relative, KOTLIN_LSP_DIR broke on the first :cd.
vim.cmd('cd ' .. tmp)
vim.env.KOTLIN_LSP_HOME, vim.env.KOTLIN_LSP_DIR = 'kotlin-lsp', nil
dofile(repo .. '/lua/plugins/kotlin.lua').config()
eq(vim.env.KOTLIN_LSP_HOME, home, 'relative KOTLIN_LSP_HOME made absolute')
vim.cmd('cd ' .. tmp .. '/p1')
eq(vim.uv.fs_lstat(vim.env.KOTLIN_LSP_DIR) ~= nil, true, 'KOTLIN_LSP_DIR still valid after :cd')
-- At STARTUP (env.lua), before any lazy plugin load: resolved against the
-- directory Neovim started in, not wherever a later :cd went.
vim.cmd('cd ' .. tmp)
vim.env.KOTLIN_LSP_HOME = 'kotlin-lsp'
require('tajbanana.env')._fix_kotlin_lsp_home()
vim.cmd('cd ' .. tmp .. '/p2')
eq(vim.env.KOTLIN_LSP_HOME, home, 'startup: relative KOTLIN_LSP_HOME resolved against the start directory')

for _, c in ipairs(vim.lsp.get_clients()) do c:stop(true) end
vim.fn.system({ 'pkill', '-f', tmp })
vim.fn.delete(tmp, 'rf')
print(('%d kotlin launch checks passed'):format(checks))
vim.cmd('qa!')
