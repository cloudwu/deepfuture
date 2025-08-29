local vdesktop = require "visual.desktop"
local flow = require "core.flow"

global pairs, print, ipairs, print_r, error

return function ()
	vdesktop.set_text("phase", "$(phase.payment)")
	while true do
		flow.sleep(0)
	end
	
	return "idle"
end
