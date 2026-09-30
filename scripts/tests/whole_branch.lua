-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/whole_branch.lua
-- The whole-branch gutter (lua/plugins/git.lua) against real gitsigns and
-- throwaway repos: bases follow every HEAD move WITHOUT focus events, the pass
-- never blocks on git, and edge cases pick the repo gitsigns itself uses.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/gitsigns.nvim')
local gs = require('gitsigns')
gs.setup(dofile('lua/plugins/git.lua')[1].opts)

local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

-- change_base spy: per-buffer call count and last base.
local calls, last = {}, {}
local change_base = gs.change_base
gs.change_base = function(base, ...)
    local b = vim.api.nvim_get_current_buf()
    calls[b] = (calls[b] or 0) + 1
    last[b] = base
    return change_base(base, ...)
end
-- Synchronous git spawns on the main loop (what used to freeze the editor).
local sync_git = 0
local system = vim.fn.system
vim.fn.system = function(cmd, ...)
    if type(cmd) == 'table' and cmd[1] == 'git' then sync_git = sync_git + 1 end
    return system(cmd, ...)
end

local tmp = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
tmp = vim.uv.fs_realpath(tmp)
local function sh(dir, script)
    local out = system({ 'sh', '-c', 'cd "$1" && ' .. script, 'sh', dir })
    assert(vim.v.shell_error == 0, out)
    return vim.trim(out)
end
local G = 'git -c user.name=t -c user.email=t@t'
local R = tmp .. '/r'
vim.fn.mkdir(R .. '/d', 'p')
sh(R, table.concat({
    'git init -q -b main', 'printf "a\\nb\\nc\\n" > f.txt', 'printf "x\\n" > d/g.txt', 'git add .',
    G .. ' commit -qm base', 'git checkout -qb b1', 'echo b1 >> f.txt', G .. ' commit -qam b1',
    'git checkout -q main', 'git checkout -qb b2', 'echo b2 >> f.txt', G .. ' commit -qam b2',
    'git checkout -q main', 'echo m >> d/g.txt', G .. ' commit -qam m2', 'git checkout -qb b3',
    'git checkout -q b1',
}, ' && '))

local function open(path)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    local b = vim.api.nvim_get_current_buf()
    vim.wait(5000, function() return calls[b] ~= nil end)
    return b
end
local fb = open(R .. '/f.txt')
local gb = open(R .. '/d/g.txt')
eq(last[fb], sh(R, 'git merge-base b1 main'), 'f.txt starts on the branch fork point')
eq(last[gb], last[fb], 'd/g.txt (sub-directory) too')

-- <leader>dv in the whole-branch view: the fork-point diff buffer must not be
-- writable (gitsigns makes a base-less diff an index buffer whose :w stages).
vim.cmd('buffer ' .. fb)
vim.fn.maparg('<leader>dv', 'n', false, true).callback()
local dv
-- Wait for the diff WINDOW: gitsigns names the scratch buffer before it has
-- read it and set its buftype.
vim.wait(3000, function()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.api.nvim_buf_get_name(b):match('^gitsigns://') and vim.wo[w].diff then dv = b end
    end
    return dv ~= nil
end)
eq(dv and vim.bo[dv].buftype ~= 'acwrite', true, '<leader>dv on the fork point: not the writable (staging) index buffer')
eq(dv and vim.api.nvim_buf_get_name(dv):find(last[fb], 1, true) ~= nil, true, '<leader>dv diffs the applied fork point')
eq(dv and table.concat(vim.api.nvim_buf_get_lines(dv, 0, -1, false), '\n'), sh(R, 'git show ' .. last[fb] .. ':f.txt'),
    '<leader>dv shows the fork-point text')
if dv then vim.cmd('silent! bwipeout! ' .. dv) end
vim.cmd('silent! only')
vim.cmd('diffoff!')
vim.cmd('buffer ' .. gb)

local function total() return (calls[fb] or 0) + (calls[gb] or 0) end
-- Move HEAD from a shell (no FocusGained) and wait for the watcher-driven pass.
local function move(script, want_calls, label)
    local before, sync_before = total(), sync_git
    sh(R, script)
    vim.wait(5000, function() return total() - before >= want_calls end)
    vim.wait(want_calls == 0 and 1500 or 300)
    eq(total() - before, want_calls, label .. ': change_base calls')
    eq(sync_git - sync_before, 0, label .. ': no synchronous git on the main loop')
end
move('git checkout -q b2', 0, 'same fork point')
move('git checkout -q b3', 2, 'new fork point')
move('git checkout -q b1', 2, 'back to b1')
move('git rebase -q main', 2, 'rebase onto an advanced main')
eq(last[fb], sh(R, 'git rev-parse main'), 'rebased: base is main tip')

