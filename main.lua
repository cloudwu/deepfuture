local ltask = require "ltask"
local spritemgr = require "soluna.spritemgr"
local mattext = require "soluna.material.text"
local font = require "soluna.font"
local soluna = require "soluna"
--local icon = require "soluna.icon"
local text = require "soluna.text"
local widget = require "core.widget"

local initial = require "gameplay.initial"
local setup = require "gameplay.setup"
local vcard = require "visual.card"

local localization = require "core.localization"

localization.load("localization/schinese.dl", "schinese")

local args = ...
local batch = args.batch

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

vcard.init(batch, font_id, sprites)

local function set_hud(w, h)
	widget.set("hud", {
		screen = {
			width = w,
			height = h,
		}
	})
end

local callback = {}

local desktop = {}

local function setup_desktop()
	initial.new()
	desktop.hand = setup.draw_worlds()
	-- todo : choose a world
	setup.new_world()
	desktop.neutral = setup.neutral()
end

setup_desktop()

--local draw = widget.draw_list("card", card_text, font_id, sprites)

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
	return r
end

local function hex_init()
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
		local xx = - n * 72 + 288
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

local hud = {}

function hud:map()
	map(self.x, self.y)
end

hud.mark_C1 = { mark = "[star]" }
hud.mark_C13 = { mark = "[circle]" }
hud.mark_M1 = { mark = "[star]" }
hud.mark_M7 = { mark = "[circle]" }
hud.mark_M13 = { mark = "[cross]" }
hud.mark_S1 = { mark = "[star]" }
hud.mark_S7 = { mark = "[circle]" }
hud.mark_S13 = { mark = "[cross]" }
hud.mark_X1 = { mark = "[star]" }
hud.mark_X7 = { mark = "[circle]" }
hud.mark_X13 = { mark = "[cross]" }

do
	local _, _, card_w, card_h = widget.get("card", "card")

	local function calc_scale(self, n)
		local w = self.w - (n - 1) * 3
		local h = self.h
		local scale_w = 1
		local scale_h = 1
		if card_w * n > w then
			scale_w = w / (card_w * n)
		end
		if card_h > h then
			scale_h = h / card_h
		end
		return scale_w > scale_h and scale_h or scale_w
	end
	
	function hud:natural()
		local scale = calc_scale(self, 6)
		w = card_w * scale + 3
		local x = self.x
		local y = self.y
		for i = 1, #desktop.neutral do
			local c = desktop.neutral[i]
			vcard.draw(c, x, y, scale)
			x = x + w
		end
	end

	function hud:homeworld()
		local scale = calc_scale(self, 4)
		w = card_w * scale + 3
		local x = self.x
		local y = self.y
		for i = 1, 4 do
--			widget.draw(batch, draw, x, y, scale)
			x = x + w
		end
	end

	function hud:colony()
		local scale = calc_scale(self, 4)
		w = card_w * scale + 3
		local x = self.x
		local y = self.y
		for i = 1, 3 do
--			widget.draw(batch, draw, x, y, scale)
			x = x + w
		end
	end
end

set_hud(args.width, args.height)
local hud_draw_list = widget.draw_list("hud", hud, font_id, sprites)

function callback.window_resize(w,h)
	set_hud(w, h)
	hud_draw_list = widget.draw_list("hud", hud, font_id, sprites)
end

function callback.frame(count)
	widget.draw(batch, hud_draw_list)
--	local rad = count * 3.1415927 / 180
--	local scale = math.sin(rad)
--	map(50, 50)
--	widget.draw(batch, draw, x, y, 0.6)

--	batch:layer(0.5, 200, 200)
---	batch:layer(-100, -140)
--	batch:layer()
--	batch:layer()
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
