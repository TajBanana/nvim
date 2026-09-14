-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/kotlin_lsp_popup.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
local dir = root .. '/kotlin-server-263.1.0'
vim.fn.mkdir(dir, 'p')
vim.fn.writefile({ 'ILS-263.1.0' }, dir .. '/build.txt')
vim.fn.writefile({ vim.json.encode({ version = '263.1.0', source = 'Open VSX' }) }, dir .. '/install-source.json')
vim.env.KOTLIN_LSP_DIR = dir
local callback
local lookups = 0
vim.system = function(cmd, _, cb)
    assert(cmd[3] == '--preview')
    callback = cb
    lookups = lookups + 1
end
vim.lsp.get_clients = function() return {} end
local log = root .. '/lsp.log'
vim.lsp.get_log_path = function() return log end
local status = require('tajbanana.lsp_status')
assert(status._installation_info(dir).source == 'Open VSX')
assert(status._installation_info(root .. '/kotlin-server-263.2.0').source:match('unknown'))
assert(status._installation_info(root .. '/mason/packages/kotlin-lsp/kotlin-server-263.3.0').source == 'Mason')
local function expiry_line(version)
    return '[ERROR] "rpc" "' .. root .. '/kotlin-server-' .. version .. '/bin/intellij-server" "stderr" "This build of intellij-server has expired."'
end
vim.fn.writefile({ expiry_line('262.1.0') }, log)
status._detect_expiry(vim.api.nvim_get_current_buf())
assert(not status._expired_kotlin and lookups == 0, 'stale version must not prompt')
vim.fn.writefile({ expiry_line('263.1.0') }, log)
status._detect_expiry(vim.api.nvim_get_current_buf())
assert(status._expired_kotlin and lookups == 1)
local popup = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(popup, 0, -1, false)
assert(lines[1]:find('263.1.0', 1, true))
assert(lines[2]:find('Open VSX', 1, true))
callback({ code = 0, stdout = 'CANDIDATE kotlin-server-263.2.0 GitHub\n' })
vim.wait(100, function()
    return vim.api.nvim_buf_get_lines(popup, 2, 3, false)[1]:find('263.2.0', 1, true) ~= nil
end)
lines = vim.api.nvim_buf_get_lines(popup, 0, -1, false)
assert(lines[3]:find('263.2.0', 1, true))
assert(lines[4]:find('GitHub (expiry check pending)', 1, true))
local updates = 0
vim.api.nvim_create_user_command('KotlinLspUpdate', function() updates = updates + 1 end, {})
for _, map in ipairs(vim.api.nvim_buf_get_keymap(popup, 'n')) do
    if map.lhs == 'y' then map.callback() end
end
assert(updates == 1 and not vim.api.nvim_buf_is_valid(popup))
callback({ code = 1, stdout = '' }) -- late lookup after dismissal is harmless
vim.wait(20, function() return false end)
status._prompt_expired()
popup = vim.api.nvim_get_current_buf()
callback({ code = 1, stdout = '' })
vim.wait(100, function()
    return vim.api.nvim_buf_get_lines(popup, 2, 3, false)[1]:find('lookup failed', 1, true) ~= nil
end)
assert(vim.api.nvim_buf_get_lines(popup, 2, 3, false)[1]:find('lookup failed', 1, true))
print('Kotlin expiry popup checks passed')
