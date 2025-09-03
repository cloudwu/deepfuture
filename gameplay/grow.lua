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

local LIMIT <const> = map_rules.sector.limit

global pairs, setmetatable, print

local DEFAULT_ADD <const> = rules.grow.add

local adv_focus = {}

function adv_focus.biology()
	vmap.focus(map.can_grow_extra())
end
	
function adv_focus.genetics()
	vmap.focus(map.grow())
end

function adv_focus.education()
	track.focus("X", true)
end

function adv_focus.agriculture()
	track.focus("S", true)
end

function adv_focus.construction()
	track.focus("C", true)
end

local grow_adv = {}

local function grow_sector(sec)
	local sec = map.grow(sec)
	for i = 1, DEFAULT_ADD do
		vmap.focus(sec)
		map.add_player(sec, 1)
		flow.sleep(5)
	end
end

local function grow_sector_extra(sec)
	map.grow_extra(sec)
	vmap.focus(sec)
	map.add_player(sec, 1)
	flow.sleep(5)
end

local function grow_sectors(t, action)
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, true)
	end
	
	local focus_state = {}
	local desc = { limit = LIMIT }
	
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "map" then
				local sec = focus_state.object
				desc.sec = sec
				if t[sec] then
					vtips.set ("tips.grow.execute", desc)
				else
					map.info(sec, desc)
					vtips.set ("tips.grow.desc", desc)
				end
			else
				vtips.set( "tips.grow.advice", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local sec, where = focus.click "left"
		if sec and where == "map" and t[sec] then
			action(sec)
			break
		end
		flow.sleep(0)
	end
	
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, false)
	end
end

function grow_adv.biology(advs)
	local set = map.list_grow_extra()
	grow_sectors(set, grow_sector_extra)
end

function grow_adv.genetics()
	grow_sector()
end

function grow_adv.education()
	track.advance("X", 1)
end

function grow_adv.agriculture()
	track.advance("S", 1)
end

function grow_adv.construction()
	track.advance("C", 2)
end

return function()
	card.verify()
	vdesktop.set_text("phase", { extra = "[blue]$(GROW)[n]" })

	-- default behaviour : add peoples
	
	local t = map.territory(1)	-- at least 1 space
	grow_sectors(t, grow_sector)
	
	local advs = class.effect "GROW"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "grow",
			adv_focus = adv_focus,
			adv_func = grow_adv,
		}
		advs:discard_used_cards()
	end
	
	map.reset()
end
