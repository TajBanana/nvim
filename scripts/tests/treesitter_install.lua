-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/treesitter_install.lua
-- A parser installed mid-session starts highlighting buffers that were opened
-- before it existed (audit_004 L12). nvim-treesitter is stubbed: the "install"
-- completes when the test says so, and the parser "appears" by registering an
-- installed parser (json) for a filetype that had none.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/site'))
local done
package.loaded['nvim-treesitter'] = {
    setup = function() end,
    get_installed = function() return {} end, -- everything "missing"
    install = function() return { await = function(_, cb) done = cb end } end,
}
dofile('lua/plugins/treesitter.lua').config()
vim.api.nvim_exec_autocmds('VimEnter', {})
assert(done, 'config installs missing parsers through install():await()')

vim.cmd('enew')
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '{ "a": 1 }' })
vim.bo[buf].filetype = 'fakelang' -- no parser yet: FileType start fails
assert(not vim.treesitter.highlighter.active[buf], 'no highlighter before the parser exists')

vim.treesitter.language.register('json', 'fakelang') -- the parser lands
done(nil) -- install finished
vim.wait(1000, function() return vim.treesitter.highlighter.active[buf] ~= nil end)
assert(vim.treesitter.highlighter.active[buf], 'open buffer highlighted once its parser was installed')
-- Fresh machine: stdpath('data')/site does not exist when Neovim first searches
-- the runtime path; the "install" then puts a real parser there. A child Neovim
-- with an empty XDG_DATA_HOME reproduces the cached-search problem.
local json_so = vim.api.nvim_get_runtime_file('parser/json.so', false)[1]
assert(json_so, 'needs the json parser installed')
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp .. '/data', 'p')
local child = tmp .. '/child.lua'
vim.fn.writefile({
    'vim.opt.rtp:prepend(' .. vim.inspect(vim.fn.getcwd()) .. ')',
    'local done',
    "package.loaded['nvim-treesitter'] = { setup = function() end, get_installed = function() return {} end,",
    '    install = function() return { await = function(_, cb) done = cb end } end }',
    "dofile(" .. vim.inspect(vim.fn.getcwd() .. '/lua/plugins/treesitter.lua') .. ').config()',
    "vim.api.nvim_exec_autocmds('VimEnter', {})",
    "vim.cmd('enew') vim.api.nvim_buf_set_lines(0, 0, -1, false, { '{}' }) vim.bo.filetype = 'json'",
    "local site = vim.fn.stdpath('data') .. '/site/parser'",
    'vim.fn.mkdir(site, "p")',
    'vim.uv.fs_copyfile(' .. vim.inspect(json_so) .. ', site .. "/json.so")',
    'done(nil)',
    'vim.wait(1000, function() return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil end)',
    "io.write(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] and 'ACTIVE' or 'INACTIVE')",
    "vim.cmd('qa!')",
}, child)
local out = vim.system({ 'nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '-l', child },
    { env = { XDG_DATA_HOME = tmp .. '/data' }, text = true }):wait(20000)
vim.fn.delete(tmp, 'rf')
assert((out.stdout or ''):find('ACTIVE', 1, true) == 1, 'fresh machine: parser found after install (got ' .. vim.inspect(out.stdout) .. ' ' .. vim.inspect(out.stderr) .. ')')

print('treesitter install checks passed')
vim.cmd('qa!')
