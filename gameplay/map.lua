local persist = require "gameplay.persist"
local vmap = require "visual.map"
local config = require "core.rules".ui

global pairs, assert

local map = {}

local galaxy = {}
local frontier = {}
local dirty = true
local SAFE

local COLOR = {
	neutral = config.map.neutral,
	player = config.map.player, 
}

local connection = {
	[11] = { 63, 14, 12 },
	[63] = { 62, 65, 14 },
	[12] = { 14, 15, 13 },
	[62] = { 61, 64, 65 },
	[14] = { 65, 16, 15 },
	[13] = { 15, 24, 21 },
	[61] = { 53, 64 },
	[65] = { 64, 66, 16 },
	[15] = { 16, 26, 24 },
	[21] = { 24, 22 },
	[64] = { 53, 55, 66 },
	[16] = { 66, 0, 26 },
	[24] = { 26, 25, 22 },
	[53] = { 52, 55 },
	[66] = { 55, 56, 0 },
	[26] = { 0, 36, 25 },
	[22] = { 25, 23 },
	[55] = { 52, 54, 56 },
	[0] = { 56, 46, 36 },
	[25] = { 36, 34, 23 },
	[52] = { 51, 54 },
	[56] = { 54, 45, 46 },
	[36] = { 46, 35, 34 },
	[23] = { 34, 31 },
	[54] = { 51, 43, 45 },
	[46] = { 45, 44, 35 },
	[34] = { 35, 32, 31 },
	[51] = { 43 },
	[45] = { 43, 42, 44 },
	[35] = { 44, 33, 32 },
	[31] = { 32 },
	[43] = { 42 },
	[44] = { 42, 33 },
	[32] = { 33 },
	[42] = { 41 },
	[33] = { 41 },
	[41] = {},
}

local function init_connection()
	for sec, conn in pairs(connection) do
		local t = {}
		for id, v in pairs(conn) do
			if v == true then
				t[id] = true
			else
				t[v] = true
				connection[v][sec] = true
			end
		end
		connection[sec] = t
	end
end
init_connection()

function map.init()
	-- todo: persisit
	galaxy = {}
	frontier = {}
	dirty = true
	SAFE = nil
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
	if last > 5 then
		r = last - 5
		last = 5
	end
	s.n = last
	assert(s.camp == camp)
	vmap.set(sec, COLOR[camp], last)
	dirty = true
	SAFE = nil
	return r
end

function map.add_neutral(sec, n)
	return add_people(sec, n, "neutral")
end

function map.add_player(sec, n)
	frontier[sec] = true
	return add_people(sec, n, "player")
end

local function check_safe()
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
end

function map.is_safe()
	if SAFE == nil then
		SAFE = check_safe()
	end
	return SAFE
end

function map.update()
	if dirty then
		vmap.update()
		dirty = false
	end
end

return map
