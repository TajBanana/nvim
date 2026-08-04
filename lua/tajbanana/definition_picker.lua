-- <leader>gd: one flat Telescope picker with every LSP location for the symbol
-- under the cursor -- definition / type / implementation / references -- tagged
-- by kind. The picker opens in NORMAL mode (j/k to move, <CR> to jump); press
-- `i` first to filter, then type "def"/"type"/"impl"/"ref". Extracted from
-- lsp.lua so that file stays declarative server setup.
--
-- Two non-obvious pieces:
--  - every capable client is queried and the results merged, de-duplicated by
--    location (a tsx buffer has several clients attached; only ts_ls answers).
--  - a previewer override handles library-class locations that arrive as URIs
--    (kotlin-lsp jar://, jdtls jdt://) with no file on disk -- see below.
local M = {}

local methods = {
    { kind = "def",  rank = 1, method = "textDocument/definition" },
    { kind = "type", rank = 2, method = "textDocument/typeDefinition" },
    { kind = "impl", rank = 3, method = "textDocument/implementation" },
    { kind = "ref",  rank = 4, method = "textDocument/references" },
}

local function open_picker(items)
    if #items == 0 then
        vim.notify("No locations found", vim.log.levels.INFO)
        return
    end
    table.sort(items, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.filename ~= b.filename then return a.filename < b.filename end
        return a.lnum < b.lnum
    end)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local displayer = require("telescope.pickers.entry_display").create({
        separator = " ",
        items = {
            { width = 6 },
            { width = 35 },
            { remaining = true },
        },
    })
    local kind_hl = { def = "GdTagDef", type = "GdTagType", impl = "GdTagImpl", ref = "GdTagRef" }
    pickers.new({ initial_mode = "normal" }, {
        prompt_title = "Go to: def / type / impl / ref",
        finder = finders.new_table({
            results = items,
            entry_maker = function(it)
                local tail = vim.fn.fnamemodify(it.filename, ":t") .. ":" .. it.lnum
                return {
                    value = it,
                    ordinal = it.kind .. " " .. tail .. " " .. it.text,
                    display = function()
                        return displayer({
                            { "[" .. it.kind .. "]", kind_hl[it.kind] },
                            tail,
                            it.text,
                        })
                    end,
                    filename = it.filename,
                    lnum = it.lnum,
                    col = it.col,
                }
            end,
        }),
        previewer = (function()
            -- Library-class locations arrive as URIs (kotlin-lsp: jar://, jrt://;
            -- jdtls: jdt://) with no file on disk, so the stock previewer's
            -- filereadable() check fails and the pane renders empty. Route URI
            -- entries through bufload, which fires the BufReadCmd decompiler
            -- handlers (kotlin.nvim); disk files keep the stock preview path.
            local previewer = conf.qflist_previewer({})
            local orig_define = previewer.define_preview
            local ns = vim.api.nvim_create_namespace("gd_uri_preview")
            previewer.define_preview = function(self, entry, status)
                if not entry.filename:match("^%a[%w+.-]*://") then
                    return orig_define(self, entry, status)
                end
                local win = self.state.winid
                    or (status and (status.preview_win
                        or (status.layout and status.layout.preview and status.layout.preview.winid)))
                if not (win and vim.api.nvim_win_is_valid(win)) then
                    return
                end
                local buf = vim.uri_to_bufnr(entry.filename)
                -- Load and show the URI buffer inside the preview window itself:
                -- the decompiler handlers write to the *current* buffer
                -- (kotlin.nvim decompiler.lua uses nvim_get_current_buf), so the
                -- buffer must be current while BufReadCmd fires -- :buffer here
                -- replicates the :edit context. Telescope resets the window to
                -- its own scratch buffer on the next entry, so this swap is
                -- self-healing.
                vim.api.nvim_win_call(win, function()
                    if not pcall(vim.cmd, ("buffer %d"):format(buf)) then
                        return
                    end
                    -- A decompile that ran while the server was still importing
                    -- times out and leaves the buffer loaded but empty -- and a
                    -- loaded buffer never refires BufReadCmd. Force a re-read so
                    -- the preview heals itself once the server is ready.
                    if vim.api.nvim_buf_line_count(buf) <= 1
                        and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") == ""
                    then
                        pcall(vim.cmd, "edit!")
                    end
                    local last = vim.api.nvim_buf_line_count(buf)
                    local lnum = math.min(entry.lnum or 1, math.max(last, 1))
                    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
                    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
                        end_row = lnum,
                        hl_group = "TelescopePreviewLine",
                        hl_eol = true,
                    })
                    pcall(vim.api.nvim_win_set_cursor, win, { lnum, 0 })
                    vim.cmd("normal! zz")
                end)
            end
            return previewer
        end)(),
        sorter = conf.generic_sorter({}),
    }):find()
end

-- Query every capable client for the symbol under the cursor, merge and
-- de-duplicate the locations, then open the picker once all requests return.
function M.open()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/definition" })
    if #clients == 0 then
        vim.notify("No LSP client supporting definitions", vim.log.levels.WARN)
        return
    end
    local jobs = {}
    for _, client in ipairs(clients) do
        for _, m in ipairs(methods) do
            if client:supports_method(m.method, bufnr) then
                table.insert(jobs, { client = client, m = m })
            end
        end
    end
    local remaining, items, seen = #jobs, {}, {}
    local function done()
        remaining = remaining - 1
        if remaining == 0 then
            open_picker(items)
        end
    end
    for _, job in ipairs(jobs) do
        local enc = job.client.offset_encoding
        local params = vim.lsp.util.make_position_params(0, enc)
        if job.m.method == "textDocument/references" then
            params.context = { includeDeclaration = false }
        end
        local ok = job.client:request(job.m.method, params, function(_, result)
            local locs = result or {}
            if not vim.islist(locs) then
                locs = { locs }
            end
            for _, it in ipairs(vim.lsp.util.locations_to_items(locs, enc)) do
                local key = it.filename .. ":" .. it.lnum .. ":" .. it.col
                if not seen[key] then
                    seen[key] = true
                    it.rank = job.m.rank
                    it.kind = job.m.kind
                    it.text = vim.trim(it.text or "")
                    table.insert(items, it)
                end
            end
            done()
        end, bufnr)
        if not ok then
            done()
        end
    end
end

return M
