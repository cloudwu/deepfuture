local persist = require "gameplay.persist"
local vmap = require "visual.map"
local config = require "core.rules".ui
local util = require "core.util"
local rules = require "core.rules".map
local card = require "gameplay.card"

global pairs, assert, print, print_r, error, type, next

local map = {}

local galaxy = {}
local colony = {}
local battlefield = {}
local expand = {}

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
	connection[0] = vmap.neighbors(0)
	return connection
end) ()

-- todo: persisit load

function map.setup()
	galaxy = persist.init("galaxy", {})
	colony = {}
end

function map.load()
	galaxy = persist.get "galaxy"
	colony = {}
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.can_move)
	util.dirty_trigger(map.can_grow)
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
	return n, s.n
end

function map.add_neutral(sec, n)
	return add_people(sec, n, "neutral")
end

function map.add_player(sec, n)
	return add_people(sec, n, "player")
end

function map.player_ctrl(sec)
	local s = galaxy[sec]
	if s and s.camp == "player" then
		return s.n
	end
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
	-- 防御性检查：如果 sec 为 nil（例如技术卡），直接返回
	if sec == nil then
		return
	end
	
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

function map.empty_neighbor(t)
	local r = {}
	for sec in pairs(t) do
		local conn = connection[sec]
		for ns in pairs(conn) do
			if galaxy[ns] == nil then
				r[ns] = 0
			end
		end
	end
	r[0] = nil
	return r
end

