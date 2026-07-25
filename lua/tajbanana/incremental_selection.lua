-- IntelliJ-style incremental selection via native treesitter (Option+Up/Down):
-- <M-Up> grows the visual selection to the enclosing node, <M-Down> shrinks it.
--
-- The node stack is buffer-scoped. A treesitter node belongs to the buffer it
-- came from, so growing/shrinking with buffer A's nodes while buffer B is
-- current would select the wrong range (or throw from an out-of-range mark).
-- We record which buffer the stack belongs to and rebuild it on a mismatch.
local M = {}

local stack = {}
local stack_buf = nil

local function select_node(node)
    local sr, sc, er, ec = node:range()
    vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
    vim.api.nvim_buf_set_mark(0, ">", er + 1, math.max(0, ec - 1), {})
    vim.cmd("normal! gv")
end

function M.setup()
    -- Normal mode has nothing to shrink yet, so <M-Up> is the sole entry point:
    -- start a fresh stack rooted at the node under the cursor.
    vim.keymap.set("n", "<M-Up>", function()
        local node = vim.treesitter.get_node()
        if node then
            stack = { node }
            stack_buf = vim.api.nvim_get_current_buf()
            select_node(node)
        end
    end, { desc = "Start incremental selection" })

    vim.keymap.set("x", "<M-Up>", function()
        -- Drop a stack left over from another buffer, then grow to the parent
        -- (or, from an empty stack, select the node under the cursor).
        if stack_buf ~= vim.api.nvim_get_current_buf() then
            stack = {}
        end
        local current = stack[#stack]
        local node = current and current:parent() or vim.treesitter.get_node()
        if node then
            stack[#stack + 1] = node
            stack_buf = vim.api.nvim_get_current_buf()
            select_node(node)
        end
    end, { desc = "Expand selection" })

    vim.keymap.set("x", "<M-Down>", function()
        if stack_buf == vim.api.nvim_get_current_buf() and #stack > 1 then
            table.remove(stack)
            select_node(stack[#stack])
        end
    end, { desc = "Shrink selection" })
end

return M
