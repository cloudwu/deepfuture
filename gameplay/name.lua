local name = {}

global assert

function name.world(card)
	assert(card.type == "world")
	card.name = "WORLD"
end

function name.tech(card)
	assert(card.type == "tech")
	card.name = "NONAME"
end

return name