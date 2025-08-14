local name = {}

function name.world(card)
	assert(card.type == "world")
	card.name = "WORLD"
end

return name