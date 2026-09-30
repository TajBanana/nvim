-- Run: nvim --headless -u NONE -i NONE -n -l scripts/tests/set_lua.lua
-- lua/tajbanana/set.lua loaded on its own: the custom filetype rules, template
-- commentstring, <leader>go's on-disk guard, <Esc>'s float closing and the
-- repaint throttle. Nothing else loaded set.lua, so these had no checks.
vim.opt.rtp:prepend(vim.fn.getcwd())
local opened = {}
package.loaded['tajbanana.system_open'] = { open = function(p) opened[#opened + 1] = p end }
local notes = {}
vim.notify = function(msg) notes[#notes + 1] = msg end
dofile('lua/tajbanana/set.lua')
-- set.lua turns on undofile: keep this test's undo files out of the real undodir.
vim.o.undodir = vim.fn.tempname()
local checks = 0
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end

local tmp = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
tmp = vim.uv.fs_realpath(tmp)
local function write(rel, text)
    vim.fn.mkdir(vim.fs.dirname(tmp .. '/' .. rel), 'p')
    vim.fn.writefile({ text or '' }, tmp .. '/' .. rel)
end
write('chart/Chart.yaml', 'name: c')
write('chart/templates/deploy.yaml')
write('chart/templates/_helpers.tpl')
write('chart/values.yaml')
write('chart/values-prod.yaml')
write('chart/values.dev.yaml')
write('chart/valuesfoo.yaml')
write('notchart/templates/x.yaml')
write('notchart/values.yaml')
write('app/compose.yaml')
write('app/docker-compose.override.yml')
write('app/.gitlab-ci.yml')
write('app/x.gotmpl')
write('app/x.yaml.gotmpl')
write('app/m.iml')
local function ft(rel)
    return vim.filetype.match({ filename = tmp .. '/' .. rel })
end
for rel, want in pairs({
    ['chart/templates/deploy.yaml'] = 'helm',
    ['chart/templates/_helpers.tpl'] = 'helm',
    ['chart/values.yaml'] = 'yaml.helm-values',
    ['chart/values-prod.yaml'] = 'yaml.helm-values',
    ['chart/values.dev.yaml'] = 'yaml.helm-values',
    ['chart/valuesfoo.yaml'] = 'yaml', -- d155bb4: not a values file
    ['notchart/templates/x.yaml'] = 'yaml', -- templates/ outside a chart
    ['notchart/values.yaml'] = 'yaml',
    ['app/compose.yaml'] = 'yaml.docker-compose',
    ['app/docker-compose.override.yml'] = 'yaml.docker-compose',
    ['app/.gitlab-ci.yml'] = 'yaml.gitlab',
    ['app/x.gotmpl'] = 'gotmpl',
    ['app/x.yaml.gotmpl'] = 'helm',
    ['app/m.iml'] = 'xml',
}) do
    eq(ft(rel), want, 'filetype of ' .. rel)
end

-- gc/gcc on Go-template files: a template comment.
vim.cmd('filetype on')
for _, rel in ipairs({ 'chart/templates/deploy.yaml', 'app/x.gotmpl' }) do
    vim.cmd('edit ' .. tmp .. '/' .. rel)
    eq(vim.bo.commentstring, '{{/* %s */}}', 'commentstring for ' .. rel)
end

-- ...and with treesitter running, where commenting takes the commentstring of
-- the INJECTED yaml at the cursor: a YAML line in a template used to get `#`,
-- which the template still renders. Needs the helm and yaml parsers.
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/site'))
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/nvim-treesitter/runtime')
vim.opt.rtp:append(vim.fn.getcwd() .. '/after')
-- `filetype plugin on` as in the real config: it loads yaml's own `# %s`
-- (without it the injected yaml had no commentstring and this passed vacuously).
vim.cmd('filetype plugin on')
if pcall(vim.treesitter.language.add, 'helm') and pcall(vim.treesitter.language.add, 'yaml') then
    local tpl = { 'metadata:', '  name: {{ .Release.Name }}', '  labels: {}' }
    vim.cmd('edit! ' .. tmp .. '/chart/templates/deploy.yaml')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, tpl)
    vim.treesitter.start(0, 'helm')
    vim.treesitter.get_parser(0):parse(true)
    eq(vim.filetype.get_option('yaml', 'commentstring'), '# %s', 'precondition: the injected yaml has its own # commentstring')
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    vim.cmd('normal gcc')
    eq(vim.api.nvim_get_current_line(), '  {{/* name: {{ .Release.Name }} */}}', 'gcc on a YAML line of a template: a template comment')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, tpl)
    vim.treesitter.get_parser(0):parse(true)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd('normal gcj')
    eq(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], '{{/* metadata: */}}', 'gcj (a range): template comments too')
    vim.bo.modified = false
else
    print('SKIPPED: helm/yaml treesitter parsers not installed')
end

-- <leader>go hands over only real on-disk paths.
local go = vim.fn.maparg('<leader>go', 'n', false, true).callback
vim.cmd('edit ' .. tmp .. '/app/compose.yaml')
go()
eq(opened[#opened], tmp .. '/app/compose.yaml', '<leader>go opens a real file')
local n = #opened
vim.cmd('enew')
vim.bo.buftype = 'nofile'
vim.api.nvim_buf_set_name(0, tmp .. '/app/compose.yaml.scratch')
go()
eq(#opened, n, '<leader>go refuses a scratch buffer')
vim.cmd('enew')
vim.api.nvim_buf_set_name(0, tmp .. '/does/not/exist.txt')
go()
eq(#opened, n, '<leader>go refuses a path that is not on disk')

-- <Esc> closes floats, but keeps fidget's (it would just re-render).
local function float(filetype)
    local b = vim.api.nvim_create_buf(false, true)
    vim.bo[b].filetype = filetype
    return vim.api.nvim_open_win(b, false, { relative = 'editor', row = 1, col = 1, width = 5, height = 1 })
end
local plain, fidget = float(''), float('fidget')
vim.fn.maparg('<Esc>', 'n', false, true).callback()
eq(vim.api.nvim_win_is_valid(plain), false, '<Esc> closes a float')
eq(vim.api.nvim_win_is_valid(fidget), true, "<Esc> keeps fidget's float")
vim.api.nvim_win_close(fidget, true)

-- Repaint throttle: a burst of scrolls is one redraw!, fired after the burst.
local redraws, real_cmd = 0, vim.cmd
vim.cmd = setmetatable({}, {
    __call = function(_, c)
        if c == 'redraw!' then redraws = redraws + 1 return end
        return real_cmd(c)
    end,
    __index = real_cmd,
})
for _ = 1, 10 do vim.api.nvim_exec_autocmds('WinScrolled', {}) end
vim.wait(150)
vim.cmd = real_cmd
eq(redraws, 1, 'ten scrolls in a burst: one repaint')

vim.fn.delete(tmp, 'rf')
print(('%d set.lua checks passed'):format(checks))
vim.cmd('qa!')
