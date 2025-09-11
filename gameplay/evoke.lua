local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local map = require "gameplay.map"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local util = require "core.util"
local ui = require "core.rules".ui
local action = require "core.rules".phase.action
local map_rules = require "core.rules".map
local mouse = require "core.mouse"
local desktop = require "gameplay.desktop"
local track = require "gameplay.track"
local card = require "gameplay.card"
local vmap = require "visual.map"
local vbutton = require "visual.button"

global assert, error, tostring, next, pairs, print

local WARNING_MASK <const> = ui.card.mask_warning
local LIMIT <const> = map_rules.sector.limit
local PEOPLE <const> = ui.map.token

local function evoke_or_action(c, state, last_action)
	local clone = util.shallow_clone(c, {})
	clone.name = "$(tips.advancement." .. action[clone.suit] .. ")"
	clone.type = "blank"	-- for action card
	vdesktop.transfer("hand", c, "float")
	if state.evoke then
		vcard.mask(c, true)
	end
	flow.sleep(5)
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	local confirm
	if state.action then
		local cards = {}
		if state.evoke then
			cards[c] = true
		end
		confirm = desktop.confirm(clone, cards)
		confirm:set_mask(true)
	end
	flow.sleep(5)
	local focus_state = {}
	local desc = {}
	local choose
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				if confirm then
					confirm.notice = focus_state.object == clone
				end
				if focus_state.object == c then
					desc.sector = c.sector
					desc.victory = c._victory
					desc.advancement = c._advancement
					if state.evoke then
						vtips.set("tips.evoke.enable", desc)
					else
						vtips.set("tips.evoke.disable", desc)
					end
				else
					assert(focus_state.object == clone)
					local action_name = action[c.suit]
					desc.action = "$(action." .. action[c.suit] .. ")"
					if state.action then
						if c.suit == "H" and map.is_safe() then
							desc.desc = "$(action." .. action[c.suit] .. ".desc.safe)"
						else
							desc.desc = "$(action." .. action[c.suit] .. ".desc)"
						end
						vtips.set("tips.evoke.action.choose", desc)
					else
						if action_name == last_action then
							vtips.set("tips.evoke.action.unique", desc)
						else
							desc.desc = "$(action." .. action[c.suit] .. ".desc.invalid)"
							vtips.set("tips.evoke.action.invalid", desc)
						end
					end
				end
			else
				vtips.set()
			end
		end
		local click = mouse.click(focus_state, "left")
		if click == c and state.evoke then
			choose = "evoke"
			break
		elseif click == clone then
			if confirm and confirm:click() then
				choose = action[c.suit]
				break
			end
		end
		if confirm then
			confirm:update()
		end
		flow.sleep(0)
	end
	if confirm then
		confirm:set_mask()
	end
	vdesktop.transfer("float", c, "deck")
	vdesktop.transfer("float", clone, "deck")
	return choose
end

local victory = {}

local function add_people(t, n, tips, focus_state)
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, true)
	end
	
	focus_state = focus_state or {}
	local desc = {
		n = n,
		limit = LIMIT,
	}
	
	local function add_peoples(sec)
		local from = t[sec]
		local to = from + n
		if to > LIMIT then
			to = LIMIT
		end
		vmap.focus(sec)
		for i = from+1, to do
			map.add_player(sec, 1)
			flow.sleep(5)
		end
	end
	
	local tips_advice = tips .. ".advice"
	
	local choose
	
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				local sec = focus_state.object
				desc.sector = sec
				if t[sec] then
					vtips.set(tips, desc)
				else
					map.info(sec, desc)
					vtips.set ("tips.grow.desc", desc)
				end
			elseif focus_state.object then
				vtips.set( tips_advice, desc)
			else
				vtips.set()
			end
		end
		local sec, where = mouse.click(focus_state, "left")
		if sec and where == "map" and t[sec] then
			if n > 0 then
				add_peoples(sec)
			end
			choose = sec
			break
		end
		flow.sleep(0)
	end
	
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, false)
	end
	
	return choose, t[choose]
end

function victory.territory(focus_state)
	local t = map.territory(0)
	t = map.empty_neighbor(t)
	if next(t) == nil then
		return
	end
	vdesktop.set_text("phase", { extra = "$(civ.territory.desc)" })
	add_people(t, 1, "tips.evoke.territory", focus_state)
end

function victory.population(focus_state)
	local t = map.territory(1)
	if next(t) == nil then
		return
	end
	local ADD <const> = 4	-- add 4 people
	vdesktop.set_text("phase", { extra = "$(civ.population.desc)" })
	add_people(t, ADD, "tips.evoke.population", focus_state)
