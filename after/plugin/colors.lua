function ColorMyTerminal()
	vim.cmd("colorscheme tokyonight-storm")
	vim.api.nvim_set_hl(0, 'LineNr', { fg = '#737373'} )
end

ColorMyTerminal()


