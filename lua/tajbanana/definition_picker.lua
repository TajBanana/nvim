-- <leader>gd: one flat Telescope picker with every LSP location for the symbol
-- under the cursor -- definition / type / implementation / references -- tagged
-- by kind. The picker opens in NORMAL mode (j/k to move, <CR> to jump); press
-- `i` first to filter, then type "def"/"type"/"impl"/"ref". Extracted from
-- lsp.lua so that file stays declarative server setup.
--
-- Non-obvious pieces:
--  - every capable client is queried and the results merged, de-duplicated by
--    location (a tsx buffer has several clients attached; only ts_ls answers).
--    A location returned by several requests keeps EVERY kind ([def,type]):
--    keeping only the first answer's tag meant filtering by "type" missed it.
--  - the picker opens when all requests answer, or after M._timeout_ms with the
--    results so far (naming the silent servers) -- it used to wait forever for
--    a server that never answers, showing nothing at all.
--  - a previewer override handles library-class locations that arrive as URIs
--    (kotlin-lsp jar://, jdtls jdt://) with no file on disk -- see below.
local M = {}

local methods = {
    { kind = "def",  rank = 1, method = "textDocument/definition" },
    { kind = "type", rank = 2, method = "textDocument/typeDefinition" },
    { kind = "impl", rank = 3, method = "textDocument/implementation" },
    { kind = "ref",  rank = 4, method = "textDocument/references" },
}
local rank_of = {}
for _, m in ipairs(methods) do
    rank_of[m.kind] = m.rank
end

M._timeout_ms = 3000

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
            { width = 19 }, -- "[def,type,impl,ref]"
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
                    ordinal = table.concat(it.kinds, " ") .. " " .. tail .. " " .. it.text,
                    display = function()
                        return displayer({
                            { "[" .. table.concat(it.kinds, ",") .. "]", kind_hl[it.kinds[1]] },
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
-- de-duplicate the locations, then open the picker once all requests return
-- (or the timeout passes).
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
    local pending, opened, timer = {}, false, nil
    local inflight = {} -- { client, id } of requests still unanswered
    local function finish(timed_out)
        if opened then
            return -- a late answer after the timeout is dropped
        end
        opened = true
        if timer and not timer:is_closing() then -- defer_fn closes it when it fires
            timer:stop()
            timer:close()
        end
        if timed_out then
            -- Cancel what is still outstanding, so a slow server stops working
            -- on an answer nobody will read.
            for _, r in pairs(inflight) do
                pcall(r.client.cancel_request, r.client, r.id)
            end
            local names = {}
            for name in pairs(pending) do
                names[#names + 1] = name
            end
            table.sort(names)
            vim.notify(("Go to (Space gd): no answer from %s after %.1fs%s"):format(
                table.concat(names, ", "), M._timeout_ms / 1000,
                #items > 0 and " -- showing what arrived" or ""), vim.log.levels.WARN)
        end
        open_picker(items)
    end
    local function done(name)
        pending[name] = (pending[name] or 1) - 1
        if pending[name] <= 0 then
            pending[name] = nil
        end
        remaining = remaining - 1
        if remaining == 0 then
            finish(false)
        end
    end
    for _, job in ipairs(jobs) do
        pending[job.client.name] = (pending[job.client.name] or 0) + 1
    end
    timer = vim.defer_fn(function()
        finish(true)
    end, M._timeout_ms)
    for _, job in ipairs(jobs) do
        local enc = job.client.offset_encoding
        local params = vim.lsp.util.make_position_params(0, enc)
        if job.m.method == "textDocument/references" then
            params.context = { includeDeclaration = false }
        end
        local slot = {}
        local ok, id = job.client:request(job.m.method, params, function(_, result)
            inflight[slot] = nil
            local locs = result or {}
            if not vim.islist(locs) then
                locs = { locs }
            end
            if opened then
                return
            end
            for _, it in ipairs(vim.lsp.util.locations_to_items(locs, enc)) do
                local key = it.filename .. ":" .. it.lnum .. ":" .. it.col
                local prev = seen[key]
                if prev then
                    if not vim.tbl_contains(prev.kinds, job.m.kind) then
                        table.insert(prev.kinds, job.m.kind)
                        table.sort(prev.kinds, function(a, b) return rank_of[a] < rank_of[b] end)
                        prev.rank = math.min(prev.rank, job.m.rank)
                    end
                else
                    it.rank = job.m.rank
                    it.kinds = { job.m.kind }
                    it.text = vim.trim(it.text or "")
                    seen[key] = it
                    table.insert(items, it)
                end
            end
            done(job.client.name)
        end, bufnr)
        if ok then
            inflight[slot] = { client = job.client, id = id }
        else
            done(job.client.name)
        end
    end
end

return M
