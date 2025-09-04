local card = require "gameplay.card"
local name = require "gameplay.name"
local focus = require "core.focus"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips".layer "hud"
local vcard = require "visual.card"
local map = require "gameplay.map"
local track = require "gameplay.track"
local rules = require "core.rules".phase
local test = require "gameplay.test"
local util = require "core.util"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local string = string

global pairs, ipairs, tostring, print, print_r

local function sleep()
	flow.sleep(5)
end

local function draw_card()
	local card = card.draw_card()
	if card == nil then
		return
	end
	vdesktop.add("deck", card)
	vdesktop.transfer("deck", card, "float")
	sleep()
	return card
end

local function wait_for_moving_float(moving)
	repeat
		local more
		for card, to in pairs(moving) do
			if not vdesktop.moving("float", card) then
				vdesktop.transfer("float", card, to)
				moving[card] = nil
			else
				more = true
			end
		end
		flow.sleep(0)
	until not more
end

local function set_neutral()
	local tmp = {}
	local n = 1
	while true do
		local c = card.card("neutral", n)
		if c == nil then
			break
		end
		n = n + 1
		tmp[c.value] = true
	end
	local moving = {}
	for i = 1, card.count "draw" + card.count "discard" do
		local c = draw_card()
		if c == nil then
			break
		end
		if c.type ~= "world" or tmp[c.value] or map.player_ctrl(c.sector) then
			card.discard(c)
			moving[c] = "deck"
			if tmp[c.value] then
				break
			end
		else
			tmp[c.value] = true
			card.putdown("neutral", c)
			moving[c] = "neutral"
			map.add_neutral(c.sector, 3)
		end
		for card, to in pairs(moving) do
			if not vdesktop.moving("float", card) then
				vdesktop.transfer("float", card, to)
				moving[card] = nil
			end
		end
	end
	
	wait_for_moving_float(moving)
end

local function clear_mask(hands)
	for _, c in ipairs(hands) do
		vcard.mask(c)
	end
end

local function choose_world(hands)
	local desc = {
		world = nil,
		type = nil,
	}
	local homeworld
	local focus_state = {}
	
	repeat
		if focus.get(focus_state) and focus_state.active == "hand" then
			local c = focus_state.object
			if c.type == "world" then
				desc.world = c.sector .. " " .. c.name
				vtips.set("tips.setup.homeworld", desc)
			else
				desc.type = string.format("$(card.type.%s)", c.type)
				vtips.set("tips.setup.invalid", desc)
			end
		elseif focus_state.lost == "hand" then
			vtips.set()
		end
		local c, from = focus.click ("left", "hand")
		if from == "hand" and c.type == "world" then
			homeworld = c
			clear_mask(hands)
		end
		flow.sleep(0)
	until homeworld
	vtips.set()
	return homeworld
end

local function new_world(hands)
	local focus_state = {}
	
	local button = {
		text = "button.new_world",
	}
	local desc = {
		type = nil
	}
	vdesktop.button_enable("button1", button)

	repeat
		if focus.get(focus_state) then
			if focus_state.active == "button1" then
				vtips.set("tips.setup.newworld")
			elseif focus_state.active == "hand" then
				desc.type = string.format("$(card.type.%s)", focus_state.object.type)
				vtips.set("tips.setup.newworld.invalid", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		flow.sleep(0)
	until focus.click ("left", "button1")
	
	vdesktop.button_enable("button1", nil)
	vtips.set()
	local newcard, card1, card2 = card.generate_newcard()
	local sec1 = card.draw_discard()
	local sec2 = card.draw_discard()
	
	newcard.type = "world"
	newcard.sector = sec1.value * 10 + sec2.value
	name.world(newcard)
	
	local advsuit = card.draw_discard()
	local advtype = card.draw_discard()
	
	local index = card.add_adv_suit(newcard, advsuit.suit)
	card.add_adv_value(newcard, index, advtype.value, newcard.era)

	card.putdown("hand", newcard)
	
	local clone = { type = "blank" }
	clone.adv1 = {}
	
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	
	local function interval()
		flow.sleep(20)
	end
	
	local function moving(c, f)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		f()
		vcard.flush(clone)
		interval()
		vdesktop.transfer("float", c, "deck")
	end
	
	interval()

	moving(card1, function ()
		clone._marker = newcard.value
	end)

	moving(card2, function ()
		clone._marker = newcard._marker
	end)
	
	moving(sec1, function ()
		clone.sector = sec1.value
	end)
	
	moving(sec2, function ()
		clone.sector = newcard.sector
		clone.name = newcard.name
		clone.era = newcard.era
		clone.type = "world"
	end)

	moving(advsuit, function ()
		clone.adv1._suit = newcard.adv1._suit
	end)

	moving(advtype, function ()
		clone.adv1._stage = newcard.adv1._stage
		clone.adv1._name = newcard.adv1._name
		clone.adv1._desc = newcard.adv1._desc
	end)
	
	interval()
	
	vdesktop.replace("float", clone, newcard)
	vdesktop.transfer("float", newcard, "hand")
	
	card.sync(newcard)

	return newcard
end

local function choose(hands)
	local have_world
	for _, c in pairs(hands) do
		if c.type == "world" then
			vcard.mask(c, true)
			have_world = true
		end
	end
	
	if have_world then
		-- at least one world card
		return choose_world(hands)
	end

	-- no world card in hand

	local c =  new_world(hands)
	hands[#hands+1] = c
	return c
end

local function set_homeworld()
	local hands = card.pile "hand"
	local homeworld = choose(hands)

	for _, c in pairs(hands) do
		if c == homeworld then
			vdesktop.transfer("hand", c, "homeworld")
			card.pickup("hand", c)
			card.putdown("homeworld", c)
			map.set_galaxy(homeworld.sector, 3, "player")
			map.settle(homeworld.sector)
		else
			vdesktop.transfer("hand", c, "deck")
			card.pickup("hand", c)
			card.putdown("discard", c)
		end
		sleep()
	end

	return homeworld
end

local function draw_hands()
	local h = {}
	local n = card.count "hand"	-- test patch may add cards
	for i = n + 1, rules.setup.draw do
		local c = card.draw_hand()
		if c == nil then
			-- in rare case, no more cards (rules.setup.draw is too large)
			break
		end
		h[i] = c
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
	return h
end

return function ()
	-- new game
	loadsave.sync_history()
	loadsave.sync_game "setup"

	vtips.set()
	test.patch "setup"
	sync()
	vdesktop.set_text("phase", {
		text = "$(phase.setup)",
		extra = false,
	})
	vdesktop.set_text("turn", {
		turn = card.turn(),
	})
	
	draw_hands()
	local homeworld = set_homeworld()
	set_neutral()
	return "start"
end
