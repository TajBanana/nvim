vim.keymap.set('n', '<leader>tt', ':TestNearest -strategy=neovim<CR>', { silent = true })
vim.keymap.set('n', '<leader>tf', ':TestFile -strategy=neovim<CR>', { silent = true })
vim.keymap.set('n', '<leader>ta', ':TestSuite <CR>', { silent = true })
