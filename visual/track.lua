local widget = require "core.widget"
local util = require "core.util"
local mattext = require "soluna.material.text"
local font = require "soluna.font"
local config = require "core.rules".ui
local grid = require "core.rules".track
local textconv = require "soluna.text"
local color = require "visual.color"
local math = math
local sin = math.sin

global assert, pairs, print

local _, _, track_w, track_h = widget.get("track", "track")
local FONT_ID
local SPRITES
local BATCH
local DRAWLIST
local MOVE_SPEED <const> = config.track.speed
local MOVE_FACTOR <const> = math.pi / (2 * MOVE_SPEED)
local MOVE_TOKEN <const> = config.track.token
local COLOR <const> = color.blend(config.track.color, config.track.focus_color)
local DURATION <const> = config.track.focus_duration

local move = {}

local track = {}

local WIDTH, HEIGHT

local content = {}

local coord = {}

local function update_coord()
	for name, minmax in pairs(grid) do
		local row = {}
		coord[name] = row
		for i = minmax.min , minmax.max do
			local id = "mark_" .. name .. i
			local x, y, w, h = widget.get("track", id)
			row[i] = {
				x = x,
				y = y,
				w = w,
				h = h,
			}
		end
	end
end

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

local function update_token(type, obj)
	local rect = coord[type][obj.index]
	if rect.w ~= obj.w or rect.h ~= obj.h or obj.text == nil then
		obj.w = rect.w
		obj.h = rect.h
		local func = mattext.block(font.cobj(), FONT_ID, config.size, config.color, "CV")
		obj.text = func( textconv.convert[MOVE_TOKEN], obj.w, obj.h)
	end
	local f = obj.focus
	if f then
		f = f + 1
		if f > DURATION * 2 then
			f = 1
		end
		obj.focus = f
		if f > DURATION then
			f = DURATION * 2 - f
		end
		local color = COLOR(f)
		local func = mattext.block(font.cobj(), FONT_ID, config.size, color, "CV")
		obj.text = func( textconv.convert[MOVE_TOKEN], obj.w, obj.h)
		if obj.fade and obj.focus == DURATION * 2 then
			obj.fade = nil
			obj.focus = nil
		end
	end
end

function track.move(type, index, focus)
	local obj = move[type]
	if obj == nil then
		obj = {}
		move[type] = obj
	end
	if obj.index and obj.index ~= index then
		obj.last_index = obj.index
		obj.index = index
		obj.time = MOVE_SPEED
		obj.reset = true
	else
		obj.index = index
	end
	if obj.focus then
		if not focus then
			obj.fade = true
		else
			obj.fade = nil
		end
	elseif focus then
		obj.focus = 0
		obj.fade = nil
	end
end

local function calc_pos(pos, obj, type)
	local time = obj.time
	if not time then
		return pos.x, pos.y
	end
	time = time - 1
	if time == 0 then
		obj.time = nil
		obj.x = nil
		obj.y = nil
		return pos.x, pos.y
	else
		obj.time = time
	end
	if obj.reset then
		obj.reset = nil
		if obj.x == nil then
			local last = coord[type][obj.last_index]
			obj.last_x = last.x
			obj.last_y = last.y
		else
			obj.last_x = obj.x
			obj.last_y = obj.y
		end
	end
	local f = sin(time * MOVE_FACTOR)
	local x = obj.last_x * f + pos.x * (1-f)
	local y = obj.last_y * f + pos.y * (1-f)
	obj.x = x
	obj.y = y
	return x, y
end

local function draw_move_tokens()
	for type, token in pairs(move) do
		update_token(type, token)
		local pos = coord[type][token.index]
		local x, y = calc_pos(pos, token, type)
		BATCH:add(token.text, x, y)
	end
end

function track.draw(x,y,w,h)
	if w ~= WIDTH or h ~=HEIGHT then
		update(w,h)
		update_coord()
	end
	BATCH:layer(x,y)
	widget.draw(BATCH, DRAWLIST)
	draw_move_tokens()
	BATCH:layer()
end

function track.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return track
