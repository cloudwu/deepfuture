local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips"

return function (from, args)
	vdesktop.describe(true)
	vtips.set "tips.desc.return"
	while true do
		if focus.click "right" or focus.click "left" then
			break
		end
		flow.sleep(0)
	end
	vdesktop.describe(false)
	vtips.set()
	return from
end
