local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local rules = require "core.rules".phase
local card = require "gameplay.card"
local class = require "core.class"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local vcard = require "visual.card"
local vtips = require "visual.tips".layer "hud"
local mouse = require "core.mouse"
local util = require "core.util"
local name = require "gameplay.name"
local addadv = require "gameplay.addadv"
local power = require "gameplay.power"
local advance = require "gameplay.advance"
local loadsave = require "core.loadsave"
local sync = require "gameplay.sync"

global next, pairs, print, assert

local function interval()
	flow.sleep(20)
end

local function moving(clone, c, f)
	vdesktop.add("deck", c)
	vdesktop.transfer("deck", c, "float")
	f(clone)
	vcard.flush(clone)
	interval()
	vdesktop.transfer("float", c, "deck")
end

local adv_focus = {}

function adv_focus.leisure()
	track.focus("C", true)
end

function adv_focus.medicine()
	track.focus("S", true)
end

function adv_focus.ecology()
	track.focus("X", true)
end

local settle_adv = {}

function settle_adv.leisure()
	track.advance("C", 2)
end

function settle_adv.government()
	local c = card.settling()
	local advsuit = card.draw_discard()

	moving(c, advsuit, function(c)
		card.add_adv_suit(c, advsuit.suit)
	end)
end

function settle_adv.medicine()
	track.advance("S", 1)
end

function settle_adv.ecology()
	track.advance("X", 1)
end

local function create_new_world()
	local newcard, card1, card2 = card.generate_newcard()
	local clone = { type = "blank" }
	
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	
	interval()

	moving(clone, card1, function (clone)
		clone._marker = newcard.value
	end)

	moving(clone, card2, function (clone)
		clone._marker = newcard._marker
	end)

	interval()
	
	vdesktop.replace("float", clone, newcard)
	
	return newcard
end

