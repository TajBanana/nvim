vim.g.mapleader = " "

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
local undodir = vim.fn.stdpath("state") .. "/undodir"
vim.fn.mkdir(undodir, "p")
vim.opt.undodir = undodir
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "100"

vim.opt.splitright = true
vim.opt.clipboard:append("unnamedplus")

vim.api.nvim_set_hl(0, "LineNr", { fg = "#737373" })

-- Set cursor blink rate (in milliseconds)
vim.cmd([[set guicursor+=a:blinkon500]])

vim.opt.ignorecase = true
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })

local term_buf = nil
local term_win = nil

function ToggleTerminal()
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

-- Map F2 in both Normal and Terminal modes to the same function
vim.keymap.set('n', '<F2>', ToggleTerminal, { silent = true })
vim.keymap.set('t', '<F2>', [[<C-\><C-n>:lua ToggleTerminal()<CR>]], { silent = true })
