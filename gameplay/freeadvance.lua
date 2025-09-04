local advance = require "gameplay.advance"

return function()
	return advance ("$(FREEACTION)", "freeadvance")
end