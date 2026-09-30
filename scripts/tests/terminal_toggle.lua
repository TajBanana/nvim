-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/terminal_toggle.lua
-- F2 terminal toggle: per-tab lookup, last-window hide, dead-terminal cleanup.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.shell = 'sh'
local t = require('tajbanana.terminal')
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end
local function wins_showing(buf)
    local n = 0
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(w) == buf then n = n + 1 end
    end
    return n
end

t.toggle() -- open in tab 1
vim.cmd('stopinsert')
local buf = vim.api.nvim_get_current_buf()
eq(vim.bo[buf].buftype, 'terminal', 'F2 opens a terminal')
vim.cmd('tabnew')
t.toggle() -- open in tab 2
vim.cmd('stopinsert')
vim.cmd('tabprevious')
t.toggle() -- tab 1 already shows it: F2 must HIDE it, not open a second window
eq(wins_showing(buf), 0, 'F2 in a tab that shows the terminal hides it there')

-- The terminal as the only window: F2 hides it without E444.
vim.cmd('tabonly | only')
t.toggle()
vim.cmd('stopinsert | only')
local ok, err = pcall(t.toggle)
eq(ok, true, 'F2 with the terminal as the only window: ' .. tostring(err))
eq(vim.api.nvim_get_current_buf() ~= buf, true, 'the window shows another buffer')
eq(vim.api.nvim_buf_is_valid(buf), true, 'the terminal stays alive (hidden)')

-- The same with a floating window open (ui2 keeps message floats around).
t.toggle()
vim.cmd('stopinsert | only')
local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false,
    { relative = 'editor', row = 1, col = 1, width = 10, height = 2 })
ok, err = pcall(t.toggle)
eq(ok, true, 'F2 as the only split, with a float open: ' .. tostring(err))
pcall(vim.api.nvim_win_close, float, true)

-- A dead terminal still visible in another tab is forgotten, then wiped once
-- no window shows it (no pile-up of [Process exited] buffers).
t.toggle()
vim.cmd('stopinsert')
vim.cmd('tabnew | buffer ' .. buf)
vim.cmd('tabprevious')
vim.fn.chansend(vim.bo[buf].channel, 'exit 3\n')
vim.wait(3000, function() return vim.fn.jobwait({ vim.bo[buf].channel }, 0)[1] ~= -1 end)
t.toggle() -- hide here
t.toggle() -- dead: a fresh terminal opens
eq(#vim.api.nvim_list_tabpages(), 2, 'the other tab showing the dead terminal survives')
vim.cmd('tabnext | enew')
eq(vim.api.nvim_buf_is_valid(buf), false, 'the dead terminal is wiped once no window shows it')

print(('%d terminal toggle checks passed'):format(checks))
vim.cmd('qa!')
