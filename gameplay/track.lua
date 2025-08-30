local persist = require "gameplay.persist"
local vtrack = require "visual.track"
local rules = require "core.rules".track
local ui = require "core.rules".ui.track
local util = require "core.util"

global pairs, error, print

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
		vtrack.move(k, v)
	end
	vtrack.flush()
end)

function track.focus(type, enable)
	if type == true then
		for key in pairs(TRACK) do
			vtrack.move(key, TRACK[key], true)
		end
	elseif not type then
		-- unfocus
		for key in pairs(TRACK) do
			vtrack.move(key, TRACK[key])
		end
	else
		vtrack.move(type, TRACK[type], enable)
	end
end

function track.check(type, diff)
	local pos = TRACK[type] or error ("Invalid track type " .. type)
	if diff > 0 then
		return pos > rules[type].min
	else
		if rules[type].loss then
			return pos - diff >= rules[type].loss
		else
			return pos - diff > rules[type].max
		end
	end
end

function track.advance(type, n)
	local pos = TRACK[type] or error ("Invalid track type " .. type)
	local min = rules[type].min
	if pos == min then
		return
	end
	pos = pos - n
	if pos <  min then
		pos = min
	end
	TRACK[type] = pos
	vtrack.move(type, pos)
end

function track.use(type, n)
	local pos = TRACK[type] or error ("Invalid track type " .. type)
	local max = rules[type].max
	if pos == max then
		return
	end
	pos = pos + n or 1
	if pos > max then
		pos = max
	end
	TRACK[type] = pos
	vtrack.move(type, pos)
end

function track.setup()
	local t = {}
	for key, v in pairs(rules) do
		t[key] = v.init
	end
	TRACK = persist.init("track", t)
	update()
end

return track
