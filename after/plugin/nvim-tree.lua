vim.g.loaded_netrw = 1
vim.g.loaded_nerwPlugin = 1

require('nvim-tree').setup()

vim.keymap.set('n', '<c-n>', ':NvimTreeFindFileToggle<CR>')

