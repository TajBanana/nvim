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

vim.opt.colorcolumn = "80"

vim.opt.splitright = true
vim.opt.clipboard:append("unnamedplus")

-- Reclaim the empty command-line row: hide it when idle (cmdheight=0) and render
-- the pending-keystroke display (showcmd) inside the statusline via lualine's %S item.
vim.opt.cmdheight = 0
vim.opt.showcmd = true
vim.opt.showcmdloc = "statusline"

-- Neovim 0.12's ui2 (experimental) replaces the legacy message grid: messages
-- that don't fit are collapsed with a `[+N]` indicator instead of raising the
-- "Press ENTER" hit-enter prompt that cmdheight=0 otherwise triggers on any
-- multi-line message. targets="msg" shows them in the ephemeral message window
-- built for cmdheight=0; `g<` opens the full history in the pager. vim.notify
-- itself is routed to fidget toasts (plugins/ui.lua). pcall: the module is
-- internal and experimental, so a rename in a future release must not break
-- startup -- it would just fall back to the legacy UI.
pcall(function()
    require("vim._core.ui2").enable({ msg = { targets = "msg" } })
end)

-- Rounded border on floating windows so LSP hover (K), signature help, and
-- diagnostic floats stand out from the buffer. nvim-cmp sets its own border
-- explicitly, so this does not double up there.
vim.opt.winborder = "rounded"

-- Force a full repaint (the <C-l> effect) after window scrolls: screen pixels
-- have been observed lagging provably-correct internal state (blame pane rows),
-- and a repaint guarantees paint == state. `redraw!` clears the whole terminal,
-- so it is throttled to at most one per 30 ms: events inside the window
-- coalesce into the pending repaint, which fires AFTER them and therefore still
-- paints the final state. Held-key scrolling no longer pushes a full screen per
-- event (noticeable over WSL/SSH). Measured cost: ~0.9ms per repaint.
local repaint_pending = false
local function repaint()
    if repaint_pending then
        return
    end
    repaint_pending = true
    vim.defer_fn(function()
        repaint_pending = false
        vim.cmd("redraw!")
    end, 30)
end

vim.api.nvim_create_autocmd("WinScrolled", {
    group = vim.api.nvim_create_augroup("ScrollRepaint", { clear = true }),
    callback = repaint,
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
            repaint()
        end
        vim.b[args.buf].repaint_lines = n
    end,
})

-- Helmfile/Go templates: *.yaml.gotmpl gets the "helm" filetype (yaml+gotmpl
-- treesitter grammar + helm-ls); other *.gotmpl fall back to plain gotmpl.
-- Neovim has no built-in detection for either.
-- NOTE: vim.filetype.add patterns are implicitly anchored (^...$) on nvim
-- 0.11+, so a leading .* is required to match the path prefix.
-- "helm" only for files that are actually inside a Helm chart: a chart is
-- defined by a Chart.yaml at the root of the directory holding `templates/`.
-- Checked with fs_stat rather than a glob so it is one stat per matching buffer.
local function helm_if_chart(path)
    -- Any templates/ ancestor whose parent is a chart root counts -- not just
    -- the outermost, so a chart's templates/templates/x.yaml is helm too.
    local from = 1
    while true do
        local s = path:find("/templates/", from, true)
        if not s then
            return nil
        end
        local chart_root = path:sub(1, s - 1)
        if vim.uv.fs_stat(chart_root .. "/Chart.yaml") or vim.uv.fs_stat(chart_root .. "/Chart.yml") then
            return "helm"
        end
        from = s + 1
    end
end

-- A chart's values files (values.yaml, values-prod.yaml, ...) sit beside its
-- Chart.yaml. `yaml.helm-values` is what lspconfig's helm_ls attaches to
-- (chart-aware values schema/completion, and .Values links from templates);
-- yamlls lists it too, and every YAML-keyed consumer (treesitter's get_lang,
-- conform, indent_scope) resolves the compound filetype back to yaml.
local function helm_values_if_chart(path)
    local dir = path:match("^(.*)/[^/]+$")
    if dir and (vim.uv.fs_stat(dir .. "/Chart.yaml") or vim.uv.fs_stat(dir .. "/Chart.yml")) then
        return "yaml.helm-values"
    end
    return nil
