---
name: add-neovim-plugin
description: Use when adding a new plugin, modifying an existing plugin config, adding keymaps, registering LSP servers or formatters, or customizing colorscheme highlights in this Neovim configuration.
---

# Add or Modify Neovim Plugin

## Overview

This config uses **lazy.nvim** with auto-discovery from `lua/plugins/`. Each file returns a plugin spec table (or list of tables). Follow the existing conventions to keep the config consistent.

## Adding a New Plugin

### Decide which file it belongs in

| Category | File | Examples |
|----------|------|----------|
| LSP, completion, snippets | `lsp.lua` | language servers, cmp sources |
| Color/theme | `colorscheme.lua` | themes, highlight overrides |
| Fuzzy finding | `telescope.lua` | telescope extensions |
| Syntax/parsing | `treesitter.lua` | treesitter plugins |
| Formatting | `formatting.lua` | formatters via conform.nvim |
| Editing utilities | `editor.lua` | motions, text objects, test runners |
| Git integration | `git.lua` | git tools |
| File navigation | `harpoon.lua` | harpoon-specific only |
| UI/visual | `ui.lua` | statusline, file tree, icons |
| **New category** | Create new `lua/plugins/<name>.lua` | Return a table or list of tables |

### Plugin spec pattern

Always lazy-load when possible. Prefer `keys`, `event`, or `cmd` triggers:

```lua
-- Single plugin in a file
return {
    "author/plugin-name",
    dependencies = { "dep/name" },  -- if needed
    event = "BufReadPre",           -- or keys/cmd for lazy loading
    opts = {
        -- plugin options (calls setup() automatically)
    },
}

-- Multiple plugins: return a list
return {
    { "author/plugin-one", opts = {} },
    { "author/plugin-two", opts = {} },
}
```

Use `config = function() ... end` only when `opts` is insufficient (e.g., need to call multiple setup functions or set keymaps conditionally).

### Keymaps

- **Global keymaps** (not plugin-specific): add to `lua/tajbanana/set.lua`
- **Plugin keymaps**: use the `keys` field in the spec (also triggers lazy-loading):
  ```lua
  keys = {
      { "<leader>xx", function() require("plugin").action() end, desc = "Do thing" },
  },
  ```
- **LSP keymaps**: add inside the `LspAttach` autocmd callback in `lsp.lua`

Leader is **Space**.

## Registering an LSP Server

1. Add the server name to `ensure_installed` in `lsp.lua` (Mason auto-installs it)
2. If the server needs custom settings, add a `vim.lsp.config("server_name", { ... })` block
3. No further setup needed — `automatic_enable = true` handles attachment

## Adding a Formatter

1. Install the formatter via Mason (`:Mason`)
2. Add the filetype mapping in `formatting.lua` under `formatters_by_ft`:
   ```lua
   formatters_by_ft = {
       lua = { "stylua" },
       javascript = { "prettierd" },  -- add like this
   },
   ```
3. Formatting is triggered manually with `<leader>gf`, not on save

## Customizing Syntax Highlights

Edit `colorscheme.lua`. The config uses a Material Darker-inspired palette with named color variables.

1. Use `:Inspect` in Neovim to find the highlight group under the cursor
2. Add/modify the highlight in the `highlights` table using the `$md_*` color variables:
   ```lua
   ["@tag.builtin.tsx"] = { fg = "$md_red" },
   ["@lsp.type.interface"] = { fg = "$md_purple", fmt = "italic" },
   ```

Available palette colors: `md_blue`, `md_yellow`, `md_purple`, `md_cyan`, `md_green`, `md_orange`, `md_red`, `md_white`, `md_grey_blue`, `md_comment`.

## Verification

After any change:
1. Open Neovim — check `:messages` for errors
2. `:Lazy` — verify plugin loads correctly
3. For LSP: `:LspInfo` on a relevant file
4. For treesitter: `:Inspect` to verify highlight groups
