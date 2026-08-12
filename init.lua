require("tajbanana.set")

-- Bootstrap lazy.nvim.
--
-- A fresh clone is pinned to the exact `lazy.nvim` commit recorded in
-- lazy-lock.json. lazy.nvim cannot restore *itself* during its own bootstrap, so
-- without this a clone lands on whatever the moving `--branch=stable` tag happens
-- to be -- diverging from the lockfile and leaving a dirty tree on first launch.
-- Checking it out here makes lazy.nvim reproduce like any other plugin; paired
-- with `pin = true` in lua/plugins/lazy.lua (which stops `:Lazy update` from
-- bumping it), the lockfile finally enforces its version. To upgrade it: drop
-- that pin, `:Lazy update`, re-pin, and commit the new lazy-lock.json.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end

    -- Pin the clone to the lockfile's commit; fall back to the cloned `stable`
    -- tag if the lockfile is missing or unreadable.
    local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
    local ok, lock = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
    end)
    local pin = ok and type(lock) == "table" and lock["lazy.nvim"] and lock["lazy.nvim"].commit
    if pin then
        vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", pin })
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
