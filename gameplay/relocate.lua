local vtips = require "visual.tips".layer "hud"
local card = require "gameplay.card"
local flow = require "core.flow"
local vcard = require "visual.card"
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"

return function()
	vtips.set()
	local colony = card.pile "colony"
	if #colony == 0 then
		return
	end
	for _, c in ipairs(colony) do
		vcard.mask(c, true)
	end
	local focus_state = {}
	local new_homeworld
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "colony" then
				vtips.set "tips.homeworld.set"
			else
				vtips.set "tips.homeworld.invalid"
			end
		elseif not focus_state.object then
			vtips.set()
		end
		local sec, region = mouse.click(focus_state, "left")
		if sec and region == "colony" then
			new_homeworld = card.pickup("colony", sec)
			break
		end
		flow.sleep(0)
	end
	for _, c in ipairs(colony) do
		vcard.mask(c)
	end
	card.putdown("homeworld", new_homeworld)
	vdesktop.transfer("colony", new_homeworld, "homeworld")
	vtips.set()
	flow.sleep(5)
	return true
end
