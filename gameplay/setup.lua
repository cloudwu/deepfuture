local card = require "gameplay.card"

local setup = {}

function setup.draw_worlds()
	-- init draw pile
	card.setup()
	local r = {}
	for i = 1, 5 do
		r[i] = card.draw_hand()
	end
	return r
end

function setup.choose_world(card)
	card.pickup("hand", card)
	card.putdown("homeworld", card)
	card.drophand()
end

function setup.new_world()
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

	card.putdown("homeworld", world)
	card.drophand()
	return world, card1, card2, card3, card4
end

function setup.neutral()
	-- todo : add cubes
	local tmp = {}
	local r = {}
	while true do
		local world = card.draw_type "world"
		if world == nil then
			-- no more worlds
			break
		end
		if tmp[world.value] then
			card.discard(world)
			return r
		else
			tmp[world.value] = true
			r[#r+1] = world
			card.putdown("neutral", world)
		end
	end
	return r
end

return setup