-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/kotlin_update_prompt.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local prompt = require('tajbanana.kotlin_update_prompt')
for _, key in ipairs({ 'y', 'n', 'q', '<Esc>', 'close' }) do
    local called, accepted = 0, nil
    prompt.ask('Kotlin LSP update', { 'To install: 263.2.0 (Open VSX)' }, 'download', function(value)
        called = called + 1
        accepted = value
    end)
    local buf = vim.api.nvim_get_current_buf()
    if key == 'close' then
        vim.api.nvim_win_close(0, true)
        vim.wait(20, function() return called > 0 end)
    else
        local found = false
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
            if map.lhs == key then map.callback(); found = true; break end
        end
        assert(found, 'missing action: ' .. key)
    end
    assert(called == 1 and accepted == (key == 'y'), 'action must resolve exactly once: ' .. key)
end
local get_mode, defer = vim.api.nvim_get_mode, vim.defer_fn
local pending
vim.api.nvim_get_mode = function() return { mode = 'i' } end
vim.defer_fn = function(callback) pending = callback end
local before = vim.api.nvim_get_current_buf()
prompt.ask('Deferred prompt', { 'Wait for normal mode' }, 'continue', function() end)
assert(pending and vim.api.nvim_get_current_buf() == before)
vim.api.nvim_get_mode = get_mode
vim.defer_fn = defer
pending()
assert(vim.api.nvim_get_current_buf() ~= before)
vim.api.nvim_win_close(0, true)
vim.wait(20, function() return false end)

-- Not only Insert mode: Insert-mode <C-o> ("niI" -- `yy` there approved a
-- download), operator-pending ("no") and a half-typed mapping (blocking) wait too.
for _, m in ipairs({ { mode = 'niI' }, { mode = 'no' }, { mode = 'n', blocking = true } }) do
    pending = nil
    vim.api.nvim_get_mode = function() return m end
    vim.defer_fn = function(callback) pending = callback end
    before = vim.api.nvim_get_current_buf()
    prompt.ask('Deferred prompt', { 'Wait' }, 'continue', function() end)
    vim.api.nvim_get_mode, vim.defer_fn = get_mode, defer
    assert(pending and vim.api.nvim_get_current_buf() == before, 'popup must wait in mode ' .. vim.inspect(m))
end
-- The command-line window (q:) reports plain Normal mode, but a window cannot
-- open there (E11): the popup must wait, not throw and leave the update hanging.
do
    local real_cmdwin = vim.fn.getcmdwintype
    pending = nil
    vim.fn.getcmdwintype = function() return ':' end
    vim.defer_fn = function(callback) pending = callback end
    before = vim.api.nvim_get_current_buf()
    local ok = pcall(prompt.ask, 'Deferred prompt', { 'Wait' }, 'continue', function() end)
    vim.fn.getcmdwintype, vim.defer_fn = real_cmdwin, defer
    assert(ok and pending and vim.api.nvim_get_current_buf() == before, 'popup must wait in the command-line window')
    -- And a window that fails to open for another reason is retried, not thrown.
    local real_open = vim.api.nvim_open_win
    local calls = 0
    vim.api.nvim_open_win = function() calls = calls + 1 error('E11: Invalid in command-line window') end
    pending = nil
    vim.defer_fn = function(callback) pending = callback end
    ok = pcall(prompt.ask, 'Retry prompt', { 'Wait' }, 'continue', function() end)
    vim.api.nvim_open_win, vim.defer_fn = real_open, defer
    assert(ok and calls == 1 and pending, 'a failed open is retried later, not raised')
end
-- The statusline's expiry prompt uses the same check.
local status = require('tajbanana.lsp_status')
local shown = false
local real_prompt = status._prompt_expired
status._prompt_expired = function() shown = true end
vim.api.nvim_get_mode = function() return { mode = 'niI' } end
vim.defer_fn = function() end
status._prompt_when_ready()
vim.api.nvim_get_mode, vim.defer_fn = get_mode, defer
status._prompt_expired = real_prompt
assert(not shown, 'expiry prompt must wait during Insert-mode <C-o>')
print('Kotlin confirmation popup actions and typing protection passed')
