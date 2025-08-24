local widget = require "core.widget"
local util = require "core.util"
local config = require "core.rules".ui

global assert

local _, _, track_w, track_h = widget.get("track", "track")
local FONT_ID
local SPRITES
local BATCH
local DRAWLIST

local track = {}

local WIDTH, HEIGHT

local content = {}

local function update(w,h)
	WIDTH = w
	HEIGHT = h
	widget.set("track", {
		track = {
			width = w,
			height = h,
		}
	})
	DRAWLIST = widget.draw_list("track", content, FONT_ID, SPRITES)
end

function track.flush()
	update(WIDTH, HEIGHT)
end

function track.set(type, index, token)
	content["mark_" .. type .. index] = { mark = token }
end

function track.draw(x,y,w,h)
	if w ~= WIDTH or h ~=HEIGHT then
		update(w,h)
	end
	BATCH:layer(x,y)
	widget.draw(BATCH, DRAWLIST)
	BATCH:layer()
end

function track.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return track
