-- Bottom terminal split toggled with F2 (normal + terminal mode). One terminal
-- buffer is reused across toggles; hiding keeps it alive so scrollback persists.
local M = {}

local term_buf

-- The terminal's window in the CURRENT tabpage, if any. Looked up each time
-- rather than tracked: a single remembered handle went stale across tabpages
-- (F2 then hid whatever window it pointed at, or opened a second window on the
-- terminal in a tab that already showed it).
local function term_win_here()
    if not (term_buf and vim.api.nvim_buf_is_valid(term_buf)) then
        return nil
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == term_buf then
            return win
        end
    end
end

-- The buffer outlives its shell when the shell exits NON-zero (Neovim only
-- auto-wipes a terminal whose job exits 0), leaving "[Process exited 1]". Reusing
-- that buffer brought back a dead terminal, so treat it as gone. It is only
-- wiped now when no window shows it: deleting a buffer closes its windows, which
-- closed a whole tabpage whose only window was the dead terminal. A visible one
-- is forgotten and set to wipe itself once no window shows it, so dead
-- terminals do not pile up in the buffer list.
local function term_alive()
    if not (term_buf and vim.api.nvim_buf_is_valid(term_buf)) then
        return false
    end
    local chan = vim.bo[term_buf].channel
    if chan == 0 or vim.fn.jobwait({ chan }, 0)[1] ~= -1 then
        if #vim.fn.win_findbuf(term_buf) == 0 then
            pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
        else
            vim.bo[term_buf].bufhidden = "wipe"
        end
        term_buf = nil
        return false
    end
    return true
end

-- Hide the terminal window. The last window of a tabpage cannot be closed
-- (E444), so there the window switches to the alternate buffer (or an empty
-- one) instead; the terminal stays alive, hidden.
local function hide(win)
    -- Count only real split windows: floats (ui2's message windows, fidget,
    -- hover docs) are tabpage windows too, and counting them tried to close
    -- the last split anyway -- E444 whenever a message had been shown.
    local splits = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(w).relative == "" then
            splits = splits + 1
        end
    end
    if splits > 1 then
        vim.api.nvim_win_hide(win)
        return
    end
    vim.api.nvim_win_call(win, function()
        local alt = vim.fn.bufnr("#")
        if alt > 0 and alt ~= term_buf and vim.api.nvim_buf_is_loaded(alt) then
            vim.cmd("buffer " .. alt)
        else
            vim.cmd("enew")
        end
    end)
end

function M.toggle()
    local win = term_win_here()
    if win then
        hide(win)
    else
        if term_alive() then
            vim.cmd("botright sbuf " .. term_buf)
        else
            vim.cmd("botright split | terminal")
            term_buf = vim.api.nvim_get_current_buf()
            vim.bo[term_buf].bufhidden = "hide"
        end
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
