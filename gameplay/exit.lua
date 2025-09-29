local soluna_app = require "soluna.app"
local flow = require "core.flow"

return function()
	soluna_app.quit()
	return flow.state.idle
end