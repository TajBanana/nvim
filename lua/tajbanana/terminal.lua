-- Bottom terminal split toggled with F2 (normal + terminal mode). One terminal
-- buffer is reused across toggles; hiding keeps it alive so scrollback persists.
local M = {}

local term_buf, term_win

-- The tracked window only counts as "the terminal, here and now": it must still
-- exist, still be showing the terminal buffer, and live in the CURRENT tabpage.
-- Without the last two checks, F2 from another tabpage hid whatever window the
-- stale handle pointed at (closing that tabpage if it was the last window there).
local function term_win_visible()
    return term_win
        and vim.api.nvim_win_is_valid(term_win)
        and term_buf
        and vim.api.nvim_win_get_buf(term_win) == term_buf
        and vim.api.nvim_win_get_tabpage(term_win) == vim.api.nvim_get_current_tabpage()
end

function M.toggle()
    if term_win_visible() then
        vim.api.nvim_win_hide(term_win)
        term_win = nil
    else
        if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
            vim.cmd("botright sbuf " .. term_buf)
        else
            vim.cmd("botright split | terminal")
            term_buf = vim.api.nvim_get_current_buf()
        end
        term_win = vim.api.nvim_get_current_win()
        vim.cmd("startinsert")
    end
end

function M.setup()
    vim.keymap.set("n", "<F2>", M.toggle, { silent = true, desc = "Toggle terminal" })
    -- From terminal mode, leave it first (<C-\><C-n>) so the toggle runs in
    -- normal mode.
    vim.keymap.set(
        "t",
        "<F2>",
        [[<C-\><C-n><cmd>lua require("tajbanana.terminal").toggle()<CR>]],
        { silent = true, desc = "Toggle terminal" }
    )
end

return M
