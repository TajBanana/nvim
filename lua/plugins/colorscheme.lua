return {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        local purple_italic = { fg = "$md_purple", fmt = "italic" }

        -- ONE consistent scheme for every language. There are no per-language
        -- (.tsx/.typescript/.kotlin/.java/...) overrides: each capture is defined
        -- once and language-scoped captures fall back to it, so a role is the
        -- same colour everywhere -- functions blue in TS, Kotlin, Go, Lua alike;
        -- types yellow; primitives cyan; parameters orange; keywords purple.
        local highlights = {
            -- functions and methods (blue everywhere)
            ["@function"]              = { fg = "$md_blue" },
            ["@function.call"]         = { fg = "$md_blue" },
            ["@function.builtin"]      = { fg = "$md_blue" },
            ["@function.method"]       = { fg = "$md_blue" },
            ["@function.method.call"]  = { fg = "$md_blue" },
            ["@method"]                = { fg = "$md_blue" },
            ["@method.call"]           = { fg = "$md_blue" },
            ["@function.macro"]        = { fg = "$md_blue" }, -- rust macros, py raw-string prefix
            ["@constructor"]           = { fg = "$md_yellow" },

            -- types, classes, namespaces (yellow); primitives (cyan)
            ["@type"]                  = { fg = "$md_yellow" },
            ["@type.builtin"]          = { fg = "$md_cyan" },  -- string/number/boolean/void
            ["@namespace"]             = { fg = "$md_yellow" },
            ["@module"]                = { fg = "$md_yellow" },
            ["@module.builtin"]        = { fg = "$md_yellow" },

            -- variables, parameters, properties
            ["@variable"]              = { fg = "$md_white" },
            ["@variable.builtin"]      = purple_italic,  -- this/super/self (keyword-like)
            ["@variable.parameter"]    = { fg = "$md_orange" },
            ["@variable.member"]       = { fg = "$md_grey_blue" },
            ["@parameter"]             = { fg = "$md_orange" },
            ["@property"]              = { fg = "$md_grey_blue" },

            -- constants
            ["@constant"]              = { fg = "$md_white" },
            ["@constant.builtin"]      = purple_italic,  -- true/false/null/undefined/NaN

            -- literals
            ["@string"]                = { fg = "$md_green" },
            ["@string.escape"]         = { fg = "$md_cyan" },
            ["@string.regexp"]         = { fg = "$md_orange" },
            ["@string.documentation"]  = { fg = "$md_green" },
            ["@string.special"]        = { fg = "$md_green" }, -- xml prolog encoding, etc.
            ["@string.special.path"]   = { fg = "$md_green" }, -- /dev/null and file paths
            ["@string.special.url"]    = { fg = "$md_cyan" },
            ["@character.special"]     = { fg = "$md_cyan" },
            ["@number"]                = { fg = "$md_orange" },
            ["@float"]                 = { fg = "$md_orange" },
            ["@number.float"]          = { fg = "$md_orange" },
            ["@boolean"]               = purple_italic,

            -- operators stay cyan (they carry meaning); brackets/delimiters are
            -- structural, so a muted rose/mauve — the one hue no role uses —
            -- keeps them distinct without clashing with the cyan/blue/orange
            -- around them.
            ["@operator"]              = { fg = "$md_cyan" },
            ["@punctuation.bracket"]   = { fg = "#C9A6B8" }, -- () [] {} — muted rose
            ["@punctuation.delimiter"] = { fg = "#C9A6B8" }, -- , ; : — muted rose
            ["@punctuation.special"]   = { fg = "$md_cyan" }, -- ${} interpolation stays accent

            -- annotations / decorators (keyword-like)
            ["@attribute"]             = purple_italic,

            -- markup tags (html/jsx/css)
            ["@tag"]           = { fg = "$md_red" },
            ["@tag.builtin"]   = { fg = "$md_red" },
            ["@tag.attribute"] = { fg = "$md_yellow", fmt = "italic" },
            ["@tag.delimiter"] = { fg = "$md_cyan" },

            -- markdown / prose markup (raw buffer text; render-markdown.nvim styles
            -- the rendered view separately). Also covers xml CDATA (@markup.raw).
            ["@markup.heading"]    = { fg = "$md_yellow", fmt = "bold" },
            ["@markup.strong"]     = { fg = "$md_white", fmt = "bold" },
            ["@markup.italic"]     = { fg = "$md_white", fmt = "italic" },
            ["@markup.raw"]        = { fg = "$md_green" },  -- inline/block code, cdata
            ["@markup.link"]       = { fg = "$md_cyan" },
            ["@markup.link.label"] = { fg = "$md_cyan" },
            ["@markup.list"]       = { fg = "#C9A6B8" },    -- markers, like delimiters
            ["@markup.quote"]      = { fg = "$md_comment", fmt = "italic" },

            -- comments (documentation blocks -- KDoc/Javadoc/JSDoc/rustdoc -- share
            -- the same grey; onedark otherwise defaults them to a darker blue-grey)
            ["@comment"]               = { fg = "$md_comment" },
            ["@comment.documentation"] = { fg = "$md_comment" },

            -- fallback captures the grammars emit for unclassified tokens: pin them
            -- to the palette so onedark's off-scheme defaults (slate/red) don't leak.
            ["@none"]  = { fg = "$md_white" }, -- bare idents parser couldn't classify
            ["@label"] = { fg = "$md_cyan" },  -- bash heredoc markers, etc.

            -- LSP semantic tokens (language-agnostic; the source of truth wherever
            -- a server provides them, since they outrank treesitter)
            ["@lsp.type.variable"]      = { fg = "$md_white" },
            ["@lsp.type.interface"]     = { fg = "$md_green", fmt = "italic" },
            ["@lsp.type.property"]      = { fg = "$md_grey_blue" },
            ["@lsp.type.method"]        = { fg = "$md_blue" },
            ["@lsp.type.function"]      = { fg = "$md_blue" },
            ["@lsp.type.class"]         = { fg = "$md_yellow" },
            ["@lsp.type.enum"]          = { fg = "$md_yellow" },
            ["@lsp.type.enumMember"]    = { fg = "$md_orange" },
            ["@lsp.type.parameter"]     = { fg = "$md_orange" },
            ["@lsp.type.keyword"]       = purple_italic,
            ["@lsp.type.namespace"]     = { fg = "$md_yellow" },
            ["@lsp.type.type"]          = { fg = "$md_yellow" },
            ["@lsp.type.typeParameter"] = { fg = "$md_yellow" },  -- generics <T>
            ["@lsp.type.annotation"]    = purple_italic,
            ["@lsp.typemod.class.abstract"]          = { fg = "$md_yellow", fmt = "italic" },
            ["@lsp.typemod.method.abstract"]         = { fg = "$md_blue", fmt = "italic" },
            ["@lsp.typemod.method.static"]           = { fg = "$md_blue", fmt = "italic" },
            ["@lsp.typemod.function.defaultLibrary"] = { fg = "$md_blue" },
            ["@lsp.typemod.function.static"]         = { fg = "$md_blue", fmt = "italic" },
            ["@lsp.typemod.variable.static"]         = { fg = "$md_grey_blue", fmt = "italic" },
            -- static-final constants: jdtls emits them as `property` (no distinct
            -- constant token), so pin the static/readonly property to constant white.
            ["@lsp.typemod.property.static"]         = { fg = "$md_white" },
            ["@lsp.typemod.property.readonly"]       = { fg = "$md_white" },
            ["@lsp.type.macro"]                      = { fg = "$md_blue" }, -- rust macros
            -- built-in globals (console/Math/JSON/window) white like any other
            -- variable — set explicitly, since onedark defaults this group to red
            -- (built-in functions already match regular functions in blue).
            ["@lsp.typemod.variable.defaultLibrary"] = { fg = "$md_white" },

            -- Line numbers a touch brighter than onedark's default blue-grey.
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
            ["LspInlayHintType"]      = { fg = "#967A47", fmt = "italic" }, -- faded md_yellow
            ["LspInlayHintParameter"] = { fg = "#7B4C40", fmt = "italic" }, -- faded md_orange

            -- git gutter signs (gitsigns): add=green, change=blue, delete=red,
            -- untracked=muted sage. Brightened past the palette so they pop.
            ["GitSignsAdd"]       = { fg = "#D5F58F" },
            ["GitSignsChange"]    = { fg = "#9CC2FF" },
            ["GitSignsDelete"]    = { fg = "#FF8A91" },
            ["GitSignsUntracked"] = { fg = "#7E9469" },

            -- Telescope: mark the previewed line and colour the matched query
            ["TelescopePreviewLine"] = { bg = "#33415e", fmt = "bold" },
            ["TelescopeMatching"]    = { fg = "$md_orange", fmt = "bold" },
        }

        -- Every keyword-family capture renders purple italic. Defined once on the
        -- base capture; language-scoped keyword captures (@keyword.import.tsx,
        -- @lsp.type.keyword.kotlin, …) fall back to these, so no per-language copy.
        for _, cap in ipairs({
            "@keyword", "@keyword.import", "@keyword.return", "@keyword.repeat",
            "@keyword.operator", "@keyword.function", "@keyword.coroutine",
            "@keyword.exception", "@keyword.modifier", "@keyword.conditional",
            "@keyword.conditional.ternary", "@keyword.directive", "@keyword.type",
            "@conditional",
        }) do
            highlights[cap] = purple_italic
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
                md_blue      = "#5B8EFF",   -- functions, methods (deeper blue)
                md_yellow    = "#FFCB6B",   -- types, classes, constructors
                md_purple    = "#C792EA",   -- keywords, booleans, annotations
                md_cyan      = "#89DDFF",   -- primitive types, operators, punctuation
                md_green     = "#C3E88D",   -- strings, interfaces
                md_orange    = "#F78C6C",   -- numbers, parameters, enum members
                md_red       = "#F07178",   -- tags, errors
                md_white     = "#EEFFFF",   -- variables, constants, default text
                md_grey_blue = "#B2CCD6",   -- properties, fields
                md_comment   = "#546E7A",   -- comments
            },
            highlights = highlights,
        })
        require("onedark").load()
    end,
}
