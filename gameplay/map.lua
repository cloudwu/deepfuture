local persist = require "gameplay.persist"
local vmap = require "visual.map"
local config = require "core.rules".ui
local util = require "core.util"
local rules = require "core.rules".map

global pairs, assert, print, print_r

local map = {}

local galaxy = {}
local frontier = {}
local colony = {}

local COLOR = {
	neutral = config.map.neutral,
	player = config.map.player, 
}

local LIMIT <const> = rules.sector.limit

local connection = (function ()
	local connection = {}
	for i = 1, 6 do
		for j = 1, 6 do
			local sec = i * 10 + j
			connection[sec] = vmap.neighbors(sec)
		end
	end
	return connection
end) ()

-- todo: persisit load

function map.init()
	galaxy = persist.init("galaxy", {})
	frontier = {}
	colony = {}
end

local function add_people(sec, n, camp)
	local s = galaxy[sec]
	if not s then
		s = { n = 0, camp = camp }
		galaxy[sec] = s
	end
	local last = s.n
	local r = 0
	last = last + n
	if last > LIMIT then
		r = last - LIMIT
		last = LIMIT
	end
	s.n = last
	assert(s.camp == camp)
	vmap.set(sec, COLOR[camp], last)
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.can_move)
	return r
end

function map.add_neutral(sec, n)
	return add_people(sec, n, "neutral")
end

function map.add_player(sec, n)
	frontier[sec] = true
	return add_people(sec, n, "player")
end

function map.settle(sec)
	colony[sec] = true
end

map.is_safe = util.dirty_update(function()
	for player in pairs(frontier) do
		local conn = connection[player]
		for sec in pairs(conn) do
			local s = galaxy[sec]
			if s and s.camp == "neutral" then
				return false
			end
		end
	end
	return true
end)

map.update = util.dirty_update(vmap.update)

map.can_move = util.dirty_update(function()
	local only_colony_sec
	for k in pairs(colony) do
		if only_colony_sec then
			only_colony_sec = nil
			break
		else
			only_colony_sec = k
		end
	end
	for player in pairs(frontier) do
		if player ~= only_colony_sec or galaxy[player].n > 1 then
			-- only_colony_sec don't allow move the last people
			local conn = connection[player]
			for sec in pairs(conn) do
				if sec ~= 0 then	-- skip blackhole
					local s = galaxy[sec]
					if not s then
						-- empty
						return true
					end
					if s.camp == "player" and s.n < LIMIT then
						return true
					end
				end
			end
		end
	end
	return false
end)

return map
