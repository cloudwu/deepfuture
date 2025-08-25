local card = require "gameplay.card"
local name = require "gameplay.name"
local rules = require "core.rules".phase
local math = math

global error

local initial = {}

function initial.new()
	-- init 36 initial cards
	card.init_deck()
	-- init draw pile
	card.setup()
	for i = 1, rules.init.worlds do
		local world = card.draw_type "blank" or "No blank card"
		local card1 = card.draw_discard()
		local card2 = card.draw_discard()
		local sector = card1.value * 10 + card2.value
		local advsuit = card.draw_discard()
		local advtype = card.draw_discard()
		world.type = "world"
		world.sector = sector
		local index = card.add_adv_suit(world, advsuit.suit)
		card.add_adv_value(world, index, advtype.value, 0)
		name.world(world)
		card.discard(world)
	end
	card.cleanup()
	card.nextera()
end

function initial.load(filename)
	error "todo"
end

return initial
