local flow = {}

local STATE
local CURRENT = {
	state = nil,
	thread = nil,
}

function flow.load(states)
	STATE = states
end

function flow.enter(state)
	assert(STATE, "Call flow.load() first")
	assert(CURRENT.thread == nil, "Running state")
	local f = STATE[state] or error ("Missing state " .. state)
	CURRENT.state = state
	CURRENT.thread = coroutine.create(function()
		local next_state = f()
		return "NEXT", next_state
	end)
end

function flow.sleep(tick)
	return "SLEEP", tick
end

local function sleep(tick)
	coroutine.yield()
	local current = CURRENT
	for i = 1, tick do
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
	CURRENT.thread = coroutine.create(sleep)
	coroutine.resume(CURRENT.thread, tick)
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
		error(cmd .. "\n" .. debug.traceback(thread))
	end
end

function flow.update()
	if CURRENT.thread then
		update_process(CURRENT.thread)
		return CURRENT.state
	end
end

return flow