end

function victory.culture()
	track.advance("C", 3)
end

function victory.might()
	track.advance("M", 2)
end

function victory.stability()
	track.advance("S", 2)
end

function victory.xeno()
	track.advance("X", 2)
end

local advancement = {}

function advancement.S()
	-- draw 3 cards
	for i = 1, 3 do
		local c = card.draw_hand()
		if c then
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			flow.sleep(5)
		end
	end
end

local function collect_blank_cards(focus_state)
	local n = 1
	local cards = {}
	while true do
		local c = card.card("hand", n)
		if c == nil then
			break
		end
		n = n + 1
		if c.type == "blank" then
			cards[c] = true
			vcard.mask(c, true)
		end
	end
	vdesktop.draw_pile_focus(true)
	return cards
end

function advancement.M(focus_state)
	vdesktop.set_text("phase", { extra = "$(civ.M.desc)" })
	local cards = collect_blank_cards(focus_state)
	local world
	local function disable_mask()
		for c in pairs(cards) do
			vcard.mask(c)
		end
		vdesktop.draw_pile_focus()
	end
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "discard" then
				vtips.set "tips.evoke.M.new"
			elseif cards[focus_state.object] then
				vtips.set "tips.evoke.M.blank"
			elseif focus_state.object then
				vtips.set "tips.evoke.M.advice"
			else
				vtips.set()
			end
		end
		local c, where = mouse.click(focus_state, "left")
		if c then
			if where == "discard" then
				disable_mask()
				world = desktop.create_new_card()
				break
			elseif cards[c] then
				disable_mask()
				world = card.pickup(where, c)
				vdesktop.transfer("hand", world, "float")
				flow.sleep(5)
				local extra_card = card.draw_hand()
				vdesktop.add("deck", extra_card)
				vdesktop.transfer("deck", extra_card, "hand")
				flow.sleep(5)
				break
			end
		end
		flow.sleep(0)
	end
	desktop.choose_sector(world)
	card.sync(world)
	flow.sleep(5)
	card.putdown("colony", world)
	vdesktop.transfer("float", world, "colony")
end

function advancement.R(focus_state)
	local extra = {}
	for i = 1, 3 do
		extra.extra = "$(tips.evoke.R.title) [blue]" .. PEOPLE:rep(4-i) .. "[n]"
		vdesktop.set_text("phase", extra)
		local t = map.territory(1)
		if next(t) == nil then
			return
		end
		add_people(t, 1, "tips.evoke.R", focus_state)
	end
end

function advancement.K()
	-- todo :  advance a tech
end

local function find_enemy()
	local t = map.territory(0)
	local enemy = {}
	local has_enemy
	for sec in pairs(t) do
		has_enemy = has_enemy or map.find_enemy(sec, enemy)
	end
	if has_enemy then
		return enemy
	end
end

function advancement.H(focus_state)
	vdesktop.set_text("phase", { extra = "$(civ.H.desc)" })
	local enemy = find_enemy()
	if enemy then
		for sec in pairs(enemy) do
			vmap.set_sector_mask(sec, true)
		end
	end
	local inc_track = not track.all_full()
	local desc = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				local sec = focus_state.object
				desc.sector = sec
				if enemy and enemy[sec] then
					vtips.set("tips.evoke.H.rival", desc)
				else
					map.info(sec, desc)
					vtips.set ("tips.grow.desc", desc)
				end
				if inc_track then
					track.focus(true)
				end
			elseif inc_track and focus_state.active == "track" then
				local what = focus_state.object	-- C/M/S/X
				track.focus(false)
				desc.type = "$(hud." .. what .. ")"
				if not track.check(what, 1) then
					vtips.set("tips.battle.safe.invalid", desc)
				else
					vtips.set("tips.battle.safe.valid", desc)
					track.focus(what, true)
				end
			else
				if inc_track then
					track.focus(true)
				end
				vtips.set()
			end
		end
		local object, where = mouse.click(focus_state, "left")
		if object then
			if enemy and enemy[object] then
				vtips.set()
				map.set_galaxy(object, enemy[object] - 1, "neutral")
				for sec in pairs(enemy) do
					vmap.set_sector_mask(sec)
				end
				enemy = nil
			end
			if inc_track and track.check(object, 1) then
				vtips.set()
				track.advance(object, 1)
				track.focus(false)
				inc_track = nil
			end
			if enemy == nil and inc_track == nil then
				break
			end
		end
		flow.sleep(0)
	end
end

local function choose_departure(t, focus_state)
	return add_people(t, 0, "tips.evoke.F.departure", focus_state)
