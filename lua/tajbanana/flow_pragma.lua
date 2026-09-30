-- Whether a JS/JSX file carries a Flow `@flow` pragma (ts_ls's root_dir in
-- lsp.lua vetoes such files). Flow reads the pragma from the comments at the TOP
-- of the file, before any code, so only that leading block is searched:
--   * `@flow` must be a whole word (`// @flow`, `/* @flow strict */`,
--     `// @flow, strict`) -- a bare substring search also matched imports like
--     `@flowio/sdk` and turned ts_ls off for ordinary files;
--   * every line inside a /* */ block counts, with or without a leading `*`
--     (a star-less `/*` / ` @flow` / ` */` header was missed);
--   * a comment AFTER code (`// TODO: remove @flow here`) is not a pragma --
--     it used to turn ts_ls off too.
-- Regression checks: scripts/tests/flow_pragma.lua.
local M = {}

local function names_flow(text)
    return text:match("@flow$") ~= nil or text:match("@flow[^%w_%-/@.]") ~= nil
end

function M.has_pragma(lines)
    local in_block = false
    for _, line in ipairs(lines) do
        local rest = line
        while rest ~= "" do
            if in_block then
                local body, after = rest:match("^(.-)%*/(.*)$")
                if names_flow(body or rest) then
                    return true
                end
                if not body then
                    rest = ""
                else
                    in_block, rest = false, after
                end
            else
                rest = rest:match("^%s*(.-)$")
                if rest == "" then
                    break
                elseif rest:sub(1, 2) == "//" then
                    if names_flow(rest:sub(3)) then
                        return true
                    end
                    rest = ""
                elseif rest:sub(1, 2) == "/*" then
                    in_block, rest = true, rest:sub(3)
                else
                    return false -- code: the leading comments are over
                end
            end
        end
    end
    return false
end

return M
