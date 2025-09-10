local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local card = require "gameplay.card"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local victory = require "gameplay.victory"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local color = require "visual.color"
local vcard = require "visual.card"
local rules_vic = require "core.rules".victory
local ui = require "core.rules".ui
local util = require "core.util"
local vtips = require "visual.tips".layer "hud"
local mouse = require "core.mouse"
local name = require "gameplay.name"

local table = table

global print, pairs, next, ipairs, assert

local COLOR <const> = color.blend(0x01000000, ui.card.mask_focus)
local DURATION <const> = ui.focus.duration

local function clear(where)
	local n = 1
	while true do
		local c = card.card(where, n)
		if c == nil then
			return
		end
		n = n + 1
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
end

local function check_tech()
	local mask = {}
	local function focus_card(c)
		mask[c] = 0
	end
	local function focus_update()
		for c, duration in pairs(mask) do
			local f = duration + 1
			if f >= DURATION * 2 then
				f = 0
				mask[c] = nil
			else
				mask[c] = f
			end
			if f >= DURATION then
				f = DURATION * 2 - 1 - f 
			end
			if f == 0 then
				vcard.mask(c)
			else
				f = f + 1
				vcard.mask(c, COLOR(f))
			end
		end
	end
	
	local n = 1
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		n = n + 1
		if card.complete(c) then
			focus_card(c)
			for i = 1, 5 do
				focus_update()
				flow.sleep(0)
			end
		end
	end
	while next(mask) do
		focus_update()
		flow.sleep(0)
	end
end

