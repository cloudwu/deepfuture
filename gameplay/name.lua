local name = {}

global assert, type

function name.world(card)
	assert(card.type == "world")
	card.name = "WORLD"
end

function name.tech(card)
	assert(card.type == "tech")
	card.name = "TECH"
end

function name.civ(card)
	assert(card.type == "civ")
	card.name = "CIV"
end

function name.sector(sec)
	assert(type(sec) == "number")
	return "NOWHERE"
end

return name