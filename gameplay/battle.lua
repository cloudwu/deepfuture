local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local class = require "core.class"
local look = require "gameplay.look"
local advancement = require "gameplay.advancement"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local rules = require "core.rules".phase
local vtips = require "visual.tips".layer "hud"
local map_rules = require "core.rules".map
local focus = require "core.focus"
local lost_sectors = require "gameplay.lostsectors"

global pairs, setmetatable, print, next

local adv_focus = {}

function adv_focus.weapons()
	track.focus("M", true)
end
	
function adv_focus.machinery()
	track.focus("S", true)
end

function adv_focus.diplomacy()
	track.focus("C", true)
end

function adv_focus.defense()
	local sec = map.battlefield()
	if sec then
		vmap.focus(sec)
	end
end

local battle_adv = {}

function battle_adv.weapons()
	track.advance("M", 1)
end

function battle_adv.machinery()
	track.advance("S", 1)
end

function battle_adv.diplomacy()
	track.advance("C", 2)
end

function battle_adv.defense(advs)
	map.hostile(1)
end

local function find_map()
	local t = map.territory()
	local r = {}
	for sec in pairs(t) do
		if map.find_enemy(sec, r) then
			r[sec] = true
		end
	end
	return r
end

local function sector_mask(set, flag)
	local n = 0
	for sec in pairs(set) do
		vmap.set_sector_mask(sec, flag)
		n = n + 1
	end
	return n
end

local function choose_battlefield_()
	local t = find_map()
	local n = sector_mask(t, true)
	if n <= 2 then
		if n == 0 then
			-- is safe
			return
		end
		local sec1 = next(t)
		local sec2 = next(t, sec1)
		return map.battle(sec1, sec2)
	end
	
	local focus_state = {}
	local desc = {}
	local sec1, sec2
	
	for i = 1, 2 do
		while true do
			if focus.get(focus_state) then
				if focus_state.active == "map" then
					local sec = focus_state.object
					map.info(sec, desc)
					if t[sec] then
						vtips.set ("tips.battle.set", desc)
					else
						vtips.set ("tips.battle.set.invalid", desc)
					end
				else
					vtips.set( "tips.battle.set.advice", desc)
				end
			elseif focus_state.lost then
				vtips.set()
			end
			local sec = focus.click "left"
			if t[sec] then
				vtips.set()
				sec1, sec2 = sec, sec1
				sector_mask(t)
				t = {}
				if map.find_enemy(sec, t) == 1 then
					sec2 = next(t)
					return map.battle(sec1, sec2)
				end
				sector_mask(t, true)
				break
			end
			flow.sleep(0)
		end
	end
	sector_mask(t)
	return map.battle(sec1, sec2)
end

local function choose_battlefield()
	local phase = { extra = "$(tips.battle.battlefield)" }
	vdesktop.set_text("phase", phase)
	choose_battlefield_()
	flow.sleep(1)	-- reset mouse click
	phase.extra = "[blue]$(BATTLE)[n]"
	vdesktop.set_text("phase", phase)
end

function battle_adv.military()
	choose_battlefield()
end

local function inc_track()
	local focus_state = {}
	track.focus(true)
	local desc = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "track" then
				local what = focus_state.object	-- C/M/S/X
				track.focus(false)
				desc.type = "$(hud." .. what .. ")"
				if track.check(what, 1) then
					vtips.set("tips.battle.safe.invalid", desc)
				else
					vtips.set("tips.battle.safe.valid", desc)
					track.focus(what, true)
				end
			else
				vtips.set "tips.battle.safe.out"
			end
		elseif focus_state.lost then
			-- focus all
			track.focus(true)
			vtips.set()
		end
		
		local t, where = focus.click "left"
		if where == "track" then
			if not track.check(t, 1) then
				track.advance(t, 1)
				track.focus(false)
				vtips.set()
				flow.sleep(1)
				return
			end
		end
		flow.sleep(0)
	end
end

return function()
	if map.is_safe() then
		inc_track()
	else
		choose_battlefield()
	end

	local map_message = {}
	local desc = {
		n = 0,
		lost = nil,
	}

	function map_message.focus(sec)
		local player_sec = map.in_battle(sec)
		if player_sec then
			if map.battle_lostctrl(1) then
				if card.has_player_world(player_sec) then
					-- would lost
					if card.check_only_sector(player_sec) then
						vtips.set ("tips.battle.prepare.invalid", desc)
					elseif map.battle_lostctrl(0) then
						vtips.set ("tips.battle.prepare.lost", desc)
					else
						vtips.set ("tips.battle.prepare", desc)
					end
				end
			else
				vtips.set ("tips.battle.prepare", desc)
			end
		else
			vtips.set ("tips.battle.retreat", desc)
		end
	end

	function map_message.click(sec, button)
		if map.in_battle(sec) then
			if button == "left" then
				desc.n = map.army(1)
			elseif button == "right" then
				desc.n = map.army(-1)
			end
		elseif button == "left" then
			desc.n = map.army(-1)
		end
		map_message.focus(sec)
	end

	local advs = class.effect "BATTLE"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "battle",
			adv_focus = adv_focus,
			adv_func = battle_adv,
			map_message = map_message,
		}
		advs:discard_used_cards()
	end
	
	advs:reset()
	
	-- confirm battle
	if not map.hostile() then
		-- no battle
		return
	end
	local button = {
		text = "button.battle.confirm",
	}
	local focus_state = {}
	
	vdesktop.button_enable("button1", button)
				
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "map" then
				map_message.focus(focus_state.object)
			elseif focus_state.active == "button1" then
				vtips.set "tips.battle.confirm"
			else
				vtips.set()
			end
		end
		local c, btn = focus.click "left"
		if c then
			if btn == "button1" then
				break
			elseif btn == "map" then
				map_message.click(c, "left")
			end
		end
		local c, btn = focus.click "right"
		if btn == "map" then
			map_message.click(c, "right")
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	local lost = map.battle_confirm()
	lost_sectors(lost)
end
