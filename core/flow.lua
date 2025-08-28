local coroutine = require "soluna.coroutine"
local debug = debug

global assert, error, tostring

local flow = {}

local STATE
local CURRENT = {
	state = nil,
	thread = nil,
}

function flow.load(states)
	STATE = states
end

function flow.enter(state, args)
	assert(STATE, "Call flow.load() first")
	assert(CURRENT.thread == nil, "Running state")
	local f = STATE[state] or error ("Missing state " .. state)
	CURRENT.state = state
	CURRENT.thread = coroutine.create(function()
		local next_state = f(args)
		return "NEXT", next_state
	end)
end

function flow.sleep(tick)
	coroutine.yield ("SLEEP", tick)
end

local function sleep(current, tick)
	coroutine.yield()
	for i = 1, tick-1 do
		coroutine.yield "YIELD"
	end
	return "RESUME", current
end

local command = {}

function command.NEXT(state)
	CURRENT.thread = nil
	flow.enter(state)
end

function command.SLEEP(tick)
	if tick <= 0 then
		return
	end
	local current = CURRENT.thread
	CURRENT.thread = coroutine.create(sleep)
	coroutine.resume(CURRENT.thread, current, tick)
end

function command.YIELD()
end

function command.RESUME(thread)
	CURRENT.thread = thread
end

local function update_process(thread)
	local ok, cmd, arg = coroutine.resume(thread)
	if ok then
		command[cmd](arg)
	else
		error(tostring(cmd) .. "\n" .. debug.traceback(thread))
	end
end

function flow.update()
	if CURRENT.thread then
		update_process(CURRENT.thread)
		return CURRENT.state
	end
end

return flow
