local rules = require "core.rules".advancement

local advancement = {}

function advancement.find(suit, value)
	for k,v in pairs(rules) do
		if v.suit == suit and v.value == value then
			return v, k
		end
	end
end

return advancement
