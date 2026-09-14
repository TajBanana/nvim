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
print('Kotlin confirmation popup actions and typing protection passed')
