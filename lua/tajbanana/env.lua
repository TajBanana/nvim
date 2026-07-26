-- Environment/PATH bootstrapping for tools nvim shells out to. The node and
-- cargo fixes only run when the tool is missing from PATH, so a login shell that
-- already has them is untouched. The SDKMAN fix is different: `java` always
-- resolves (macOS /usr/bin/java), so it prepends SDKMAN's bins to override the
-- system JDK with the SDKMAN default -- see fix_sdkman_path.
local M = {}

-- nvm is lazy-loaded in .zshrc, so node is usually missing from PATH when nvim
-- launches from a GUI and Mason's node-based servers (ts_ls, yamlls, ...) die
-- with exit 127. Prepend the nvm node matching nvm's `default` alias, falling
-- back to the newest installed when the default is `node`/unset/unresolvable.
local function fix_node_path()
    if vim.fn.executable("node") ~= 0 then
        return
    end
    -- Parse each nvm dir's {major, minor, patch}; skip any whose name isn't
    -- vX.Y.Z. An unexpected entry would otherwise make the comparator do
    -- tonumber(nil) < ... and crash table.sort, aborting the whole config load.
    local nodes = {}
    for _, bin in ipairs(vim.fn.glob(vim.env.HOME .. "/.nvm/versions/node/*/bin", true, true)) do
        local maj, min, patch = bin:match("v(%d+)%.(%d+)%.(%d+)")
        if maj then
            nodes[#nodes + 1] = {
                path = bin,
                maj = tonumber(maj),
                min = tonumber(min),
                patch = tonumber(patch),
            }
        end
    end
    if #nodes == 0 then
        return
    end
    table.sort(nodes, function(a, b)
        if a.maj ~= b.maj then
            return a.maj < b.maj
        end
        if a.min ~= b.min then
            return a.min < b.min
        end
        return a.patch < b.patch
    end)

    -- Resolve nvm's `default` alias to a version string. The alias file can
    -- chain (default -> lts/* -> lts/hydrogen -> v18.20.4), so follow it up to
    -- a few hops. A non-numeric target (`node`, `stable`, unset) means "newest".
    local function resolve_alias(name, depth)
        if depth > 5 then
            return name
        end
        local f = vim.env.HOME .. "/.nvm/alias/" .. name
        if vim.fn.filereadable(f) == 0 then
            return name
        end
        local line = vim.trim((vim.fn.readfile(f) or { "" })[1] or "")
        if line == "" then
            return name
        end
        return resolve_alias(line, depth + 1)
    end

    -- Default to newest; override with the default alias when it resolves to a
    -- concrete version prefix that some installed version matches.
    local chosen = nodes[#nodes]
    local ver = (resolve_alias("default", 0) or ""):match("^v?(%d[%d%.]*)")
    if ver then
        local want = {}
        for n in ver:gmatch("%d+") do
            want[#want + 1] = tonumber(n)
        end
        for i = #nodes, 1, -1 do -- descending: highest matching version wins
            local comp = { nodes[i].maj, nodes[i].min, nodes[i].patch }
            local match = true
            for j, w in ipairs(want) do
                if comp[j] ~= w then
                    match = false
                    break
                end
            end
            if match then
                chosen = nodes[i]
                break
            end
        end
    end

    vim.env.PATH = chosen.path .. ":" .. vim.env.PATH
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

-- SDKMAN is lazy-loaded in .zshrc (like nvm), so its candidate bins aren't on
-- PATH for a GUI-launched nvim. Unlike node, `java` still resolves -- macOS
-- /usr/bin/java dispatches to the system JDK -- so nvim's JVM tooling silently
-- diverges from the SDKMAN default the terminal and builds use. Prepend each
-- candidate's `current` bin (a symlink to the `sdk default` version) so
-- kotlin-lsp, jdtls, ktlint, and :! gradle match the terminal. Prepending (not
-- appending) is deliberate: it must beat the system java on PATH.
local function fix_sdkman_path()
    local dir = vim.env.SDKMAN_DIR or (vim.env.HOME .. "/.sdkman")
    for _, candidate in ipairs({ "java", "kotlin", "gradle" }) do
        local bin = dir .. "/candidates/" .. candidate .. "/current/bin"
        -- Skip absent candidates and anything already on PATH (e.g. nvim launched
        -- from a shell where `sdk` was already sourced) to avoid duplicate entries.
        if vim.fn.isdirectory(bin) == 1 and not (":" .. (vim.env.PATH or "") .. ":"):find(":" .. bin .. ":", 1, true) then
            vim.env.PATH = bin .. ":" .. vim.env.PATH
        end
    end
    -- gradle and jdtls read JAVA_HOME over PATH; set it to the SDKMAN default
    -- only when unset, so an inherited `sdk use <ver>` session is left untouched.
    local java_home = dir .. "/candidates/java/current"
    if vim.fn.isdirectory(java_home) == 1 and (vim.env.JAVA_HOME or "") == "" then
        vim.env.JAVA_HOME = java_home
    end
end

function M.setup()
    fix_node_path()
    fix_cargo_path()
    fix_sdkman_path()
end

return M
