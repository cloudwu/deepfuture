local coroutine = require "soluna.coroutine"
local util = require "core.util"
local debug = debug

global assert, error, tostring, print, setmetatable, pairs

local flow = {}

local STATE
local CURRENT = {
	state = nil,
	thread = nil,
}

function flow.load(states)
	STATE = states
	local checker = {}
	for k in pairs(states) do
		checker[k] = k
	end
	flow.state = setmetatable(checker, { __index = function(_, k) error ("Invalid state name " .. tostring(k)) end })
end

function flow.enter(state, args)
	assert(STATE, "Call flow.load() first")
	assert(CURRENT.thread == nil, "Running state")
	local f = STATE[state] or error ("Missing state " .. tostring(state))
	CURRENT.state = state
	CURRENT.thread = coroutine.create(function()
		local next_state, args = f(args)
		return "NEXT", next_state, args
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

function command.NEXT(state, args)
	CURRENT.thread = nil
	flow.enter(state, args)
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
	local ok, cmd, arg1, arg2 = coroutine.resume(thread)
	if ok then
		command[cmd](arg1, arg2)
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
