-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/definition_picker.lua
-- <leader>gd picker (backlog_005 B7): a location returned by several requests
-- keeps every kind, and a server that never answers no longer blocks the picker.
vim.opt.rtp:prepend(vim.fn.getcwd())
local shown -- items handed to the Telescope picker
package.loaded['telescope.pickers'] = {
    new = function(_, spec) return { find = function() shown = spec.finder end } end,
}
package.loaded['telescope.finders'] = { new_table = function(t) return t.results end }
package.loaded['telescope.config'] = { values = {
    qflist_previewer = function() return { define_preview = function() end } end,
    generic_sorter = function() end,
} }
package.loaded['telescope.pickers.entry_display'] = { create = function() return function() end end }
local notes = {}
vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end

local picker = require('tajbanana.definition_picker')
picker._timeout_ms = 200
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

local file = vim.fn.tempname() .. '.lua'
vim.fn.writefile({ 'local x = 1', 'return x' }, file)
local uri = vim.uri_from_fname(file)
local loc = { uri = uri, range = { start = { line = 0, character = 6 }, ['end'] = { line = 0, character = 7 } } }
local cancelled = {}
local function client(name, answers)
    local next_id = 0
    return {
        name = name, offset_encoding = 'utf-16',
        supports_method = function() return true end,
        request = function(_, method, _, cb)
            local a = answers[method]
            if a ~= 'silent' then vim.schedule(function() cb(nil, a) end) end
            next_id = next_id + 1
            return true, next_id
        end,
        cancel_request = function(_, id) cancelled[#cancelled + 1] = name .. ':' .. id end,
    }
end
vim.cmd('edit ' .. file)

-- Same location from definition AND typeDefinition: one entry, both kinds.
vim.lsp.get_clients = function() return { client('fake', {
    ['textDocument/definition'] = loc, ['textDocument/typeDefinition'] = { loc },
    ['textDocument/implementation'] = {}, ['textDocument/references'] = {},
}) } end
shown = nil
picker.open()
vim.wait(1000, function() return shown ~= nil end)
eq(#shown, 1, 'one entry for the shared location')
eq(table.concat(shown[1].kinds, ','), 'def,type', 'it keeps both kinds, in rank order')

-- A server that never answers: the picker still opens with what arrived, and
-- the silent server is named.
vim.lsp.get_clients = function() return {
    client('quick', { ['textDocument/definition'] = loc, ['textDocument/typeDefinition'] = {},
        ['textDocument/implementation'] = {}, ['textDocument/references'] = {} }),
    client('mute', { ['textDocument/definition'] = 'silent', ['textDocument/typeDefinition'] = 'silent',
        ['textDocument/implementation'] = 'silent', ['textDocument/references'] = 'silent' }),
} end
shown, notes = nil, {}
picker.open()
vim.wait(2000, function() return shown ~= nil end)
eq(shown ~= nil, true, 'picker opens despite a silent server')
eq(#shown, 1, 'with the results that arrived')
eq(notes[1] and notes[1].msg:find('no answer from mute', 1, true) ~= nil, true, 'the silent server is named')
eq(notes[1] and notes[1].level, vim.log.levels.WARN, 'as a warning')
eq(#cancelled, 4, "the silent server's four outstanding requests are cancelled")
eq(notes[1].msg:find('<leader>', 1, true), nil, 'no literal <leader> in the message')

vim.fn.delete(file)
print(('%d definition picker checks passed'):format(checks))
vim.cmd('qa!')
