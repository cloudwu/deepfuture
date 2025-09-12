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
local string = string
global print, pairs, next, ipairs, assert, print_r

local COLOR <const> = color.blend(0x01000000, ui.card.mask_focus)
local DURATION <const> = ui.desktop.focus_duration

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

local function collect_advs()
	local n = 1
	local adv = {}
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		card.collect_suits(c, adv)
		n = n + 1
	end
	return adv
end

local ADV_NEED <const> = rules_vic.advancement
local WONDER_NEED <const> = rules_vic.wonder

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

local function name_sector(sector)
	local n = name.sector(sector)
	local x, y = vdesktop.screen_sector_coord(sector)	
	vdesktop.camera_focus(x, y, 5)
	flow.sleep(30)
	local name_object = {}
	for i = 1, 255 do
		local vname = string.format("[%08X]%s[n]", (i << 24) | 0x202040, n)
		name_object.name = vname
		vmap.set_sector_name(sector, name_object)
		vmap.update()
		flow.sleep(0)
	end
	map.set_sector_name(sector, n )
	map.update()
	loadsave.sync_map()
	vdesktop.camera_focus()
end

local function checker_wonder(vics, advs, sec)
	local obj = map.get_name(sec)
	if obj.wonder then
		--already has wonder
		return
	end
	local suits = {}
	for suit, n in pairs(advs) do
		if n >= WONDER_NEED then
			suits[#suits+1] = suit
		end
	end
	if #suits == 0 then
		-- no suit >= 5 (WONDER_NEED)
		return
	end
	local wonder_types = {}
	for _, vic in ipairs(vics) do
		local symbol = rules_vic.symbol[vic]
		for _, suit in ipairs(suits) do
			local key = symbol .. suit
			wonder_types[key] = true
		end
	end
	map.wonder_available(wonder_types)
	if next(wonder_types) == nil then
		-- no available wonders
		return
	end
	return wonder_types
end

local function merge_suits(wonders)
	local r = {}
	for key in pairs(wonders) do
		local symbol = key:sub(1,1)
		local suit = key:sub(2,2)
		r[symbol] = (r[symbol] or "") .. suit
	end
	return r
end

local function gen_symbol_choice(wonders,sec)
	local choose = {}
	local tmp = {}
	for symbol, suits in pairs(wonders) do
		local suit = suits:gsub("." , function(c) tmp.suit = c; return card.suit_info(tmp) end)
		local clone = {
			type = "blank" ,
			name = "$(wonder.choose.title)",
			desc = "$(wonder." .. symbol .. ")",
			symbol = symbol,
			suit = suit,
			suits = suits,
			sector = sec,
			info = "$(wonder.choose)",
		}
		choose[clone] = true
		vcard.mask(clone, true)
		vdesktop.add("deck", clone)
		vdesktop.transfer("deck", clone, "float")
		flow.sleep(5)
	end
	return choose
end

local function choose_symbol(choose, sec)
	local focus_state = {}
	local desc = { sector = sec }
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				local c = focus_state.object
				local vic = choose[c]
				desc.symbol = c.symbol
				desc.suit = c.suit
				desc.desc = "$(wonder." .. c.symbol .. ")"
				vtips.set("tips.wonder.symbol", desc)
			elseif focus_state.object then
				vtips.set "tips.wonder.advice"
			else
				vtips.set()
			end
		end
		local clone = mouse.click(focus_state, "left")
		if choose[clone] then
			return clone
		end
		flow.sleep(0)
	end
end

local function gen_suit_choice(choose_card, sec)
	local tmp = {}
	local choose = {}
	local suits = choose_card.suits 
	local symbol = choose_card.symbol
	for i = 1, #suits do
		tmp.suit = suits:sub(i,i)
		local clone = {
			type = "blank" ,
			name = "$(wonder.suits.title)",
			desc = "$(wonder." .. symbol .. ")",
			suit = card.suit_info(tmp),
			suits = tmp.suit,
			sector = sec,
			info = "$(wonder.suits.choose)",
		}
		choose[clone] = tmp.suit
		vcard.mask(clone, true)
		vdesktop.add("deck", clone)
		vdesktop.transfer("deck", clone, "float")
		flow.sleep(5)
	end
	return choose
end

local function choose_suit(choose, symbol, sec)
	local focus_state = {}
	local desc = {
		sector = sec,
		symbol = symbol,
	}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				local c = focus_state.object
				desc.suit = c.suit
				desc.desc = "$(wonder." .. symbol .. ")"
				vtips.set("tips.wonder.suit", desc)
			elseif focus_state.object then
				vtips.set "tips.wonder.advice"
			else
				vtips.set()
			end
		end
		local clone = mouse.click(focus_state, "left")
		if choose[clone] then
			return clone
		end
		flow.sleep(0)
	end
end

local function choose_wonder(wonders, sec)
	vdesktop.set_text("phase", {
		extra = "$(phase.victory.wonder)",
	})
	wonders.TM = true
	wonders = merge_suits(wonders)
	local choose = gen_symbol_choice(wonders, sec)
	local choose_card = choose_symbol(choose, sec)
	drop_float(choose)
	
	if #choose_card.suits == 1 then
		-- no choise of suits
		return choose_card.symbol, choose_card.suits
	end

	local choose = gen_suit_choice(choose_card, sec)
	local symbol = choose_card.symbol
	local choose_card = choose_suit(choose, symbol, sec)
	drop_float(choose)
	
	return symbol, choose_card.suits
end

local function create_wonder(sector, symbol, suit)
	local x, y = vdesktop.screen_sector_coord(sector)	
	vdesktop.camera_focus(x, y, 5)
	flow.sleep(30)
	local name_object = {
		name = map.get_name(sector).name,
		suit = suit,
	}
	for i = 1, 255 do
		local vsymbol = string.format("[%08X]%s", (i << 24) | 0x000040, symbol)
		name_object.wonder = vsymbol
		vmap.set_sector_name(sector, name_object)
		vmap.update()
		flow.sleep(0)
	end
	map.set_sector_wonder(sector, symbol, suit)
	map.update()
	loadsave.sync_map()
	vdesktop.camera_focus()
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
	
	local h = card.card("homeworld", 1)
	if not map.get_name(h.sector) then
		name_sector(h.sector)
	end
	local advs = collect_advs()
	local wonders = checker_wonder(vics, advs, h.sector)
	if wonders then
		local symbol, suit = choose_wonder(wonders, h.sector)
		create_wonder(h.sector, symbol, suit)
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

	gen_civ_card(vics, advs)

	card.next_era()

	return flow.state.nextgame
end