map.is_safe = util.dirty_update(function()
	for player, obj in pairs(galaxy) do
		if obj.camp == "player" and obj.extra ~= obj.n then
			local conn = connection[player]
			for sec in pairs(conn) do
				local s = galaxy[sec]
				if s and s.camp == "neutral" and s.n ~= s.extra then
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

local function find_map_(sec, result)
	local conn = connection[sec]
	for nsec in pairs(conn) do
		if result[nsec] == nil then
			local s = galaxy[nsec]
			if nsec ~= 0 then
				if s == nil or (s.camp == "player" and s.n < LIMIT) then
					-- can expand to this sector
					return true
				end
			end
			result[nsec] = true
		end
	end
end

local function find_map(result, dist)
	if dist <= 0 then
		return
	end
	local nset = {}
	local n = 0
	for sec, enable in pairs(result) do
		if enable then
			result[sec] = false
			n = n + 1
			nset[n] = sec
		end
	end
	for i = 1, n do
		if find_map_(nset[i], result) then
			return true
		end
	end
	return find_map(result, dist - 1)
end

function map.can_expand(dist)
	dist = dist or 1
	local set = {}
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and obj.n > 1 then
			set[sec] = true
		end
	end
	return find_map(set, dist)
end

local function mark_expand_(sec, result)
	local conn = connection[sec]
	for nsec in pairs(conn) do
		if result[nsec] == nil then
			local s = galaxy[nsec]
			result[nsec] = false
		end
	end
end

local function mark_expand(result, dist)
	if dist <= 0 then
		return
	end
	local nset = {}
	local n = 0
	for sec, flag in pairs(result) do
		if flag == false then
			result[sec] = true
			n = n + 1
			nset[n] = sec
		end
	end
	for i = 1, n do
		mark_expand_(nset[i], result)
	end
	mark_expand(result, dist - 1)
end

function map.expand_start(dist)
	local set = {}
	for sec, obj in pairs(galaxy) do
		if obj.camp == "player" and obj.n > 1 then
			local tmp = { [sec] = true }
			if find_map(tmp, dist) then
				set[sec] = true
			end
		end
	end
	return set
end

function map.expand_count()
	local s = galaxy[expand.start]
	if not s then
		return
	end
	return s.extra, expand.start
end

function map.expand_choose_start(sec)
	assert(expand.start == nil)
	expand.start = sec
end

function map.expand(dist)
	local sec = expand.start or error "No start sector"
	expand = {
		[sec] = false
	}
	mark_expand(expand, dist)
	expand[sec] = nil
	expand[0] = nil
	for sec in pairs(expand) do
		local s = galaxy[sec]
		if s == nil or (s.n ~= LIMIT and s.camp == "player") then
			expand[sec] = true
			vmap.set_sector_mask(sec, true)
		else
			expand[sec] = nil
		end
	end
	expand.start = sec
end

local function set_extra(sec)
	local s = galaxy[sec]
	if s == nil or s.n == 0 then
		vmap.set(sec, nil)
	else
		vmap.set(sec, COLOR[s.camp], s.n, s.extra)
	end
end

function map.check_expand(sec, spacecraft)
	local start = galaxy[expand.start]
	if start == nil then
		-- no start
		return
	end
	local people = start.n - (start.extra or 0)
	if people <= 1 then
		return false, "$(tips.expand.invalid.lastpeople)"
	end
	if not expand[sec] then
		return false, "$(tips.expand.invalid.dest)"
	end
	local s = galaxy[sec]
	if s and s.n + 1 > LIMIT then
		return false, "$(tips.expand.invalid.full)"
	end
	local extra = (s and s.extra) or 0
	if extra > 1 then
		-- already expand
		return true
	end
	
	local dest
	local need_spacecraft = 0
	
	for dsec, enable in pairs(expand) do
		if enable then
			local s = galaxy[dsec]
			if s and s.extra then
				need_spacecraft = need_spacecraft + 1
				if s.extra > 1 then
					dest = dsec
				end
			end
		end
	end
	
	if dest then
		if dest == sec then
			-- expand to dest
			return true
		end
		if extra == 1 then
			return false, "$(tips.expand.invalid.already)"
		else
			assert(extra == 0)
			return need_spacecraft + 1 <= spacecraft, "$(tips.expand.invalid.spacecraft)"
		end
	elseif extra == 1 then
		-- new dest
		return true
	else
		assert(extra == 0)
		return need_spacecraft <= spacecraft, "$(tips.expand.invalid.spacecraft)"
	end
end

function map.expand_back(sec, test)
	if not expand.start then
		return
	end
	if not expand[sec] then
		return
	end
	local s = galaxy[sec]
	if not s or not s.extra then
		return
	end
	if not test then
		local start = galaxy[expand.start]
		start.extra = start.extra - 1
		if start.extra == 0 then
			start.extra = nil
		end
		s.n = s.n - 1
		if s.n == 0 then
			galaxy[sec] = nil
		else
			s.extra = s.extra - 1
			if s.extra == 0 then
				s.extra = nil
			end
		end
		set_extra(sec)
		set_extra(expand.start)
		util.dirty_trigger(map.update)
		map.update()
	end
	return true
end

function map.expand_people(sec)
	local s = expand[sec] or error ("Invalid dest sec " .. sec)
	s = galaxy[sec]
	local start = galaxy[expand.start]
	local start_n = start.n - (start.extra or 0)
	-- add to sec
	start.extra = (start.extra or 0) + 1
	if not s then
		add_people(sec, 1, "player")
		s = galaxy[sec]
		s.extra = 1
	else
		s.n = s.n + 1
		s.extra = (s.extra or 0) + 1
	end
	set_extra(sec)
	set_extra(expand.start)
	util.dirty_trigger(map.update)
	map.update()
end

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

function map.find_enemy(sec, r)
	local s = galaxy[sec]
	if s == nil and s.extra == s.n then
		return
	end
	local camp = s.camp
	local conn = connection[sec]
	local enemy = 0
	for nsec in pairs(conn) do
		local ns = galaxy[nsec]
		if ns and ns.n ~= ns.extra and ns.camp ~= camp then
			r[nsec] = ns.n
			enemy = enemy + 1
		end
	end
	if enemy == 0 then
		return
	else
		return enemy
	end
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

local function clear_battlefield()
	if battlefield.player then
		vmap.set_sector_mask(battlefield.player)
	end
	if battlefield.neutral then
		vmap.set_sector_mask(battlefield.neutral)
	end
end

function map.reset()
	local s = galaxy[expand.start]
	if s and s.extra then
		s.n = s.n - s.extra
		s.extra = nil
		set_extra(expand.start)
	end
	for sec, obj in pairs(galaxy) do
		obj.grow = nil
		obj.extra = nil
	end
	clear_battlefield()
	battlefield = {}
	for sec, enable in pairs(expand) do
		if enable then
			set_extra(sec)
			vmap.set_sector_mask(sec)
		end
	end
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.can_move)
	util.dirty_trigger(map.can_grow)
	map.update()
	expand = {}
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

