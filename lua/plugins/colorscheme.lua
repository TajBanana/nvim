return {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        local purple_italic = { fg = "$md_purple", fmt = "italic" }

        local highlights = {
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
            ["@variable.builtin"]      = purple_italic,  -- this/super/self (IJ: keyword-like)
            ["@parameter"]             = { fg = "$md_orange" },
            ["@property"]              = { fg = "$md_grey_blue" },

            -- constants
            ["@constant"]              = { fg = "$md_white" },
            ["@constant.builtin"]      = purple_italic,  -- true/false/null/undefined/NaN (IJ: keyword-like)

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

            -- renamed captures (treesitter main branch): the old names above are
            -- kept for compat, these are the current ones — without them onedark
            -- defaults leak through
            ["@function.method"]        = { fg = "$md_blue" },
            ["@function.method.call"]   = { fg = "$md_blue" },
            ["@variable.parameter"]     = { fg = "$md_orange" },
            ["@variable.member"]        = { fg = "$md_grey_blue" },
            ["@boolean"]                = purple_italic,
            ["@module.builtin"]         = { fg = "$md_yellow" },
            ["@number.float"]           = { fg = "$md_orange" },
            ["@string.documentation"]   = { fg = "$md_green" },
            ["@string.special.url"]     = { fg = "$md_cyan" },
            ["@character.special"]      = { fg = "$md_cyan" },
            ["@attribute"]              = purple_italic,  -- annotations/decorators (IJ style)
            ["@lsp.typemod.variable.static"]         = { fg = "$md_grey_blue", fmt = "italic" },
            ["@lsp.typemod.variable.defaultLibrary"] = { fg = "$md_cyan" },

            -- markup tags (html/css selectors; tsx/js scoped rules override)
            ["@tag"]           = { fg = "$md_red" },
            ["@tag.builtin"]   = { fg = "$md_red" },
            ["@tag.attribute"] = { fg = "$md_yellow", fmt = "italic" },
            ["@tag.delimiter"] = { fg = "$md_cyan" },

            -- misc
            ["@comment"]               = { fg = "$md_comment" },

            -- Line numbers a touch brighter than onedark's default blue-grey.
            -- Moved here from set.lua, where the override was silently clobbered
            -- because onedark loads (and repaints LineNr) after set.lua ran.
            ["LineNr"] = { fg = "#737373" },

            -- <leader>gd picker kind tags
            ["GdTagDef"]  = { fg = "$md_yellow" },
            ["GdTagType"] = { fg = "$md_green", fmt = "italic" },
            ["GdTagImpl"] = { fg = "$md_blue" },
            ["GdTagRef"]  = { fg = "$md_purple" },

            -- Inlay hints, semantically tinted (see tajbanana/inlay_tint):
            -- each kind wears its palette color pre-blended ~45–55% toward the
            -- #16181c editor background — terminals have no text alpha, so
            -- transparency is simulated. Re-blend if the background changes.
            ["LspInlayHint"]          = { fg = "#778082", fmt = "italic" }, -- kindless: faded white
            ["LspInlayHintType"]      = { fg = "#967A47", fmt = "italic" }, -- faded md_yellow (brighter, reads yellow not orange)
            ["LspInlayHintParameter"] = { fg = "#7B4C40", fmt = "italic" }, -- faded md_orange

            -- git gutter signs (gitsigns): add=green, change=blue, delete=red
            -- so the whole-branch diff view (<leader>gB) reads at a glance.
            -- Change is blue to match IntelliJ's "modified" gutter marker.
            -- Brightened past the palette (md_green/blue/red) explicitly so the
            -- signs pop -- and stay clearly brighter than the muted untracked
            -- green below. Gutter-only; the palette vars still drive syntax.
            ["GitSignsAdd"]    = { fg = "#D5F58F" }, -- brighter md_green
            ["GitSignsChange"] = { fg = "#9CC2FF" }, -- brighter md_blue
            ["GitSignsDelete"] = { fg = "#FF8A91" }, -- brighter md_red
            -- untracked files (new, not yet git-added) keep the `┆` glyph but
            -- wear a muted grey-green -- same "new" hue family as adds, dimmer
            -- and greyer so real adds (bright green) still stand out. Without
            -- this it inherits GitSignsAdd and is indistinguishable from adds.
            ["GitSignsUntracked"] = { fg = "#7E9469" },

            -- Telescope: mark the previewed line (the diagnostic / grep match /
            -- definition the picker jumped to) so the issue stands out in the
            -- preview pane; and colour the matched query text in results
            ["TelescopePreviewLine"] = { bg = "#33415e", fmt = "bold" },
            ["TelescopeMatching"]    = { fg = "$md_orange", fmt = "bold" },

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
            ["@lsp.type.keyword"]          = purple_italic,
            ["@lsp.type.namespace"]        = { fg = "$md_yellow" },
            ["@lsp.type.typeParameter"]    = { fg = "$md_yellow" },  -- generics <T>
            ["@lsp.typemod.class.abstract"]   = { fg = "$md_yellow", fmt = "italic" },
            ["@lsp.typemod.method.abstract"]  = { fg = "$md_blue",   fmt = "italic" },
            ["@lsp.typemod.function.defaultLibrary"] = { fg = "$md_blue" },
            ["@lsp.typemod.function.static"]         = { fg = "$md_blue", fmt = "italic" },

            -- java
            ["@lsp.type.annotation.java"]        = purple_italic,
            ["@lsp.type.typeParameter.java"]      = { fg = "$md_yellow" },
            ["@lsp.type.function.groovy"]         = { fg = "$md_blue" },
            ["@lsp.typemod.method.static.java"]   = { fg = "$md_blue",      fmt = "italic" },
            ["@lsp.typemod.variable.static.java"] = { fg = "$md_grey_blue", fmt = "italic" },

            -- kotlin: IntelliJ Material Darker parity (pixel-sampled from the
            -- IDE; functions stay blue and class declarations yellow, unlike the
            -- tsx scheme). Keyword captures are generated below.
            ["@lsp.type.type.kotlin"]             = { fg = "$md_yellow" },
            ["@lsp.type.annotation.kotlin"]       = purple_italic,
            ["@lsp.type.typeParameter.kotlin"]    = { fg = "$md_yellow" },
            ["@variable.member.kotlin"]           = { fg = "$md_white" },
            ["@function.builtin.kotlin"]          = { fg = "$md_blue", fmt = "italic" },
            ["@lsp.type.keyword.kotlin"]          = purple_italic,
            ["@attribute.kotlin"]                 = purple_italic,
            -- constructor property declarations stay white; plain function
            -- parameters use the base orange like every other language
            ["@lsp.type.property.kotlin"]   = { fg = "$md_white" },

            -- typescript / javascript (tsx + ts + js + jsx). Keyword captures
            -- are generated below; these are the type/function/tag differences.
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

            -- tsx: IntelliJ Material Darker parity (pixel-sampled from IDE, see
            -- docs/tsx-intellij-color-parity.md). Scoped to tsx so other
            -- languages keep the VS Code-style semantic colors.
            ["@type.tsx"]                = { fg = "$md_green", fmt = "italic" },
            ["@type.builtin.tsx"]        = purple_italic,  -- string/number/boolean
            ["@function.tsx"]            = { fg = "$md_yellow" },
            ["@function.call.tsx"]       = { fg = "$md_yellow" },
            ["@function.builtin.tsx"]    = { fg = "$md_yellow" },
            ["@function.method.tsx"]     = { fg = "$md_blue" },
            ["@function.method.call.tsx"] = { fg = "$md_blue" },
            ["@function.setter.tsx"]     = { fg = "$md_blue" },  -- custom capture, after/queries/tsx
            ["@boolean.tsx"]             = purple_italic,
            ["@constant.builtin.tsx"]    = purple_italic,
            ["@property.tsx"]            = { fg = "$md_white" },
            ["@variable.member.tsx"]     = { fg = "$md_white" },
            ["@tag.attribute.tsx"]       = { fg = "$md_yellow", fmt = "italic" },
            ["@none.tsx"]                = { fg = "$md_white" },  -- JSX text content

            -- plain typescript: same IntelliJ parity as tsx (primitive types
            -- purple italic, types green italic, free functions yellow,
            -- locals/methods blue, props white; params use the base orange)
            ["@boolean.typescript"]             = purple_italic,
            ["@constant.builtin.typescript"]    = purple_italic,
            ["@type.builtin.typescript"]        = purple_italic,
            ["@type.typescript"]                = { fg = "$md_green", fmt = "italic" },
            ["@function.typescript"]            = { fg = "$md_yellow" },
            ["@function.call.typescript"]       = { fg = "$md_yellow" },
            ["@function.builtin.typescript"]    = { fg = "$md_yellow" },
            ["@function.method.typescript"]     = { fg = "$md_blue" },
            ["@function.method.call.typescript"] = { fg = "$md_blue" },
            ["@function.setter.typescript"]     = { fg = "$md_blue" },
            ["@property.typescript"]            = { fg = "$md_white" },
            ["@variable.member.typescript"]     = { fg = "$md_white" },
            ["@lsp.type.property.typescript"]   = { fg = "$md_white" },
            ["@lsp.type.interface.typescript"]  = { fg = "$md_green", fmt = "italic" },
            ["@lsp.type.type.typescript"]       = { fg = "$md_green", fmt = "italic" },
            ["@lsp.typemod.function.local.typescript"] = { fg = "$md_blue" },
            ["@lsp.type.method.typescript"]     = { fg = "$md_blue" },
            ["@lsp.type.property.typescriptreact"]             = { fg = "$md_white" },
            ["@lsp.type.interface.typescriptreact"]            = { fg = "$md_green", fmt = "italic" },
            ["@lsp.type.type.typescriptreact"]                 = { fg = "$md_green", fmt = "italic" },
            ["@lsp.typemod.function.local.typescriptreact"]    = { fg = "$md_blue" },
            ["@lsp.type.method.typescriptreact"]               = { fg = "$md_blue" },
            ["@tag.javascript"]                          = { fg = "$md_yellow" },
            ["@tag.builtin.javascript"]                  = { fg = "$md_red" },
            ["@tag.attribute.javascript"]                = purple_italic,
            ["@tag.delimiter.javascript"]                = { fg = "$md_cyan" },

            -- json
            ["@property.json"]  = { fg = "$md_purple" },

            -- yaml
            ["@property.yaml"]  = { fg = "$md_red" },
        }

        -- Every keyword-family capture renders purple italic (IntelliJ style).
        -- Rather than hand-copy the list into each language block — which drifted
        -- (e.g. @keyword.directive was in base + kotlin but neither ts scope) —
        -- generate it for the base and each language scope from one source list,
        -- so the copies are structurally incapable of falling out of sync.
        local kw_captures = {
            "@keyword", "@keyword.import", "@keyword.return", "@keyword.repeat",
            "@keyword.operator", "@keyword.function", "@keyword.coroutine",
            "@keyword.exception", "@keyword.modifier", "@keyword.conditional",
            "@keyword.conditional.ternary", "@keyword.directive", "@keyword.type",
            "@conditional",
        }
        for _, cap in ipairs(kw_captures) do
            for _, scope in ipairs({ "", ".kotlin", ".tsx", ".typescript" }) do
                highlights[cap .. scope] = purple_italic
            end
        end

        require("onedark").setup({
            style = "deep",
            colors = {
                -- Darkened, desaturated backgrounds: 30% darker than the "deep"
                -- style defaults, then ~30% desaturated toward grey to cut the
                -- blue cast. Every group onedark defines derives from these keys,
                -- so this restyles the editor, floats, Pmenu dropdowns, Telescope,
                -- nvim-tree, and statusline fills in one place.
                bg0  = "#16181c",   -- main editor background   (deep: #1a212e)
                bg1  = "#1c1e23",   -- panels, Pmenu, cursorline (deep: #21283b)
                bg2  = "#22252b",   -- selections               (deep: #283347)
                bg3  = "#23252c",   -- visual selection         (deep: #2a324a)
                bg_d = "#111316",   -- sidebars (nvim-tree)     (deep: #141b24)

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
            highlights = highlights,
        })
        require("onedark").load()
    end,
}