end

local function expand_2(from_sec, from_n, t, focus_state)
	local start_n = from_n
	vtips.set()
	map.expand_choose_start(from_sec)
	map.expand(1)
	local button = {
		text = "button.expand.confirm",
		disable = true,
		n = 0,
	}
	vdesktop.button_enable("button1", button)
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, true)
	end
	
	local desc = {}
	local expand = {}
	
	local function can_expand(sec)
		if button.n == 2 then
			-- already 2 dest
			if expand[sec] == nil then
				return false, "$(tips.evoke.F.invalid.exceed)"
			end
		end
		if from_n == 1 then
			return false, "$(tips.evoke.F.invalid.nopeople)"
		end
		if button.n == 1 and expand[sec] and from_n == 2 then
			return false, "$(tips.evoke.F.invalid.reserve)"
		end
		local d = (expand[sec] or 0) + t[sec]
		if d >= LIMIT then
			return false, "$(tips.evoke.F.invalid.limit)"
		end
		return true
	end
	
	local function set_tips(sector)
		desc.sector = sector
		if t[sector] then
			local can, reason = can_expand(sector)
			if can then
				vtips.set("tips.evoke.F.expand", desc)
			else
				desc.reason = reason
				vtips.set("tips.evoke.F.expand.invalid", desc)
			end
		elseif sector == from_sec then
			desc.people = start_n - from_n
			vtips.set ("tips.evoke.F.from", desc)
		else
			map.info(sector, desc)
			vtips.set ("tips.grow.desc", desc)
		end
	end

	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				set_tips(focus_state.object)
			elseif focus_state.active == "button1" then
				if button.n == 2 then
					vtips.set ("tips.evoke.F.confirm", desc)
				else
					desc.n = button.n
					vtips.set ("tips.evoke.F.confirm.invalid", desc)
				end
			elseif focus_state.object then
				vtips.set "tips.evoke.F.advice"
			else
				vtips.set()
			end
		end
		local sec, where = mouse.click(focus_state, "left")
		if t[sec] then
			if can_expand(sec) then
				if expand[sec] == nil then
					button.n = button.n + 1
					if button.n == 2 then
						button.disable = nil
					end
					vbutton.update "button1"
					expand[sec] = 1
				else
					expand[sec] = expand[sec] + 1
				end
				from_n = from_n - 1
				map.expand_people(sec)
				set_tips(sec)
			end
		end
		if where == "button1" and button.n == 2 then
			break
		end
		local sec, where = mouse.click(focus_state, "right")
		if expand[sec] then
			if expand[sec] == 1 then
				if button.n == 2 then
					button.disable = true
				end
				button.n = button.n - 1
				expand[sec] = nil
				vbutton.update "button1"
			else
				expand[sec] = expand[sec] - 1
			end
			from_n = from_n + 1
			map.expand_back(sec)
			set_tips(sec)
		end
		flow.sleep(0)
	end
	for sec in pairs(t) do
		vmap.set_sector_mask(sec)
	end
	map:reset()
	vdesktop.button_enable("button1", nil)
end

function advancement.F(focus_state)
	local t = map.territory(0)
	for sec, n in pairs(t) do
		if n < 3 then
			-- must at least 3 people, because need expand into 2 adjacent sectors
			t[sec] = nil
		end
		local neighbor = map.find_neighbor(sec)
		local count = 0
		for sec, n in pairs(neighbor) do
			if n < LIMIT then
				count = count + 1
				if count >= 2 then
					break
				end
			end
		end
		-- at least 2 expand object sectors
		if count < 2 then
			t[sec] = nil
		end
	end
	if next(t) == nil then
		return
	end
	
	vdesktop.set_text("phase", { extra = "$(civ.F.desc)" })
	local sec, sec_n = choose_departure(t, focus_state)
	local neighbor = map.find_neighbor(sec)
	for sec, n in pairs(neighbor) do
		if n >= LIMIT then
			neighbor[sec] = nil
		end
	end
	expand_2(sec, sec_n, neighbor, focus_state)
end

local function evoke(c)
	vtips.set()
	local f = victory[c.victory] or error ("Invalid victory type " .. tostring(c.victory))
	f {}
	vtips.set()
	local f = advancement[c.advancement] or error ("Invalid advancement type " .. tostring(c.advancement))
	f {}
end

return function (c, state, last_action)
	local action = evoke_or_action(c, state, last_action)
	if action == "evoke" then
		vdesktop.set_text("phase", { extra = "$(action.evoke)" })
		evoke(c)
	end
	return action
end