local function gen_extra(vics)
	local tmp = {}
	for _, vic in ipairs(vics) do
		tmp[#tmp+1] = "${vic." .. vic .. "|}"
	end
	return table.concat(tmp, " ")
end

local victory_ani = {}
local PLAYER <const> = ui.map.player

function victory_ani.population(checker, extra)
	local pop = extra.vic
	local count = 0
	for sec, n in pairs(checker) do
		for i = 1, n do
			count = count + 1
			pop.people = count	
			vmap.set(sec, PLAYER, n, i)
			vmap.update()
			vdesktop.set_text("phase", extra)
			flow.sleep(1)
		end
	end
end

function victory_ani.territory(checker, extra)
	local t = extra.vic
	local count = 0
	for sec in pairs(checker) do
		count = count + 1
		t.sec = count
		vmap.focus(sec)
		vdesktop.set_text("phase", extra)
		flow.sleep(5)
	end
end

function victory_ani.culture(checker, extra)
	track.focus("C", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.might(checker, extra)
	track.focus("M", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.stability(checker, extra)
	track.focus("S", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.xeno(checker, extra)
	track.focus("X", true)
	flow.sleep(30)
	track.focus(nil)
end

local function drop_float(choose)
	vtips.set()
	for c in pairs(choose) do
		vdesktop.transfer("float", c, "deck")
		flow.sleep(5)
	end
	while true do
		local c = next(choose)
		if c == nil then
			break
		end
		flow.sleep(0)
		if not vdesktop.moving("deck", c) then
			choose[c] = nil
		end
	end
end

local function choose_victory(c, vics)
	local choose = {}
	for _, vic in ipairs(vics) do
		local clone = util.shallow_clone(c, {})
		clone.victory = vic
		card.gen_desc(clone)
		clone._name = "[blue]$(victory." .. vic .. ")[n]"
		clone._marker = ""
		vcard.mask(clone, true)
		vdesktop.add("deck", clone)
		vdesktop.transfer("deck", clone, "float")
		choose[clone] = vic
		flow.sleep(5)
	end
	
	local focus_state = {}
	local desc = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				local vic = choose[focus_state.object]
				desc.adv = "$(civ." .. vic .. ".desc)"
				desc.victory = "$(victory." .. vic .. ")"
				vtips.set("tips.civ.victory", desc)
			elseif focus_state.object then
				vtips.set "tips.civ.victory.advice"
			else
				vtips.set()
			end
		end
		local clone = mouse.click(focus_state, "left")
		local vic = choose[clone]
		if vic then
			c.victory = vic
			break
		end
		flow.sleep(0)
	end
	drop_float(choose)
end

local function add_adv(c, adv, index)
	local a = c[index]
	if a == nil then
		return
	end
	adv[a.suit] = (adv[a.suit] or 0) + 1
end

local function collect_advs()
	local n = 1
	local adv = {}
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		add_adv(c, adv, "adv1")
		add_adv(c, adv, "adv2")
		add_adv(c, adv, "adv3")
		n = n + 1
	end
	return adv
end

local ADV_NEED <const> = rules_vic.advancement

local function choose_advancement(c, advs)
	local choose = {}
	for suit, n in pairs(advs) do
		if n >= ADV_NEED then
			local clone = util.shallow_clone(c, {})
			clone.advancement = suit
			card.gen_desc(clone)
			clone._name = "[blue]$(civ.advancement." .. suit .. ")[n]"
			clone._marker = ""
			vcard.mask(clone, true)
			vdesktop.add("deck", clone)
			vdesktop.transfer("deck", clone, "float")
			choose[clone] = suit
			flow.sleep(5)
		end
	end
	local focus_state = {}
	local desc = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				local suit = choose[focus_state.object]
				desc.suit = "$(civ.advancement." .. suit .. ")"
				desc.adv = "$(civ." .. suit .. ".desc)"
				desc.n = advs[suit]
				vtips.set("tips.civ.advancement", desc)
			elseif focus_state.object then
				desc.n = ADV_NEED
				vtips.set ("tips.civ.advancement.advice", desc)
			else
				vtips.set()
			end
		end
		local clone = mouse.click(focus_state, "left")
		local adv = choose[clone]
		if adv then
			c.advancement = adv
			break
		end
		flow.sleep(0)
	end
	drop_float(choose)
end

local function show_clone_card(c)
	local clone = util.shallow_clone(c, {})
	card.gen_desc(clone)
	clone._name = ""
	clone._marker = ""
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	return clone
end

local function wait_moving(c, from, to)
	vdesktop.transfer(from, c, to)
	flow.sleep(1)
	while vdesktop.moving(to, c) do
		flow.sleep(0)
	end
end

local function add_homeworld(c, clone)
	local h = card.card("homeworld", 1)
	wait_moving(h, "homeworld", "float")
	c.sector = h.sector
	clone.sector = h.sector
	c.world = h.name
	clone.world = h.name
	
	name.civ(c)
	clone.name = c.name
	card.gen_desc(clone)
	clone._marker = ""
	vcard.flush(clone)
	flow.sleep(10)
	wait_moving(h, "float", "homeworld")
end

local function add_tech(clone, tech, index)
	wait_moving(tech, "homeworld", "float")
	clone.tech[index] = tech.name
	vcard.flush(clone)
	flow.sleep(10)
	wait_moving(tech, "float", "homeworld")
end

local function add_techs(c, clone)
	c.tech = {}
	clone.tech = c.tech
	local n = 2
	local tech = 0
	while true do
		local t = card.card("homeworld", n)
		if t == nil then
			break
		end
		n = n + 1
		if card.complete(t) then
			tech = tech + 1
			add_tech(clone, t, tech)
		end
	end
end

local function add_marker(c, clone, card1, card2)
	card.gen_desc(c)
	vcard.flush(c)
	vdesktop.add("deck", card1)
	wait_moving(card1, "deck", "float")
	clone._marker = card1.value
	vcard.flush(clone)
	flow.sleep(10)
	wait_moving(card1, "float", "deck")
	
	vdesktop.add("deck", card2)
	wait_moving(card2, "deck", "float")
	clone._marker = c._marker
	vcard.flush(clone)
	flow.sleep(10)
	wait_moving(card2, "float", "deck")
	vdesktop.replace("float", clone, c)
	vcard.mask(c, true)
end

local function gen_civ_card(vics, advs)
	local c, card1, card2 = card.generate_newcard()
	c.type = "civ"
	choose_victory(c, vics)
	choose_advancement(c, advs)
	local clone = show_clone_card(c)
	add_homeworld(c, clone)
	add_techs(c, clone)
	add_marker(c, clone, card1, card2)
	card.sync(c)
	-- todo : rename new civ card
	local focus_state = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				vtips.set "tips.civ.confirm"
			elseif focus_state.object then
				vtips.set "tips.civ.confirm.advice"
			else
				vtips.set()
			end
		end
		if mouse.click(focus_state, "left") == c then
			break
		end
		flow.sleep(0)
	end
	card.discard(c)
	vdesktop.transfer("float", c, "deck")
end

return function()
	vdesktop.set_text("phase", {
		text = "$(phase.victory)",
	})
	check_tech()
	
	local vics = {}
	local checker = victory.checker()
	for _, vic in ipairs(rules_vic.name) do
		if checker[vic](checker) then
			vics[#vics+1] = vic
		end
	end
	
	local extra = {
		extra = gen_extra(vics),
		vic = {},
	}

	for _, vic in ipairs(vics) do
		local f = victory_ani[vic]
		if f then
			extra.vic[vic] = "$(victory." .. vic .. ".title)"
			f(checker, extra)
			flow.sleep(5)
			vdesktop.set_text("phase", extra)
		end
	end
	
	extra.extra = "$(civ.phase.create)"
	vdesktop.set_text("phase", extra)
	
	local advs = collect_advs()
	gen_civ_card(vics, advs)
--[[
	local focus_state = {}
	while true do
		mouse.get(focus_state)	
		if mouse.click(focus_state, "left") then
			break
		end
		flow.sleep(0)
	end
]]
	card.next_era()

	return flow.state.nextgame
end
