local card = require "gameplay.card"
local name = require "gameplay.name"
local rules = require "core.rules".phase
local math = math

global error

local initial = {}

local function random_adv_value(c)
	local r = math.random(3)
	local index = "adv"..r
	local value = rules.init.set or card.draw_discard().value
	card.add_adv_value(c, index, value, 0)
end

local function gen_random_adv(n)
	for i = 1, n do
		local c = card.draw_discard()
		if c.type == "blank" then
			c.type = "tech"
			c.name = ""
			local advsuit1 = card.draw_discard()
			local advsuit2 = card.draw_discard()
			local advsuit3 = card.draw_discard()
			card.add_adv_suit(c, advsuit1.suit)
			card.add_adv_suit(c, advsuit2.suit)
			card.add_adv_suit(c, advsuit3.suit)
			random_adv_value(c)
		end
		if c.type == "world" then
			local advsuit = card.draw_discard()
			local index = card.add_adv_suit(c, advsuit.suit)
			if index then
				local value = rules.init.set or card.draw_discard().value
				card.add_adv_value(c, index, value, 0)
			end
		elseif c.type == "tech" then
			random_adv_value(c)
			if c.adv1.value and c.adv2.value and c.adv3.value then
				c.name = "NONAME"
			end
		end
	end
end

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
	if rules.init.random then
		gen_random_adv(rules.init.random)
	end
	card.cleanup()
	card.nextera()
end

function initial.load(filename)
	error "todo"
end

return initial
