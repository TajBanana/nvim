return {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("onedark").setup({
            style = "deep",
            colors = {
                -- Material Darker palette
                md_blue      = "#82AAFF",   -- functions, methods
                md_yellow    = "#FFCB6B",   -- classes, types, constructors
                md_purple    = "#C792EA",   -- interfaces, keywords (some), jsx attributes
                md_cyan      = "#89DDFF",   -- keywords, operators, punctuation
                md_green     = "#C3E88D",   -- strings
                md_orange    = "#F78C6C",   -- numbers, parameters
                md_red       = "#F07178",   -- tags (html/jsx built-ins), errors
                md_white     = "#EEFFFF",   -- variables, default text
                md_grey_blue = "#B2CCD6",   -- properties, fields
                md_comment   = "#546E7A",   -- comments
            },
            highlights = {
                -- keywords: base + all subtypes (onedark base overrides some, so be explicit)
                -- IntelliJ Material Darker style globally: purple italic
                ["@keyword"]               = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.import"]        = { fg = "$md_purple", fmt = "italic" },  -- import/export/require
                ["@keyword.return"]        = { fg = "$md_purple", fmt = "italic" },  -- return
                ["@keyword.repeat"]        = { fg = "$md_purple", fmt = "italic" },  -- for/while/do
                ["@keyword.operator"]      = { fg = "$md_purple", fmt = "italic" },  -- typeof/instanceof/in/of/new
                ["@keyword.function"]      = { fg = "$md_purple", fmt = "italic" },  -- function keyword
                ["@keyword.coroutine"]     = { fg = "$md_purple", fmt = "italic" },  -- async/await
                ["@keyword.exception"]     = { fg = "$md_purple", fmt = "italic" },  -- try/catch/throw/finally
                ["@keyword.modifier"]      = { fg = "$md_purple", fmt = "italic" },  -- public/private/static/final/readonly
                ["@keyword.conditional"]   = { fg = "$md_purple", fmt = "italic" },  -- if/else/switch (newer name)
                ["@keyword.directive"]     = { fg = "$md_purple", fmt = "italic" },  -- preprocessor directives
                ["@conditional"]           = { fg = "$md_purple", fmt = "italic" },  -- if/else/switch (older name, keep for compat)

                -- functions and calls
                ["@function"]              = { fg = "$md_blue" },
                ["@function.call"]         = { fg = "$md_blue" },  -- calling a function
                ["@function.builtin"]      = { fg = "$md_blue" },
                ["@method"]                = { fg = "$md_blue" },
                ["@method.call"]           = { fg = "$md_blue" },  -- calling a method
                ["@constructor"]           = { fg = "$md_yellow" },

                -- types
                ["@type"]                  = { fg = "$md_yellow" },
                ["@type.builtin"]          = { fg = "$md_cyan" },  -- string/number/boolean/void
                ["@namespace"]             = { fg = "$md_yellow" }, -- namespace/module (older name)
                ["@module"]                = { fg = "$md_yellow" }, -- namespace/module (newer name)

                -- variables
                ["@variable"]              = { fg = "$md_white" },
                ["@variable.builtin"]      = { fg = "$md_purple", fmt = "italic" },  -- this/super/self (IJ: keyword-like)
                ["@parameter"]             = { fg = "$md_orange" },
                ["@property"]              = { fg = "$md_grey_blue" },

                -- constants
                ["@constant"]              = { fg = "$md_white" },
                ["@constant.builtin"]      = { fg = "$md_purple", fmt = "italic" },  -- true/false/null/undefined/NaN (IJ: keyword-like)

                -- literals
                ["@string"]                = { fg = "$md_green" },
                ["@string.escape"]         = { fg = "$md_cyan" },  -- \n \t \" etc.
                ["@string.regexp"]         = { fg = "$md_orange" }, -- regex patterns
                ["@number"]                = { fg = "$md_orange" },
                ["@float"]                 = { fg = "$md_orange" },

                -- punctuation
                ["@operator"]              = { fg = "$md_cyan" },
                ["@punctuation.bracket"]   = { fg = "$md_cyan" },
                ["@punctuation.delimiter"] = { fg = "$md_cyan" },
                ["@punctuation.special"]   = { fg = "$md_cyan" },  -- ${} in template literals

                -- renamed captures (treesitter main branch): the old names
                -- above are kept for compat, these are the current ones —
                -- without them onedark defaults leak through
                ["@function.method"]        = { fg = "$md_blue" },
                ["@function.method.call"]   = { fg = "$md_blue" },
                ["@variable.parameter"]     = { fg = "$md_orange" },
                ["@variable.member"]        = { fg = "$md_grey_blue" },
                ["@boolean"]                = { fg = "$md_purple", fmt = "italic" },
                ["@module.builtin"]         = { fg = "$md_yellow" },
                ["@number.float"]           = { fg = "$md_orange" },
                ["@string.documentation"]   = { fg = "$md_green" },
                ["@string.special.url"]     = { fg = "$md_cyan" },
                ["@character.special"]      = { fg = "$md_cyan" },
                ["@keyword.conditional.ternary"] = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.type"]           = { fg = "$md_purple", fmt = "italic" },
                ["@attribute"]              = { fg = "$md_purple", fmt = "italic" },  -- annotations/decorators (IJ style)
                ["@lsp.typemod.variable.static"]         = { fg = "$md_grey_blue", fmt = "italic" },
                ["@lsp.typemod.variable.defaultLibrary"] = { fg = "$md_cyan" },

                -- markup tags (html/css selectors; tsx/js scoped rules override)
                ["@tag"]           = { fg = "$md_red" },
                ["@tag.builtin"]   = { fg = "$md_red" },
                ["@tag.attribute"] = { fg = "$md_yellow", fmt = "italic" },
                ["@tag.delimiter"] = { fg = "$md_cyan" },

                -- misc
                ["@comment"]               = { fg = "$md_comment" },

                -- <leader>gd picker kind tags
                ["GdTagDef"]  = { fg = "$md_yellow" },
                ["GdTagType"] = { fg = "$md_green", fmt = "italic" },
                ["GdTagImpl"] = { fg = "$md_blue" },
                ["GdTagRef"]  = { fg = "$md_purple" },

                -- lsp (language-agnostic)
                ["@lsp.type.variable"]         = { fg = "$md_white" },
                ["@lsp.type.interface"]        = { fg = "$md_green", fmt = "italic" },  -- interfaces green italic everywhere
                ["@lsp.type.property"]         = { fg = "$md_grey_blue" },
                ["@lsp.type.method"]           = { fg = "$md_blue" },
                ["@lsp.type.function"]         = { fg = "$md_blue" },
                ["@lsp.type.class"]            = { fg = "$md_yellow" },
                ["@lsp.type.enum"]             = { fg = "$md_yellow" },
                ["@lsp.type.enumMember"]       = { fg = "$md_orange" },
                ["@lsp.type.parameter"]        = { fg = "$md_orange" },
                ["@lsp.type.keyword"]          = { fg = "$md_purple", fmt = "italic" },
                ["@lsp.type.namespace"]        = { fg = "$md_yellow" },
                ["@lsp.type.typeParameter"]    = { fg = "$md_yellow" },  -- generics <T>
                ["@lsp.typemod.class.abstract"]   = { fg = "$md_yellow", fmt = "italic" },
                ["@lsp.typemod.method.abstract"]  = { fg = "$md_blue",   fmt = "italic" },
                ["@lsp.typemod.function.defaultLibrary"] = { fg = "$md_blue" },
                ["@lsp.typemod.function.static"]         = { fg = "$md_blue", fmt = "italic" },

                -- java
                ["@lsp.type.annotation.java"]        = { fg = "$md_purple", fmt = "italic" },
                ["@lsp.type.typeParameter.java"]      = { fg = "$md_yellow" },
                ["@lsp.type.function.groovy"]         = { fg = "$md_blue" },
                ["@lsp.typemod.method.static.java"]   = { fg = "$md_blue",      fmt = "italic" },
                ["@lsp.typemod.variable.static.java"] = { fg = "$md_grey_blue", fmt = "italic" },

                -- kotlin: IntelliJ Material Darker parity (pixel-sampled from
                -- the IDE; functions stay blue and class declarations yellow,
                -- unlike the tsx scheme)
                ["@lsp.type.type.kotlin"]             = { fg = "$md_yellow" },
                ["@lsp.type.annotation.kotlin"]       = { fg = "$md_purple", fmt = "italic" },
                ["@lsp.type.typeParameter.kotlin"]    = { fg = "$md_yellow" },
                ["@variable.member.kotlin"]           = { fg = "$md_white" },
                ["@function.builtin.kotlin"]          = { fg = "$md_blue", fmt = "italic" },
                ["@keyword.kotlin"]             = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.conditional.kotlin"] = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.coroutine.kotlin"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.directive.kotlin"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.exception.kotlin"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.function.kotlin"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.import.kotlin"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.modifier.kotlin"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.repeat.kotlin"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.return.kotlin"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.type.kotlin"]        = { fg = "$md_purple", fmt = "italic" },
                ["@lsp.type.keyword.kotlin"]    = { fg = "$md_purple", fmt = "italic" },
                ["@attribute.kotlin"]           = { fg = "$md_purple", fmt = "italic" },
                -- constructor props / param declarations white; named-argument
                -- usages keep the base parameter orange
                ["@lsp.typemod.parameter.declaration.kotlin"] = { fg = "$md_white" },
                ["@lsp.type.property.kotlin"]   = { fg = "$md_white" },

                -- typescript / javascript (tsx + ts + js + jsx)
                ["@constructor.tsx"]                         = { fg = "$md_yellow", fmt = "bold" },
                ["@constructor.javascript"]                  = { fg = "$md_yellow", fmt = "bold" },
                ["@lsp.type.function.typescript"]            = { fg = "$md_yellow" },
                ["@lsp.type.function.typescriptreact"]       = { fg = "$md_yellow" },
                ["@lsp.type.function.javascript"]            = { fg = "$md_blue" },
                ["@lsp.type.class.typescriptreact"]          = { fg = "$md_yellow" },
                ["@lsp.type.class.javascript"]               = { fg = "$md_yellow" },
                ["@lsp.type.typeParameter.typescript"]       = { fg = "$md_yellow" },
                ["@lsp.type.typeParameter.typescriptreact"]  = { fg = "$md_yellow" },
                ["@tag.tsx"]                                 = { fg = "$md_yellow" },
                ["@tag.builtin.tsx"]                         = { fg = "$md_red" },
                ["@tag.delimiter.tsx"]                       = { fg = "$md_cyan" },

                -- tsx: IntelliJ Material Darker parity (pixel-sampled from IDE,
                -- see docs/tsx-intellij-color-parity.md). Scoped to tsx so
                -- other languages keep the VS Code-style semantic colors.
                ["@keyword.tsx"]             = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.import.tsx"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.return.tsx"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.conditional.tsx"] = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.repeat.tsx"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.operator.tsx"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.function.tsx"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.coroutine.tsx"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.exception.tsx"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.modifier.tsx"]    = { fg = "$md_purple", fmt = "italic" },
                ["@conditional.tsx"]         = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.conditional.ternary.tsx"] = { fg = "$md_purple", fmt = "italic" },
                ["@type.tsx"]                = { fg = "$md_green", fmt = "italic" },
                ["@type.builtin.tsx"]        = { fg = "$md_purple", fmt = "italic" },  -- string/number/boolean
                ["@function.tsx"]            = { fg = "$md_yellow" },
                ["@function.call.tsx"]       = { fg = "$md_yellow" },
                ["@function.builtin.tsx"]    = { fg = "$md_yellow" },
                ["@function.method.tsx"]     = { fg = "$md_blue" },
                ["@function.method.call.tsx"] = { fg = "$md_blue" },
                ["@function.setter.tsx"]     = { fg = "$md_blue" },  -- custom capture, after/queries/tsx
                ["@boolean.tsx"]             = { fg = "$md_purple", fmt = "italic" },
                ["@constant.builtin.tsx"]    = { fg = "$md_purple", fmt = "italic" },
                ["@parameter.tsx"]           = { fg = "$md_white" },
                ["@variable.parameter.tsx"]  = { fg = "$md_white" },
                ["@property.tsx"]            = { fg = "$md_white" },
                ["@variable.member.tsx"]     = { fg = "$md_white" },
                ["@tag.attribute.tsx"]       = { fg = "$md_yellow", fmt = "italic" },
                ["@none.tsx"]                = { fg = "$md_white" },  -- JSX text content

                -- plain typescript: same IntelliJ parity as tsx (keywords and
                -- primitive types purple italic, types green italic, free
                -- functions yellow, locals/methods blue, params/props white)
                ["@keyword.typescript"]             = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.import.typescript"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.return.typescript"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.conditional.typescript"] = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.conditional.ternary.typescript"] = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.repeat.typescript"]      = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.operator.typescript"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.function.typescript"]    = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.coroutine.typescript"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.exception.typescript"]   = { fg = "$md_purple", fmt = "italic" },
                ["@keyword.modifier.typescript"]    = { fg = "$md_purple", fmt = "italic" },
                ["@conditional.typescript"]         = { fg = "$md_purple", fmt = "italic" },
                ["@boolean.typescript"]             = { fg = "$md_purple", fmt = "italic" },
                ["@constant.builtin.typescript"]    = { fg = "$md_purple", fmt = "italic" },
                ["@type.builtin.typescript"]        = { fg = "$md_purple", fmt = "italic" },
                ["@type.typescript"]                = { fg = "$md_green", fmt = "italic" },
                ["@function.typescript"]            = { fg = "$md_yellow" },
                ["@function.call.typescript"]       = { fg = "$md_yellow" },
                ["@function.builtin.typescript"]    = { fg = "$md_yellow" },
                ["@function.method.typescript"]     = { fg = "$md_blue" },
                ["@function.method.call.typescript"] = { fg = "$md_blue" },
                ["@function.setter.typescript"]     = { fg = "$md_blue" },
                ["@parameter.typescript"]           = { fg = "$md_white" },
                ["@variable.parameter.typescript"]  = { fg = "$md_white" },
                ["@property.typescript"]            = { fg = "$md_white" },
                ["@variable.member.typescript"]     = { fg = "$md_white" },
                ["@lsp.type.parameter.typescript"]  = { fg = "$md_white" },
                ["@lsp.type.property.typescript"]   = { fg = "$md_white" },
                ["@lsp.type.interface.typescript"]  = { fg = "$md_green", fmt = "italic" },
                ["@lsp.type.type.typescript"]       = { fg = "$md_green", fmt = "italic" },
                ["@lsp.typemod.function.local.typescript"] = { fg = "$md_blue" },
                ["@lsp.type.method.typescript"]     = { fg = "$md_blue" },
                ["@lsp.type.parameter.typescriptreact"]            = { fg = "$md_white" },
                ["@lsp.type.property.typescriptreact"]             = { fg = "$md_white" },
                ["@lsp.type.interface.typescriptreact"]            = { fg = "$md_green", fmt = "italic" },
                ["@lsp.type.type.typescriptreact"]                 = { fg = "$md_green", fmt = "italic" },
                ["@lsp.typemod.function.local.typescriptreact"]    = { fg = "$md_blue" },
                ["@lsp.type.method.typescriptreact"]               = { fg = "$md_blue" },
                ["@tag.javascript"]                          = { fg = "$md_yellow" },
                ["@tag.builtin.javascript"]                  = { fg = "$md_red" },
                ["@tag.attribute.javascript"]                = { fg = "$md_purple", fmt = "italic" },
                ["@tag.delimiter.javascript"]                = { fg = "$md_cyan" },

                -- json
                ["@property.json"]  = { fg = "$md_purple" },

                -- yaml
                ["@property.yaml"]  = { fg = "$md_red" },
            },
        })
        require("onedark").load()
    end,
}
