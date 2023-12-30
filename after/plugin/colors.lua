function ColorMyTerminal()
    require('onedark').setup {
    style = 'darker',
    colors = {
        red = '#bf6528'
    }
}
    require('onedark').load()
	vim.cmd("colorscheme onedark")
	vim.api.nvim_set_hl(0, 'LineNr', { fg = '#737373'} )
end

ColorMyTerminal()

