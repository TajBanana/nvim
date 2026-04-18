return {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("onedark").setup({
            style = "deep",
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
                ["@lsp.type.function.typescript"] = { fg = "$method_blue" },
                ["@tag.attribute.tsx"] = { fg = "$yellow", fmt = "italic" },
                ["@tag.builtin.tsx"] = { fg = "$light_blue" },
                ["@tag.tsx"] = { fg = "$yellow" },
                ["@tag.delimiter.tsx"] = { fg = "$light_blue", fmt = "bold" },

                -- kotlin
                ["@lsp.type.type.kotlin"] = { fg = "#00B6C9" },
                ["@variable.member.kotlin"] = { fg = "$method_blue" },
                ["@function.builtin.kotlin"] = { fg = "$method_blue", fmt = "italic" },

                -- json
                ["@property.json"] = { fg = "#ea90fc" },

                -- yaml
                ["@property.yaml"] = { fg = "#f76b60" },
            },
        })
        require("onedark").load()
    end,
}
