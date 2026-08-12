-- Statusline indicator for language-server load status.
--
-- Beside the current buffer's filetype, lualine shows:
--   ✓ green   a server has attached AND finished loading (no in-flight work)
--   ⟳ yellow  a server is attached but still working (indexing / initial load)
--   ✗ red     a server is EXPECTED for this filetype but none has attached
--   ○ grey    a real filetype with no configured server
--   (blank)   no filetype at all (special buffers, terminals, the file tree)
--
-- "Finished loading" is detected from LSP work-done progress ($/progress): a
-- server that is still indexing keeps a progress token open, so ✓ is withheld
-- until every token has ended. Servers that emit no progress are ready as soon
-- as they attach (they have no async load phase to report), so they go straight
-- to ✓. This is why the icon no longer flips to ✓ the instant the client
-- attaches -- it waits for the work to finish. The X -> ⟳ -> ✓ progression makes
-- a slow server (kotlin-lsp, jdtls) visible; an expired/dead one stays X.
--
-- Only each filetype's PRIMARY language server drives the indicator; linters and
-- other secondary clients that attach to the same buffer are ignored (see the
-- PRIMARY table below for why that has to be per-filetype).

local M = {}

local OK = "✓"
local LOADING = "⟳"
local BAD = "✗"
local NONE = "○"
local OK_FG = "#C3E88D" -- md_green
local LOADING_FG = "#FFCB6B" -- md_yellow
local BAD_FG = "#F07178" -- md_red
local NONE_FG = "#5c6370" -- muted comment grey

-- The ONE language server that represents each filetype. The indicator tracks
-- only this server; every other client that attaches to the same buffer is
-- ignored. A single primary per filetype is deliberate: several filetypes draw
-- more than one server, and the extras finish at a different time, which made
-- the icon flip to ✓ the moment one settled and back to ⟳ while the real server
-- was still indexing. Real overlaps in this config (see the ft-overlap audit):
--   .ts / .js        -> ts_ls + eslint (linter)
--   .tsx / .jsx      -> ts_ls + eslint + graphql (embedded gql`` queries)
--   yaml.helm-values -> yamlls + helm_ls
-- graphql is why a name-based ignore list is not enough: it is auxiliary on a
-- .tsx buffer but the PRIMARY server on a real .graphql file, so the choice has
-- to be per filetype, not per client name.
--
-- A filetype absent here has no configured server (-> the grey ○). Mirror this
-- with ensure_installed in lua/plugins/lsp.lua when adding a language.
local PRIMARY = {
    typescript = "ts_ls",
    typescriptreact = "ts_ls",
    javascript = "ts_ls",
    javascriptreact = "ts_ls",
    lua = "lua_ls",
    java = "jdtls",
    kotlin = "kotlin_lsp",
    json = "jsonls",
    jsonc = "jsonls",
    yaml = "yamlls",
    ["yaml.docker-compose"] = "yamlls",
    ["yaml.gitlab"] = "yamlls",
    ["yaml.helm-values"] = "helm_ls",
    css = "cssls",
    scss = "cssls",
    less = "cssls",
    html = "html",
    python = "pyright",
    go = "gopls",
    gomod = "gopls",
    gowork = "gopls",
    gotmpl = "gopls",
    bash = "bashls",
    sh = "bashls",
    dockerfile = "dockerls",
    graphql = "graphql",
    helm = "helm_ls",
}
-- rust_analyzer is only enabled when a toolchain is present (see lsp.lua), so
-- only claim rust then -- otherwise every .rs file shows a red X on a Rust-less
-- machine.
if vim.fn.executable("rustc") == 1 and vim.fn.executable("cargo") == 1 then
    PRIMARY.rust = "rust_analyzer"
end

-- Per-client set of open work-done progress tokens: active[client_id][token] =
-- true while that operation is running. A client with any open token is still
-- "loading". Populated by the LspProgress autocmd below.
local active = {}

local function client_loading(client_id)
    local toks = active[client_id]
    return toks ~= nil and next(toks) ~= nil
end

-- Pure classification of a buffer's status from its filetype and attached
-- clients (each entry { name = <string>, loading = <bool> }). Only the filetype's
-- PRIMARY server is considered; any other attached client is ignored. Returns
-- "ok" (primary attached and idle), "loading" (primary attached, work in
-- flight), "bad" (a primary is configured but not attached), "none" (no server
-- configured for this filetype), or nil (no filetype). Exposed for testing.
function M._classify(ft, clients)
    if ft == "" then
        return nil
    end
    local primary = PRIMARY[ft]
    if not primary then
        return "none"
    end
    local attached, loading = false, false
    for _, c in ipairs(clients) do
        if c.name == primary then
            attached = true
            if c.loading then
                loading = true
            end
        end
    end
    if not attached then
        return "bad"
    end
    return loading and "loading" or "ok"
end

local function state()
    local clients = {}
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
        clients[#clients + 1] = { name = c.name, loading = client_loading(c.id) }
    end
    return M._classify(vim.bo.filetype, clients)
end

function M.component()
    local s = state()
    if s == "ok" then
        return OK
    elseif s == "loading" then
        return LOADING
    elseif s == "bad" then
        return BAD
    elseif s == "none" then
        return NONE
    end
    return ""
end

function M.color()
    local s = state()
    if s == "ok" then
        return { fg = OK_FG }
    elseif s == "loading" then
        return { fg = LOADING_FG }
    elseif s == "bad" then
        return { fg = BAD_FG }
    elseif s == "none" then
        return { fg = NONE_FG }
    end
    return nil
end

local group = vim.api.nvim_create_augroup("lsp_status_line", { clear = true })

-- Track work-done progress so ✓ waits for indexing/initial load to finish.
-- ev.data field name has moved between nvim versions (params vs result); accept
-- either. A "begin" opens a token, "end" closes it; "report" leaves it open.
vim.api.nvim_create_autocmd("LspProgress", {
    group = group,
    callback = function(ev)
        local data = ev.data or {}
        local params = data.params or data.result or {}
        local token = params.token
        local value = params.value or {}
        local cid = data.client_id
        if cid == nil or token == nil then
            return
        end
        if value.kind == "begin" then
            active[cid] = active[cid] or {}
            active[cid][token] = true
        elseif value.kind == "end" then
            if active[cid] then
                active[cid][token] = nil
            end
        end
        pcall(function()
            require("lualine").refresh()
        end)
    end,
})

-- Flip the indicator the moment a client attaches/detaches too, and drop a
-- detached client's progress bookkeeping so it can't get stuck "loading".
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = group,
    callback = function(ev)
        if ev.event == "LspDetach" and ev.data and ev.data.client_id then
            active[ev.data.client_id] = nil
        end
        pcall(function()
            require("lualine").refresh()
        end)
    end,
})

return M
