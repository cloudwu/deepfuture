local vregion = require "visual.region"
local vmap = require "visual.map"
local vcard = require "visual.card"
local widget = require "core.widget"

local M = {}

local desktop = {
	hand = {},
	homeworld = {},
	neutral = {},
	colony = {},
	hand = {},
	discard = { { type = "back" } },
	draw_pile = 0,
	discard_pile = 0,
}

local region = {
	neutral = vregion(),
	homeworld = vregion(),
	colony = vregion(),
	hand = vregion(),
	discard = vregion(),
}

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
	
	local function update_region(self, what, n)
		region[what]:animation_update()
		if region[what]:update(self.w, self.h) then
			local scale = calc_scale(self, n)
			local offx = card_w * scale + 3
			local x = 0
			for idx, obj in ipairs(region[what]) do
				obj.x = x
				obj.scale = scale
				if idx > 3 then
					obj.focus_target.x = obj.x - card_w * (1-scale)
				end
				obj.focus_target.scale = 1
				x = x + offx
			end
		end
	end
	
	function hud:neutral()
		update_region(self, "neutral",6)
		region.neutral:draw(self.x, self.y)
	end

	function hud:homeworld()
		update_region(self, "homeworld",4)
		region.homeworld:draw(self.x, self.y)
	end

	function hud:colony()
		update_region(self, "colony",4)
		region.colony:draw(self.x, self.y)
	end
	
	function hud:discard()
		local discard = desktop.discard
		discard = discard[#discard]
		discard.draw = desktop.draw_pile
		discard.discard = desktop.discard_pile
		update_region(self, "discard",1)
		region.discard:draw(self.x, self.y)
	end
	
	function hud:hand()
		region.hand:animation_update()
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
				x = (self.w - w) / 2
				offx = card_w + 3
			end
			local dy = self.h - card_h
			if dy >= 0 then
				dy = - 20
			end
			for _, obj in ipairs(region.hand) do
				obj.x = x
				obj.scale = 1
				obj.focus_target.y = dy
				x = x + offx
			end
		end

		region.hand:draw(self.x, self.y)
	end
end

local function set_hud(w, h)
	widget.set("hud", {
		screen = {
			width = w,
			height = h,
		}
	})
end

local hud_draw_list
local update_hud_draw_list
local batch

function M.flush(w, h)
	update_hud_draw_list(w, h)
end

local mouse_x = 0
local mouse_y = 0
local focus_region_name

local function test_func_(region_name, flag,  x, y, w, h)
	if flag then
		return flag
	end
	local c = region[region_name]:test(mouse_x, mouse_y, x, y)
	if c then
		for k,v in pairs(region) do
			if k == region_name then
				v:focus(c)
				focus_region_name = region_name
			else
				v:focus(nil)
			end
		end
		return c
	end
	if focus_region_name == region_name then
		focus_region_name = nil
	end
	region[region_name]:focus(nil)
end

local function focus_map_test(...)
	local card = test_func_(...)
	if type(card) == "table" and card.sector then
		vmap.focus(card.sector)
	end
	if card ~= nil then
		return true
	end
end

local function test_func(...)
	if test_func_(...) then
		return true
	end
end

local test = {
	neutral = focus_map_test,
	homeworld = focus_map_test,
	colony = focus_map_test,
	hand = focus_map_test,
}

local hud_test_list

function M.mouse_move(x, y)
	mouse_x = x
	mouse_y = y
	widget.test(mouse_x, mouse_y, batch, hud_test_list)
end

function M.draw(count)
	widget.draw(batch, hud_draw_list, focus_region_name)
end

function M.card_count(draw, discard)
	desktop.draw_pile = draw
	desktop.discard_pile = discard
end

function M.add(where, list)
	local pile = desktop[where]
	local r = region[where]
	for _, card in ipairs(list) do
		pile[#pile+1] = card
		r:add(card)
	end
end

function M.init(args)
	batch = args.batch
	vcard.init(batch, args.font_id, args.sprites)
	vmap.init(batch, args.font_id, args.sprites)
	local font_id = args.font_id
	local sprites = args.sprites
	local width = args.width
	local height = args.height
	function update_hud_draw_list(w, h)
		w = w or width
		h = h or height
		set_hud(w, h)
		hud_draw_list = widget.draw_list("hud", hud, font_id, sprites)
	end
	update_hud_draw_list()
	hud_test_list = widget.test_list("hud", test)
end

return M
