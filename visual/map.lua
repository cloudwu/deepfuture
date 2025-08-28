local widget = require "core.widget"
local mask = require "soluna.material.mask"
local config = require "core.rules".ui
local map = {}
local table = table

global pairs, tostring, ipairs, assert, print_r, error

local FONT_ID
local SPRITES
local BATCH

-- size is the outer circle's radius
-- See f https://www.redblobgames.com/grids/hexagons/
local HEX_SIZE = config.map.size

local focus_color <const> = config.map.focus_color
local token <const> = config.map.token
local tokens_width <const> = config.map.tokens_width
local SECTOR_TO_AXIAL <const> = {
	[11] = 30, [12] = 40, [13] = 50, [14] = 31, [15] = 41, [16] = 32,
	[21] = 60, [22] = 61, [23] = 62, [24] = 51, [25] = 52, [26] = 42,
	[31] = 63, [32] = 54, [33] = 45, [34] = 53, [35] = 44, [36] = 43,
	[41] = 36, [42] = 26, [43] = 16, [44] = 35, [45] = 25, [46] = 34,
	[51] = 06, [52] = 05, [53] = 04, [54] = 15, [55] = 14, [56] = 24,
	[61] = 03, [62] = 12, [63] = 21, [64] = 13, [65] = 22, [66] = 23,
	[0] = 33,
}

local AXIAL_TO_SECTOR <const> = (function()
	local result = {}
	for sector,v in pairs(SECTOR_TO_AXIAL) do
		local q = v // 10
		local r = v % 10
		local coord = q << 3 | r
		result[coord] = sector
		SECTOR_TO_AXIAL[sector] = coord
	end
	return result
end)()

local neighbors <const> = {
	{ 1, 0 }, { 1, -1 }, { 0 , -1},
	{-1, 0 }, {-1,  1 }, { 0 ,  1},
}
local function neighbor_sector(coord, n)
	local q = coord >> 3
	local r = coord & 7
	q = q + n[1]
	r = r + n[2]
	coord = q << 3 | r
	return AXIAL_TO_SECTOR[coord]
end

function map.neighbors(sector)
	local coord = SECTOR_TO_AXIAL[sector] or error ("Invalid sector " .. sector)
	local result = {}
	for _, n in ipairs(neighbors) do
		local s = neighbor_sector(coord, n)
		if s then
			result[s] = true
		end
	end
	return result
end

local hex_drawlist = {}
local hex_people = {}

local function people_icons(color, n)
	local r =  color
	if n <= tokens_width then
		r = r .. (token:rep(n))
	else
		local line1 = n // 2
		local line2 = n - line1
		r = r .. (token:rep(line1)) .. "\n" .. (token:rep(line2))
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
	for sector in pairs(SECTOR_TO_AXIAL) do
		if sector ~= 0 then
			local p = hex_people[sector]
			if p then
				hex_text.content = {
					people = people_icons(table.unpack(p))
				}
			else
				hex_text.content = nil
			end
			hex_text.id = sector
			hex_drawlist[sector] = widget.draw_list("hex", hex_text, FONT_ID, SPRITES)
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

local HEX_HORIZ <const> = HEX_SIZE * 3 / 2
local HEX_VERT <const> = HEX_SIZE * 3 ^ 0.5 / 2

function map.draw(x, y)
	y = y - 3 * HEX_VERT
	BATCH:layer(x,y)
	for sector, coord in pairs(SECTOR_TO_AXIAL) do
		local q = coord >> 3
		local r = coord & 7
		
		local x = HEX_HORIZ * r 
		local y = HEX_VERT * ((q << 1) + r)
		
		if sector == 0 then
			BATCH:add(SPRITES.hex, x, y)
			BATCH:add(SPRITES.core, x, y)
		else
			BATCH:layer(x,y)
			widget.draw(BATCH, hex_drawlist[sector])
			if sector == focus.sector then
				local c = update_focus_color()
				if c then
					BATCH:add(mask.mask(SPRITES.hex, c))
				end
			end
			BATCH:layer()
		end
	end
	BATCH:layer()
end

function map.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return map