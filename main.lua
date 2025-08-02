local ltask = require "ltask"
local spritemgr = require "soluna.spritemgr"
local mattext = require "soluna.material.text"
local font = require "soluna.font"
local soluna = require "soluna"
local icon = require "soluna.icon"
local layout = require "soluna.layout"

local batch = ...

local function font_init()
	local sysfont = require "soluna.font.system"
	font.import(assert(sysfont.ttfdata "微软雅黑"))
	font.import_icon(icon.bundle "asset/icons.dl")
	return font.name ""
end

local loader = ltask.uniqueservice "loader"
local sprites = ltask.call(loader, "loadbundle", "asset/sprites.dl")
local render = ltask.uniqueservice "render"
ltask.call(render, "load_sprites", "asset/sprites.dl")
local font_id = font_init()

local callback = {}

local function text(c, color)
	local cp = utf8.codepoint(c)
	return mattext.char(cp, font_id, 24, color)
end

local icons = { "sun", "moon", "heart", "skull", "hand", "foot" }

local fontcobj = font.cobj()
-- local block = mattext.block(fontcobj, font_id, 16)
-- local label = block ("这[FF0000]是[800000]五[400000]个[n]字[i0] [00FF00]你好[n]世界")

local dom = layout.load "asset/card.dl"

local text = {
	["card.corner"] = "1[i0]",
	["card.world"] = "55 广州",
	["card.title"] = "0. 星球",
	["card.adv1"] = "[i0] 工程.0",
	["card.desc1"] = "[0000FF][[发展] [n]M+1",
	["card.adv2"] = "[i1] 艺术.1",
	["card.desc2"] = "[0000FF][[开始] [n]C+1",
	["card.adv3"] = "[i2] 医学.1",
	["card.desc3"] = "[0000FF][[殖民] [n]S+1",
}

local function draw_list(dom)
	local pos = layout.calc(dom)
	for _, obj in ipairs(pos) do
		if obj.image then
			obj.command = { sprites[obj.image], obj.x, obj.y }
		elseif obj.text then
			local block = mattext.block(fontcobj, font_id, obj.size or 16, obj.color or 0, obj.align)
			local label = block(text[obj.text], obj.w, obj.h)
			obj.command = { label, obj.x, obj.y }
		end
	end
	return pos
end

local draw = draw_list(dom)

local offx = 100
local offy = 100

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

local function hex_init()
	local number = mattext.block(fontcobj, font_id, 12, 0x808080)
	for _, v in pairs(hex_id) do
		for k, content in pairs(v) do
			v[k] = number(tostring(content), 30, 20)
		end
	end
end

hex_init()

local function map(x, y)
	local id = sprites.hex 
	for i = 1, #lines do
		local n = lines[i]
		local xx = x - n * 72
		for j = 1, n do
			batch:add(id, xx, y)
			local label = hex_id[i][j]
			if label then
				batch:add(label, xx + 26 , y + 5)
			else
				batch:add(sprites.core, xx, y)
			end
			xx = xx + 144
		end
		y = y + 42
	end
	
end

function callback.frame(count)
	local rad = count * 3.1415927 / 180
	local scale = math.sin(rad)
	for _, obj in ipairs(draw) do
		local o, x, y = table.unpack(obj.command)
		batch:add(o, x + offx, y + offy)
	end
	map(600, 100)
--	batch:add(sprites.cardface, 256, 200)
--	if soluna.gamepad.A then
--		batch:add(text ("你", 0xff0000), 20, 100)
--		batch:add(text ("好", 0x0000ff), 50, 100)
--		batch:add(label, 200, 200)
--		for i, name in ipairs(icons) do
--			batch:add(icon.symbol(name, 18, 0xff0000), 50 + i * 25, 100)
--		end
--	end
--	batch:add(sprites.avatar, 256, 400, scale + 1.2, -rad)
--	batch:add(sprites.avatar, 256, 600, - scale + 1.2, rad)
end

--local sdf = require "soluna.image.sdf"
--local file = require "soluna.file"
--local data = file.load "asset/star.png" 
--local oimg = assert(sdf.load(data))
--sdf.save("sdfstar.png", oimg)

return callback
