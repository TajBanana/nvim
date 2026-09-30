-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/inlay_tint.lua
-- Hints sharing one position must be tinted by their label, whatever order core
-- rendered the chunks in (it iterates clients with pairs()).
vim.opt.rtp:prepend(vim.fn.getcwd())
local tint = require('tajbanana.inlay_tint')
local ns = vim.api.nvim_create_namespace('nvim.lsp.inlayhint')
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'call(value)' })

local hints = {
    { inlay_hint = { position = { line = 0, character = 5 }, label = 'name:', kind = 2 } },
    { inlay_hint = { position = { line = 0, character = 5 }, label = { { value = ': ' }, { value = 'Int' } }, kind = 1 } },
    { inlay_hint = { position = { line = 0, character = 10 }, label = 'unknown', kind = nil } },
}
vim.lsp.inlay_hint.get = function() return hints end

-- Chunks deliberately in the REVERSE of the hint list order, with padding.
vim.api.nvim_buf_set_extmark(buf, ns, 0, 5, { virt_text = {
    { ': Int', 'LspInlayHint' }, { ' ' }, { 'name:', 'LspInlayHint' },
}, virt_text_pos = 'inline' })
vim.api.nvim_buf_set_extmark(buf, ns, 0, 10, { virt_text = { { 'unknown', 'LspInlayHint' } }, virt_text_pos = 'inline' })

tint.schedule(buf)
vim.wait(1000, function() return false end, 20)

local groups = {}
for _, em in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    for _, chunk in ipairs(em[4].virt_text) do
        if chunk[2] then groups[chunk[1]] = chunk[2] end
    end
end
assert(groups[': Int'] == 'LspInlayHintType', 'type hint: ' .. tostring(groups[': Int']))
assert(groups['name:'] == 'LspInlayHintParameter', 'parameter hint: ' .. tostring(groups['name:']))
assert(groups['unknown'] == 'LspInlayHint', 'kindless hint keeps LspInlayHint: ' .. tostring(groups['unknown']))
print('inlay tint checks passed (label matching independent of chunk order)')
vim.cmd('qa!')
