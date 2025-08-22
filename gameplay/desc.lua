--local card = require "gameplay.card"
local flow = require "core.flow"
--local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips"

return function (from, args)
	vdesktop.describe(true)
	flow.sleep(100)
	vdesktop.describe(false)
	return from
end