function map.battle(sec1, sec2)
	local conn = connection[sec1]
	if not conn[sec2] then
		error ("Not connected " .. sec1 .. ":" .. sec2)
	end
	local obj1 = galaxy[sec1] or error (sec1 .. " is empty")
	local obj2 = galaxy[sec2] or error (sec2 .. " is empty")
	if obj2.camp == "player" then
		sec1, sec2 = sec2, sec1
		obj1, obj2 = obj2, obj1
	end
	if obj1.camp ~= "player" then
		error (sec1 .. "is not player")
	end
	if obj2.camp ~= "neutral" then
		error (sec2 .. "is not neutral")
	end
	clear_battlefield()
	battlefield.player = sec1
	battlefield.neutral = sec2
	vmap.set_sector_mask(sec1, true)
	vmap.set_sector_mask(sec2, true)
	return sec1, sec2
end

function map.army(def)
	local player = galaxy[battlefield.player]
	local neutral = galaxy[battlefield.neutral]
	if def > 0 then
		local player_extra = (player.extra or 0) + def
		local neutral_extra = (neutral.extra or 0) + def
		if player_extra > player.n then
			local diff = player_extra - player.n
			player_extra = player.n
			neutral_extra = neutral_extra - diff
		end
		if neutral_extra > neutral.n then
			local diff = neutral_extra - neutral.n
			neutral_extra = neutral.n
			player_extra = player_extra - diff
		end
		player.extra = player_extra
		neutral.extra = neutral_extra
	elseif def <= 0 then
		local player_extra = player.extra or 0
		local neutral_extra = neutral.extra or 0
		if player_extra < -def then
			def = -player_extra
		end
		player_extra = player_extra + def
		neutral_extra = neutral_extra + def
		
		if player_extra <= 0 then
			player.extra = nil
		else
			player.extra = player_extra
		end
		if neutral_extra <= 0 then
			neutral.extra = nil
		else
			neutral.extra = neutral_extra
		end
	end
	set_extra(battlefield.player)
	set_extra(battlefield.neutral)
	util.dirty_trigger(map.is_safe)
	util.dirty_trigger(map.update)
	util.dirty_trigger(map.battle_lostall)
	map.update()
	return player.extra
end

map.battle_lostall = util.dirty_update(function()
	local territory = {}
	local n = 1
	repeat
		local c = card.card("colony", n)
		if c then
			territory[c.sector] = true
			n = n + 1
		end
	until c == nil
	territory[card.card("homeworld", 1).sector] = true

	for sec, obj in pairs(galaxy) do
		if obj.extra then
			if obj.n - obj.extra == 0  then
				territory[sec] = nil
			end
		end
	end

	return next(territory) == nil
end)

function map.battle_confirm()
	local lost = {}
	for sec, obj in pairs(galaxy) do
		if obj.extra then
			obj.n = obj.n - obj.extra
			obj.extra = nil
			if obj.n == 0 then
				galaxy[sec] = nil
				vmap.set(sec, nil)
				lost[sec] = true
			else
				vmap.set(sec, COLOR[obj.camp], obj.n)
			end
		end
	end
	clear_battlefield()
	battlefield = {}
	util.dirty_trigger(map.update)
	map.update()
	if next(lost) then
		return lost
	end
end

function map.hostile(def)
	local sec = battlefield.neutral
	if sec == nil then
		return
	end
	local obj = galaxy[sec]
	local extra = (obj.extra or 0) + (def or 0)
	if def then
		if extra > obj.n then
			extra = obj.n
		elseif extra < 0 then
			extra = nil
		end
		obj.extra = extra
		set_extra(sec)
		util.dirty_trigger(map.update)
		util.dirty_trigger(map.is_safe)
		map.update()
	end
	return extra
end

function map.battlefield()
	local player = battlefield.player
	if player == nil then
		return
	end
	local neutral = battlefield.neutral
	local player_sec = galaxy[player]
	local neutral_sec = galaxy[neutral]
	return neutral, neutral_sec.n, player, player_sec.n
end

function map.in_battle(sec)
	if sec == battlefield.neutral or sec == battlefield.player then
		return battlefield.player, battlefield.neutral
	end
end

function map.battle_lostctrl(def)
	local sec = battlefield.player
	local obj = galaxy[sec]
	if obj == nil or obj.extra == nil then
		return
	end
	return obj.extra + (def or 0) >= obj.n
end

return map
