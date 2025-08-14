local card = require "gameplay.card"
local name = require "gameplay.name"

local initial = {}

function initial.new()
	-- init 36 initial cards
	card.init_deck()
	-- init draw pile
	card.setup()
	for i = 1, 12 do
		local world = card.draw_type "blank" or "No blank card"
		local card1 = card.draw_discard()
		local card2 = card.draw_discard()
		local sector = card1.value * 10 + card2.value
		world.type = "world"
		world.sector = sector
		name.world(world)
	end
	card.cleanup()
end

function initial.load(filename)
	error "todo"
end

return initial
