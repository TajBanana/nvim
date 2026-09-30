-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/kotlin_expiry_current.lua
-- The ⏱ expiry check when kotlin-lsp is launched through the `current` symlink
-- (the self-managed setup): the log names `current`, not a version, so an
-- expiry logged BEFORE `current` was last repointed belongs to the previous
-- build and must not flag the new one.
vim.opt.rtp:prepend(vim.fn.getcwd())
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end
local root = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
vim.fn.mkdir(root .. '/kotlin-server-263.2.0', 'p')
root = vim.uv.fs_realpath(root)
vim.uv.fs_symlink(root .. '/kotlin-server-263.2.0', root .. '/current')
vim.env.KOTLIN_LSP_HOME = root
vim.env.KOTLIN_LSP_DIR = root .. '/current'
vim.system = function() return {} end -- the popup's preview lookup
vim.lsp.get_clients = function() return {} end
local log = root .. '/lsp.log'
vim.lsp.get_log_path = function() return log end
local status = require('tajbanana.lsp_status')

local function expiry_at(t)
    return ('[ERROR][%s] log.lua:150\t"rpc"\t"%s/current/bin/intellij-server"\t"stderr"\t"This build of intellij-server has expired."')
        :format(os.date('%Y-%m-%d %H:%M:%S', t), root)
end
local repointed = vim.uv.fs_lstat(root .. '/current').mtime.sec
vim.fn.writefile({ expiry_at(repointed - 3600) }, log) -- the OLD build expired an hour before the update
status._detect_expiry(vim.api.nvim_get_current_buf())
eq(status._expired_kotlin, false, 'an expiry logged before current was repointed is ignored')
vim.fn.writefile({ expiry_at(repointed + 5) }, log) -- the new build itself expired
status._detect_expiry(vim.api.nvim_get_current_buf())
eq(status._expired_kotlin, true, 'an expiry logged after the repoint flags the current build')

vim.fn.delete(root, 'rf')
print(('%d kotlin expiry (current) checks passed'):format(checks))
vim.cmd('qa!')
