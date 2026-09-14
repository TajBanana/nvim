local M = {}

local function in_placeholder()
    local node = require("luasnip.session").current_nodes[vim.api.nvim_get_current_buf()]
    -- $0 is the snippet exit, not an argument placeholder. Compare byte
    -- positions rather than LuaSnip's in_snippet(), which only checks rows.
    if not node or not node.pos or node.pos <= 0 or not node.mark then return false end
    local ok, first, last = pcall(node.mark.pos_begin_end, node.mark)
    if not ok then return false end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    return (row > first[1] or (row == first[1] and col >= first[2]))
        and (row < last[1] or (row == last[1] and col <= last[2]))
end

function M.confirm(cmp, select)
    local entry = cmp.get_selected_entry()
    if not entry and select then entry = cmp.get_entries()[1] end
    local kinds = vim.lsp.protocol.CompletionItemKind
    local kind = entry and entry:get_kind()
    local is_value = kind == kinds.Variable or kind == kinds.Field
        or kind == kinds.Property or kind == kinds.Constant
    local was_placeholder = in_placeholder()
    return cmp.confirm({ select = select }, function()
        -- The confirmation callback runs after insertion and snippet expansion.
        -- Only the explicitly accepted value can trigger this, never typing or
        -- accepting a method/snippet. Skip one ')' even inside nested calls.
        if not is_value or was_placeholder or in_placeholder() then return end
        local cursor = vim.api.nvim_win_get_cursor(0)
        local col = cursor[2]
        if vim.api.nvim_get_current_line():sub(col + 1, col + 1) == ")" then
            vim.api.nvim_win_set_cursor(0, { cursor[1], col + 1 })
        end
    end)
end

return M
