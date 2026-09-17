local M = {}

local languages = {
    kotlin = "kotlin",
    typescript = "typescript",
    typescriptreact = "tsx",
    javascript = "javascript",
    javascriptreact = "javascript",
    yaml = "yaml",
    helm = "yaml", -- Helm injects YAML around its Go-template expressions.
}

local web_nodes = {
    "lexical_declaration", "variable_declaration", "call_expression", "new_expression",
    "object", "array", "object_type", "interface_body", "class_body", "enum_body",
    "jsx_self_closing_element",
}

M.include = {
    kotlin = {
        "property_declaration", "call_expression", "try_expression",
        "catch_block", "finally_block", "object_literal",
    },
    typescript = web_nodes,
    tsx = web_nodes,
    javascript = web_nodes,
    yaml = { "block_mapping_pair", "block_sequence_item", "flow_mapping", "flow_sequence" },
}

-- YAML nodes can end at column zero on the next line, after trailing blank
-- lines. ibl treats that endpoint as an inclusive line and uses its indent.
-- Present a trimmed range to the renderer without changing the syntax tree.
local function yaml_scope(buf, node)
    local sr, sc, er, ec = node:range()
    local lines = vim.api.nvim_buf_get_lines(buf, sr, er + 1, false)
    local last = #lines
    if ec == 0 and sr + last - 1 == er then last = last - 1 end
    while last > 1 and not lines[last]:find("%S") do last = last - 1 end
    local row = sr + last - 1
    if row == er then return node end
    local col = #(lines[last] or "")
    local byte = vim.api.nvim_buf_get_offset(buf, row) + col
    return setmetatable({
        end_ = function() return row, col, byte end,
        range = function(_, include_bytes)
            if include_bytes then
                local _, _, start_byte = node:start()
                return sr, sc, start_byte, row, col, byte
            end
            return sr, sc, row, col
        end,
    }, {
        __index = function(_, key)
            local value = node[key]
            if type(value) == "function" then
                return function(_, ...) return value(node, ...) end
            end
            return value
        end,
    })
end

function M.setup()
    if M.installed then return end
    M.installed = true
    local scope = require("ibl.scope")
    local get_cursor_range, get_scope = scope.get_cursor_range, scope.get

    scope.get_cursor_range = function(win)
        local buf = vim.api.nvim_win_get_buf(win)
        if not languages[vim.bo[buf].filetype] then return get_cursor_range(win) end
        -- Leading whitespace lies outside declarations and opening tags. Use
        -- the cursor itself, or the first nonblank character when in the indent.
        local pos = vim.api.nvim_win_get_cursor(win)
        local line = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1] or ""
        local col = math.max(pos[2], #(line:match("^%s*") or ""))
        -- Keep the YAML guide while moving through an embedded {{ ... }}
        -- expression: anchor on the mapping key/list marker on this line.
        if vim.bo[buf].filetype == "helm" then col = #(line:match("^%s*") or "") end
        return { pos[1] - 1, col, pos[1] - 1, col }
    end

    scope.get = function(buf, config)
        local node = get_scope(buf, config)
        local lang = languages[vim.bo[buf].filetype]
        if not lang then return node end
        local defaults = require("ibl.scope_languages")[lang] or {}
        local function contains(list, kind)
            return vim.tbl_contains(list or {}, kind) or vim.tbl_contains(list or {}, "*")
        end
        while node do
            local kind = node:type()
            local included = contains(config.scope.include.node_type[lang], kind)
                or contains(config.scope.include.node_type["*"], kind)
            local excluded = contains(config.scope.exclude.node_type[lang], kind)
                or contains(config.scope.exclude.node_type["*"], kind)
            -- Inline arguments/objects/callbacks have no vertical guide of
            -- their own; retain the enclosing multiline scope instead.
            local multiline = node:start() < node:end_()
            if (included or (defaults[kind] and not excluded))
                and (multiline or (lang == "kotlin" and kind == "property_declaration")) then
                return lang == "yaml" and yaml_scope(buf, node) or node
            end
            node = node:parent()
        end
    end
end

return M
