local persist = require "gameplay.persist"
local vmap = require "visual.map"
local config = require "core.rules".ui
local util = require "core.util"
local rules = require "core.rules".map

global pairs, assert, print, print_r, error

local map = {}

local galaxy = {}
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

function map.setup()
	galaxy = persist.init("galaxy", {})
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
	if camp == "player" then
		util.dirty_trigger(map.can_grow)
	end
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
	util.dirty_trigger(map.can_grow)
	return n
end

function map.add_neutral(sec, n)
	return add_people(sec, n, "neutral")
end

function map.add_player(sec, n)
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
	util.dirty_trigger(map.can_grow)
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
	if camp == "player" then
		util.dirty_trigger(map.can_grow)
	end
end

function map.sync()
	vmap.clear()
	for sec, obj in pairs(galaxy) do
		vmap.set(sec, COLOR[obj.camp], obj.n)
	end
	vmap.update()
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
	util.dirty_trigger(map.can_grow)
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
	for player, obj in pairs(galaxy) do
		if obj.camp == "player" then
			local conn = connection[player]
			for sec in pairs(conn) do
				local s = galaxy[sec]
				if s and s.camp == "neutral" then
					return false
				end
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
	for player, obj in pairs(galaxy) do
		if obj.camp == "player" and (player ~= only_colony_sec or obj.n > 1) then
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

map.can_grow = util.dirty_update(function()
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and obj.n < LIMIT then
			return true
		end
	end
end)

function map.territory(limit)
	limit = LIMIT - (limit or 0)
	local r = {}
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and obj.n > 0 and obj.n <= limit then
			r[sec] = obj.n
		end
	end
	return r
end

function map.can_grow_more()
	for sec, obj in pairs(galaxy) do
		if obj.grow and obj.n < LIMIT then
			return true
		end
	end
end

function map.can_grow_extra()
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and	not obj.grow and not obj.extra and obj.n < LIMIT then
			return sec
		end
	end
end

function map.list_grow_extra()
	local r = {}
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and	not obj.grow and not obj.extra and obj.n < LIMIT then
			r[sec] = true
		end
	end
	return r
end

function map.reset()
	for sec, obj in pairs(galaxy) do
		obj.grow = nil
		obj.extra = nil
	end
end

function map.grow(sec)
	if sec then
		local s = galaxy[sec]
		if s then
			s.grow = true
		end
		return sec
	else
		for sec, obj in pairs(galaxy) do
			if obj.grow and obj.n < LIMIT then
				return sec
			end
		end
	end
end

function map.grow_extra(sec)
	local s = galaxy[sec]
	if s then
		s.extra = true
	end
end

function map.info(sec, desc)
	desc.sec = sec
	if sec == 0 then
		desc.what = "$(BLACKHOLE)"
	else
		desc.what = "$(SECTOR)"
	end
	local obj = galaxy[sec]
	if obj == nil or obj.n == 0 then
		desc.desc = "$(EMPTY_SECTOR)"
	else
		desc.people = obj.n
		if obj.camp == "player" then
			desc.desc = "$(FRIEND_SECTOR)"
		else
			desc.desc = "$(HOSTILE_SECTOR)"
		end
	end
end

return map
