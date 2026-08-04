-- Open each file listed in $NVTEST_FILES (newline separated) with the REAL
-- config, let LSP/treesitter settle, and report per-file state + any errors.
-- Results are written as JSON-ish lines to $NVTEST_OUT.
local files = {}
for line in (vim.env.NVTEST_FILES or ""):gmatch("[^\n]+") do
    files[#files + 1] = line
end
local out = assert(io.open(vim.env.NVTEST_OUT, "w"))
local settle = tonumber(vim.env.NVTEST_SETTLE or "6000")

-- Collect hard errors as they happen, not just at the end.
local errors = {}
local orig_notify = vim.notify
vim.notify = function(msg, level, o)
    if level and level >= vim.log.levels.ERROR then
        errors[#errors + 1] = "notify: " .. tostring(msg)
    end
    return orig_notify(msg, level, o)
end

local function esc(s)
    return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " | ")
end

local i = 0
local function step()
    i = i + 1
    if i > #files then
        -- Anything that reached :messages (autocmd errors surface only here).
        local msgs = vim.fn.execute("messages")
        for line in msgs:gmatch("[^\n]+") do
            if line:match("^E%d+:") or line:match("[Ee]rror executing") or line:match("Lua callback")
                or line:match("attempt to") or line:match("stack traceback") then
                errors[#errors + 1] = "messages: " .. line
            end
        end
        out:write('{"kind":"errors","items":[')
        for n, e in ipairs(errors) do
            out:write((n > 1 and "," or "") .. '"' .. esc(e) .. '"')
        end
        out:write("]}\n")
        out:close()
        vim.cmd("qa!")
        return
    end

    local f = files[i]
    local ok, err = pcall(vim.cmd, "edit! " .. vim.fn.fnameescape(f))
    if not ok then
        errors[#errors + 1] = "edit " .. f .. ": " .. tostring(err)
        return vim.defer_fn(step, 50)
    end

    vim.defer_fn(function()
        local buf = vim.api.nvim_get_current_buf()
        local ft = vim.bo[buf].filetype
        -- treesitter highlighter actually attached?
        local ts = false
        local okh, hl = pcall(function() return vim.treesitter.highlighter.active[buf] end)
        ts = okh and hl ~= nil

        local clients = {}
        for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
            clients[#clients + 1] = c.name
        end
        table.sort(clients)

        -- gitsigns attached / what base is it diffing against?
        local base = "n/a"
        local okc, cache = pcall(require, "gitsigns.cache")
        if okc and cache.cache[buf] then
            local gobj = cache.cache[buf].git_obj
            base = tostring(gobj and gobj.revision or "index")
        end

        local diags = #vim.diagnostic.get(buf)

        out:write(string.format(
            '{"kind":"file","path":"%s","ft":"%s","ts":%s,"clients":"%s","base":"%s","diags":%d,"lines":%d}\n',
            esc(f), esc(ft), tostring(ts), esc(table.concat(clients, "+")), esc(base), diags,
            vim.api.nvim_buf_line_count(buf)
        ))
        out:flush()
        step()
    end, settle)
end

vim.defer_fn(step, 3000)
