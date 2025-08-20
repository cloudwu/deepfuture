local card = require "gameplay.card"
local name = require "gameplay.name"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
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

local function set_homeworld()
	local homeworld = new_world()
	vdesktop.add("deck", homeworld)
	vdesktop.transfer("deck", homeworld, "homeworld")
	map.add_player(homeworld.sector, 3)
	sleep()
	return homeworld
end

local function draw_worlds()
	-- todo : config draw cards
	for i = 1, 5 do
		local c = card.draw_hand()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
end

return function ()
	card.setup()
	draw_worlds()
	local homeworld = set_homeworld()
	set_neutral( homeworld )
	return "idle"
end
