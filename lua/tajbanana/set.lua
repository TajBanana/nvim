vim.g.mapleader = " "

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
local undodir = vim.fn.stdpath("state") .. "/undodir"
vim.fn.mkdir(undodir, "p")
vim.opt.undodir = undodir
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "100"

vim.opt.splitright = true
vim.opt.clipboard:append("unnamedplus")

-- Reclaim the empty command-line row: hide it when idle (cmdheight=0) and render
-- the pending-keystroke display (showcmd) inside the statusline via lualine's %S item.
vim.opt.cmdheight = 0
vim.opt.showcmd = true
vim.opt.showcmdloc = "statusline"

-- Rounded border on floating windows so LSP hover (K), signature help, and
-- diagnostic floats stand out from the buffer. nvim-cmp sets its own border
-- explicitly, so this does not double up there.
vim.opt.winborder = "rounded"

-- Force a full repaint (the <C-l> effect) on EVERY window scroll: screen
-- pixels have been observed lagging provably-correct internal state (blame
-- pane rows), and repainting per scroll event guarantees paint == state.
-- Deliberately un-debounced by choice; if flicker or CPU ever becomes
-- noticeable during held-key scrolling, reintroduce a debounce here.
-- Measured cost in a live session: ~0.9ms per repaint.
vim.api.nvim_create_autocmd("WinScrolled", {
    group = vim.api.nvim_create_augroup("ScrollRepaint", { clear = true }),
    callback = function()
        vim.cmd("redraw!")
    end,
})

-- Same paint==state concern for LINE-COUNT changes: deleting or pasting whole
-- lines (dd, p/P, o/O, dap, undo) shifts every row below, so the gutter/blame
-- pane can lag exactly like a scroll does. Character-level edits (x, r, an
-- in-line cw) don't move rows, so gate the repaint on the buffer's line count
-- actually changing -- tracked per-buffer, so it never fires on cursor motion
-- or in-line edits. BufReadPost/BufNewFile seed the baseline; TextChanged and
-- InsertLeave catch normal-mode and insert-mode (o/O, multiline paste) edits.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "TextChanged", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("LineCountRepaint", { clear = true }),
    callback = function(args)
        local n = vim.api.nvim_buf_line_count(args.buf)
        if vim.b[args.buf].repaint_lines ~= nil and vim.b[args.buf].repaint_lines ~= n then
            vim.cmd("redraw!")
        end
        vim.b[args.buf].repaint_lines = n
    end,
})

-- Helmfile/Go templates: *.yaml.gotmpl gets the "helm" filetype (yaml+gotmpl
-- treesitter grammar + helm-ls); other *.gotmpl fall back to plain gotmpl.
-- Neovim has no built-in detection for either.
-- NOTE: vim.filetype.add patterns are implicitly anchored (^...$) on nvim
-- 0.11+, so a leading .* is required to match the path prefix.
vim.filetype.add({
    extension = {
        iml = "xml", -- IntelliJ module files are XML; nvim doesn't detect them
    },
    pattern = {
        [".*%.ya?ml%.gotmpl"] = { "helm", { priority = 10 } },
        [".*%.gotmpl"] = "gotmpl",
        -- Real Helm charts don't use a .gotmpl extension -- their templates are
        -- plain `<chart>/templates/*.yaml` containing {{ }} that is NOT valid
        -- YAML. Without these rules nvim called them `yaml`, yamlls attached and
        -- reported every Go-template delimiter as a syntax error (measured: 1393
        -- diagnostics on one statefulset.yaml, 3145 on a kube-prometheus-stack
        -- template), while helm_ls -- installed via ensure_installed for exactly
        -- this -- could never attach. *.tpl helper files were landing on the
        -- unrelated `mustache`/`smarty` filetype for the same reason.
        -- Priority 10 beats nvim's built-in extension match on .yaml/.yml.
        [".*/templates/.*%.ya?ml"] = { "helm", { priority = 10 } },
        [".*/templates/.*%.tpl"] = { "helm", { priority = 10 } },
    },
})

-- PATH bootstrapping for node (nvm lazy-load) and cargo/rustc (rustup) so
-- Mason's node-based servers and rust-analyzer can be spawned — see env.lua.
require("tajbanana.env").setup()

-- Set cursor blink rate. All THREE of blinkwait/blinkon/blinkoff must be
-- non-zero for the cursor to blink at all -- setting blinkon alone (as this line
-- used to) leaves blinkoff at 0, which means "never blink".
vim.opt.guicursor:append("a:blinkwait700-blinkon500-blinkoff400")

vim.opt.ignorecase = true
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true, desc = "Half page down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true, desc = "Half page up (centered)" })

-- Feature modules extracted from this file (see each for detail): the F2
-- terminal toggle, treesitter incremental selection (<M-Up>/<M-Down>), and the
-- forge shortcuts (which detect GitHub vs GitLab from the remote host, so the
-- same config works on a personal GitHub box and a work GitLab one).
require("tajbanana.terminal").setup()
require("tajbanana.incremental_selection").setup()
require("tajbanana.forge").setup()

