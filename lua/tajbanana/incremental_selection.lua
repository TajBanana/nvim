-- IntelliJ-style incremental selection via native treesitter (Option+Up/Down):
-- <M-Up> grows the visual selection to the enclosing node, <M-Down> shrinks it.
--
-- The node stack is buffer-scoped. A treesitter node belongs to the buffer it
-- came from, so growing/shrinking with buffer A's nodes while buffer B is
-- current would select the wrong range (or throw from an out-of-range mark).
-- We record which buffer the stack belongs to and rebuild it on a mismatch.
--
-- The stack is also dropped when visual mode ends or the buffer is edited --
-- see reset(). Without that, a later `v` + <M-Up> would expand from the PREVIOUS
-- session's node instead of the current selection, and a retained node whose
-- buffer has since been edited reports stale pre-edit coordinates (its tree is
-- kept alive by the reference, so :parent() still succeeds) which can point past
-- the end of the buffer.
local M = {}

local stack = {}
local stack_buf = nil

local function reset()
    stack = {}
    stack_buf = nil
end

-- Convert a node's END point, which treesitter reports as EXCLUSIVE, into the
-- inclusive (row, col) that nvim_buf_set_mark needs.
--
-- A node that swallows a trailing newline ends at column 0 of the FOLLOWING
-- line, so the naive `er + 1, ec - 1` both overshoots the row and underflows the
-- column. That is not a rare edge case: nvim's parser feeds a trailing \n after
-- the last line, so the ROOT node always ends at (line_count, 0) -- meaning the
-- natural end state of "keep expanding" reliably produced
-- E5108: Invalid 'line': out of range.
local function inclusive_end(er, ec)
    local last = vim.api.nvim_buf_line_count(0)
    if ec > 0 then
        -- Same line, one column back off the exclusive end.
        return math.min(er + 1, last), ec - 1
    end
    -- Column 0: the node really ends at the end of the previous line.
    local row = math.max(1, math.min(er, last))
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    return row, math.max(0, #line - 1)
end

local function select_node(node)
    local sr, sc, er, ec = node:range()
    local last = vim.api.nvim_buf_line_count(0)
    local start_row = math.max(1, math.min(sr + 1, last))
    local end_row, end_col = inclusive_end(er, ec)
    if end_row < start_row then
        return false
    end
    vim.api.nvim_buf_set_mark(0, "<", start_row, sc, {})
    vim.api.nvim_buf_set_mark(0, ">", end_row, end_col, {})
    -- Re-enter visual CHARWISE explicitly rather than a bare `gv`: gv reuses
    -- whatever visual mode was last used, so after a linewise (V) or blockwise
    -- selection every expansion would be rounded out to whole lines or a
    -- rectangle, and a following y/d would take more than the node.
    vim.cmd("normal! gv")
    if vim.fn.mode() ~= "v" then
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { start_row, sc })
        vim.cmd("normal! o")
        vim.api.nvim_win_set_cursor(0, { end_row, end_col })
    end
    return true
end

-- Grow to the nearest ancestor that actually covers MORE text than the current
-- node. Treesitter chains often stack several nodes on identical ranges, which
-- would otherwise make a keypress look like it did nothing.
local function grow_from(node)
    local sr, sc, er, ec = node:range()
    local parent = node:parent()
    while parent do
        local psr, psc, per, pec = parent:range()
        if psr ~= sr or psc ~= sc or per ~= er or pec ~= ec then
            return parent
        end
        parent = parent:parent()
    end
    return nil
end

function M.setup()
    -- Normal mode has nothing to shrink yet, so <M-Up> is the sole entry point:
    -- start a fresh stack rooted at the node under the cursor.
    vim.keymap.set("n", "<M-Up>", function()
        local node = vim.treesitter.get_node()
        -- An empty or brand-new buffer has no node worth selecting; bail rather
        -- than erroring on the very first keypress.
        if not node then
            return
        end
        stack = { node }
        stack_buf = vim.api.nvim_get_current_buf()
        if not select_node(node) then
            reset()
        end
    end, { desc = "Start incremental selection" })

    vim.keymap.set("x", "<M-Up>", function()
        -- Drop a stack left over from another buffer, then grow to the parent
        -- (or, from an empty stack, select the node under the cursor).
        if stack_buf ~= vim.api.nvim_get_current_buf() then
            reset()
        end
        local current = stack[#stack]
        local node = current and grow_from(current) or vim.treesitter.get_node()
        -- No enclosing node left (already at the root): keep the current
        -- selection instead of throwing.
        if not node then
            return
        end
        stack[#stack + 1] = node
        stack_buf = vim.api.nvim_get_current_buf()
        if not select_node(node) then
            table.remove(stack)
        end
    end, { desc = "Expand selection" })

    vim.keymap.set("x", "<M-Down>", function()
        if stack_buf == vim.api.nvim_get_current_buf() and #stack > 1 then
            table.remove(stack)
            select_node(stack[#stack])
        end
    end, { desc = "Shrink selection" })

    -- Leaving visual mode ends the session, and any edit invalidates the stored
    -- ranges. Either way the next <M-Up> must start from the cursor again.
    local grp = vim.api.nvim_create_augroup("IncrementalSelectionReset", { clear = true })
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = grp,
        pattern = "[vV\22]*:*",
        callback = function()
            -- Still visual (v -> V, or o-pending inside visual): keep the stack.
            if not vim.fn.mode():match("^[vV\22]") then
                reset()
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = grp,
        callback = function(ev)
            if ev.buf == stack_buf then
                reset()
            end
        end,
    })
end

return M