-- Opt-out survives :edit, and :edit does not stack autocmds.
vim.cmd('buffer ' .. fb)
vim.fn.maparg('<leader>gB', 'n', false, true).callback()
local function wipeouts() return #vim.api.nvim_get_autocmds({ event = 'BufWipeout', buffer = fb }) end
local w0 = wipeouts()
for _ = 1, 3 do vim.cmd('edit!') vim.wait(300) end
eq(wipeouts(), w0, ':edit does not stack BufWipeout autocmds')
local before = calls[fb]
-- b2's fork point differs from rebased b1's, so d/g.txt (still wanted) re-diffs once.
move('git checkout -q b2', 1, 'switch with one buffer opted out')
eq(calls[fb], before, 'opted-out buffer keeps the index view')

-- A file opened through a symlink from outside any repo.
vim.fn.mkdir(tmp .. '/home', 'p')
vim.uv.fs_symlink(R .. '/f.txt', tmp .. '/home/link.txt')
local lb = open(tmp .. '/home/link.txt')
eq(last[lb], sh(R, 'git merge-base HEAD main'), 'symlinked file gets its target repo\'s base')

-- A sub-directory that becomes its own repo mid-session: keep the outer repo's
-- base (the one gitsigns diffs against), never the inner repo's sha.
local N = tmp .. '/outer'
vim.fn.mkdir(N .. '/sub', 'p')
sh(N, 'git init -q -b main && echo x > sub/x.txt && git add . && ' .. G .. ' commit -qm o && git checkout -qb feat')
local nb = open(N .. '/sub/x.txt')
local outer_base = last[nb]
sh(N .. '/sub', 'git init -q -b main && git add x.txt && ' .. G .. ' commit -qm inner')
local inner = sh(N .. '/sub', 'git rev-parse HEAD')
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(1500)
eq(last[nb] ~= inner, true, 'nested repo: never the inner repo\'s sha')
eq(last[nb], outer_base, 'nested repo: outer base kept')

-- A repo opened before its first commit is watched from the start.
local U = tmp .. '/unborn'
vim.fn.mkdir(U, 'p')
sh(U, 'git init -q -b main && echo u > u.txt')
vim.cmd('edit ' .. U .. '/u.txt')
local ub = vim.api.nvim_get_current_buf()
vim.wait(3000, function() return vim.b[ub].gitsigns_status_dict ~= nil end)
vim.wait(500)
sh(U, 'git add . && ' .. G .. ' commit -qm first && git checkout -qb feat && echo more >> u.txt && git add . && ' .. G .. ' commit -qm second')
vim.wait(5000, function() return last[ub] ~= nil end)
eq(last[ub], sh(U, 'git rev-parse main'), 'unborn repo: base applied after the first commits, no focus event')

-- Two HEAD moves in quick succession, the first pass slowed down: the newer
-- HEAD's fork point must win (a stale pass used to finish last and apply).
sh(R, 'git checkout -q b1')
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(2000)
local real_system, delayed = vim.system, false
vim.system = function(cmd, opts, cb)
    if not delayed and type(cmd) == 'table' and vim.tbl_contains(cmd, 'merge-base') and cb then
        delayed = true
        return real_system(cmd, opts, function(res) vim.defer_fn(function() cb(res) end, 1500) end)
    end
    return real_system(cmd, opts, cb)
end
sh(R, 'git checkout -q b2')
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(800)
sh(R, 'git checkout -q b3')
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(4000)
vim.system = real_system
eq(last[gb], sh(R, 'git merge-base b3 main'), 'overlapping HEAD moves: the newest fork point wins')

