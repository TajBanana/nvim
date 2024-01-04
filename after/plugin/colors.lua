require('onedark').setup {
    style = 'deep',
    colors = {
        red = '#f37759',
    }
}

require('onedark').setup {
    highlights= {
        ['@conditional'] = {fg = '#7096fd'},
        ['@constructor'] = {fg = '#e9af4c'},
        ['@lsp.type.class.typescriptreact'] = {fg = '#e9af4c'},
        ['@string'] = {fg = '#b8e67b'},
        ['@function'] = {fg = '#7096fe'},
        ['@method'] = {fg = '#7096fd'},
        ['@type.builtin'] = {fg = '#efbd5d'},
        ['@variable'] = {fg = '#ffffff'},
        ['@property'] = {fg = '#ffffff'},
        ['@operator'] = {fg = '#85cdd6'},
        ['@punctuation.bracket'] = {fg = '#ababab'},
        ['@lsp.type.variable'] = {fg = '#ffffff'},
        ['@lsp.type.interface'] = {fg = '#b8e67b', fmt = 'italic'},
        ['@lsp.type.property'] = {fg = '#bebebe'},
        ['@lsp.type.method'] = {fg = '#7096fd'},
        ['@lsp.type.function.groovy'] = {fg = '#7096fd'},
        ['@lsp.typemod.function.defaultLibrary'] = {fg = '#7096fd'},

    }
}

require('onedark').load()
