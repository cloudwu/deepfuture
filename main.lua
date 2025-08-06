local ltask = require "ltask"
local spritemgr = require "soluna.spritemgr"
local mattext = require "soluna.material.text"
local font = require "soluna.font"
local soluna = require "soluna"
--local icon = require "soluna.icon"
local layout = require "soluna.layout"
local text = require "soluna.text"
local widget = require "core.widget"

local batch = ...

soluna.set_window_title "Deep Future"

local function font_init()
	local sysfont = require "soluna.font.system"
	font.import(assert(sysfont.ttfdata "微软雅黑"))
	text.init "asset/icons.dl"
	return font.name ""
end

local loader = ltask.uniqueservice "loader"
local sprites = ltask.call(loader, "loadbundle", "asset/sprites.dl")
local render = ltask.uniqueservice "render"
ltask.call(render, "load_sprites", "asset/sprites.dl")
local font_id = font_init()

local callback = {}

local card_text = {
	["card.corner"] = "1[sun]",
	["card.world"] = "55 一个名字很长的星球",
	["card.title"] = "0. [planet]星球",
	["card.adv1"] = "[moon] 工程.0",
	["card.desc1"] = "[blue][[发展] [n]M+1",
	["card.adv2"] = "[moon] 艺术.1",
	["card.desc2"] = "[blue][[开始] [n]C+1",
	["card.adv3"] = "[heart] 医学.1",
	["card.desc3"] = "[0000FF][[殖民] [n]S+1",
}

for k,v in pairs(card_text) do
	card_text[k] = text.convert[v]
end

local draw = widget.draw_list("card", card_text, font_id, sprites)

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

local hex_people = {
	[63] = { "008000", 5 },
	[16] = { "black", 3 },
	[31] = { "red", 4 },
	[41] = { "blue", 2 },
	[25] = { "808000", 1 },
}

local function people_icons(color, n)
	local r = "["..color.."]"
	if n <= 3 then
		r = r .. ("[people]"):rep(n)
	else
		r = r .. "[people][people]\n" .. ("[people]"):rep(n-2)
	end
	return text.convert[r]
end

local function hex_init()
	local hex_text = {}
	for _, v in pairs(hex_id) do
		for k, content in pairs(v) do
			local p = hex_people[content]
			if p then
				hex_text["hex.people"] = people_icons(table.unpack(p))
			else
				hex_text["hex.people"] = nil
			end
			hex_text["hex.id"] = text.convert["[gray]".. tostring(content)]
			v[k] = widget.draw_list("hex", hex_text, font_id, sprites)
		end
	end
end

hex_init()

local function map(x, y)
	batch:layer(x,y)
	y = 0
	for i = 1, #lines do
		local n = lines[i]
		local xx = - n * 72
		for j = 1, n do
			local list = hex_id[i][j]
			if list then
				for _, obj in ipairs(list) do
					local o, dx, dy = table.unpack(obj)
					batch:add(o, dx + xx, dy + y)
				end
			else
				batch:add(sprites.hex, xx, y)
				batch:add(sprites.core, xx, y)
			end
			xx = xx + 144
		end
		y = y + 42
	end
	batch:layer()
end

function callback.frame(count)
	local rad = count * 3.1415927 / 180
	local scale = math.sin(rad)
	batch:layer(0.5, rad, 200, 200)
	batch:layer(-100, -140)
	for _, obj in ipairs(draw) do
		local o, x, y = table.unpack(obj)
		batch:add(o, x, y)
	end
	batch:layer()
	batch:layer()
	map(600, 100)
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
