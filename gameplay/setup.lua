local card = require "gameplay.card"
local name = require "gameplay.name"
local focus = require "core.focus"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips"
local map = require "gameplay.map"

local function new_world()
	local world, card1, card2 = card.generate_newcard()
	
	-- todo: for multiple players, check sector
	local card3 = card.draw_discard()
	local card4 = card.draw_discard()
	local sector = card3.value * 10 + card4.value

	local advsuit = card.draw_discard()
	local advtype = card.draw_discard()

	world.type = "world"
	world.sector = sector

	world.adv1 = {
		suit = advsuit.suit,
		value = advtype.value,
		era = world.era,
	}
	card.gen_desc(world)
	name.world(world)

	card.putdown("homeworld", world)
	card.drophand()
	return world, card1, card2, card3, card4
end

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
	local n1, n2 = card.count()
	local tmp = {}
	local moving = {}
	for i = 1, n1 + n2 do
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

local function choose_world()
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
		homeworld = focus.click ("left", "hand")
		flow.sleep(0)
	until homeworld
	vtips.set()
	return homeworld
end

local function set_homeworld(hands)
	local homeworld = choose_world()
--	local homeworld = new_world()

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

local function draw_worlds()
	local h = {}
	for i = 1, 5 do
		local c = card.draw_hand()
		h[i] = c
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
	return h
end

--[[
local function draw_hands()
	for i = 1, 5 do
		local c = card.draw_hand()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
end
]]

return function ()
	card.setup()
	local hands = draw_worlds()
	local homeworld = set_homeworld(hands)
	set_neutral( homeworld )
	-- todo : to game
--	draw_hands()
	return "player"
end
