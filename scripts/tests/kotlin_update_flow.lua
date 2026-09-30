-- Run: nvim --headless -u NONE -i NONE -l scripts/tests/kotlin_update_flow.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local requests, prompts, restarts = {}, {}, {}
-- notices[i] is the message, levels[i] its level (WARN vs ERROR is part of the contract).
local notices, levels = {}, {}
vim.notify = function(message, level) notices[#notices + 1] = message; levels[#levels + 1] = level end
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
    assert(levels[#levels] == vim.log.levels.WARN, ('exit %d is an expected refusal: WARN'):format(code))
end
update.start()
requests[#requests].opts.stderr(nil, 'curl: network failed')
requests[#requests].callback({ code = 7 })
drain()
assert(levels[#levels] == vim.log.levels.ERROR, 'a real failure is an ERROR')
assert(prompts[4].label == 'retry')
prompts[4].callback(false)
assert(not update.is_running())
vim.lsp.get_clients = function() return {} end

-- :KotlinLspRollback: same guard and restart path, script run in `rollback` mode.
local rollbacks = {}
vim.system = function(cmd, _, callback)
    assert(cmd[3] == 'rollback', 'rollback runs the script in rollback mode')
    rollbacks[#rollbacks + 1] = callback
    return {}
end
local rstops = 0
vim.lsp.get_clients = function() return { { stop = function() rstops = rstops + 1 end } } end
package.loaded['tajbanana.lsp_status']._expired_kotlin = true
restarts = {}
update.rollback()
assert(#rollbacks == 1 and update.is_running())
update.rollback()
update.start()
assert(#rollbacks == 1 and update.is_running(), 'rollback shares the update guard')
rollbacks[1]({ code = 0, stdout = 'ROLLED-BACK kotlin-server-262.1.0\n', stderr = '' })
drain()
assert(rstops == 1 and update.is_running(), 'rollback stops the client, then reattaches')
assert(not package.loaded['tajbanana.lsp_status']._expired_kotlin)
restarts[1]()
assert(not update.is_running())
local before = #notices
update.rollback()
rollbacks[2]({ code = 14, stdout = '', stderr = 'Previous build kotlin-server-262.1.0 has expired' })
drain()
assert(not update.is_running() and rstops == 1, 'expired previous build: no restart')
assert(notices[before + 2]:find('has expired', 1, true), 'refusal reason surfaced')
assert(levels[before + 2] == vim.log.levels.WARN, 'expired previous build is an expected refusal: WARN')
before = #notices
update.rollback()
rollbacks[3]({ code = 1, stdout = '', stderr = ('server log line\n'):rep(400) .. 'Could not validate previous build' })
drain()
assert(levels[before + 2] == vim.log.levels.ERROR, 'rollback validation failure is an ERROR')
assert(#notices[before + 2] <= 1200, 'rollback error is trimmed like the update path')
assert(notices[before + 2]:find('Could not validate', 1, true), 'the tail (the reason) is kept')
vim.lsp.get_clients = function() return {} end
print('Kotlin update confirmation, retry, restart, rollback, and overlap checks passed')
