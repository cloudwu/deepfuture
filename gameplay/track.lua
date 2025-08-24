local persist = require "gameplay.persist"
local vtrack = require "visual.track"
local rules = require "core.rules".track
local ui = require "core.rules".ui.track
local util = require "core.util"

global pairs

local track = {}

local TRACK

local update = util.dirty_update(function()
	for k,v in pairs(TRACK) do
		local r = rules[k]
		if r.win then
			vtrack.set(k, r.win, ui.win)
		end
		if r.loss then
			vtrack.set(k, r.loss, ui.loss)
		end
		vtrack.set(k, v, ui.token)
	end
	vtrack.flush()
end)

function track.setup()
	local t = {}
	for key, v in pairs(rules) do
		t[key] = v.init
	end
	TRACK = t
	update()
end

return track
