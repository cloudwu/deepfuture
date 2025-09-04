local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local focus = require "core.focus"
local card = require "gameplay.card"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local track = require "gameplay.track"

return function()
	loadsave.sync_game "loss"
	sync()
	
	local reason
	local homeworld = card.card("homeworld", 1)
	if not homeworld or homeworld.type ~= "world" then
		reason = "homeworld"
	else
		reason = track.loss()
	end
	
	reason = reason or "unknown"
	
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
	
	clear "hand"
	clear "homeworld"
	clear "colony"
	clear "neutral"
	card.setup()
	track.setup()
	map.setup()
	
	return "setup"
end