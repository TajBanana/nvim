local M = {}

-- Whether a popup may take focus now: plain Normal mode and not in the middle
-- of a key sequence. Checking only the FIRST letter of the mode let through
-- "niI" (Insert-mode <C-o>: typing `yy` there approved a download) and "no"
-- (operator pending); `blocking` is set while a mapping waits for more keys.
-- Also used by lsp_status.lua's expiry prompt.
-- Also not from the command-line window (q:, q/): it reports plain Normal
-- mode, but opening a window there fails (E11); the update then never got an
-- answer and held its cross-process lock until Neovim exited.
function M.can_show()
    local mode = vim.api.nvim_get_mode()
    return mode.mode == "n" and not mode.blocking and vim.fn.getcmdwintype() == ""
end

-- Async confirmations must not steal keystrokes while the user is typing.
function M.ask(title, lines, accept_label, callback)
    local function show()
        if not M.can_show() then
            vim.defer_fn(show, 500)
            return
        end
        local content = vim.list_extend(vim.deepcopy(lines), { "", "[y] " .. accept_label .. "    [n] dismiss" })
        local width = 1
        for _, line in ipairs(content) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
        width = math.min(width + 2, math.max(1, vim.o.columns - 4))
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].modifiable = false
        local previous = vim.api.nvim_get_current_win()
        local ok_win, win = pcall(vim.api.nvim_open_win, buf, true, {
            relative = "editor", style = "minimal", border = "rounded",
            title = " " .. title .. " ", title_pos = "left",
            width = width, height = #content,
            row = math.max(0, math.floor((vim.o.lines - #content) / 2) - 1),
            col = math.max(0, math.floor((vim.o.columns - width) / 2)),
            noautocmd = true,
        })
        if not ok_win then
            -- Any other place a window cannot open right now: wipe the buffer
            -- and try again shortly, rather than leaving the caller unanswered.
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
            vim.defer_fn(show, 500)
            return
        end
        local resolved = false
        local function resolve(accepted)
            if resolved then return end
            resolved = true
            if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
            if vim.api.nvim_win_is_valid(previous) then pcall(vim.api.nvim_set_current_win, previous) end
            callback(accepted)
        end
        vim.keymap.set("n", "y", function() resolve(true) end, { buffer = buf, nowait = true, silent = true })
        for _, key in ipairs({ "n", "q", "<Esc>" }) do
            vim.keymap.set("n", key, function() resolve(false) end, { buffer = buf, nowait = true, silent = true })
        end
        vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = buf, once = true,
            callback = function()
                if not resolved then
                    resolved = true
                    vim.schedule(function() callback(false) end)
                end
            end,
        })
    end
    show()
end

return M