-- <leader>gB back on while a FocusGained refresh overlaps it (the toggle's
-- state read slowed down): the refresh took the buffer for up to date, the
-- toggle's late read was dropped, and the base stayed on the index with a
-- false "no main/master" warning.
vim.cmd('buffer ' .. gb)
local toggle = vim.fn.maparg('<leader>gB', 'n', false, true).callback
local notes, real_notify = {}, vim.notify
vim.notify = function(msg) notes[#notes + 1] = msg end
toggle() -- off
local before_on = calls[gb] or 0
delayed = false
vim.system = function(cmd, opts, cb)
    if not delayed and type(cmd) == 'table' and vim.tbl_contains(cmd, '--absolute-git-dir') and cb then
        delayed = true
        return real_system(cmd, opts, function(res) vim.defer_fn(function() cb(res) end, 800) end)
    end
    return real_system(cmd, opts, cb)
end
toggle() -- on
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(3000, function() return (calls[gb] or 0) > before_on end)
vim.wait(1200)
vim.system, vim.notify = real_system, real_notify
eq((calls[gb] or 0) > before_on and last[gb], sh(R, 'git merge-base b3 main'),
    'gB on racing a FocusGained refresh: the fork-point base is applied')
eq(vim.tbl_contains(notes, 'git signs: no main/master to diff against'), false, 'and no false "no main/master" warning')

-- A->B->A while git is slow (the verifier's repro): a pass for A that turned
-- stale after its fork-point lookup used to leave applied_head = A for a base
-- it never applied, so the later refresh for A skipped the buffer for good and
-- B's fork point stayed. cat-file delayed 1 s, merge-base against main's tip 2 s.
local AB = tmp .. '/ab'
vim.fn.mkdir(AB, 'p')
sh(AB, table.concat({ 'git init -q -b main', 'printf "a\\nb\\nc\\n" > f.txt', 'git add .', G .. ' commit -qm base',
    'git checkout -qb b1', 'echo b1 >> f.txt', G .. ' commit -qam b1', 'git checkout -q main', 'echo m >> f.txt',
    G .. ' commit -qam m2', 'git checkout -qb b2', 'echo b2 > other.txt', 'git add .', G .. ' commit -qm b2',
    'git checkout -q main', 'echo m3 > m3.txt', 'git add .', G .. ' commit -qm m3', 'git checkout -q b2' }, ' && '))
local ab = open(AB .. '/f.txt')
local X, Y, M = sh(AB, 'git merge-base b1 main'), sh(AB, 'git merge-base b2 main'), sh(AB, 'git rev-parse main')
eq(last[ab], Y, 'A->B->A: starts on b2\'s fork point')
vim.system = function(cmd, opts, cb)
    if type(cmd) == 'table' and cb then
        local delay = (vim.tbl_contains(cmd, 'cat-file') and 1000)
            or (vim.tbl_contains(cmd, 'merge-base') and vim.tbl_contains(cmd, M) and 2000) or nil
        if delay then return real_system(cmd, opts, function(r) vim.defer_fn(function() cb(r) end, delay) end) end
    end
    return real_system(cmd, opts, cb)
end
sh(AB, 'git checkout -q b1') vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(200)
sh(AB, 'git checkout -q main') vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(1100)
sh(AB, 'git checkout -q b1') vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(2500)
vim.system = real_system
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(4000, function() return last[ab] == X end)
eq(last[ab], X, 'A->B->A with slow git: back on b1\'s fork point')
vim.cmd('silent! bwipeout! ' .. ab)

-- Watchers are closed once no buffer uses the repo any more.
local function watchers_in(dir)
    local n = 0
    vim.uv.walk(function(h)
        if h:get_type() == 'fs_event' and not h:is_closing() then
            local ok, p = pcall(h.getpath, h)
            if ok and p and vim.startswith(p, dir) then n = n + 1 end
        end
    end)
    return n
end
eq(watchers_in(R .. '/.git') > 0, true, 'the repo is watched while its buffers are open')
for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    if vim.startswith(vim.uv.fs_realpath(name) or name, R .. '/') or vim.startswith(name, tmp .. '/home') then
        vim.cmd('silent! bwipeout! ' .. b)
    end
end
eq(watchers_in(R .. '/.git'), 0, 'watchers closed when the last buffer of the repo is wiped')

-- A buffer saved into ANOTHER repo releases the first repo's watchers.
local P, Q = tmp .. '/P', tmp .. '/Q'
for _, d in ipairs({ P, Q }) do
    vim.fn.mkdir(d, 'p')
    sh(d, 'git init -q -b main && echo x > f.txt && git add . && ' .. G .. ' commit -qm i && git checkout -qb feat')
end
local pb = open(P .. '/f.txt')
eq(watchers_in(P .. '/.git') > 0, true, 'P watched')
vim.cmd('saveas! ' .. Q .. '/new.txt')
vim.wait(2500)
vim.cmd('silent! bwipeout! ' .. pb)
vim.wait(300)
eq(watchers_in(P .. '/.git'), 0, ':saveas into another repo, then wipe: no watcher left on the old repo')
eq(watchers_in(Q .. '/.git'), 0, '... nor on the new one')

-- :saveas to a place outside any repo releases the repo's watchers at once
-- (they used to stay until the buffer was wiped).
local sb = open(Q .. '/f.txt')
eq(watchers_in(Q .. '/.git') > 0, true, 'Q watched again')
local N = tmp .. '/plain'
vim.fn.mkdir(N, 'p')
vim.cmd('saveas! ' .. N .. '/plain.txt')
vim.wait(2500, function() return watchers_in(Q .. '/.git') == 0 end)
eq(watchers_in(Q .. '/.git'), 0, ':saveas outside any repo: the old repo is no longer watched')
vim.cmd('silent! bwipeout! ' .. sb)

-- Wiped while a refresh's git call is in flight: no watcher is (re-)created.
local qb = open(Q .. '/f.txt')
vim.cmd('silent! bwipeout! ' .. qb)
vim.api.nvim_exec_autocmds('FocusGained', {})
vim.wait(1500)
eq(watchers_in(Q .. '/.git'), 0, 'a buffer wiped during a pass leaves no watcher')

vim.fn.delete(tmp, 'rf')
print(('%d whole-branch gutter checks passed'):format(checks))
vim.cmd('qa!')