-- Esc in normal mode clears search highlighting and closes any floating
-- windows (diagnostic floats, hover docs, previews) — normal-mode Esc is
-- otherwise a no-op, so nothing is lost. Fidget's LSP-progress popup is
-- excluded: it re-renders itself immediately, so closing it just flickers.
vim.keymap.set("n", "<Esc>", function()
    vim.cmd("nohlsearch")
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative ~= "" then
            local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
            if ft ~= "fidget" then
                pcall(vim.api.nvim_win_close, win, false)
            end
        end
    end
end, { desc = "Clear search highlight, close floats" })

-- Cycle open files like IntelliJ tabs (buffers ARE the open-file list; these
-- replaced harpoon, which was only ever used for cycling, not pinned jumps)
vim.keymap.set("n", "<leader>]", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>[", "<cmd>bprevious<cr>", { desc = "Previous buffer" })

-- Show the current line's diagnostics (the full error/warning text that inline
-- virtual text truncates) in a float. Global on purpose: vim.diagnostic works
-- without an LSP, so this isn't tied to LspAttach. source=true labels which
-- tool produced each message when several are attached.
vim.keymap.set("n", "<leader>e", function()
    vim.diagnostic.open_float({ scope = "line", source = true })
end, { desc = "Show line diagnostics (float)" })

-- Open the current file in its OS default app (html -> browser, pdf -> viewer).
-- vim.ui.open picks the right launcher per platform (open / xdg-open / wslview /
-- explorer.exe), which the previous hardcoded `!open` did not -- that was macOS
-- only and simply errored on Linux and WSL. Going through vim.ui.open also drops
-- the `:!` shell round-trip, so cmdline-special characters (%, #, !) in the
-- filename are no longer re-expanded by Vim before the shell sees them.
--
-- Open the current file in its OS default app. Three platforms, three launchers,
-- and the selection is made HERE rather than by vim.ui.open. Why:
--
-- 1. vim.ui.open's preference order (runtime/lua/vim/ui.lua) is xdg-open, THEN
--    wslview, THEN explorer.exe -- so explorer is a fallback, not the WSL rule.
--    Installing wl-clipboard pulled in xdg-utils as a dependency (same dpkg
--    transaction), which put xdg-open on PATH and silently moved nvim's choice
--    onto it. This box has no desktop session and no registered MIME handler, so
--    xdg-open exits 4 for every file -- valid POSIX path or not -- and
--    <leader>go stopped working with no config change to blame.
-- 2. vim.ui.open launches DETACHED and returns the process object; its error
--    return is non-nil only when NO handler exists at all. A launcher that runs
--    and then fails is invisible to the caller. That is why (1) went unnoticed.
--
-- So each platform's launcher and its path format are chosen together (they are
-- coupled -- picking them apart was the original bug), and every failure is
-- reported instead of shrugged at:
--
--   mac    `open <posix>`        exits 0 on success, non-zero on failure
--   WSL    `explorer.exe <win>`  needs a Windows path; ALWAYS exits 1, even on
--                                success, so its code is deliberately ignored
--   linux  `xdg-open <posix>`    exits 0 on success; 1-4 on failure
--
-- All three handle any file type -- these invoke the desktop's default-handler
-- machinery (on Windows, the shell's default verb), not just directories.
vim.keymap.set("n", "<leader>go", function()
    local path = vim.fn.expand("%:p")
    if path == "" then
        vim.notify("No file to open", vim.log.levels.WARN)
        return
    end
    local plat = require("tajbanana.platform")

    -- WSL first: it is also `linux`, so the more specific case has to win.
    if plat.wsl then
        local win = vim.system({ "wslpath", "-w", path }, { text = true }):wait()
        local winpath = vim.trim(win.stdout or "")
        if win.code ~= 0 or winpath == "" then
            vim.notify("wslpath failed for: " .. path, vim.log.levels.ERROR)
            return
        end
        -- detach so the launcher outlives nvim; exit code is meaningless here.
        vim.system({ "explorer.exe", winpath }, { detach = true })
        return
    end

    local cmd = plat.mac and "open" or "xdg-open"
    if vim.fn.executable(cmd) ~= 1 then
        vim.notify(
            ("No file opener: `%s` is not executable (mac expects `open`, linux `xdg-open`)"):format(cmd),
            vim.log.levels.ERROR
        )
        return
    end
    -- NOT detached: both launchers hand off to the desktop and exit immediately,
    -- so the exit code arrives at once and the app they spawned is unaffected.
    vim.system({ cmd, path }, { text = true }, function(r)
        if r.code ~= 0 then
            local detail = vim.trim((r.stderr or "") ~= "" and r.stderr or (r.stdout or ""))
            vim.schedule(function()
                vim.notify(
                    ("%s failed (exit %d)%s"):format(cmd, r.code, detail ~= "" and (": " .. detail) or ""),
                    vim.log.levels.ERROR
                )
            end)
        end
    end)
end, { desc = "Open file in default app" })