local function settling(advs)
	local n = advs:update { society = true }
	
	local cards = {}
	local blank_cards = {}
	local n = 1
	local has_world = false
	while true do
		local c = card.card("hand",n)
		if not c then
			break
		end
		n = n + 1
		if c.type == "world" then
			has_world = true
			if map.player_ctrl(c.sector) then
				cards[c] = true
			end
		elseif not has_world and c.type == "blank" then
			blank_cards[#blank_cards+1] = c
		end
	end
	local allow_new_world
	if not has_world then
		-- no world card in hand
		if next(cards) == nil then
			local n = #blank_cards
			if n == 0 then
				-- no blank card in hand, too.
				-- allow settle new world from draw pile
				allow_new_world = true
			else
				-- blank cards can use
				for i = 1, n do
					cards[blank_cards[i]] = true
				end
			end
		end
	end

	-- add neutral worlds
	n = 1
	while true do
		local c = card.card("neutral",n)
		if not c then
			break
		end
		n = n + 1
		if map.player_ctrl(c.sector) then
			cards[c] = true
		end
	end
	
	local function set_mask(enable)
		if allow_new_world then
			vdesktop.draw_pile_focus(enable)
		end
		for c in pairs(cards) do
			vcard.mask(c, enable)
		end
	end
	
	set_mask(true)
	
	local desc = {}
	local focus_state = {}
	local settling
	local from
	
	while true do
		if mouse.get(focus_state) then
			local c = focus_state.object
			if cards[c] then
				-- choose card
				if c.type == "world" then
					desc.world = c
					if focus_state.active == "neutral" then
						vtips.set("tips.settle.capture", desc)
					else
						vtips.set("tips.settle.hand", desc)
					end
				else
					vtips.set "tips.settle.blank"
				end
			elseif focus_state.active == "discard" then
				vtips.set "tips.settle.newworld"
			elseif advs:can_use(c) then
				vtips.set "tips.settle.society"
			elseif focus_state.object then
				vtips.set "tips.settle.advice"
			else
				vtips.set()
			end
		end
		local c, where = mouse.click(focus_state, "left")
		if c then
			if cards[c] then
				-- settle a world
				set_mask()
				settling = card.pickup(where, c)
				from = where
				vdesktop.transfer(where, settling, "float")
				flow.sleep(5)
				if where == "hand" then
					-- from hand, draw one card
					local extra_card = card.draw_hand()
					vdesktop.add("deck", extra_card)
					vdesktop.transfer("deck", extra_card, "hand")
					flow.sleep(5)
				end
				break
			elseif advs:can_use(c) then
				local adv_name = advs:focus(c)
				assert(adv_name == "society")
				advs:use(c)
				-- enable draw pile
				allow_new_world = true
				vdesktop.draw_pile_focus(true)
				advs:reset()
			elseif where == "discard" then
				-- create a new world
				set_mask()
				settling = create_new_world()
				break
			end
		end
		flow.sleep(0)
	end
	vtips.set()
	return settling, from
end

local function choose_sector(c)
	vcard.mask(c, true)
	local focus_state = {}
	
	while true do
		if mouse.get(focus_state) then
			if c == focus_state.object then
				vtips.set "tips.settle.confirm"
			else
				vtips.set "tips.settle.confirm.advice"
			end
		elseif not focus_state.object then
			vtips.set()
		end
		if mouse.click(focus_state, "left") then
			vdesktop.transfer("float", c, "deck")
			break
		end
		flow.sleep(0)
	end
	vcard.mask(c)
	
	-- choose sector
	local t = map.territory()
	for sec in pairs(t) do
		vmap.set_sector_mask(sec, true)
	end
	
	local desc = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				local sec = focus_state.object
				desc.sec = sec
				if t[sec] then
					vtips.set ("tips.settle.map.confirm", desc)
				else
					map.info(sec, desc)
					vtips.set ("tips.settle.map.desc", desc)
				end
			elseif focus_state.object then
				vtips.set( "tips.settle.map.advice", desc)
			else
				vtips.set()
			end
		end
		local sec, where = mouse.click(focus_state, "left")
		if sec and where == "map" and t[sec] then
			c.sector = sec
			break
		end
		flow.sleep(0)
	end
	for sec in pairs(t) do
		vmap.set_sector_mask(sec)
	end
	vtips.set()
	
	-- add init adv
	
	c.type = "world"

	local clone = util.shallow_clone(c, { adv1 = {}})

	local advsuit = card.draw_discard()
	local advtype = card.draw_discard()
	
	local index = card.add_adv_suit(c, advsuit.suit)
	card.add_adv_value(c, index, advtype.value, c.era)
	card.gen_desc(c)
	name.world(c)	-- todo: name it
	vcard.flush(c)
	
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	
	interval()
	
	moving(clone, advsuit, function (clone)
		clone.adv1._suit = c.adv1._suit
	end)

	moving(clone, advtype, function (clone)
		clone.adv1._stage = c.adv1._stage
		clone.adv1._name = c.adv1._name
		clone.adv1._desc = c.adv1._desc
	end)
	
	interval()
	
	vdesktop.replace("float", clone, c)
end

local function draw_value(c, adv_index)
	local advtype = card.draw_discard()
	c[adv_index].era = c.era
	
	moving(c, advtype, function (c)
		c[adv_index].value = advtype.value
		card.gen_desc(c)
	end)
	
	interval()
end

local function choose_adv(c, advs)
	local choose = addadv.choose_random_adv(c)
	if #choose == 0 then
		-- no adv
		return
	end
	if card.chosen(c) == 0 then
		addadv.add_choice(choose)
	end
	if #choose == 1 then
		-- only one random choise
		draw_value(c, choose[1]._random)
		return
	end
	-- random choice or choose one
	local click_card = addadv.choose_or_random(choose, c, advs)

	local adv_index = click_card._random
	if adv_index then
		-- draw card
		draw_value(c, adv_index)
	elseif click_card._choose then
		addadv.choose_value(c, click_card._choose)
	end
	return choose_adv(c, advs)
end

return function()
	loadsave.sync_game "settle"
	sync()
	vdesktop.set_text("phase", { text = "$(phase.action)" })
	vdesktop.set_text("phase", { extra = "[blue]$(SETTLE)[n]" } )
	-- default behaviour : choose settle world
	
	local advs = class.effect "SETTLE"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local newworld, from = settling(advs)
	if newworld.type == "blank" then
		choose_sector(newworld)
		card.sync(newworld)
	end
	card.settling(newworld)

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "settle",
			adv_focus = adv_focus,
			adv_func = settle_adv,
		}
		-- choose adv if government
		choose_adv(newworld, advs)
		advs:discard_used_cards()
		advs:reset()
	end
	
	card.putdown("colony", newworld)
	vdesktop.transfer("float", newworld, "colony")
	flow.sleep(5)
	if from == "neutral" then
		-- free power and advance
		return "freepower"
	end
	
	return "action"
end
