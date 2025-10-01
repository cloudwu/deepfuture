local language = require "core.language"
local name = {}

global assert, type, ipairs, print

local names = {}

function name.reset(deck)
	names.world = {}
	names.tech = {}
	names.civ = {}
	names.sector = {}
	if deck == nil then
		return
	end
	for _, c in ipairs(deck) do
		local set = names[c.type]
		if set and c.name then
			set[c.name] = true
		end
	end
end

function name.world(card)
	assert(card.type == "world")
	repeat
		card.name = language.random_world_name()
	until not names.world[card.name]
end

function name.tech(card)
	assert(card.type == "tech")
	card.name = "TECH" .. card._id
end

function name.civ(card)
	assert(card.type == "civ")
	repeat
		card.name = language.random_civ_name()
	until not names.civ[card.name]
end

function name.sector(sec)
	assert(type(sec) == "number")
	return language.random_sector_name()
end

return name