vim.g.loaded_netrw = 1
vim.g.loaded_nerwPlugin = 1

require('nvim-tree').setup{
    view = {
        adaptive_size = true,
    },
    update_focused_file = {
        enable = true
    }
}

vim.keymap.set('n', '<A-1>', ':NvimTreeFindFileToggle<CR>')

