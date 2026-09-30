-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/flow_pragma.lua
-- The ts_ls Flow veto: only a real `@flow` pragma in a comment turns ts_ls off.
vim.opt.rtp:prepend(vim.fn.getcwd())
local flow = require('tajbanana.flow_pragma')
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

eq(flow.has_pragma({ '// @flow' }), true, '// @flow')
eq(flow.has_pragma({ '/* @flow strict */', 'import x from "y";' }), true, '/* @flow strict */')
eq(flow.has_pragma({ '/**', ' * Copyright',  ' * @flow', ' */' }), true, '@flow inside a doc block')
eq(flow.has_pragma({ '/* @flow*/' }), true, '@flow directly before */')
eq(flow.has_pragma({ 'import sdk from "@flowio/sdk";' }), false, 'an @flowio import is not a pragma')
eq(flow.has_pragma({ 'const s = "@flow";' }), false, '@flow in a string is not a pragma')
eq(flow.has_pragma({ '// uses @flowtype/x' }), false, '@flowtype in a comment is not the pragma')
eq(flow.has_pragma({ '// @noflow' }), false, '@noflow is not @flow')
-- Only the LEADING comments count, as for Flow itself.
eq(flow.has_pragma({ 'const a = 1;', '// TODO: remove @flow here' }), false, 'a comment after code is not a pragma')
eq(flow.has_pragma({ 'import x from "y";', '/** Handles @flow events */' }), false, 'a doc comment after code is not a pragma')
eq(flow.has_pragma({ '/*', ' @flow', ' */' }), true, 'star-less block header')
eq(flow.has_pragma({ '// @flow, strict' }), true, '@flow followed by a comma')
eq(flow.has_pragma({ '', '/* Copyright */', '// @flow', 'import x from "y";' }), true, 'pragma after a licence comment and a blank line')

print(('%d flow pragma checks passed'):format(checks))
vim.cmd('qa!')
