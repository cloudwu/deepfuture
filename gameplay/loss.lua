local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local focus = require "core.focus"
local card = require "gameplay.card"

return function(reason)
	vdesktop.set_text("phase", {
		text = "$(phase.end)",
		extra = "$(tips.end."..reason..")"
	})
	local button = {
		text = "button.restart",
	}	
	vdesktop.button_enable("button1", button)
	while true do
		local c , btn = focus.click "left"
		if btn == "button1" then
			break
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	card.next_turn()
	vdesktop.set_text("phase", { extra = false })
	return "setup"
end