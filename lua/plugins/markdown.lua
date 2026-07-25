-- In-buffer markdown rendering: headings, lists, code blocks, tables,
-- checkboxes and callouts are drawn styled directly in the buffer (the raw
-- `#`/`*`/backtick markup is concealed) so `.md` files read like a rendered
-- document while staying fully editable. Uses the treesitter markdown +
-- markdown_inline parsers (see treesitter.lua) and nvim-web-devicons for icons.
--
-- Hybrid editing (the default render_modes): rendered in normal mode, but the
-- line under the cursor and insert/visual mode fall back to raw source so you
-- always edit the real text. `<leader>md` toggles rendering off/on.
return {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons",
    },
    opts = {},
    keys = {
        { "<leader>md", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
}
