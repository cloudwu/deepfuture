local card = require "gameplay.card"
local name = require "gameplay.name"
local vcard = require "visual.card"
local rules = require "core.rules".phase
local loadsave = require "core.loadsave"
local math = math

global error

local initial = {}

function initial.new()
	-- reset save
	loadsave.init_deck()
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
		vcard.flush(world)
		card.sync(world)
		card.discard(world)
	end
	card.cleanup()
	card.next_era()
end

return initial
