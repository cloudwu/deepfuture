local widget = require "core.widget"
local mask = require "soluna.material.mask"
local config = require "core.rules".ui

local map = {}
local table = table

global pairs, tostring, ipairs, assert

local FONT_ID
local SPRITES
local BATCH

local focus_color <const> = config.map.focus_color
local lines = { 1, 2, 3, 4, 3, 4, 3, 4, 3, 4, 3, 2, 1 }
local hex_id = {
	{ 11 },
	{ 63, 12 },
	{ 62, 14, 13 },
	{ 61, 65, 15, 21 },
	{ 64, 16, 24 },
	{ 53, 66, 26, 22 },
	{ 55, nil, 25 },
	{ 52, 56, 36, 23 },
	{ 54, 46, 34 },
	{ 51, 45, 35, 31 },
	{ 43, 44, 32 },
	{ 42, 33 },
	{ 41 },
}
local hex_drawlist = {}

local hex_people = {}

local function people_icons(color, n)
	local r =  color
	if n <= 3 then
		r = r .. ("[people]"):rep(n)
	else
		r = r .. "[people][people]\n" .. ("[people]"):rep(n-2)
	end
	return r
end

function map.set(sector, color, n)
	if not color then
		hex_people[sector] = nil
	else
		hex_people[sector] = {color, n}
	end
end

local focus = {
	sector = nil,
	time = 0,
}

function map.focus(sector)
	if focus.sector ~= sector then
		focus.sector = sector
		focus.time = 60
	end
end

function map.update()
	local hex_text = {}
	for _, v in pairs(hex_id) do
		for k, content in pairs(v) do
			local p = hex_people[content]
			if p then
				hex_text.content = {
					people = people_icons(table.unpack(p))
				}
			else
				hex_text.content = nil
			end
			hex_text.id = tostring(content)
			hex_drawlist[content] = widget.draw_list("hex", hex_text, FONT_ID, SPRITES)
		end
	end
end

local function update_focus_color()
	if focus.sector then
		local t = focus.time
		focus.time = t - 1
		if t == 0 then
			focus.sector = nil
		else
			return t << 24 | focus_color
		end
	end
end

function map.draw(x, y)
	BATCH:layer(x,y)
	y = 0
	for i = 1, #lines do
		local n = lines[i]
		local xx = - n * 72 + 288
		for j = 1, n do
			local id = hex_id[i][j]
			if id then
				local list = hex_drawlist[id]
				for _, obj in ipairs(list) do
					local o, dx, dy = table.unpack(obj)
					BATCH:add(o, dx + xx, dy + y)
				end
				if id == focus.sector then
					local c = update_focus_color()
					if c then
						BATCH:add(mask.mask(SPRITES.hex, c), xx, y)
					end
				end
			else
				BATCH:add(SPRITES.hex, xx, y)
				BATCH:add(SPRITES.core, xx, y)
			end
			xx = xx + 144
		end
		y = y + 42
	end
	BATCH:layer()
end

function map.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return map