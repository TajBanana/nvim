-- Bottom terminal split toggled with F2 (normal + terminal mode). One terminal
-- buffer is reused across toggles; hiding keeps it alive so scrollback persists.
local M = {}

local term_buf, term_win

function M.toggle()
    if term_win and vim.api.nvim_win_is_valid(term_win) then
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
