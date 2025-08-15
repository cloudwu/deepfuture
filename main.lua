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
local card = require "gameplay.card"
local vcard = require "visual.card"
local vmap = require "visual.map"

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
vmap.init(batch, font_id, sprites)

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

local function draw_hand(n)
	local r = {}
	for i = 1, n do
		r[#r+1] = card.draw_hand()
	end
	return r
end

local function set_neutral(card)
	local sec = card.sector
	local hex = desktop.map[sec]
	if hex == nil then
		hex = { "black", 0 }
		desktop.map[sec] = hex
	end
	local n = hex[2] + 3
	if n > 5 then
		n = 5
	end
	hex[2] = n
end

local function setup_desktop()
	initial.new()
	desktop.hand = setup.draw_worlds()
	-- todo : choose a world
	desktop.homeworld = { (setup.new_world()) }
	desktop.neutral = setup.neutral(desktop.homeworld[1])
	desktop.colony = {}
	desktop.hand = draw_hand(5)
	local map = {}
	desktop.map = map
	for _, card in ipairs(desktop.neutral) do
		set_neutral(card)
	end
	map[desktop.homeworld[1].sector] = { "blue", 3 }
end

setup_desktop()

local function hex_init()
	for k,v in pairs(desktop.map) do
		vmap.set(k, v[1], v[2])
	end
	vmap.update()
end

hex_init()

local hud = {}

function hud:map()
	vmap.draw(self.x, self.y)
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
	local _, _, card_w, card_h = widget.get("blankcard", "card")

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
		local w = card_w * scale + 3
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
		local w = card_w * scale + 3
		local x = self.x
		local y = self.y
		local n = #desktop.homeworld
		if n > 4 then
			w = (self.w - card_w * scale) / (n-1)
		end
		for i = 1, n do
			local c = desktop.homeworld[i]
			vcard.draw(c, x, y, scale)
			x = x + w
		end
	end

	function hud:colony()
		local scale = calc_scale(self, 4)
		local w = card_w * scale + 3
		local x = self.x
		local y = self.y
		local n = #desktop.colony
		if n > 4 then
			w = (self.w - card_w * scale) / (n-1)
		end
		for i = 1, n do
			local c = desktop.colony[i]
			vcard.draw(c, x, y, scale)
			x = x + w
		end
	end
	
	function hud:hand()
		local n = #desktop.hand
		local x = self.x
		local y = self.y
		if n == 0 then
			return
		end
		local w = card_w * n + 3 * (n - 1)
		local offx
		if w > self.w then
			offx = (self.w - card_w) / (n - 1)
			w = self.w
		else
			offx = card_w + 3
		end
		local x = x + (self.w - w) / 2
		for i = 1, n do
			local c = desktop.hand[i]
			vcard.draw(c, x, y, 1)
			x = x + offx
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
