require("onedark").setup({
    style = "deep",
    colors = {},
})

require("onedark").setup({
    colors = {
        red = "#f38759",
        pure_white = "#ffffff",
        method_blue = "#7096fd",
        custom_yellow = "#e9af4c",
        custom_green = "#a6e058",
        property_grey = "#cfcfcf",
        light_blue = "#85cdd6",
        react_component = "#60c2d1",
        bracket = "#ababab",
        string = "#b7d989",
    },

    highlights = {
        ["@conditional"] = { fg = "$method_blue" },
        ["@constructor"] = { fg = "$custom_yellow" },
        ["@string"] = { fg = "$string" },
        ["@function"] = { fg = "#method_blue" },
        ["@method"] = { fg = "$method_blue" },
        ["@type.builtin"] = { fg = "#efbd5d" },
        ["@variable"] = { fg = "$pure_white" },
        ["@property"] = { fg = "$pure_white" },
        ["@operator"] = { fg = "$light_blue" },
        ["@punctuation.bracket"] = { fg = "$bracket" },

        -- lsp
        ["@lsp.type.variable"] = { fg = "$pure_white" },
        ["@lsp.type.interface"] = { fg = "$custom_green", fmt = "italic" },
        ["@lsp.type.property"] = { fg = "$property_grey" },
        ["@lsp.type.method"] = { fg = "$method_blue" },
        ["@lsp.type.function.groovy"] = { fg = "$method_blue" },

        -- typescriptreact
        ["@constructor.tsx"] = { fg = "$react_component", fmt = "bold" },
        ["@constructor.javascript"] = { fg = "$react_component", fmt = "bold" },
        ["@lsp.typemod.function.defaultLibrary"] = { fg = "$method_blue" },
        ["@lsp.type.function.typescriptreact"] = { fg = "$method_blue" },
        ["@lsp.type.class.typescriptreact"] = { fg = "$custom_yellow" },
        ["@tag.attribute.tsx"] = { fg = "$yellow", fmt = "italic" },
    },
})

require("onedark").load()