end

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
        --
        -- Gated on a Chart.yaml sibling at the chart root. `templates/` is NOT a
        -- Helm-specific directory name: matching it alone claimed Ansible
        -- (roles/*/templates/*.yaml), Spring (src/main/resources/templates/),
        -- CloudFormation and .github/templates as `helm` -- losing yamlls schema
        -- validation and silently making <leader>gf a no-op on them, since
        -- formatting.lua has no helm entry. Returning nil falls through to
        -- nvim's own detection, so a non-chart file stays plain yaml.
        --
        -- Priority 20, above the compose/GitLab/values rules below: equal
        -- priorities are tried in an unspecified order, so inside a chart's
        -- templates/ a docker-compose.yml became yaml.docker-compose while a
        -- compose.yaml became helm. Everything in a chart's templates/ is a
        -- template (and a non-chart file falls through to those rules).
        [".*/templates/.*%.ya?ml"] = { helm_if_chart, { priority = 20 } },
        [".*/templates/.*%.tpl"] = { helm_if_chart, { priority = 20 } },
        -- values.yaml, values-prod.yaml, values_ci.yaml, values.dev.yaml -- but
        -- not valuesfoo.yaml (the earlier `values[^/]*` claimed any prefix).
        [".*/values%.ya?ml"] = { helm_values_if_chart, { priority = 10 } },
        [".*/values[-_.][^/]*%.ya?ml"] = { helm_values_if_chart, { priority = 10 } },
        -- Compose and GitLab CI files: yamlls attaches to these compound
        -- filetypes like plain yaml, and they give schema tooling a hook.
        -- Anchored on exact names so e.g. composer.yml is not claimed.
        [".*/compose%.ya?ml"] = { "yaml.docker-compose", { priority = 10 } },
        [".*/compose%.[^/]+%.ya?ml"] = { "yaml.docker-compose", { priority = 10 } },
        [".*/docker%-compose%.ya?ml"] = { "yaml.docker-compose", { priority = 10 } },
        [".*/docker%-compose%.[^/]+%.ya?ml"] = { "yaml.docker-compose", { priority = 10 } },
        [".*%.gitlab%-ci%.ya?ml"] = { "yaml.gitlab", { priority = 10 } },
    },
})

-- Go-template files have no 'commentstring' from their ftplugin, so the
-- built-in gc/gcc did nothing on them. A template comment renders to nothing,
-- unlike a YAML `#` comment, which would still be emitted by the template.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("TemplateCommentstring", { clear = true }),
    pattern = { "helm", "gotmpl" },
    callback = function(args)
        vim.bo[args.buf].commentstring = "{{/* %s */}}"
    end,
})

-- PATH bootstrapping for node (nvm lazy-load) and cargo/rustc (rustup) so
-- Mason's node-based servers and rust-analyzer can be spawned — see env.lua.
require("tajbanana.env").setup()

-- Set cursor blink rate. All THREE of blinkwait/blinkon/blinkoff must be
-- non-zero for the cursor to blink at all -- setting blinkon alone (as this line
-- used to) leaves blinkoff at 0, which means "never blink".
vim.opt.guicursor:append("a:blinkwait700-blinkon500-blinkoff400")

vim.opt.ignorecase = true
-- A capital letter in the pattern makes that search case-sensitive; all-lower
-- stays case-insensitive. (`*`/`#` ignore smartcase.)
vim.opt.smartcase = true
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
-- windows (diagnostic floats, hover docs, previews, ui2's message window and
-- pager) — normal-mode Esc is otherwise a no-op, so nothing is lost. Excluded:
-- fidget's popup (it re-renders immediately, so closing it just flickers) and
-- ui2's own cmdline/dialog windows, which it owns and expects to stay valid.
local keep_floats = { fidget = true, cmd = true, dialog = true }
vim.keymap.set("n", "<Esc>", function()
    vim.cmd("nohlsearch")
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative ~= "" then
            local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
            if not keep_floats[ft] then
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
-- In nvim-tree it opens the node under the cursor (file or folder) instead.
-- Only real on-disk paths are handed over: special buffers (the tree itself,
-- terminals, scheme:// URIs) have a non-empty but fake %:p, which made
-- `open`/`xdg-open` fail -- and on WSL made explorer.exe silently open its
-- default folder.
-- A scratch/terminal/quickfix buffer is never "the file", even when its name
-- happens to match a real path (a nofile buffer named after a file on disk
-- opened that file).
local special_buftype = { nofile = true, nowrite = true, terminal = true, prompt = true, quickfix = true }
vim.keymap.set("n", "<leader>go", function()
    local path
    if vim.bo.filetype == "NvimTree" then
        local ok, api = pcall(require, "nvim-tree.api")
        local node = ok and api.tree.get_node_under_cursor() or nil
        path = node and node.absolute_path
    elseif not special_buftype[vim.bo.buftype] then
        path = vim.fn.expand("%:p")
    end
    if not path or path == "" or not vim.uv.fs_stat(path) then
        vim.notify("Not a file on disk" .. ((path and path ~= "") and (": " .. path) or ""), vim.log.levels.WARN)
        return
    end
    require("tajbanana.system_open").open(path)
end, { desc = "Open file in default app" })
