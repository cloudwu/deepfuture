local power = require "gameplay.power"

return function()
	power ("$(FREEACTION)", "freepower")
	return "freeadvance"
end