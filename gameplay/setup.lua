local card = require "gameplay.card"
local name = require "gameplay.name"
local focus = require "core.focus"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips".layer "hud"
local vcard = require "visual.card"
local map = require "gameplay.map"
local rules = require "core.rules".phase

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

local function wait_for_moving(moving)
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

local function set_neutral(homeworld)
	local sec = homeworld.sector
	local tmp = {}
	local moving = {}
	for i = 1, card.count "draw" + card.count "discard" do
		local c = draw_card()
		if c == nil then
			break
		end
		if c.type ~= "world" or c.sector == sec or tmp[c.value] then
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
	
	wait_for_moving(moving)
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

local function clone_card(from, to)
	for k,v in pairs(from) do
		to[k] = v
	end
	return to
end

local function new_world(hands)
	local focus_state = {}
	
	repeat
		if focus.get(focus_state) and focus_state.active == "hand" then
			vtips.set("tips.setup.newworld")
		elseif focus_state.lost == "hand" then
			vtips.set()
		end
		flow.sleep(0)
	until focus.click ("left", "hand")
	clear_mask(hands)
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
	
	-- clone from blank
	local clone = clone_card(newcard, {})
	clone.sector = ""
	clone._marker = ""
	clone.adv1 = clone_card(newcard.adv1, {})
	clone.adv1._suit = ""
	clone.adv1._stage = ""
	clone.adv1._name = ""
	clone.adv1._desc = ""
	
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
		clone._marker = tostring(clone.value)-- .. "$(suit." .. obj.suit .. ")"
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
	
	for _, c in pairs(hands) do
		vcard.mask(c, true)
	end
	
	local c =  new_world(hands)
	hands[#hands+1] = c
	return c
end

local function set_homeworld(hands)
	local homeworld = choose(hands)

	local moving = {}
	for _, c in pairs(hands) do
		if c == homeworld then
			vdesktop.transfer("hand", c, "homeworld")
			card.pickup("hand", c)
			card.putdown("homeworld", c)
			map.add_player(homeworld.sector, 3)
			moving[c] = "homeworld"
		else
			vdesktop.transfer("hand", c, "deck")
			card.pickup("hand", c)
			card.putdown("discard", c)
			moving[c] = "deck"
		end
		sleep()
	end
	
	wait_for_moving(moving)

	return homeworld
end

local function no_world_card(c)
	while c.type == "world" do
		card.pickup("hand", c)
		card.discard(c)
		c = card.draw_hand()
	end
	return c
end

local function draw_hands()
	local h = {}
	for i = 1, rules.setup.draw do
		local c = card.draw_hand()
		if rules.setup.no_worlds then
			c = no_world_card(c)
		end
		h[i] = c
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
	return h
end

return function ()
	vdesktop.set_text("phase", "$(phase.setup)")
	card.setup()
	local hands = draw_hands()
	local homeworld = set_homeworld(hands)
	set_neutral( homeworld )
	return "start"
end
