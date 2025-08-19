local persist = require "gameplay.persist"
local vmap = require "visual.map"

local map = {}
local NEUTRAL_COLOR <const> = "black"
local PLAYER_COLOR <const> = "blue"

local galaxy = {}
local dirty = true

function map.init()
	galaxy = {}
end

local function add_people(sec, n, color)
	local last = galaxy[sec] or 0
	local r = 0
	last = last + n
	if last > 5 then
		r = last - 5
		last = 5
	end
	vmap.set(sec, color, last)
	dirty = true
	return r
end

function map.add_neutral(sec, n)
	return add_people(sec, n, NEUTRAL_COLOR)
end

function map.add_player(sec, n)
	return add_people(sec, n, PLAYER_COLOR)
end

function map.update()
	if dirty then
		vmap.update()
		dirty = false
	end
end

return map
