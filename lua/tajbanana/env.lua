-- Environment/PATH bootstrapping for tools nvim shells out to. Both fixes only
-- run when the tool is missing from PATH, so a normal login shell that already
-- has them is untouched.
local M = {}

-- nvm is lazy-loaded in .zshrc, so node is usually missing from PATH when nvim
-- launches from a GUI and Mason's node-based servers (ts_ls, yamlls, ...) die
-- with exit 127. Prepend the newest installed nvm node.
local function fix_node_path()
    if vim.fn.executable("node") ~= 0 then
        return
    end
    -- Parse each nvm dir's {major, minor}; skip any whose name isn't vX.Y. An
    -- unexpected entry would otherwise make the comparator do tonumber(nil) < ...
    -- and crash table.sort, aborting the whole config load.
    local nodes = {}
    for _, bin in ipairs(vim.fn.glob(vim.env.HOME .. "/.nvm/versions/node/*/bin", true, true)) do
        local maj, min = bin:match("v(%d+)%.(%d+)")
        if maj then
            nodes[#nodes + 1] = { path = bin, maj = tonumber(maj), min = tonumber(min) }
        end
    end
    table.sort(nodes, function(a, b)
        if a.maj ~= b.maj then
            return a.maj < b.maj
        end
        return a.min < b.min
    end)
    if #nodes > 0 then
        vim.env.PATH = nodes[#nodes].path .. ":" .. vim.env.PATH
    end
end

-- rustup's toolchain proxies aren't on the default PATH (brew keeps them in its
-- own prefix); rust-analyzer needs cargo/rustc visible to load workspaces.
local function fix_cargo_path()
    if vim.fn.executable("cargo") ~= 0 then
        return
    end
    for _, dir in ipairs({ vim.env.HOME .. "/.cargo/bin", "/opt/homebrew/opt/rustup/bin" }) do
        if vim.fn.isdirectory(dir) == 1 then
            vim.env.PATH = vim.env.PATH .. ":" .. dir
            break
        end
    end
end

function M.setup()
    fix_node_path()
    fix_cargo_path()
end

return M
