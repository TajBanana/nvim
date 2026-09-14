-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/completion.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.virtualedit = 'onemore'
local session = { current_nodes = {} }
package.loaded['luasnip.session'] = session
local completion = require('tajbanana.completion')
local kinds = vim.lsp.protocol.CompletionItemKind
local cases = 0
local function check(opts)
    session.current_nodes = {}
    local buf = vim.api.nvim_get_current_buf()
    if opts.node then session.current_nodes[buf] = opts.node end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { opts.line })
    vim.api.nvim_win_set_cursor(0, { 1, opts.col })
    local entry = { get_kind = function() return opts.kind or kinds.Variable end }
    local accepted = false
    local cmp = {
        get_selected_entry = function() if not opts.unselected then return entry end end,
        get_entries = function() return { entry } end,
        confirm = function(options, callback)
            accepted = not opts.unselected or options.select
            if accepted then
                if opts.after_node then session.current_nodes[buf] = opts.after_node end
                callback()
            end
            return accepted
        end,
    }
    assert(completion.confirm(cmp, opts.tab or false) == accepted)
    assert(vim.api.nvim_win_get_cursor(0)[2] == opts.expected, vim.inspect(opts))
    assert(vim.api.nvim_get_current_line() == opts.line)
    cases = cases + 1
end
for _, kind in ipairs({ kinds.Variable, kinds.Field, kinds.Property, kinds.Constant }) do
    for _, tab in ipairs({ false, true }) do
        check({ line = 'object.method(value)', col = 19, expected = 20, kind = kind, tab = tab })
    end
end
check({ line = 'outer(inner(value))', col = 17, expected = 18 })
check({ line = 'method(value, next)', col = 12, expected = 12 })
check({ line = 'method(value )', col = 12, expected = 12 })
check({ line = 'method(value)', col = 12, expected = 12, unselected = true })
check({ line = 'method(value)', col = 12, expected = 13, unselected = true, tab = true })
check({ line = 'méthod(value)', col = 13, expected = 14 })
for _, kind in ipairs({ kinds.Method, kinds.Function, kinds.Snippet, kinds.Text }) do
    check({ line = 'method()', col = 7, expected = 7, kind = kind })
end
local function node(pos, first, last)
    return { pos = pos, mark = { pos_begin_end = function() return { 0, first }, { 0, last } end } }
end
check({ line = 'method(value)', col = 12, expected = 12, node = node(1, 7, 12) })
check({ line = 'method(value)', col = 12, expected = 12, after_node = node(1, 7, 12) })
check({ line = 'method(value)', col = 12, expected = 13, node = node(0, 12, 12) })
-- An earlier snippet on the same line must not block the jump.
check({ line = 'method(value)', col = 12, expected = 13, node = node(1, 0, 3) })
print(cases .. ' completion cases passed')
