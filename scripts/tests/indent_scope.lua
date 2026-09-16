-- Run: nvim --headless -n -u NONE -i NONE -l scripts/tests/indent_scope.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/site'))
vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/indent-blankline.nvim'))
vim.treesitter.language.register('tsx', 'typescriptreact')
local spec
for _, candidate in ipairs(dofile('lua/plugins/ui.lua')) do
    if candidate.main == 'ibl' then spec = candidate end
end
spec.config(nil, spec.opts)
local config = vim.tbl_deep_extend('force', require('ibl.config').default_config, spec.opts)
local scope = require('ibl.scope')
local checks = 0
local function buffer(lang, ft, lines)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo.filetype = ft
    assert(not vim.treesitter.get_parser(buf, lang):parse()[1]:root():has_error())
    return buf
end
local function expect(row, col, kind, start_row)
    vim.api.nvim_win_set_cursor(0, { row, col })
    local node = scope.get(vim.api.nvim_get_current_buf(), config)
    assert(node and node:type() == kind and node:start() == start_row - 1,
        ('%s:%d:%d expected %s at %d, got %s'):format(vim.bo.filetype, row, col, kind, start_row,
            node and (node:type() .. ' at ' .. (node:start() + 1)) or 'nil'))
    checks = checks + 1
end
buffer('tsx', 'typescriptreact', {
    'function View() {',
    '    const config = {',
    '        nested: {',
    '            enabled: true,',
    '        },',
    '    }',
    '    send(',
    '        read(),',
    '        { inline: true },',
    '        () => value,',
    '    )',
    '    return <Panel',
    '        title="hello"',
    '        options={{',
    '            enabled: true,',
    '        }}',
    '    />',
    '}',
})
expect(2, 0, 'lexical_declaration', 2)
expect(4, 0, 'object', 3)
for _, row in ipairs({7, 8, 9, 10, 11}) do expect(row, 9, 'call_expression', 7) end
expect(13, 0, 'jsx_self_closing_element', 12)
expect(15, 0, 'object', 14)
expect(17, 4, 'jsx_self_closing_element', 12)
buffer('typescript', 'typescript', {
    'interface Options {', '    name: string', '    nested: {', '        enabled: boolean', '    }', '}',
    'const values = [', '    1,', '    2,', ']',
})
expect(2, 0, 'interface_body', 1)
expect(4, 0, 'object_type', 3)
expect(8, 0, 'array', 7)
buffer('yaml', 'yaml', {
    'services:', '  kafka:', '    image: kafka', '    ports:', '      - "9092:9092"',
    '    environment:', '      NODE_ID: 1', '  ui:', '    image: ui',
    'include:', '  - project: shared', '    ref: main',
})
expect(2, 0, 'block_mapping_pair', 2)
expect(3, 0, 'block_mapping_pair', 2)
expect(5, 0, 'block_mapping_pair', 4)
expect(7, 0, 'block_mapping_pair', 6)
expect(9, 0, 'block_mapping_pair', 8)
expect(12, 0, 'block_sequence_item', 11)
buffer('kotlin', 'kotlin', {
    'fun send() {', '    val event =', '        Event', '            .builder()', '            .build()',
    '    log.info(', '        "sent",', '        event.toString(),', '    )', '}',
})
expect(2, 0, 'property_declaration', 2)
for _, row in ipairs({6, 7, 8, 9}) do expect(row, 8, 'call_expression', 6) end
buffer('kotlin', 'kotlin', {
    'fun send() {',
    '    try {',
    '        sendEvent()',
    '    } catch (ex: Exception) {',
    '        report(ex)',
    '    } finally {',
    '        cleanup()',
    '    }',
    '    wrap(',
    '        object : Wrapper() {',
    '            init {',
    '                configure()',
    '            }',
    '        }',
    '    )',
    '}',
})
expect(3, 0, 'try_expression', 2)
expect(5, 0, 'catch_block', 4)
expect(7, 0, 'finally_block', 6)
expect(10, 0, 'object_literal', 10)
expect(12, 0, 'anonymous_initializer', 11)
-- Inspect the actual overlay column, not just the selected syntax node.
for _, suffix in ipairs({ {}, { '' }, { '', '', 'other:', '  image: other' } }) do
    local lines = { 'kafka:', '  repository:', '    image: apache/kafka', '    tag: "4.3.1"' }
    vim.list_extend(lines, suffix)
    local buf = buffer('yaml', 'yaml', lines)
    vim.bo.shiftwidth = 4 -- also exercises YAML indents smaller than the editor default
    vim.bo.tabstop = 4
    expect(3, 4, 'block_mapping_pair', 2)
    assert(scope.get(buf, config):end_() == 3, 'YAML scope must end on tag, not a blank line or sibling')
    require('ibl').refresh(buf)
    local marks = vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace('indent_blankline'),
        { 2, 0 }, { 2, -1 }, { details = true })
    local columns = {}
    for _, mark in ipairs(marks) do
        local col = 0
        for _, chunk in ipairs(mark[4].virt_text or {}) do
            if vim.inspect(chunk[2]):find('@ibl.scope', 1, true) then columns[#columns + 1] = col end
            col = col + vim.fn.strdisplaywidth(chunk[1])
        end
    end
    assert(vim.deep_equal(columns, { 2 }), 'guide must align with repository: ' .. vim.inspect(columns))
    checks = checks + 1
end
vim.bo.filetype = 'lua'
assert(scope.get_cursor_range(0)[2] == 0, 'unrelated filetypes must keep original cursor lookup')
print(('PASS: %d scope checks plus unrelated-filetype fallback'):format(checks))
vim.cmd('qa!')
