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
local vregion = require "visual.region"

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

local region = {
	neutral = vregion(),
	homeworld = vregion(),
	colony = vregion(),
	hand = vregion(),
}

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
	for what,r in pairs(region) do
		local cards = desktop[what]
		for i = 1, #cards do
			r:add(cards[i])
		end
	end
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
	vmap.draw(self.x + self.w - 532, self.y)
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
	
	local function draw_region(self, what, n)
		if region[what]:update(self.w, self.h) then
			local scale = calc_scale(self, n)
			local offx = card_w * scale + 3
			local x = 0
			for _, obj in ipairs(region[what]) do
				obj.x = x
				obj.scale = scale
				x = x + offx
			end
		end
		region[what]:draw(self.x, self.y)
	end
	
	function hud:neutral()
		draw_region(self, "neutral",6)
	end

	function hud:homeworld()
		draw_region(self, "homeworld",4)
	end

	function hud:colony()
		draw_region(self, "colony",4)
	end
	
	function hud:hand()
		if region.hand:update(self.w, self.h) then
			local n = #desktop.hand
			local x = 0
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
			for _, obj in ipairs(region.hand) do
				obj.x = x
				obj.scale = 1
				x = x + offx
			end
		end

		region.hand:draw(self.x, self.y)
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
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

local mouse_x = 0
local mouse_y = 0

function callback.mouse_move(x, y)
	mouse_x = x
	mouse_y = y
	
end

local function test_func(region_name, flag,  x, y, w, h)
	region[region_name]:focus(nil)
	if flag then
		return flag
	end
	if x >= 0 and x < w and y >= 0 and y < h then
		local c = region[region_name]:test(mouse_x, mouse_y, x, y)
		if c then
			region[region_name]:focus(c)
			return true
		end
	end
end

local test = {
	neutral = test_func,
	homeworld = test_func,
	colony = test_func,
	hand = test_func,
}

local hud_test_list = widget.test_list("hud", test)

function callback.mouse_button(btn, down)
	if down == 1 then
		widget.test(mouse_x, mouse_y, batch, hud_test_list)
	end
end

return callback
