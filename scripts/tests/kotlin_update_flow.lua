-- Run with nvim --headless -u NONE -i NONE -l scripts/tests/kotlin_update_flow.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local requests, prompts, restarts = {}, {}, {}
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
package.loaded['tajbanana.kotlin_update_prompt'] = {
    ask = function(title, lines, label, callback)
        prompts[#prompts + 1] = { title = title, lines = lines, label = label, callback = callback }
    end,
}
package.loaded['tajbanana.lsp_status'] = { _expired_kotlin = true }
local stops = 0
vim.lsp.get_clients = function() return { { stop = function() stops = stops + 1 end } } end
vim.defer_fn = function(callback) restarts[#restarts + 1] = callback end
vim.system = function(cmd, opts, callback)
    assert(cmd[3] == '--interactive' and opts.stdin == true)
    local request = { opts = opts, callback = callback, answers = {}, closed = false }
    requests[#requests + 1] = request
    return { write = function(_, data)
        if data == nil then request.closed = true else request.answers[#request.answers + 1] = data end
    end }
end
local function drain() vim.wait(20, function() return false end) end
local update = require('tajbanana.kotlin_update')
update.start()
assert(#requests == 1 and update.is_running())
update.start()
assert(#requests == 1, 'overlapping command must not start')
local first = requests[1]
first.opts.stdout(nil, 'CONFIRM-OPEN-')
drain()
assert(#prompts == 0)
first.opts.stdout(nil, 'VSX 263.1.0 263.2.0\n')
drain()
assert(#prompts == 1)
assert(prompts[1].lines[1]:find('263.1.0 (GitHub)', 1, true))
assert(prompts[1].lines[3]:find('263.2.0 (Open VSX)', 1, true))
assert(#first.answers == 0, 'no automatic approval')
update.start()
assert(#requests == 1, 'guard must cover confirmation')
prompts[1].callback(true)
assert(first.answers[1] == 'y\n' and first.closed)
first.opts.stdout(nil, 'UPDATED kotlin-server-263.2.0\n')
first.callback({ code = 0 })
drain()
assert(stops == 1 and update.is_running())
assert(not package.loaded['tajbanana.lsp_status']._expired_kotlin)
restarts[1]()
assert(not update.is_running())

update.start()
local second = requests[2]
second.opts.stdout(nil, 'CONFIRM-OPEN-VSX 263.1.0 263.2.0\n')
drain()
prompts[2].callback(false)
assert(second.answers[1] == 'n\n')
second.callback({ code = 20 })
drain()
assert(not update.is_running() and stops == 1)

update.start()
local third = requests[3]
third.opts.stderr(nil, 'sha256 MISMATCH for archive')
third.callback({ code = 1 })
drain()
assert(#prompts == 3 and prompts[3].label == 'retry')
assert(prompts[3].lines[1] == 'Checksum verification failed.')
update.start()
assert(#requests == 3, 'guard must cover retry prompt')
prompts[3].callback(true)
assert(#requests == 4)
requests[4].opts.stdout(nil, 'UP-TO-DATE kotlin-server-263.1.0\n')
requests[4].callback({ code = 0 })
drain()
assert(not update.is_running() and stops == 1)

for _, code in ipairs({ 75, 11, 12 }) do
    update.start()
    local request = requests[#requests]
    request.opts.stderr(nil, 'No action available')
    request.callback({ code = code })
    drain()
    assert(not update.is_running())
    assert(#prompts == 3, 'busy or no alternative must not offer download')
end
update.start()
requests[#requests].opts.stderr(nil, 'curl: network failed')
requests[#requests].callback({ code = 7 })
drain()
assert(prompts[4].label == 'retry')
prompts[4].callback(false)
assert(not update.is_running())
vim.lsp.get_clients = function() return {} end
print('Kotlin update confirmation, retry, restart, and overlap checks passed')
