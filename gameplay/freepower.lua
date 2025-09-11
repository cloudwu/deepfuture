local power = require "gameplay.power"
local flow = require "core.flow"

return function()
	power ("$(FREEACTION)", "freepower")
	return flow.state.freeadvance
end