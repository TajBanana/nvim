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
local selecting = false

local yaml_blocks = {
    block_mapping_pair = true, block_mapping = true, block_node = true,
    block_sequence_item = true, block_sequence = true,
}

local function node_range(node)
    local sr, sc, er, ec = node:range()
    if vim.bo.filetype == "helm" and yaml_blocks[node:type()] then
        local line = vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or ""
        -- The YAML injection omits template actions. An unquoted value at the
        -- end of a mapping can therefore lie beyond the YAML node's endpoint.
        if line:sub(ec + 1):match("^%s*{{") then
            local parser = vim.treesitter.get_parser(0)
            local root = parser:parse()[1]:root()
            -- Find the next text segment after the omitted action. Its start
            -- includes both closing braces and any multiline template action.
            local function next_text(parent)
                for child in parent:iter_children() do
                    local cr, cc = child:start()
                    if child:type() == "text" and (cr > er or (cr == er and cc > ec)) then
                        return cr, cc
                    end
                    local row, col = next_text(child)
                    if row then return row, col end
                end
            end
            local row, col = next_text(root)
            if row then er, ec = row, col end
        end
    end
    -- Entries and blocks should copy with their first line's indentation (and
    -- list marker), rather than starting halfway across that line. Scalar word
    -- selections remain precise until expansion reaches an entry.
    -- "yaml" plus its compound filetypes (yaml.helm-values, yaml.gitlab, ...).
    local ft = vim.bo.filetype
    if (ft == "helm" or ft == "yaml" or vim.startswith(ft, "yaml.")) and yaml_blocks[node:type()] then
        sc = 0
        if sr == er then
            ec = #(vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or "")
        end
    end
    return sr, sc, er, ec
end

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
        local row = math.min(er + 1, last)
        local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
        local char = vim.fn.matchstr(line:sub(1, ec), ".$")
        return row, math.max(0, ec - #char)
    end
    -- Column 0: the node really ends at the end of the previous line.
    local row = math.max(1, math.min(er, last))
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    return row, math.max(0, #line - #vim.fn.matchstr(line, ".$"))
end

local function select_node(node)
    local sr, sc, er, ec = node_range(node)
    local last = vim.api.nvim_buf_line_count(0)
    local start_row = math.max(1, math.min(sr + 1, last))
    local end_row, end_col = inclusive_end(er, ec)
    if end_row < start_row then
        return false
    end
    vim.api.nvim_buf_set_mark(0, "<", start_row, sc, {})
    vim.api.nvim_buf_set_mark(0, ">", end_row, end_col, {})
    -- Build an explicit characterwise selection. gv swaps selections when
    -- already visual and can trigger ModeChanged, discarding our own stack.
    selecting = true
    vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
    vim.api.nvim_win_set_cursor(0, { start_row, sc })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { end_row, end_col })
    selecting = false
    return true
end

local function same_selection(a, b)
    local ar, ac, aer, aec = node_range(a)
    local br, bc, ber, bec = node_range(b)
    aer, aec = inclusive_end(aer, aec)
    ber, bec = inclusive_end(ber, bec)
    return ar == br and ac == bc and aer == ber and aec == bec
end

-- Grow to the nearest ancestor that actually covers MORE text than the current
-- node. Treesitter chains often stack several nodes on identical ranges, which
-- would otherwise make a keypress look like it did nothing.
local function grow_from(node)
    local sr, sc, er, ec = node_range(node)
    local parent = node:parent()
    while parent do
        if not same_selection(node, parent) then
            break
        end
        parent = parent:parent()
    end
    if vim.bo.filetype == "helm" then
        -- A Go-template expression's AST parent may be the whole file. Bridge
        -- to the smallest YAML ancestor that contains the complete expression.
        local line = vim.api.nvim_buf_get_lines(0, sr, sr + 1, false)[1] or ""
        local candidate = vim.treesitter.get_node({
            pos = { sr, #(line:match("^%s*") or "") }, ignore_injections = false,
        })
        while candidate do
            local ar, ac, br, bc = node_range(candidate)
            local contains = (ar < sr or (ar == sr and ac <= sc))
                and (br > er or (br == er and bc >= ec))
            if yaml_blocks[candidate:type()] and contains and not same_selection(node, candidate) then
                if not parent then return candidate end
                local pr, pc, qr, qc = node_range(parent)
                if (ar > pr or (ar == pr and ac >= pc))
                    and (br < qr or (br == qr and bc <= qc)) then
                    return candidate
                end
                break
            end
            candidate = candidate:parent()
        end
    end
    return parent
end

local function cursor_node()
    local ok, parser = pcall(vim.treesitter.get_parser, 0)
    if not ok or not parser then return nil end
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local col = math.max(pos[2], #(line:match("^%s*") or ""))
    parser:parse({ pos[1] - 1, pos[1] })
    return vim.treesitter.get_node({ pos = { pos[1] - 1, col }, ignore_injections = false })
end

function M.setup()
    -- Normal mode has nothing to shrink yet, so <M-Up> is the sole entry point:
    -- start a fresh stack rooted at the node under the cursor.
    vim.keymap.set("n", "<M-Up>", function()
        local node = cursor_node()
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
        local node
        if current then
            node = grow_from(current)
        else
            node = cursor_node()
        end
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
            if not selecting and not vim.fn.mode():match("^[vV\22]") then
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
