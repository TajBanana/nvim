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

-- nvm is lazy-loaded in .zshrc, so node is usually missing from PATH when
-- nvim starts and Mason's node-based LSP servers (ts_ls, yamlls, ...) die
-- with exit 127. Prepend the newest nvm node unless node is already found.
if vim.fn.executable("node") == 0 then
    local bins = vim.fn.glob(vim.env.HOME .. "/.nvm/versions/node/*/bin", true, true)
    table.sort(bins, function(a, b)
        local maj_a, min_a = a:match("v(%d+)%.(%d+)")
        local maj_b, min_b = b:match("v(%d+)%.(%d+)")
        if maj_a ~= maj_b then return tonumber(maj_a) < tonumber(maj_b) end
        return tonumber(min_a) < tonumber(min_b)
    end)
    if #bins > 0 then
        vim.env.PATH = bins[#bins] .. ":" .. vim.env.PATH
    end
end

-- rustup's toolchain proxies aren't on the default PATH (brew keeps them in
-- its own prefix); rust-analyzer needs cargo/rustc visible to load workspaces
if vim.fn.executable("cargo") == 0 then
    for _, dir in ipairs({ vim.env.HOME .. "/.cargo/bin", "/opt/homebrew/opt/rustup/bin" }) do
        if vim.fn.isdirectory(dir) == 1 then
            vim.env.PATH = vim.env.PATH .. ":" .. dir
            break
        end
    end
end

vim.api.nvim_set_hl(0, "LineNr", { fg = "#737373" })

-- Set cursor blink rate (in milliseconds)
vim.cmd([[set guicursor+=a:blinkon500]])

vim.opt.ignorecase = true
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true, desc = "Half page down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true, desc = "Half page up (centered)" })

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
vim.keymap.set('n', '<F2>', ToggleTerminal, { silent = true, desc = "Toggle terminal" })
vim.keymap.set('t', '<F2>', [[<C-\><C-n>:lua ToggleTerminal()<CR>]], { silent = true, desc = "Toggle terminal" })

-- Incremental selection using native treesitter (like IntelliJ Option+Up/Down)
local ts_node_stack = {}

local function select_node(node)
    local sr, sc, er, ec = node:range()
    vim.api.nvim_buf_set_mark(0, "<", sr + 1, sc, {})
    vim.api.nvim_buf_set_mark(0, ">", er + 1, ec - 1, {})
    vim.cmd("normal! gv")
end

vim.keymap.set("n", "<M-Up>", function()
    local node = vim.treesitter.get_node()
    if node then
        ts_node_stack = { node }
        select_node(node)
    end
end, { desc = "Start incremental selection" })

vim.keymap.set("n", "<M-Down>", function()
    local node = vim.treesitter.get_node()
    if node then
        ts_node_stack = { node }
        select_node(node)
    end
end, { desc = "Start incremental selection" })

vim.keymap.set("x", "<M-Up>", function()
    local current = ts_node_stack[#ts_node_stack]
    local node = current and current:parent() or vim.treesitter.get_node()
    if node then
        table.insert(ts_node_stack, node)
        select_node(node)
    end
end, { desc = "Expand selection" })

vim.keymap.set("x", "<M-Down>", function()
    if #ts_node_stack > 1 then
        table.remove(ts_node_stack)
        select_node(ts_node_stack[#ts_node_stack])
    end
end, { desc = "Shrink selection" })
