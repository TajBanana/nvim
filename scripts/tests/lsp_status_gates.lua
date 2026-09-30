-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/lsp_status_gates.lua
-- The statusline only expects a server lsp.lua can actually install/enable on
-- this machine: without npm, an npm-built server that is not installed shows
-- the grey ○ (no server), not a red ✗ -- mirroring the Rust and Go gates.
vim.opt.rtp:prepend(vim.fn.getcwd())
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

-- nvim-lspconfig's REAL configs: ts_ls, jsonls, yamlls, cssls and html have
-- function cmds there (a version that inspected `cmd` took those as "can
-- start"). PATH holds only system dirs plus a fake installed yaml-language-server.
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/nvim-lspconfig')
eq(type(vim.lsp.config.ts_ls.cmd), 'function', 'precondition: lspconfig ts_ls has a function cmd')
local bin = vim.fn.tempname()
vim.fn.mkdir(bin, 'p')
vim.fn.writefile({ '#!/bin/sh' }, bin .. '/yaml-language-server')
vim.fn.setfperm(bin .. '/yaml-language-server', 'rwxr-xr-x')
vim.env.PATH = bin .. ':/usr/bin:/bin'
local real = vim.fn.executable
local function load(tools)
    vim.fn.executable = function(bin)
        if tools[bin] ~= nil then return tools[bin] and 1 or 0 end
        return real(bin)
    end
    package.loaded['tajbanana.lsp_status'] = nil
    local status = require('tajbanana.lsp_status')
    vim.fn.executable = real
    return status
end

local s = load({ npm = false, go = false, rustc = false, cargo = false })
for _, ft in ipairs({ 'typescript', 'json', 'css', 'html', 'python', 'sh', 'dockerfile', 'graphql' }) do
    eq(s._classify(ft, {}), 'none', 'no npm, server not installed: grey ○, not a red ✗ (' .. ft .. ')')
end
eq(s._classify('yaml', {}), 'bad', 'no npm, yamlls installed: still expected')
eq(s._classify('go', {}), 'none', 'no go: gopls not expected')
eq(s._classify('rust', {}), 'none', 'no rust toolchain: rust_analyzer not expected')
eq(s._classify('lua', {}), 'bad', 'lua_ls (not npm-built) is always expected')

s = load({ npm = true, go = true, rustc = true, cargo = true })
eq(s._classify('typescript', {}), 'bad', 'with npm: ts_ls expected (Mason can install it)')
eq(s._classify('go', {}), 'bad', 'with go: gopls expected')
eq(s._classify('rust', {}), 'bad', 'with a rust toolchain: rust_analyzer expected')

vim.fn.delete(bin, 'rf')
print(('%d lsp status gate checks passed'):format(checks))
vim.cmd('qa!')
