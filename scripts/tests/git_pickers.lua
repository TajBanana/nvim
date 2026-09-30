-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/git_pickers.lua
-- <leader>gc / <leader>gh preview command (backlog_005 B8): merge and root
-- commits show what they changed, and delta is only used when installed.
vim.opt.rtp:prepend(vim.fn.getcwd())
local gp = require('tajbanana.git_pickers')
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local function sh(script)
    local out = vim.fn.system({ 'sh', '-c', 'cd "$1" && ' .. script, 'sh', tmp })
    assert(vim.v.shell_error == 0, out)
    return vim.trim(out)
end
local G = 'git -c user.name=t -c user.email=t@t'
sh(table.concat({ 'git init -q -b main', 'echo root > a.txt', 'git add .', G .. ' commit -qm root',
    'git checkout -qb side', 'echo side > b.txt', 'git add .', G .. ' commit -qm side',
    'git checkout -q main', 'echo main >> a.txt', G .. ' commit -qam main',
    G .. ' merge -q --no-ff -m merge side', 'echo dirty >> a.txt' }, ' && '))

-- Run the preview command without delta (plain git output) and return it.
local real = vim.fn.executable
vim.fn.executable = function(b) return b == 'delta' and 0 or real(b) end
local function preview(rev, file)
    local cmd = gp._show_cmd(sh('git rev-parse ' .. rev), file, 200)
    eq(cmd[2] .. ' ' .. cmd[3], '--no-pager show', 'no delta installed: no pager at all')
    return vim.fn.system(vim.list_extend({ 'git', '-C', tmp }, vim.list_slice(cmd, 2)))
end
local merge = preview('HEAD')
eq(merge:find('+side', 1, true) ~= nil, true, 'merge commit shows what it brought in (first parent)')
local root = preview('HEAD~2~0^{/root}')
eq(root:find('+root', 1, true) ~= nil, true, 'root commit shows its content')
eq(root:find('dirty', 1, true), nil, 'root commit is not compared with the working tree')
eq(preview('HEAD', 'a.txt'):find('b.txt', 1, true), nil, 'file-scoped preview stays on that file')

-- In the preview's terminal (a tty, so git pages), without delta but with
-- this repo's git/delta.gitconfig included globally (core.pager = delta):
-- the preview showed "unable to execute pager 'delta'" instead of the diff.
local cfg = tmp .. '/global.gitconfig'
vim.fn.writefile({ '[include]', '\tpath = ' .. vim.fn.getcwd() .. '/git/delta.gitconfig' }, cfg)
local term_buf = vim.api.nvim_create_buf(false, true)
local exited
vim.api.nvim_buf_call(term_buf, function()
    vim.fn.jobstart(gp._show_cmd(sh('git rev-parse HEAD'), nil, 200), {
        term = true, cwd = tmp,
        env = { PATH = '/usr/bin:/bin', GIT_CONFIG_GLOBAL = cfg, PAGER = 'less' },
        on_exit = function() exited = true end,
    })
end)
vim.wait(5000, function() return exited end)
local screen = table.concat(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false), '\n')
eq(exited, true, 'terminal preview exits (no pager waiting at a prompt)')
eq(screen:find('+side', 1, true) ~= nil and screen:find('delta', 1, true) == nil, true,
    'terminal preview shows the diff, not a pager error: ' .. screen:sub(1, 120))
vim.fn.executable = real

-- The pickers use the current FILE's repo, not nvim's cwd.
local elsewhere = vim.fn.tempname()
vim.fn.mkdir(elsewhere, 'p')
vim.cmd('cd ' .. elsewhere)
vim.cmd('edit ' .. tmp .. '/a.txt')
eq(gp._repo_root(), sh('git rev-parse --show-toplevel'), 'repo root from the file, not from the (non-repo) cwd')
vim.cmd('cd -')

-- With delta, a user's pager.show (here `less`) must not take over the preview:
-- it hung at less's prompt. The preview's GIT_PAGER=delta outranks it.
if real('delta') == 1 then
    local cfg2 = tmp .. '/pager.gitconfig'
    vim.fn.writefile({ '[pager]', '\tshow = less' }, cfg2)
    local buf2 = vim.api.nvim_create_buf(false, true)
    local done2
    vim.api.nvim_buf_call(buf2, function()
        vim.fn.jobstart(gp._show_cmd(sh('git rev-parse HEAD'), nil, 200), {
            term = true, cwd = tmp,
            env = vim.tbl_extend('force', { GIT_CONFIG_GLOBAL = cfg2 }, gp._preview_env() or {}),
            on_exit = function() done2 = true end,
        })
    end)
    vim.wait(5000, function() return done2 end)
    eq(done2, true, 'pager.show=less: the preview still exits (delta, not less, pages)')
    if not done2 then vim.fn.jobstop(vim.b[buf2].terminal_job_id) end
end

-- With delta: side-by-side only when the preview pane itself is wide.
if real('delta') == 1 then
    local function sbs(width) return table.concat(gp._show_cmd('HEAD', nil, width), ' '):match('side%-by%-side=(%a+)') end
    eq(sbs(160), 'true', 'wide pane: side by side')
    eq(sbs(80), 'false', 'narrow pane: unified')
end

vim.fn.delete(tmp, 'rf')
print(('%d git picker checks passed'):format(checks))
vim.cmd('qa!')
