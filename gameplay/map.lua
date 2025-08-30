local persist = require "gameplay.persist"
local vmap = require "visual.map"
local config = require "core.rules".ui
local util = require "core.util"
local rules = require "core.rules".map

global pairs, assert, print, print_r, error

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

function map.sub_player(sec, n)
	local s = galaxy[sec]
	if not s or s.camp ~= "player" then
		return 0
	end
	assert(s.camp == "player")
	if s.n <= n then
		-- clear sector
		galaxy[sec] = nil
		n = s.n
		s.n = 0
	else
		s.n = s.n - n
	end
	if s.n == 0 then
		vmap.set(sec, nil)
	else
		vmap.set(sec, COLOR[s.camp], s.n)
	end
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.can_move)
	return n
end

function map.add_neutral(sec, n)
	return add_people(sec, n, "neutral")
end

function map.add_player(sec, n)
	frontier[sec] = true
	return add_people(sec, n, "player")
end

function map.player_ctrl(sec)
	local s = galaxy[sec]
	return s and s.camp == "player"
end

function map.neighbor(sector, idx)
	local conn = connection[sector]
	for n, id in pairs(conn) do
		if id == idx then
			return n
		end
	end
end

function map.settle(sec)
	local s = galaxy[sec]
	if s and s.camp == "player" then
		colony[sec] = true
	else
		colony[sec] = nil
	end
	util.dirty_trigger(map.can_move)
end

function map.set_galaxy(sec, n, camp)
	if n == 0 then
		galaxy[sec] = nil
		vmap.set(sec, nil)
	else
		local s = { n = n, camp = camp }
		galaxy[sec] = s
		vmap.set(sec, COLOR[camp], n)
	end
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.can_move)
end

local function can_move(sec)
	local conn = connection[sec]
	for sec in pairs(conn) do
		if sec ~= 0 then
			local s = galaxy[sec]
			if not s or (s.camp == "player" and s.n < LIMIT) then
				return true
			end
		end
	end
end

function map.move(sec_from, sec_to)
	local from = galaxy[sec_from] or error ("No people in " .. sec_from)
	local to = galaxy[sec_to]
	if not to then
		to = {
			n = 0,
			camp = "player",
		}
		galaxy[sec_to] = to
	end
	to.n = to.n + 1
	from.n = from.n - 1
	if from.n == 0 then
		galaxy[sec_from] = nil
		map.settle(sec_from)
	end
	vmap.set(sec_from, COLOR[from.camp], from.n)
	vmap.set(sec_to, COLOR[to.camp], to.n)
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.can_move)
end

function map.find_ctrl(is_expand)
	local r = {}
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" then
			if can_move(sec) then
				if is_expand then
					if obj.n > 1 then
						r[sec] = obj.n
					end
				else
					r[sec] = obj.n
				end
			end
		end
	end
	return r
end

function map.find_neighbor(sec)
	local conn = connection[sec]
	local r = {}
	for sec in pairs(conn) do
		if sec ~= 0 then
			local s = galaxy[sec]
			if not s or (s.camp == "player" and s.n < LIMIT) then
				r[sec] = s and s.n or 0
			end
		end
	end
	return r
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
