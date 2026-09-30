-- Per-kind inlay hint colors. Neovim's renderer paints every hint with the
-- single LspInlayHint group, discarding the LSP kind (1 = Type, 2 =
-- Parameter). This module re-tints rendered hints so a type hint wears the
-- palette's type color and a parameter hint the parameter color, both faded
-- toward the editor background ("semi-transparent" look). Colors live in
-- colorscheme.lua (LspInlayHintType / LspInlayHintParameter; kindless hints
-- keep LspInlayHint).
--
-- Fragility note (accepted trade-off): this rewrites extmarks owned by core
-- in its private "nvim.lsp.inlayhint" namespace; a Neovim upgrade that
-- changes the renderer may break the tinting (hints then fall back to plain
-- LspInlayHint grey, nothing worse). Re-renders briefly show grey until the
-- debounced re-tint pass runs.

local M = {}

-- same id core uses: nvim_create_namespace returns the existing namespace
local ns = vim.api.nvim_create_namespace("nvim.lsp.inlayhint")

local kind_group = {
    [1] = "LspInlayHintType",
    [2] = "LspInlayHintParameter",
}
local tintable = {
    LspInlayHint = true,
    LspInlayHintType = true,
    LspInlayHintParameter = true,
}

local function retint(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local ok, hints = pcall(vim.lsp.inlay_hint.get, { bufnr = buf })
    if not ok or #hints == 0 then
        return
    end
    -- hints bucketed exactly like the renderer: by (line, character), each with
    -- its label text as the renderer builds it (string, or parts joined)
    local by_pos = {}
    for _, h in ipairs(hints) do
        local p = h.inlay_hint.position
        local key = p.line .. ":" .. p.character
        local label = h.inlay_hint.label
        if type(label) ~= "string" then
            local parts = {}
            for _, part in ipairs(label) do
                parts[#parts + 1] = part.value
            end
            label = table.concat(parts)
        end
        by_pos[key] = by_pos[key] or {}
        table.insert(by_pos[key], { text = label, kind = h.inlay_hint.kind })
    end
    for _, em in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
        local id, row, col, d = em[1], em[2], em[3], em[4]
        local entries = d.virt_text and by_pos[row .. ":" .. col]
        if entries then
            -- Match each chunk to a hint by its label TEXT, not by position:
            -- core assembles the chunks with pairs() over clients, so when two
            -- hints share a position their order is unspecified and a positional
            -- pairing could swap the type and parameter colours. Padding chunks
            -- carry no group. Each hint is consumed once (duplicate labels).
            local used, changed = {}, false
            for _, chunk in ipairs(d.virt_text) do
                if tintable[chunk[2]] then
                    local kind
                    for j, e in ipairs(entries) do
                        if not used[j] and e.text == chunk[1] then
                            used[j], kind = true, e.kind
                            break
                        end
                    end
                    local want = kind_group[kind] or "LspInlayHint"
                    if chunk[2] ~= want then
                        chunk[2] = want
                        changed = true
                    end
                end
            end
            if changed then
                vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
                    id = id,
                    virt_text = d.virt_text,
                    virt_text_pos = d.virt_text_pos,
                    priority = d.priority,
                    right_gravity = d.right_gravity,
                })
            end
        end
    end
end

local timers = {}

---Debounced re-tint for a buffer (nvim re-renders hints on its own schedule;
---we follow shortly after).
function M.schedule(buf)
    local t = timers[buf]
    if not t then
        t = vim.uv.new_timer()
        timers[buf] = t
    end
    t:stop()
    t:start(120, 0, vim.schedule_wrap(function()
        retint(buf)
    end))
end

function M.setup()
    local grp = vim.api.nvim_create_augroup("InlayTint", { clear = true })
    -- WinScrolled: lines scrolled into view are painted plain LspInlayHint by
    -- core's decoration provider on first draw, so re-tint them once revealed.
    vim.api.nvim_create_autocmd(
        { "LspAttach", "InsertLeave", "TextChanged", "BufEnter", "CursorHold", "LspProgress", "WinScrolled" },
        {
            group = grp,
            callback = function(ev)
                local buf = (ev.event == "LspProgress" or ev.event == "WinScrolled")
                        and vim.api.nvim_get_current_buf()
                    or ev.buf
                M.schedule(buf)
            end,
        }
    )
    -- BufDelete/BufUnload as well as BufWipeout: a buffer that is merely deleted
    -- or unloaded never fires BufWipeout, so its idle libuv timer handle (and
    -- table entry) leaked for the rest of the session, one per buffer visited.
    vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete", "BufUnload" }, {
        group = grp,
        callback = function(ev)
            local t = timers[ev.buf]
            if t then
                t:stop()
                t:close()
                timers[ev.buf] = nil
            end
        end,
    })
end

-- exposed for verification
M._retint = retint

return M
