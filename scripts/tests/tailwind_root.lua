-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/tailwind_root.lua
-- tailwindcss root detection: Tailwind projects of every shape, and nothing else.
vim.opt.rtp:prepend(vim.fn.getcwd())
local find = require('tajbanana.tailwind_root').find
local checks = 0
local tmp = vim.fn.resolve(vim.fn.tempname())
local function write(path, text)
    vim.fn.mkdir(vim.fs.dirname(tmp .. '/' .. path), 'p')
    vim.fn.writefile({ text }, tmp .. '/' .. path)
end
local function root_of(path)
    local r = find(tmp .. '/' .. path)
    return r and r:sub(#tmp + 2) or nil
end
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

write('plain/.git/HEAD', 'x')
write('plain/README.md', 'x')
write('v3/tailwind.config.ts', 'x')
write('v3/src/a.html', 'x')
write('pc/postcss.config.mjs', "export default { plugins: { '@tailwindcss/postcss': {} } }")
write('pc/src/a.html', 'x')
write('pcno/postcss.config.js', 'module.exports = { plugins: { autoprefixer: {} } }')
write('pcno/src/a.html', 'x')
write('rails/Gemfile.lock', '    tailwindcss-rails (4.0.0)')
write('rails/postcss.config.js', 'module.exports = { plugins: { autoprefixer: {} } }')
write('rails/app/views/a.html.erb', 'x')
write('phx/mix.lock', '"tailwind": {:hex, :tailwind, "0.2.4"}')
write('phx/lib/app_web/a.heex', 'x')
write('dj/theme/static_src/tailwind.config.js', 'x')
write('dj/templates/a.html', 'x')
write('dj4/theme/static_src/postcss.config.js', "plugins: { '@tailwindcss/postcss': {} }")
write('dj4/theme/templates/base.html', 'x')
write('pj/package.json', '{"devDependencies":{"tailwindcss":"4"}}')
write('pj/src/a.html', 'x')
write('mono/package.json', '{"devDependencies":{"tailwindcss":"4"}}')
write('mono/packages/ui/package.json', '{"name":"ui"}')
write('mono/packages/ui/src/a.tsx', 'x')
write('deno/deno.json', '{"imports":{"tailwindcss":"npm:tailwindcss@4"}}')
write('deno/routes/a.tsx', 'x')

eq(root_of('plain/README.md'), nil, 'plain git repo: never started')
eq(root_of('pcno/src/a.html'), nil, 'postcss without tailwind: not started')
eq(root_of('v3/src/a.html'), 'v3', 'tailwind.config.*')
eq(root_of('pc/src/a.html'), 'pc', 'v4 via @tailwindcss/postcss')
eq(root_of('rails/app/views/a.html.erb'), 'rails', 'Rails Gemfile.lock beside a tailwind-free postcss config')
eq(root_of('phx/lib/app_web/a.heex'), 'phx', 'Phoenix mix.lock')
eq(root_of('dj/templates/a.html'), 'dj/theme/static_src', 'Django theme/static_src tailwind config')
eq(root_of('dj4/theme/templates/base.html'), 'dj4/theme/static_src', 'Django v4 theme/static_src postcss config')
eq(root_of('pj/src/a.html'), 'pj', 'package.json depending on tailwindcss')
eq(root_of('mono/packages/ui/src/a.tsx'), 'mono', 'monorepo root package.json past a tailwind-free sub-package')
eq(root_of('deno/routes/a.tsx'), 'deno', 'deno.json importing tailwindcss')

-- Bounded: a package.json above the repo root, or in $HOME outside any repo,
-- must not root the server there.
write('up/package.json', '{"devDependencies":{"tailwindcss":"4"}}')
write('up/repo/.git/HEAD', 'x')
write('up/repo/src/a.html', 'x')
eq(root_of('up/repo/src/a.html'), nil, 'a package.json above the git root is ignored')
local real_home = vim.uv.os_homedir
vim.uv.os_homedir = function() return tmp .. '/fakehome' end
write('fakehome/package.json', '{"devDependencies":{"tailwindcss":"4"}}')
write('fakehome/work/api/a.html', 'x')
eq(root_of('fakehome/work/api/a.html'), nil, 'outside git: $HOME/package.json is ignored')
-- A symlinked home and a new file in a directory that does not exist yet: the
-- unresolved start never equalled the resolved home, so the walk passed it.
write('realhome/package.json', '{"devDependencies":{"tailwindcss":"4"}}')
vim.uv.fs_symlink(tmp .. '/realhome', tmp .. '/linkhome')
vim.uv.os_homedir = function() return tmp .. '/linkhome' end
eq(require('tajbanana.tailwind_root').find(tmp .. '/linkhome/new/deeper/a.html'), nil,
    'symlinked home, missing directories: $HOME/package.json is still ignored')
vim.uv.os_homedir = real_home

vim.fn.delete(tmp, 'rf')
print(('%d tailwind root checks passed'):format(checks))
