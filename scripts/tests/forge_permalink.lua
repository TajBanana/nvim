-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/forge_permalink.lua
-- <leader>gl permalink guards against a throwaway repo with a GitHub "origin".
vim.opt.rtp:prepend(vim.fn.getcwd())
local opened, notes = {}, {}
package.loaded['tajbanana.system_open'] = { open = function(url) opened[#opened + 1] = url end }
vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
-- A fake clipboard provider, so the test never touches the real clipboard.
-- `clip_works = false` simulates a copy command that fails silently.
local clip, clip_works = { 'old' }, true
vim.g.clipboard = {
    name = 'test',
    copy = {
        ['+'] = function(lines) if clip_works then clip = lines end end,
        ['*'] = function(lines) if clip_works then clip = lines end end,
    },
    paste = { ['+'] = function() return clip end, ['*'] = function() return clip end },
}
local forge = require('tajbanana.forge')
-- Offline: the pushed-check fallback (git ls-remote) must not reach a network.
vim.env.GIT_SSH_COMMAND = 'false'
vim.env.GIT_TERMINAL_PROMPT = '0'
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

local tmp = vim.fn.resolve(vim.fn.tempname())
local repo = tmp .. '/repo'
local function git(...)
    local out = vim.fn.system(vim.list_extend({ 'git', '-C', repo, '-c', 'user.name=t', '-c', 'user.email=t@t' }, { ... }))
    assert(vim.v.shell_error == 0, out)
    return vim.trim(out)
end
vim.fn.mkdir(repo .. '/dir', 'p')
git('init', '-q', '-b', 'main')
git('remote', 'add', 'origin', 'git@github.com:o/r.git')
vim.fn.writefile({ 'a', 'b', 'c', 'd' }, repo .. '/f.txt')
vim.fn.writefile({ 'a', 'b' }, repo .. '/dir/ü ñ.txt')
git('add', '.')
git('commit', '-qm', 'one')

-- Run open_line on `path` (absolute, or relative to the repo) at line 2, or on
-- `range`; returns the last notification.
local function link(path, range)
    vim.cmd('edit! ' .. vim.fn.fnameescape(path:sub(1, 1) == '/' and path or (repo .. '/' .. path)))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    opened, notes = {}, {}
    forge.open_line(range)
    return notes[#notes] or {}
end

-- (Offline: the remote cannot be asked, which is said as such -- it used to
-- read "not pushed, push first".)
eq(link('f.txt').msg:find('Could not check', 1, true) ~= nil, true, 'no tracking ref, remote unreachable: refused, and says why')
-- What a push to origin leaves behind: the remote-tracking ref (no network).
git('update-ref', 'refs/remotes/origin/main', 'HEAD')
local sha = git('rev-parse', 'HEAD')
local blob = 'https://github.com/o/r/blob/' .. sha .. '/'
local n = link('f.txt')
eq(opened[1], blob .. 'f.txt#L2', 'permalink by SHA')
eq(n.msg:find('^Permalink copied: ') ~= nil, true, 'copy reported')
eq(clip[1], blob .. 'f.txt#L2', 'link is on the clipboard')
eq(n.level, vim.log.levels.INFO, 'clean file -> INFO')

link('f.txt', { 2, 4 })
eq(opened[1], blob .. 'f.txt#L2-L4', 'GitHub range anchor repeats the L')

clip_works = false
n = link('f.txt')
eq(n.msg:find('copy failed') ~= nil, true, 'a failing clipboard is reported, not claimed')
clip_works = true

-- Non-ASCII + space: fully percent-encoded, so macOS `open` does not re-encode.
link('dir/ü ñ.txt')
eq(opened[1], blob .. 'dir/%C3%BC%20%C3%B1.txt#L2', 'non-ASCII path is percent-encoded')

vim.fn.writefile({ 'a', 'CHANGED', 'c', 'd' }, repo .. '/f.txt')
n = link('f.txt')
eq(#opened, 1, 'dirty file still opens')
eq(n.level == vim.log.levels.WARN and n.msg:find('uncommitted') ~= nil, true, 'dirty file warns')
git('checkout', '-q', '--', 'f.txt')

vim.fn.writefile({ 'x', 'y' }, repo .. '/new.txt')
n = link('new.txt')
eq(#opened, 0, 'untracked file: nothing opened')
eq(n.msg:find('not committed') ~= nil, true, 'untracked file is refused')
git('add', 'new.txt')
eq(link('new.txt').msg:find('not committed') ~= nil, true, 'staged-only file is refused')
git('rm', '-q', '--cached', 'new.txt')

-- A symlink from outside any repo into it (how ~/.ideavimrc is set up).
vim.fn.mkdir(tmp .. '/home', 'p')
vim.uv.fs_symlink(repo .. '/f.txt', tmp .. '/home/.dotrc')
link(tmp .. '/home/.dotrc')
eq(opened[1], blob .. 'f.txt#L2', 'symlink into the repo links the target')

-- A file name with glob characters, beside a DIRTY file it would match as a
-- pattern: a[1].txt is clean.
vim.fn.writefile({ 'a', 'b' }, repo .. '/a[1].txt')
vim.fn.writefile({ 'a', 'b' }, repo .. '/a1.txt')
vim.fn.writefile({ 'a', 'b' }, repo .. '/we[i]rd {n}^|.txt')
git('add', '.')
git('commit', '-qm', 'globs')
git('update-ref', 'refs/remotes/origin/main', 'HEAD')
sha = git('rev-parse', 'HEAD')
blob = 'https://github.com/o/r/blob/' .. sha .. '/'
vim.fn.writefile({ 'a', 'CHANGED' }, repo .. '/a1.txt')
n = link('a[1].txt')
eq(n.level, vim.log.levels.INFO, 'glob-character file name is not a pathspec (no false dirty warning)')
eq(opened[1], blob .. 'a%5B1%5D.txt#L2', 'brackets encoded')
git('checkout', '-q', '--', 'a1.txt')
link('we[i]rd {n}^|.txt')
eq(opened[1], blob .. 'we%5Bi%5Drd%20%7Bn%7D%5E%7C.txt#L2', 'RFC 3986 characters encoded')

-- macOS: a decomposed (NFD) file name on disk is stored composed (NFC) by git;
-- the URL must name what git stored.
if vim.fn.has('mac') == 1 and git('config', '--get', 'core.precomposeunicode') == 'true' then
    local nfd = 'u\204\136-nfd.txt' -- u + COMBINING DIAERESIS
    vim.fn.writefile({ 'a', 'b' }, repo .. '/' .. nfd)
    git('add', '.')
    git('commit', '-qm', 'nfd')
    git('update-ref', 'refs/remotes/origin/main', 'HEAD')
    sha = git('rev-parse', 'HEAD')
    blob = 'https://github.com/o/r/blob/' .. sha .. '/'
    link(nfd)
    eq(opened[1], blob .. '%C3%BC-nfd.txt#L2', 'NFD name on disk links to the NFC path git stored')
end

-- A global nvim.forge must not re-label this repo (the override is --local).
local gcfg = tmp .. '/gitconfig'
vim.fn.writefile({ '[nvim]', '\tforge = gitlab' }, gcfg)
vim.env.GIT_CONFIG_GLOBAL = gcfg
link('f.txt')
eq(opened[1], blob .. 'f.txt#L2', 'global nvim.forge ignored')
vim.env.GIT_CONFIG_GLOBAL = nil

git('checkout', '-q', '--detach')
link('f.txt')
eq(opened[1], blob .. 'f.txt#L2', 'detached HEAD still links (via origin)')
git('checkout', '-q', 'main')

-- Tracking a local branch (remote ".") falls back to origin.
git('config', 'branch.main.remote', '.')
link('f.txt')
eq(opened[1], blob .. 'f.txt#L2', 'branch.<b>.remote = "." falls back to origin')

-- A non-origin upstream on GitLab, with a trailing ".git/" in its URL.
git('remote', 'add', 'upstream', 'https://gitlab.example.com/g/sub/r.git/')
git('update-ref', 'refs/remotes/upstream/main', 'HEAD')
git('config', 'branch.main.remote', 'upstream')
link('f.txt', { 2, 3 })
eq(opened[1], 'https://gitlab.example.com/g/sub/r/-/blob/' .. sha .. '/f.txt#L2-3', 'upstream remote, GitLab range, .git/ stripped')

-- Remote URL shapes: an ssh host alias (second GitHub account), GitHub's
-- SSH-over-443 host, and http(s) remotes on a custom port.
local sshcfg = tmp .. '/ssh_config'
vim.fn.writefile({ 'Host github.com-work', '  HostName github.com' }, sshcfg)
forge._ssh_config = sshcfg
git('config', 'branch.main.remote', 'origin')
local function with_origin(url, range)
    git('remote', 'set-url', 'origin', url)
    link('f.txt', range)
    return opened[1]
end
eq(with_origin('git@github.com-work:o/r.git'), blob .. 'f.txt#L2', 'ssh alias resolved to its HostName')
eq(with_origin('ssh://git@ssh.github.com:443/o/r.git'), blob .. 'f.txt#L2', 'ssh.github.com -> github.com')
-- A real host name keeps its name even when ssh config gives it another
-- HostName (a dedicated ssh host / IP): that used to become "Unsupported forge".
vim.fn.writefile({ 'Host github.com-work', '  HostName github.com',
    'Host gitlab.example.com', '  HostName gitlab-ssh.example.com',
    'Host github.com', '  HostName 140.82.112.3',
    'Host work.github.com', '  HostName github.com' }, sshcfg)
eq(with_origin('git@gitlab.example.com:g/r.git'),
    'https://gitlab.example.com/g/r/-/blob/' .. sha .. '/f.txt#L2', 'real host kept despite a different ssh HostName')
eq(with_origin('git@github.com:o/r.git'), blob .. 'f.txt#L2', 'github.com kept despite an IP HostName')
eq(with_origin('git@github.com-work:o/r.git'), blob .. 'f.txt#L2', 'an alias still resolves to its HostName')
-- A dotted alias under a public forge (it built https://work.github.com/...).
eq(with_origin('git@work.github.com:o/r.git'), blob .. 'f.txt#L2', 'work.github.com alias -> github.com')
-- Dotted aliases with a real-looking TLD, whose HostName is a public forge.
vim.fn.writefile({ 'Host github.personal', '  HostName github.com', 'Host gitlab.work', '  HostName gitlab.com',
    'Host ssh.github.com', '  HostName 140.82.112.35', '  Port 443' }, sshcfg)
eq(with_origin('git@github.personal:o/r.git'), blob .. 'f.txt#L2', 'github.personal (HostName github.com) -> github.com')
eq(with_origin('git@gitlab.work:g/r.git'), 'https://gitlab.com/g/r/-/blob/' .. sha .. '/f.txt#L2',
    'gitlab.work (HostName gitlab.com) -> gitlab.com')
-- ssh.github.com is mapped before its HostName (an IP here) is looked at.
eq(with_origin('ssh://git@ssh.github.com:443/o/r.git'), blob .. 'f.txt#L2', 'ssh.github.com with an IP HostName -> github.com')
-- A DOTTED alias with no HostName is refused, even with an nvim.forge
-- override (the link named the alias itself: https://github.com-zz/...).
git('config', '--local', 'nvim.forge', 'gitlab')
git('remote', 'set-url', 'origin', 'git@github.com-zz:g/r.git')
local n_alias = link('f.txt')
eq(#opened == 0 and n_alias.msg:find('ssh alias', 1, true) ~= nil, true, 'unresolved dotted alias refused, even with nvim.forge')
-- ...but an IP address, a one-word intranet name (no HostName: it IS the host
-- ssh connects to) and a punycode TLD are real hosts: round 8 refused them.
for _, host in ipairs({ '10.1.2.3', 'gitserver', 'git.xn--p1ai' }) do
    eq(with_origin('git@' .. host .. ':g/r.git'), 'https://' .. host .. '/g/r/-/blob/' .. sha .. '/f.txt#L2',
        'nvim.forge + ' .. host .. ': linked')
end
git('config', '--local', '--unset', 'nvim.forge')
-- `ssh -G` reads the config file git's ssh uses (-F in core.sshCommand).
forge._ssh_config = nil
local cfg_f = tmp .. '/ssh_config_F'
vim.fn.writefile({ 'Host zz-work', '  HostName github.com' }, cfg_f)
git('config', '--local', 'core.sshCommand', 'ssh -F ' .. cfg_f)
local saved_cmd = vim.env.GIT_SSH_COMMAND
vim.env.GIT_SSH_COMMAND = nil
eq(with_origin('git@zz-work:o/r.git'), blob .. 'f.txt#L2', 'alias resolved from the -F file in core.sshCommand')
vim.env.GIT_SSH_COMMAND = saved_cmd
git('config', '--local', '--unset', 'core.sshCommand')
forge._ssh_config = sshcfg
eq(with_origin('https://u:tok@gitlab.corp:8443/g/r.git'),
    'https://gitlab.corp:8443/g/r/-/blob/' .. sha .. '/f.txt#L2', 'https port kept, credentials dropped')
eq(with_origin('http://gitlab.internal:8080/g/r.git'),
    'http://gitlab.internal:8080/g/r/-/blob/' .. sha .. '/f.txt#L2', 'http scheme and port kept')
git('remote', 'set-url', 'origin', 'git@github.com:o/r.git')

-- A cache-enabled clipboard provider (xclip/wl-copy/win32yank shape) whose copy
-- command fails: must be reported, not "copied".
vim.g.clipboard = {
    name = 'cachefail', cache_enabled = 1,
    copy = { ['+'] = { 'sh', '-c', 'cat >/dev/null; exit 1' }, ['*'] = { 'sh', '-c', 'cat >/dev/null; exit 1' } },
    paste = { ['+'] = { 'printf', 'old' }, ['*'] = { 'printf', 'old' } },
}
vim.cmd('unlet! g:loaded_clipboard_provider')
vim.cmd('runtime autoload/provider/clipboard.vim')
n = link('f.txt')
eq(n.msg:find('copy failed') ~= nil, true, 'failed copy with a cached provider is reported')
eq(n.level, vim.log.levels.WARN, 'failed copy is a WARN')

-- A clipboard tool that fails only after the read-back (1 s): the "copied"
-- is corrected by a follow-up warning.
vim.g.clipboard = {
    name = 'slowfail', cache_enabled = 1,
    copy = { ['+'] = { 'sh', '-c', 'cat >/dev/null; sleep 1; exit 1' }, ['*'] = { 'sh', '-c', 'cat >/dev/null; sleep 1; exit 1' } },
    paste = { ['+'] = { 'printf', 'old' }, ['*'] = { 'printf', 'old' } },
}
vim.cmd('unlet! g:loaded_clipboard_provider')
vim.cmd('runtime autoload/provider/clipboard.vim')
link('f.txt')
vim.wait(4000, function()
    for _, x in ipairs(notes) do if x.msg:find('NOT copied', 1, true) then return true end end
    return false
end)
local corrected = false
for _, x in ipairs(notes) do if x.msg:find('NOT copied', 1, true) and x.level == vim.log.levels.WARN then corrected = true end end
eq(corrected, true, 'a copy that fails after the read-back is corrected by a warning')

-- File names with a leading space or a control character survive intact.
git('config', 'branch.main.remote', 'origin')
for _, name in ipairs({ ' lead.txt', 'ctl\1x.txt' }) do
    vim.fn.writefile({ 'a', 'b' }, repo .. '/' .. name)
end
git('add', '.')
git('commit', '-qm', 'odd names')
git('update-ref', 'refs/remotes/origin/main', 'HEAD')
sha = git('rev-parse', 'HEAD')
blob = 'https://github.com/o/r/blob/' .. sha .. '/'
link(' lead.txt')
eq(opened[1], blob .. '%20lead.txt#L2', 'a leading space is kept (and encoded)')
link('ctl\1x.txt')
eq(opened[1], blob .. 'ctl%01x.txt#L2', 'a control character is kept and encoded')

-- Single-branch clone: its fetch refspec covers only main, so a pushed feature
-- branch has no remote-tracking ref -- the remote itself is asked.
local bare, sb = tmp .. '/bare.git', tmp .. '/single'
vim.fn.system({ 'git', 'clone', '-q', '--bare', repo, bare })
vim.fn.system({ 'git', 'clone', '-q', '--single-branch', '--branch', 'main', bare, sb })
local function gsb(...)
    local out = vim.fn.system(vim.list_extend({ 'git', '-C', sb, '-c', 'user.name=t', '-c', 'user.email=t@t' }, { ... }))
    assert(vim.v.shell_error == 0, out)
    return vim.trim(out)
end
gsb('config', 'nvim.forge', 'github')
gsb('switch', '-qc', 'feat')
vim.fn.writefile({ 'x', 'y' }, sb .. '/feat.txt')
gsb('add', '.')
gsb('commit', '-qm', 'feat')
gsb('push', '-q', '-u', 'origin', 'feat')
eq(gsb('for-each-ref', 'refs/remotes/origin/feat'), '', 'no tracking ref for the pushed branch')
opened, notes = {}, {}
vim.cmd('edit! ' .. sb .. '/feat.txt')
vim.api.nvim_win_set_cursor(0, { 1, 0 })
forge.open_line()
eq(#opened, 1, 'single-branch clone: a pushed HEAD is linked, not refused')

-- A pushed commit with newer commits on top of it on the remote (HEAD is an
-- ancestor of a remote tip, not the tip itself).
vim.fn.writefile({ 'x', 'y', 'z' }, sb .. '/feat.txt')
gsb('commit', '-qam', 'newer')
gsb('push', '-q', 'origin', 'feat')
gsb('checkout', '-q', 'HEAD~1')
opened, notes = {}, {}
vim.cmd('edit! ' .. sb .. '/feat.txt')
vim.api.nvim_win_set_cursor(0, { 1, 0 })
forge.open_line()
eq(#opened, 1, 'a pushed commit below the remote tip is linked')

-- A remote with thousands of refs (GitLab: refs/merge-requests/*, tags): one
-- merge-base per ref froze the editor for ~27 ms a ref (about a minute here).
local base_sha = vim.trim(vim.fn.system({ 'git', '-C', bare, 'rev-parse', 'main' }))
local refs = {}
for i = 1, 2000 do refs[#refs + 1] = ('create refs/tags/t%d %s'):format(i, base_sha) end
vim.fn.system({ 'git', '-C', bare, 'update-ref', '--stdin' }, table.concat(refs, '\n') .. '\n')
gsb('checkout', '-q', 'feat')
gsb('commit', '-q', '--allow-empty', '-m', 'local only')
opened, notes = {}, {}
vim.cmd('edit! ' .. sb .. '/feat.txt')
local t_refs = vim.uv.hrtime()
forge.open_line()
local refs_secs = (vim.uv.hrtime() - t_refs) / 1e9
eq(notes[#notes] and notes[#notes].msg:find('is not on', 1, true) ~= nil, true, '2000 refs, unpushed HEAD: refused')
eq(refs_secs < 3, true, ('2000 refs: no per-ref git call (took %.1fs)'):format(refs_secs))
-- A remote ref whose commit is NOT present locally (pushed from elsewhere):
-- rev-list must skip it (--ignore-missing), or the whole ancestry test failed.
local other = tmp .. '/other-clone'
vim.fn.system({ 'git', 'clone', '-q', bare, other })
vim.fn.system({ 'git', '-C', other, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '--allow-empty', '-m', 'elsewhere' })
vim.fn.system({ 'git', '-C', other, 'push', '-q', 'origin', 'HEAD:refs/heads/elsewhere' })
-- Only a TAG contains HEAD (among the 2000), and it points at a commit ON TOP
-- of HEAD -- so the ancestry test (rev-list) decides, next to the unknown tip.
gsb('commit', '-q', '--allow-empty', '-m', 'on top')
vim.fn.system({ 'git', '-C', sb, 'push', '-q', 'origin', 'HEAD:refs/tags/only-tag' })
gsb('checkout', '-q', 'HEAD~1')
opened, notes = {}, {}
vim.cmd('edit! ' .. sb .. '/feat.txt')
forge.open_line()
eq(#opened, 1, 'a commit only a tag (a descendant) contains is linked, beside a tip missing locally')
gsb('checkout', '-q', 'feat')

-- The ssh program git would use is respected: a GIT_SSH wrapper is not
-- overridden (GIT_SSH_COMMAND takes precedence over it), and OpenSSH gets the
-- non-interactive options.
local ssh_log = tmp .. '/ssh.log'
vim.fn.mkdir(tmp .. '/bin', 'p')
for _, name in ipairs({ 'wrap', 'bin/ssh' }) do
    vim.fn.writefile({ '#!/bin/sh', 'echo "' .. name .. ' $*" >> ' .. ssh_log, 'exit 1' }, tmp .. '/' .. name)
    vim.fn.setfperm(tmp .. '/' .. name, 'rwxr-xr-x')
end
local saved_global = vim.env.GIT_CONFIG_GLOBAL
vim.env.GIT_CONFIG_GLOBAL = tmp .. '/no-global' -- no core.sshCommand from the real one
gsb('remote', 'set-url', 'origin', 'git@nohost.invalid:o/r.git')
gsb('commit', '-q', '--allow-empty', '-m', 'unpushed again')
vim.env.GIT_SSH_COMMAND, vim.env.GIT_SSH = nil, tmp .. '/wrap'
vim.fn.delete(ssh_log)
forge.open_line()
local logged = vim.fn.filereadable(ssh_log) == 1 and table.concat(vim.fn.readfile(ssh_log), '\n') or ''
eq(logged:find('^wrap ') ~= nil, true, 'GIT_SSH wrapper is used for the remote check')
vim.env.GIT_SSH, vim.env.GIT_SSH_COMMAND = nil, tmp .. '/bin/ssh -p 22'
vim.fn.delete(ssh_log)
forge.open_line()
logged = vim.fn.filereadable(ssh_log) == 1 and table.concat(vim.fn.readfile(ssh_log), '\n') or ''
eq(logged:find('-o BatchMode=yes', 1, true) ~= nil and logged:find('-p 22', 1, true) ~= nil, true,
    'OpenSSH: its own options kept, BatchMode added')
-- core.sshCommand (no GIT_SSH_COMMAND): its OpenSSH also gets BatchMode.
vim.env.GIT_SSH_COMMAND = nil
gsb('config', 'core.sshCommand', tmp .. '/bin/ssh -p 2222')
vim.fn.delete(ssh_log)
forge.open_line()
logged = vim.fn.filereadable(ssh_log) == 1 and table.concat(vim.fn.readfile(ssh_log), '\n') or ''
eq(logged:find('-o BatchMode=yes', 1, true) ~= nil and logged:find('-p 2222', 1, true) ~= nil, true,
    'core.sshCommand OpenSSH: its options kept, BatchMode added')
gsb('config', '--unset', 'core.sshCommand')
vim.env.GIT_CONFIG_GLOBAL = saved_global
vim.env.GIT_SSH_COMMAND = 'false'

-- A remote whose ssh never answers (passphrase / host-key prompt, VPN down):
-- bounded, no Lua error, and nothing left running.
local hang = tmp .. '/hang-ssh'
vim.fn.writefile({ '#!/bin/sh', 'sleep 30' }, hang) -- no exec: pgrep must see the script
vim.fn.setfperm(hang, 'rwxr-xr-x')
vim.env.GIT_SSH_COMMAND = hang
gsb('remote', 'set-url', 'origin', 'git@github.com:o/r.git')
gsb('commit', '-q', '--allow-empty', '-m', 'unpushed')
opened, notes = {}, {}
local t0 = vim.uv.hrtime()
local ok_call, call_err = pcall(forge.open_line)
local secs = (vim.uv.hrtime() - t0) / 1e9
eq(ok_call, true, 'a hanging remote check raises no error: ' .. tostring(call_err))
eq(secs < 8, true, ('bounded (took %.1fs)'):format(secs))
eq(notes[#notes] and notes[#notes].msg:find('timed out', 1, true) ~= nil, true, 'and refuses: the check timed out (not "push first")')
vim.wait(500)
eq(vim.trim(vim.fn.system({ 'pgrep', '-f', hang })), '', 'no orphaned ssh left running')

-- Space gm's token-free fallback is bounded the same way (it had no limit).
opened, notes = {}, {}
forge._open_request_via_lsremote({
    forge = { head_glob = 'refs/pull/*/head', head_pattern = '^refs/pull/(%d+)/head$', request_path = '/pull/' },
    remote_name = 'origin', branch = 'feat', dir = sb, base = 'https://github.com/o/r',
}, 'https://github.com/o/r/compare/feat')
vim.wait(8000, function() return #notes > 0 end, 50)
eq(notes[1] and notes[1].msg:find('timed out', 1, true) ~= nil, true, 'Space gm fallback: a hanging remote times out')
eq(#opened, 0, 'Space gm fallback: nothing opened on a timeout')
vim.wait(500)
eq(vim.trim(vim.fn.system({ 'pgrep', '-f', hang })), '', 'Space gm fallback: no orphaned ssh')
vim.env.GIT_SSH_COMMAND = 'false'

-- Space gm's fallback looks the change request up by the branch's name ON the
-- remote: a local `mine` tracking origin/feat-remote used to be looked up as
-- `mine` (so an existing PR was missed and the create page opened).
gsb('remote', 'set-url', 'origin', bare)
gsb('checkout', '-qb', 'mine')
gsb('push', '-q', 'origin', 'HEAD:refs/heads/feat-remote')
gsb('config', 'branch.mine.remote', 'origin')
gsb('config', 'branch.mine.merge', 'refs/heads/feat-remote')
vim.fn.system({ 'git', '-C', bare, 'update-ref', 'refs/pull/7/head', gsb('rev-parse', 'HEAD') })
gsb('config', 'nvim.forge', 'github')
opened, notes = {}, {}
vim.cmd('edit! ' .. sb .. '/feat.txt')
local real_exe = vim.fn.executable
vim.fn.executable = function(b) return (b == 'gh' or b == 'glab') and 0 or real_exe(b) end -- the token-free path
forge.open_request()
vim.wait(5000, function() return #opened > 0 end, 50)
vim.fn.executable = real_exe
eq(opened[1] and opened[1]:match('/pull/7$') ~= nil, true, 'Space gm fallback: found by the upstream branch name: ' .. tostring(opened[1]))

-- ...but the upstream name must not win over the branch's own name: a branch
-- created from origin/main (upstream = main) and pushed under its own name used
-- to get a "create PR from main" page instead of its PR.
local function gm(name, remote, merge)
    gsb('checkout', '-qB', name)
    gsb('config', 'branch.' .. name .. '.remote', remote)
    gsb('config', 'branch.' .. name .. '.merge', merge)
    opened = {}
    vim.cmd('edit! ' .. sb .. '/feat.txt')
    vim.fn.executable = function(b) return (b == 'gh' or b == 'glab') and 0 or real_exe(b) end
    forge.open_request()
    vim.wait(5000, function() return #opened > 0 end, 50)
    vim.fn.executable = real_exe
    return opened[1] or ''
end
gsb('commit', '-q', '--allow-empty', '-m', 'featA')
gsb('push', '-q', 'origin', 'HEAD:refs/heads/featA')
vim.fn.system({ 'git', '-C', bare, 'update-ref', 'refs/pull/3/head', gsb('rev-parse', 'HEAD') })
eq(gm('featA', 'origin', 'refs/heads/main'):match('/pull/3$') ~= nil, true, 'created from origin/main, pushed as itself: its PR')
eq(gm('featB', '.', 'refs/heads/main'):match('/compare/featB') ~= nil, true, 'tracking a LOCAL branch: its own name')
gsb('commit', '-q', '--allow-empty', '-m', 'featC')
eq(gm('featC', 'origin', 'refs/heads/main'):match('/compare/featC') ~= nil, true, 'created from origin/main, not pushed: create page for itself')

vim.fn.delete(tmp, 'rf')
print(('%d forge permalink checks passed'):format(checks))
