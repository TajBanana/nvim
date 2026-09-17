-- Run: nvim --headless -n -u NONE -i NONE -l scripts/tests/incremental_selection.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/site'))
require('tajbanana.incremental_selection').setup()
local checks = 0
local function escape()
    vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true))
end
local function press(key)
    local mode = vim.fn.mode() == 'v' and 'x' or 'n'
    vim.fn.maparg(key, mode, false, true).callback()
end
local function selection()
    local start = vim.fn.getpos('v')
    local finish = vim.api.nvim_win_get_cursor(0)
    return { start[2], start[3] - 1, finish[1], finish[2] }
end
local function expect(range)
    assert(vim.fn.mode() == 'v')
    assert(vim.deep_equal(selection(), range), vim.inspect(selection()) .. ' ~= ' .. vim.inspect(range))
    checks = checks + 1
end
for _, ft in ipairs({ 'yaml', 'helm' }) do
    escape()
    vim.cmd('enew!')
    vim.bo.filetype = ft
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        'kafka:', '  repository:', '    image: apache/kafka', '    tag: "4.3.1"', '',
    })
    -- No explicit parse: first invocation must populate the injection tree.
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    press('<M-Up>')
    expect({3, 4, 3, 8})
    local ranges = { selection() }
    for _ = 1, 4 do
        press('<M-Up>')
        ranges[#ranges + 1] = selection()
    end
    expect({1, 0, 5, 0})
    for _ = 1, 3 do press('<M-Up>'); expect(ranges[#ranges]) end
    for i = #ranges - 1, 1, -1 do press('<M-Down>'); expect(ranges[i]) end
    escape()
    vim.api.nvim_win_set_cursor(0, { 4, 4 })
    press('<M-Up>')
    expect({4, 4, 4, 6})
end
escape()
vim.cmd('enew!')
vim.bo.filetype = 'helm'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'image: {{ .Values.image }}' })
vim.api.nvim_win_set_cursor(0, {1, 19})
press('<M-Up>')
expect({1, 18, 1, 22}) -- Go-template field, not the entire YAML document.
local function load_helm(lines)
    escape()
    vim.cmd('enew!')
    vim.bo.filetype = 'helm'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end
local controller = {
    'spec:',
    '  containers:',
    '  - name: kafka',
    '    ports:',
    '    - name: client',
    '      containerPort: {{.Values.kafka.ports.client}}',
    '    - name: controller ',
    '      containerPort: {{.Values.kafka.ports.controller}}',
    '    envFrom:',
    '      - configMapRef:',
    '          name: {{.Release.Name}}-kafka-configmap',
    '',
}
load_helm(controller)
vim.api.nvim_win_set_cursor(0, {7, 14})
press('<M-Up>')
expect({7, 12, 7, 21})
press('<M-Up>')
expect({7, 0, 7, #controller[7] - 1})
press('<M-Up>')
expect({7, 0, 8, #controller[8] - 1})
press('<M-Down>')
expect({7, 0, 7, #controller[7] - 1})

local function contains(outer, inner)
    return (outer[1] < inner[1] or (outer[1] == inner[1] and outer[2] <= inner[2]))
        and (outer[3] > inner[3] or (outer[3] == inner[3] and outer[4] >= inner[4]))
end
local function check_all_positions(lines)
    load_helm(lines)
    for row, line in ipairs(lines) do
        for col = 0, #line - 1 do
            escape()
            vim.api.nvim_win_set_cursor(0, {row, col})
            press('<M-Up>')
            local history = { selection() }
            for step = 1, 50 do
                press('<M-Up>')
                local next_range = selection()
                if vim.deep_equal(next_range, history[#history]) then break end
                assert(contains(next_range, history[#history]),
                    ('non-monotonic expansion at %d:%d'):format(row, col))
                assert(step < 50, 'expansion cycle')
                history[#history + 1] = next_range
            end
            for i = #history - 1, 1, -1 do press('<M-Down>'); assert(vim.deep_equal(selection(), history[i]), ('shrink at %d:%d step %d: %s expected %s'):format(row,col,i,vim.inspect(selection()),vim.inspect(history[i]))); checks=checks+1 end
        end
    end
end
check_all_positions(controller)
check_all_positions({
    '{{- if .Values.enabled }}',
    'spec:',
    '  port: {{',
    '    .Values.port',
    '  }}',
    '  name: "{{.Release.Name}}-kafka"',
    '{{- end }}',
})
load_helm({'name: café'})
vim.api.nvim_win_set_cursor(0, {1, 8})
press('<M-Up>')
expect({1, 6, 1, 9}) -- final character starts at byte 9, not its continuation byte
escape()
vim.cmd('enew!')
vim.bo.filetype = 'no_such_parser'
press('<M-Up>')
assert(vim.fn.mode() == 'n', 'missing parser should be a no-op')
print(('PASS: %d incremental selection checks and missing-parser fallback'):format(checks))
vim.cmd('qa!')
