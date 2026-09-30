-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/repo_diagnostics.lua
-- Offline checks for <leader>xr project detection, the parsers and errorformats.
vim.opt.rtp:prepend(vim.fn.getcwd())
-- -u NONE skips mason's PATH setup; add its bin dir so the tool-gated checks
-- (golangci-lint, hadolint) run where Mason has installed them.
vim.env.PATH = vim.fn.stdpath('data') .. '/mason/bin:' .. vim.env.PATH
local diag = require('tajbanana.repo_diagnostics')
local checks, skipped = 0, {}
local function eq(got, want, what)
    checks = checks + 1
    assert(got == want, ('%s: got %s, want %s'):format(what, vim.inspect(got), vim.inspect(want)))
end
local has = function(t) return vim.fn.executable(t) == 1 end
-- Run `fn` only when `tool` is installed; otherwise record the skip so the
-- summary says what was NOT checked instead of silently passing.
local function with_tool(tool, fn)
    if has(tool) then fn() else skipped[#skipped + 1] = tool end
end

local root = vim.fn.resolve(vim.fn.tempname())
local function write(path, text)
    vim.fn.mkdir(vim.fs.dirname(root .. '/' .. path), 'p')
    vim.fn.writefile(vim.split(text or '', '\n'), root .. '/' .. path)
end
-- monorepo: go service with a Dockerfile, a JS frontend, a helm chart, a
-- yamllint-configured dir, and a Dockerfile-only dir; a stray package.json,
-- pyproject.toml and node_modules/.bin ABOVE the git root must never win.
write('package.json', '{}')
write('pyproject.toml', '')
write('node_modules/.bin/tsc', '')
vim.fn.system({ 'git', 'init', '-q', root .. '/repo' })
write('repo/svc/go.mod', 'module x')
write('repo/svc/Dockerfile', 'FROM alpine')
write('repo/svc/cmd/main.go', 'package main')
write('repo/web/package.json', '{}')
write('repo/web/src/app.ts', '')
write('repo/chart/Chart.yaml', 'name: c')
write('repo/chart/templates/d.yaml', '')
write('repo/chart/charts/sub/Chart.yaml', 'name: sub')
write('repo/chart/charts/sub/templates/cm.yaml', '')
write('repo/conf/.yamllint', '')
write('repo/conf/a.yaml', '')
write('repo/img/Dockerfile.prod', 'FROM alpine')
write('repo/img/Dockerfile.dockerignore', 'node_modules')
write('repo/img/café/Dockerfile', 'FROM alpine')
write('repo/py/svc/requirements.txt', '')
write('repo/py/svc/app.py', '')
write('repo/plain/readme.md', '')
-- A JS project whose package.json is at the repo root but whose nearer marker
-- is a sub-directory tsconfig.json.
vim.fn.system({ 'git', 'init', '-q', root .. '/mixed' })
write('mixed/package.json', '{}')
write('mixed/js/app/tsconfig.json', '{}')
write('mixed/js/app/a.ts', '')
-- npm/yarn workspace: the tool is hoisted to the workspace root.
vim.fn.system({ 'git', 'init', '-q', root .. '/ws' })
write('ws/package.json', '{}')
write('ws/node_modules/.bin/eslint', '')
write('ws/packages/foo/package.json', '{}')
write('ws/packages/foo/src/a.ts', '')

local function detect_for(path)
    vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/' .. path))
    local spec, dir, reason = diag._detect()
    return spec and spec.name, dir and vim.fn.fnamemodify(dir, ':t'), reason, spec
end

-- detection
local name, dir, reason, spec = detect_for('repo/svc/cmd/main.go')
eq(dir, 'svc', 'go: nearest root, not the git root')
eq(name, has('golangci-lint') and 'golangci-lint' or 'go vet', 'go tool; go.mod beats Dockerfile at equal depth')
with_tool('golangci-lint', function()
    -- v2 reports paths relative to the config file's dir unless told otherwise.
    eq(vim.tbl_contains(spec.cmd, '--path-mode=abs'), true, 'golangci-lint v2 asks for absolute paths')
end)
name, dir, reason = detect_for('repo/web/src/app.ts')
eq(dir, 'web', 'js sub-project root')
eq(name == nil and reason:find('not found') ~= nil, true, 'no eslint/tsc: node_modules above the git root is ignored')
_, dir = detect_for('mixed/js/app/a.ts')
eq(dir, 'app', 'nearest of package.json/tsconfig.json wins (equal-priority markers)')
_, dir = detect_for('repo/py/svc/app.py')
eq(dir, 'svc', 'requirements.txt found although pyproject.toml sits above the git root')
name, dir, _, spec = detect_for('ws/packages/foo/src/a.ts')
eq(dir, 'foo', 'workspace package is the project root')
eq(name, 'eslint', 'hoisted eslint found at the workspace root')
eq(spec.cmd[1], root .. '/ws/node_modules/.bin/eslint', 'hoisted eslint path')
_, dir = detect_for('repo/chart/templates/d.yaml')
eq(dir, 'chart', 'helm chart root')
_, dir = detect_for('repo/conf/a.yaml')
eq(dir, 'conf', 'yamllint only with a config file')
_, dir = detect_for('repo/img/Dockerfile.prod')
eq(dir, 'img', 'Dockerfile.* project')
_, _, reason = detect_for('repo/plain/readme.md')
eq(reason and reason:find('no known linter') ~= nil, true, 'plain dir must not pick up package.json above the git root')

-- go vet errorformat (spec built with golangci-lint hidden)
local real_executable = vim.fn.executable
vim.fn.executable = function(t) return t == 'golangci-lint' and 0 or real_executable(t) end
_, _, _, spec = detect_for('repo/svc/cmd/main.go')
vim.fn.executable = real_executable
eq(spec.name, 'go vet', 'go vet without golangci-lint')
local items = diag._efm_items({ stdout = table.concat({
    '# x/cmd',
    'vet: cmd/main.go:3:27: cannot use "s" (untyped string constant) as int value',
    'cmd/main.go:4:2: fmt.Printf format %d has arg "s" of wrong type string',
}, '\n') }, root .. '/repo/svc', spec.efm)
eq(#items, 2, 'go vet: both type error and analyzer finding parsed, "# pkg" dropped')
eq(vim.api.nvim_buf_get_name(items[1].bufnr), root .. '/repo/svc/cmd/main.go', 'go vet: "vet: " prefix is not part of the filename')
eq(items[1].lnum .. ':' .. items[1].col, '3:27', 'go vet: position')

-- a local tool without the execute bit is reported, not a raw EACCES
local notes = {}
local real_notify = vim.notify
vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
write('repo/web/node_modules/.bin/eslint', '')
vim.cmd('edit ' .. root .. '/repo/web/src/app.ts')
diag.run()
vim.notify = real_notify
eq(notes[1] and notes[1].msg:find('is not executable') ~= nil, true, 'non-executable local eslint: clear error')
eq(notes[1] and notes[1].level, vim.log.levels.ERROR, 'non-executable local eslint: ERROR level')

-- eslint parser
items = diag._parse.eslint({ stdout = vim.json.encode({
    { filePath = '/a/b.ts', messages = {
        { line = 3, column = 5, severity = 2, message = 'no', ruleId = 'no-undef' },
        { line = 7, column = 1, severity = 1, message = 'warn', ruleId = vim.NIL },
    } },
}) })
eq(#items, 2, 'eslint items')
eq(items[1].type .. items[1].lnum .. ':' .. items[1].col, 'E3:5', 'eslint severity 2 -> E')
eq(items[1].text, 'no [no-undef]', 'eslint rule id')
eq(items[2].type, 'W', 'eslint severity 1 -> W')
eq(diag._parse.eslint({ stdout = 'Oops! Something went wrong' }), nil, 'unparseable eslint output -> nil')

-- helm parser: output captured from real helm v4.3 runs, plus the v3 shapes.
local chart = root .. '/repo/chart'
items = diag._parse.helm({ stdout = table.concat({
    '==> Linting .',
    '[INFO] Chart.yaml: icon is recommended',
    '[INFO] values.yaml: file does not exist',
    '[ERROR] templates/d.yaml: unable to parse YAML: error converting YAML to JSON: yaml: line 12: did not find expected key',
    '[ERROR] templates/: parse error at (c/charts/sub/templates/cm.yaml:3): function "nope" not defined',
    '[ERROR] templates/: c/templates/d.yaml:1:13',
    '  executing "c/templates/d.yaml" at <.Values.x.y>:',
    '    nil pointer evaluating interface {}.y',
    '[ERROR] templates/: template: c/charts/sub/templates/cm.yaml:4:5: executing "cm" at <x>: error',
    '[ERROR] ' .. chart .. ': chart metadata is missing these dependencies: sub',
    '[ERROR] ' .. chart .. '/charts/sub: chart.metadata.version is required',
    '[ERROR] Chart.yaml: unable to parse YAML',
    '\terror converting YAML to JSON: yaml: line 3: mapping values are not allowed in this context',
    '[ERROR] : unable to load chart',
    '\tcannot load Chart.yaml: error converting YAML to JSON: yaml: line 3: mapping values',
    '[WARNING] templates/: directory not found',
    '',
    'Error: 1 chart(s) linted, 1 chart(s) failed',
}, '\n'), stderr = '' }, chart)
local function where(i) return items[i].filename:sub(#chart + 2) .. ':' .. items[i].lnum .. items[i].type end
eq(#items, 8, 'helm: INFO, summary and re-reported lines dropped')
eq(where(1), 'templates/d.yaml:12E', 'helm yaml error with line')
eq(items[1].text:find('rendered template') ~= nil, true, 'helm yaml line is flagged as a rendered-output line')
eq(where(2), 'charts/sub/templates/cm.yaml:3E', 'helm parse error -> file:line in parens, chart name stripped')
eq(where(3), 'templates/d.yaml:1E', 'helm v4 execution error -> file:line:col')
eq(items[3].text:find('nil pointer', 1, true) ~= nil, true, 'helm v4 continuation lines kept in the message')
eq(where(4), 'charts/sub/templates/cm.yaml:4E', 'helm v3 execution error')
eq(where(5), 'Chart.yaml:1E', 'helm absolute chart dir -> its Chart.yaml')
eq(where(6), 'charts/sub/Chart.yaml:1E', 'helm absolute sub-chart dir -> the sub-chart Chart.yaml')
eq(where(7), 'Chart.yaml:3E', 'helm Chart.yaml YAML error -> line from the continuation')
-- (the bare "[ERROR] : unable to load chart / cannot load Chart.yaml" re-report
-- of item 7 is dropped)
eq(where(8), 'Chart.yaml:1W', 'helm directory entry -> Chart.yaml, never a directory')
eq(items[3].col, 13, 'helm v4 column kept')

-- helm: file name with a space, a sub-chart whose name differs from its
-- directory, a packaged (.tgz) sub-chart, a ':' in the chart path, and a broken
-- values.yaml (captured from helm 4.3), which reports itself three times.
write('repo/chart/templates/my file.yaml', 'x')
write('repo/chart/charts/subdir/Chart.yaml', 'apiVersion: v2\nname: othername')
write('repo/chart/charts/subdir/templates/cm.yaml', 'a: 1')
write('repo/chart/charts/pkg-1.0.0.tgz', '')
write('repo/chart/values.yaml', 'a: [')
items = diag._parse.helm({ stdout = table.concat({
    '[ERROR] templates/: parse error at (c/templates/my file.yaml:1): function "nope" not defined',
    '[ERROR] templates/: c/charts/othername/templates/cm.yaml:1:13',
    '  executing "c/charts/othername/templates/cm.yaml" at <.Values.x.y>:',
    '[ERROR] templates/: template: c/charts/pkg/templates/x.yaml:2:3: executing "x": boom',
    '[ERROR] values.yaml: unable to parse YAML: error converting YAML to JSON: yaml: line 1: did not find expected node content',
    '[ERROR] templates/: cannot load values.yaml: cannot unmarshal yaml document: error converting YAML to JSON: yaml: line 1: x',
    '[ERROR] : unable to load chart',
    '\tcannot load values.yaml: cannot unmarshal yaml document: error converting YAML to JSON: yaml: line 1: x',
}, '\n'), stderr = '' }, chart)
eq(#items, 4, 'helm: the values.yaml re-reports are dropped')
eq(where(1), 'templates/my file.yaml:1E', 'helm file name with a space')
eq(where(2), 'charts/subdir/templates/cm.yaml:1E', 'helm sub-chart found by its Chart.yaml name, not its directory')
eq(where(3) .. (items[3].text:find('packaged sub%-chart pkg') and ' packaged' or ''), 'Chart.yaml:1E packaged',
    'helm packaged sub-chart -> Chart.yaml, labelled')
eq(where(4), 'values.yaml:1E', 'helm broken values.yaml: one entry, on values.yaml')
local colon = root .. '/co:lon'
write('co:lon/Chart.yaml', 'name: z')
items = diag._parse.helm({ stdout = '[ERROR] ' .. colon .. ': chart metadata is missing these dependencies: x' }, colon)
eq(items[1].filename, colon .. '/Chart.yaml', 'helm: a ":" in the chart path does not truncate it')
eq(items[1].text, 'chart metadata is missing these dependencies: x', 'helm: message intact')

-- hadolint parser
items = diag._parse.hadolint({ stdout = vim.json.encode({
    { file = 'Dockerfile.prod', line = 1, column = 1, level = 'warning', code = 'DL3006', message = 'Always tag' },
}) }, '/img')
eq(items[1].filename .. ':' .. items[1].text, '/img/Dockerfile.prod:DL3006: Always tag', 'hadolint json')

with_tool('hadolint', function()
    -- The file list: a tracked Dockerfile deleted from the working tree must
    -- not reach hadolint (one missing path aborts the whole run), the ignore
    -- file is not a Dockerfile, and a non-ASCII path must not be lost to git's
    -- C-quoting.
    write('repo/img/Dockerfile.old', 'FROM alpine')
    vim.fn.system({ 'git', '-C', root .. '/repo', 'add', 'img/Dockerfile.old' })
    vim.fn.delete(root .. '/repo/img/Dockerfile.old')
    vim.cmd('edit ' .. root .. '/repo/img/Dockerfile.prod')
    spec = diag._detect()
    local files = vim.list_slice(spec.cmd, 6)
    table.sort(files)
    eq(table.concat(vim.list_slice(spec.cmd, 1, 5), ' '), 'hadolint -f json --no-fail --', 'hadolint: -- before files')
    eq(table.concat(files, '|'), 'Dockerfile.prod|café/Dockerfile', 'hadolint: deleted and .dockerignore skipped, non-ASCII kept')
end)

-- Outside git only the file's own directory counts: a marker above it (here a
-- pyproject.toml in `nogit/`) must not be picked up, and the walk stays local.
write('nogit/pyproject.toml', '')
write('nogit/a/b/x.py', '')
_, _, reason = detect_for('nogit/a/b/x.py')
eq(reason and reason:find('no known linter') ~= nil, true, 'outside git: a marker above the file dir is ignored')
write('nogit/a/b/pyproject.toml', '')
_, dir = detect_for('nogit/a/b/x.py')
eq(dir, 'b', 'outside git: a marker in the file dir is used')
-- A new file in a directory that does not exist yet: its nearest existing
-- ancestor, not nvim's cwd.
vim.cmd('cd ' .. root .. '/repo/svc')
vim.cmd('enew')
vim.api.nvim_buf_set_name(0, root .. '/repo/py/svc/newdir/deeper/new.py')
spec, dir = diag._detect()
eq(dir and vim.fn.fnamemodify(dir, ':t'), 'svc', 'missing directory: nearest existing ancestor (py/svc), not cwd (repo/svc)')
eq(spec and spec.name, 'ruff', 'missing directory: ruff for py/svc')
eq(vim.tbl_contains(spec.cmd, 'never'), true, 'ruff runs with --color never')
vim.cmd('cd ' .. vim.fn.fnameescape(vim.env.PWD or '/'))

-- golangci-lint's logfmt diagnostics are not entries (they hid the failure).
items = diag._efm_items({ stdout = '', stderr = 'level=error msg="[linters_context] typechecking error: x"\ncmd/main.go:3:5: real' },
    root .. '/repo/svc', '%-Glevel=%.%#,%f:%l:%c: %m')
eq(#items, 1, 'golangci logfmt line dropped')
eq(vim.api.nvim_buf_get_name(items[1].bufnr), root .. '/repo/svc/cmd/main.go', 'golangci real entry kept')

with_tool('hadolint', function()
    -- Dockerfile.md is prose; a gitignored Dockerfile being edited still counts;
    -- a conflicted Dockerfile (listed once per stage by git) is passed once.
    local R = root .. '/dk'
    vim.fn.system({ 'git', 'init', '-q', '-b', 'main', R })
    write('dk/Dockerfile', 'FROM alpine')
    write('dk/Dockerfile.md', '# notes')
    write('dk/.gitignore', 'build/')
    write('dk/build/Dockerfile', 'FROM alpine')
    local G = { 'git', '-C', R, '-c', 'user.name=t', '-c', 'user.email=t@t' }
    local function g(...) vim.fn.system(vim.list_extend(vim.deepcopy(G), { ... })) end
    g('add', '.') g('commit', '-qm', 'a')
    g('checkout', '-qb', 'x') vim.fn.writefile({ 'FROM alpine:1' }, R .. '/Dockerfile') g('commit', '-qam', 'x')
    g('checkout', '-q', 'main') vim.fn.writefile({ 'FROM alpine:2' }, R .. '/Dockerfile') g('commit', '-qam', 'm')
    g('merge', '-q', 'x') -- conflicts on Dockerfile
    -- The gitignored file is its own nearest project; it used to report
    -- "no Dockerfile found" while being edited.
    vim.cmd('edit ' .. R .. '/build/Dockerfile')
    spec, dir = diag._detect()
    eq(dir, R .. '/build', 'gitignored Dockerfile: its own directory')
    eq(table.concat(vim.list_slice(spec.cmd, 6), '|'), 'Dockerfile', 'gitignored Dockerfile being edited is linted')
    vim.cmd('edit ' .. R .. '/Dockerfile')
    spec = diag._detect()
    eq(table.concat(vim.list_slice(spec.cmd, 6), '|'), 'Dockerfile', 'conflicted Dockerfile listed once; Dockerfile.md skipped')
end)

-- helm: a broken SUB-chart values.yaml / Chart.yaml is reported on the
-- sub-chart's file (output captured from helm 4.3; "subdir" is the directory).
write('repo/chart/charts/subdir/values.yaml', 'a: [')
items = diag._parse.helm({ stdout = table.concat({
    '[ERROR] templates/: error unpacking subchart subdir in c: cannot load values.yaml: cannot unmarshal yaml document: error converting YAML to JSON: yaml: line 1: did not find expected node content',
    '[ERROR] : unable to load chart',
    '\terror unpacking subchart subdir in c: cannot load values.yaml: cannot unmarshal yaml document: error converting YAML to JSON: yaml: line 1: did not find expected node content',
}, '\n') }, root .. '/repo/chart')
eq(#items, 1, 'helm sub-chart values error: one entry')
eq(items[1].filename, root .. '/repo/chart/charts/subdir/values.yaml', 'helm sub-chart values error lands on the sub-chart')

-- tsc without a tsconfig.json in the project: a clear reason, not tsc's help.
vim.fn.system({ 'git', 'init', '-q', root .. '/tsws' })
write('tsws/package.json', '{}')
write('tsws/node_modules/.bin/tsc', '')
write('tsws/packages/bar/package.json', '{}')
write('tsws/packages/bar/src/a.ts', '')
name, dir, reason = detect_for('tsws/packages/bar/src/a.ts')
eq(name == nil and reason:find('tsconfig', 1, true) ~= nil, true, 'tsc is not run without any tsconfig.json')
write('tsws/tsconfig.json', '{}') -- inherited from the workspace root
name = detect_for('tsws/packages/bar/src/a.ts')
eq(name, 'tsc', 'tsc runs in a package that inherits a parent tsconfig.json')
vim.fn.delete(root .. '/tsws/tsconfig.json')
write('tsws/packages/bar/tsconfig.json', '{}')
name = detect_for('tsws/packages/bar/src/a.ts')
eq(name, 'tsc', 'tsc runs once the package has a tsconfig.json')

with_tool('hadolint', function()
    -- Outside git, nested node_modules / dot-dirs are skipped too.
    write('nogit2/Dockerfile', 'FROM alpine')
    write('nogit2/sub/node_modules/pkg/Dockerfile', 'FROM alpine')
    write('nogit2/sub/.cache/Dockerfile', 'FROM alpine')
    write('nogit2/sub/app/Dockerfile', 'FROM alpine')
    vim.cmd('edit ' .. root .. '/nogit2/Dockerfile')
    spec = diag._detect()
    local files = vim.list_slice(spec.cmd, 6)
    table.sort(files)
    eq(table.concat(files, '|'), 'Dockerfile|sub/app/Dockerfile', 'nested node_modules and dot-dirs skipped outside git')
end)

-- cargo workspace member: paths are reported relative to the workspace root.
vim.fn.system({ 'git', 'init', '-q', root .. '/rs' })
write('rs/Cargo.toml', '[workspace]\nmembers = ["crates/foo"]')
write('rs/crates/foo/Cargo.toml', '[package]\nname = "foo"')
write('rs/crates/foo/src/lib.rs', 'pub fn f() {}')
_, dir, _, spec = detect_for('rs/crates/foo/src/lib.rs')
eq(dir, 'foo', 'cargo: the member crate is the project (only it is checked)')
eq(spec.base, root .. '/rs', 'cargo: entries resolve against the workspace root')
items = diag._efm_items({ stdout = 'crates/foo/src/lib.rs:1:34: error[E0308]: mismatched types' }, spec.base, spec.efm)
eq(vim.api.nvim_buf_get_name(items[1].bufnr), root .. '/rs/crates/foo/src/lib.rs', 'cargo: the entry names the real file')

-- Every entry gets a severity (they used to have none for the errorformat tools).
eq(items[1].type, 'E', 'cargo: error[...] -> E')
items = diag._efm_items({ stdout = 'crates/foo/src/lib.rs:2:1: warning: unused variable' }, spec.base, spec.efm)
eq(items[1].type, 'W', 'cargo: warning -> W')
items = diag._efm_items({ stdout = 'vet: cmd/main.go:3:27: cannot use "s"' }, root .. '/repo/svc', 'vet: %f:%l:%c: %m,%f:%l:%c: %m')
eq(items[1].type, 'E', 'go vet: no severity printed -> E')
real_executable = vim.fn.executable
vim.fn.executable = function(t) return t == 'yamllint' and 1 or real_executable(t) end
_, _, _, spec = detect_for('repo/conf/a.yaml')
vim.fn.executable = real_executable
items = diag._efm_items({ stdout = table.concat({
    './a.yaml:2:1: [error] duplication of key "a" in mapping (key-duplicates)',
    './a.yaml:3:81: [warning] line too long (82 > 80 characters) (line-length)',
}, '\n') }, root .. '/repo/conf', spec.efm)
eq(items[1].type .. items[2].type, 'EW', 'yamllint: [error]/[warning] -> E/W')
eq(items[1].text, 'duplication of key "a" in mapping (key-duplicates)', 'yamllint: message without the severity tag')

-- hadolint parse errors carry newlines.
items = diag._parse.hadolint({ stdout = vim.json.encode({
    { file = 'Dockerfile', line = 1, column = 1, level = 'error', code = 'DL1000', message = "unexpected 'F'\nexpecting '#', ADD\n" },
}) }, '/img')
eq(items[1].text, "DL1000: unexpected 'F' expecting '#', ADD", 'hadolint: message on one line')

-- helm 4.3 schema failure (captured): the detail follows on UNINDENTED lines,
-- and the templates/ entry re-reports the values.yaml one.
items = diag._parse.helm({ stdout = table.concat({
    '==> Linting .',
    '[INFO] Chart.yaml: icon is recommended',
    "[ERROR] values.yaml: - at '/replicaCount': got string, want integer",
    '',
    "[ERROR] templates/: values don't meet the specifications of the schema(s) in the following chart(s):",
    'c:',
    "- at '/replicaCount': got string, want integer",
    '',
    '',
    'Error: 1 chart(s) linted, 1 chart(s) failed',
}, '\n') }, chart)
eq(#items, 1, 'helm schema failure: one entry (the templates/ re-report is dropped)')
eq(where(1), 'values.yaml:1E', 'helm schema failure lands on values.yaml')
items = diag._parse.helm({ stdout = table.concat({
    "[ERROR] templates/: values don't meet the specifications of the schema(s) in the following chart(s):",
    'c:',
    "- at '/replicaCount': got string, want integer",
    '',
}, '\n') }, chart)
eq(items[1].text:find("got string, want integer", 1, true) ~= nil, true, 'helm: unindented detail lines are kept')

-- tsc (output shape from tsc 6.0): chained reasons on indented lines, and a
-- package that only INHERITS a parent tsconfig.json.
local pkg = root .. '/tsws/packages/bar'
local tsc_out = { stdout = table.concat({
    "src/a.ts(2,7): error TS2322: Type '{ a: { b: string; }; }' is not assignable to type '{ a: { b: number; }; }'.",
    "  The types of 'a.b' are incompatible between these types.",
    "    Type 'string' is not assignable to type 'number'.",
    "../foo/src/b.ts(1,5): error TS2322: Type 'string' is not assignable to type 'number'.",
    root .. '/tsws/node_modules/typescript/lib/lib.d.ts',
    pkg .. '/src/a.ts',
    root .. '/tsws/packages/foo/src/b.ts',
}, '\n') }
local own = { tsconfig = pkg .. '/tsconfig.json', file = pkg .. '/src/a.ts' }
local inh = { tsconfig = root .. '/tsws/tsconfig.json', inherited = true, file = pkg .. '/src/a.ts' }
items = diag._parse.tsc(tsc_out, pkg, own)
eq(#items, 2, 'tsc with its own tsconfig: every entry of its project')
eq(items[1].text, "TS2322: Type '{ a: { b: string; }; }' is not assignable to type '{ a: { b: number; }; }'."
    .. " The types of 'a.b' are incompatible between these types. Type 'string' is not assignable to type 'number'.",
    'tsc: continuation lines kept')
eq(items[1].filename .. ':' .. items[1].lnum .. ':' .. items[1].col .. items[1].type, pkg .. '/src/a.ts:2:7E', 'tsc: position')
eq(items[2].filename, root .. '/tsws/packages/foo/src/b.ts', 'tsc: ../ paths resolved')
local problem
items, problem = diag._parse.tsc(tsc_out, pkg, inh)
eq(#items .. tostring(problem), '1nil', 'inherited tsconfig: only the package\'s entries, no problem')
local sibling_only = { code = 2, stdout = table.concat({
    "../foo/src/b.ts(1,5): error TS2322: Type 'string' is not assignable to type 'number'.",
    root .. '/tsws/packages/foo/src/b.ts',
}, '\n') }
items, problem = diag._parse.tsc(sibling_only, pkg, inh)
eq(#items == 0 and problem and problem:find('does not include', 1, true) ~= nil, true,
    'inherited tsconfig that does not cover the file: reported, not "no issues"')
-- A clean package while a SIBLING has errors (tsc exits 2): not a tool failure.
local explained
items, problem, explained = diag._parse.tsc({ code = 2, stdout = sibling_only.stdout .. '\n' .. pkg .. '/src/a.ts' }, pkg, inh)
eq(#items .. tostring(problem) .. tostring(explained), '0niltrue',
    'clean package, errors only in a sibling: no entries, no problem, exit explained')
-- tsc that never ran (node missing): nil, so the failure itself is reported.
eq(diag._parse.tsc({ code = 127, stdout = '', stderr = 'env: node: No such file or directory' }, pkg, inh), nil,
    'tsc did not run: unparseable (the exit and stderr are reported), not "does not include"')
-- A solution-style config (`files: []` + `references`) compiles nothing.
items, problem = diag._parse.tsc({ code = 0, stdout = '' }, pkg, vim.tbl_extend('force', own, { solution = true }))
eq(problem and problem:find('compiles no files', 1, true) ~= nil and problem:find('tsc -b', 1, true) ~= nil, true,
    'solution-style tsconfig: reported, not "no issues"')
-- The package's own tsconfig whose include misses the edited file.
items, problem = diag._parse.tsc({ code = 0, stdout = root .. '/tsws/node_modules/typescript/lib/lib.d.ts\n' .. pkg .. '/src/other.ts' },
    pkg, own)
eq(problem and problem:find('src/a.ts', 1, true) ~= nil, true, 'own tsconfig not covering the edited file: reported')
-- A config error with no position (broken `extends`) lands on the tsconfig.
items = diag._parse.tsc({ code = 2, stdout = "error TS5083: Cannot read file '/x/missing.json'.\n" .. pkg .. '/src/a.ts' }, pkg, inh)
eq(#items == 1 and items[1].filename == inh.tsconfig and items[1].text:find('TS5083') ~= nil, true,
    'position-less config error: an entry on the tsconfig')
write('tsws/tsconfig.json', '{}')
vim.fn.delete(root .. '/tsws/packages/bar/tsconfig.json')
_, _, _, spec = detect_for('tsws/packages/bar/src/a.ts')
eq(spec.cmd[#spec.cmd], root .. '/tsws/tsconfig.json', 'tsc: runs the tsconfig it found (-p), with --listFiles')

-- With a real tsc (Mason's typescript-language-server bundles one) and node.
local mason_tsc = vim.fn.stdpath('data') .. '/mason/packages/typescript-language-server/node_modules/typescript/bin/tsc'
local node = vim.fn.exepath('node')
if node == '' then
    local nvm = vim.fn.glob(vim.env.HOME .. '/.nvm/versions/node/*/bin/node', false, true)
    node = nvm[#nvm] or ''
end
if node ~= '' and vim.fn.filereadable(mason_tsc) == 1 then
    local picked = false
    package.loaded['telescope.builtin'] = { quickfix = function() picked = true end }
    write('tsws/node_modules/.bin/tsc', ('#!/bin/sh\nexec %s %s "$@"'):format(node, mason_tsc))
    vim.fn.setfperm(root .. '/tsws/node_modules/.bin/tsc', 'rwxr-xr-x')
    write('tsws/tsconfig.json', '{"compilerOptions":{"strict":true,"types":[]},"include":["src"]}')
    write('tsws/src/root.ts', 'export const r: number = 1;')
    write('tsws/packages/bar/src/a.ts', 'let x: number = "s";')
    local function lint(path)
        notes, picked = {}, false
        vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
        vim.cmd('edit ' .. root .. '/' .. path)
        diag.run()
        -- Done when it reports (no entries) or opens the picker (entries).
        vim.wait(60000, function() return #notes >= 2 or picked end, 50)
        vim.notify = real_notify
        return notes[#notes].msg
    end
    local msg = lint('tsws/packages/bar/src/a.ts')
    eq(msg:find('does not include', 1, true) ~= nil, true,
        'real tsc: an inherited project that skips the package is reported (was "found no issues")')
    write('tsws/tsconfig.json', '{"compilerOptions":{"strict":true,"types":[]},"include":["src","packages/*/src"]}')
    write('tsws/src/root.ts', 'export const r: number = "root";')
    lint('tsws/packages/bar/src/a.ts')
    items = vim.fn.getqflist()
    eq(#items, 1, 'real tsc: only the package\'s error, not the root project\'s')
    eq(vim.api.nvim_buf_get_name(items[1].bufnr), pkg .. '/src/a.ts', 'real tsc: entry on the package file')
    -- Clean package, errors only in the root project: "no issues", not a
    -- "tool/config error" (tsc exits 2).
    write('tsws/packages/bar/src/a.ts', 'export const x: number = 1;')
    msg = lint('tsws/packages/bar/src/a.ts')
    eq(msg:find('found no issues', 1, true) ~= nil, true, 'real tsc: clean package beside a failing one: ' .. msg)
    -- tsc that cannot run (its node is missing): the failure is reported.
    write('tsws/node_modules/.bin/tsc', '#!/bin/sh\nexec /no/such/node "$@"')
    msg = lint('tsws/packages/bar/src/a.ts')
    eq(msg:find('exited', 1, true) ~= nil, true, 'real tsc wrapper without node: the failure is reported: ' .. msg)
else
    skipped[#skipped + 1] = 'tsc (Mason typescript-language-server) / node'
end

-- The buffer's Dockerfile is added only when it exists on disk: an unsaved new
-- one aborted the whole hadolint run ("does not exist").
real_executable = vim.fn.executable
vim.fn.executable = function(t) return t == 'hadolint' and 1 or real_executable(t) end
vim.cmd('enew')
vim.api.nvim_buf_set_name(0, root .. '/repo/img/Dockerfile.unsaved')
spec = diag._detect()
vim.fn.executable = real_executable
eq(vim.tbl_contains(spec.cmd, 'Dockerfile.unsaved'), false, 'hadolint: an unsaved Dockerfile is not passed')

-- A SUB-chart's schema failure (helm 4.3, captured) lands on the sub-chart's
-- values.yaml -- unless the parent's values.yaml overrides that sub-chart.
local schema_fail = { stdout = table.concat({
    '==> Linting .',
    "[ERROR] templates/: values don't meet the specifications of the schema(s) in the following chart(s):",
    'othername:',
    "- at '/port': got string, want integer",
    '', '',
    'Error: 1 chart(s) linted, 1 chart(s) failed',
}, '\n') }
vim.fn.writefile({ 'port: "x"' }, chart .. '/charts/subdir/values.yaml')
vim.fn.writefile({ 'replicaCount: 1' }, chart .. '/values.yaml')
items = diag._parse.helm(schema_fail, chart)
eq(#items == 1 and items[1].filename, chart .. '/charts/subdir/values.yaml', 'sub-chart schema failure -> the sub-chart values.yaml')
vim.fn.writefile({ 'replicaCount: 1', 'othername:', '  port: "x"' }, chart .. '/values.yaml')
items = diag._parse.helm(schema_fail, chart)
eq(items[1].filename, chart .. '/values.yaml', 'parent overrides the sub-chart key -> the parent values.yaml')
-- Parent AND sub-chart fail their schemas (helm 4.3, captured): one entry each;
-- the sub-chart's used to vanish behind the parent's.
vim.fn.writefile({ 'port: "x"' }, chart .. '/charts/subdir/values.yaml')
vim.fn.writefile({ 'replicaCount: "x"' }, chart .. '/values.yaml')
items = diag._parse.helm({ stdout = table.concat({
    '==> Linting .',
    "[ERROR] values.yaml: - at '/replicaCount': got string, want integer",
    '',
    "[ERROR] templates/: values don't meet the specifications of the schema(s) in the following chart(s):",
    'c:',
    "- at '/replicaCount': got string, want integer",
    'othername:',
    "- at '/port': got string, want integer",
    '', '',
    'Error: 1 chart(s) linted, 1 chart(s) failed',
}, '\n') }, chart)
local files = {}
for _, it in ipairs(items) do files[#files + 1] = it.filename:sub(#chart + 2) end
table.sort(files)
eq(table.concat(files, ' '), 'charts/subdir/values.yaml values.yaml', 'both schema failures: parent and sub-chart entries')

-- A linter killed by a signal (crash, OOM) is a failure, not "no issues":
-- vim.system reports it as code 0 + signal.
local fakebin = root .. '/fakebin'
vim.fn.mkdir(fakebin, 'p')
vim.fn.writefile({ '#!/bin/sh', 'kill -SEGV $$' }, fakebin .. '/go')
vim.fn.setfperm(fakebin .. '/go', 'rwxr-xr-x')
local saved_path = vim.env.PATH
vim.env.PATH = fakebin .. ':' .. saved_path
real_executable = vim.fn.executable
vim.fn.executable = function(t) return t == 'golangci-lint' and 0 or real_executable(t) end
notes = {}
vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
vim.cmd('edit ' .. root .. '/repo/svc/cmd/main.go')
diag.run()
vim.wait(5000, function() return #notes >= 2 end, 20)
vim.notify, vim.fn.executable, vim.env.PATH = real_notify, real_executable, saved_path
eq(notes[#notes] and notes[#notes].msg:find('killed (signal 11)', 1, true) ~= nil, true,
    'a crashed linter is reported, not "found no issues": ' .. tostring(notes[#notes] and notes[#notes].msg))

-- One run at a time: a second <leader>xr while one is in flight is refused
-- (two jobs raced for the quickfix list).
local real_system = vim.system
local spawned, finish = 0, nil
vim.system = function(_, _, cb)
    spawned = spawned + 1
    finish = cb
    return {}
end
notes = {}
vim.notify = function(msg, level) notes[#notes + 1] = { msg = msg, level = level } end
package.loaded['telescope.builtin'] = { quickfix = function() end }
vim.cmd('edit ' .. root .. '/repo/svc/cmd/main.go')
diag.run()
diag.run()
eq(spawned, 1, 'second run while one is in flight: not started')
eq(notes[#notes].msg:find('still running', 1, true) ~= nil, true, 'second run: says the first is still running')
finish({ code = 0, stdout = '', stderr = '' })
vim.wait(1000, function() return notes[#notes].msg:find('no issues', 1, true) ~= nil end)
diag.run()
eq(spawned, 2, 'after the first run finished a new one starts')
finish({ code = 0, stdout = '', stderr = '' })
vim.wait(1000, function() return false end, 10)
vim.system, vim.notify = real_system, real_notify

vim.fn.delete(root, 'rf')
print(('%d repo lint checks passed%s'):format(checks,
    #skipped > 0 and (' (SKIPPED, not installed: ' .. table.concat(skipped, ', ') .. ')') or ''))
