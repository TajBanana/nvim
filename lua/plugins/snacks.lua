return {
    -- Inline raster-image viewing (png/jpeg/gif/webp/...) in the terminal via
    -- WezTerm's kitty graphics protocol (enable_kitty_graphics in .wezterm.lua).
    -- SVG is deliberately NOT handled: rendering proved unreliable on this
    -- WezTerm build, and opening the raw XML source is more useful anyway —
    -- so .svg files open as plain markup (snacks' default formats omit svg).
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
        image = {
            enabled = true,
            -- Don't auto-preview images referenced inside markdown/docs. On
            -- WezTerm inline rendering isn't possible (no kitty unicode-
            -- placeholder support), so snacks falls back to a floating window
            -- that pops up whenever the cursor reaches an image link — intrusive.
            -- Opening an image FILE directly (:e foo.png) is unaffected; it uses
            -- a separate full-window path.
            doc = { enabled = false },
        },
    },
}
