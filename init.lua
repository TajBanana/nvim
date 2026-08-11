require("tajbanana.set")

-- Bootstrap lazy.nvim.
--
-- NOTE: `--branch=stable` is a MOVING target, and lazy.nvim cannot restore
-- *itself* during its own bootstrap -- so whatever this clone lands on is what
-- gets written to lazy-lock.json. If the pin there disagrees, every fresh clone
-- rewrites the lockfile and the user starts with a dirty working tree before
-- doing anything. The pin is therefore kept equal to the commit `stable`
-- currently resolves to:
--
--     git ls-remote https://github.com/folke/lazy.nvim.git 'refs/tags/stable^{}'
--
-- Re-sync it whenever lazy.nvim cuts a release (it is the one plugin whose
-- version this lockfile cannot actually enforce).
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
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
