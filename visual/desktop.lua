local vregion = require "visual.region"
local vmap = require "visual.map"
local vcard = require "visual.card"
local vtips = require "visual.tips"
local widget = require "core.widget"
local util = require "core.util"
local focus = require "core.focus"

local M = {}

local desktop = {
	discard = { type = "back" },
	draw_pile = 0,
	discard_pile = 0,
}

local region = util.map (function(name)
	return vregion(name) 
end) { "neutral", "homeworld", "colony", "hand", "discard", "deck", "float" } 

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
		local r = region[what]
		r:animation_update()
		if r:update(self.w, self.h, self.x, self.y) then
			local scale = calc_scale(self, n)
			local offx = n <= 1 and 0 or (card_w * scale + 3)
			local x = 0
			for idx, obj in ipairs(r) do
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

	local function update_discard(self)
		local r = region.discard
		r:animation_update()
		if r:update(self.w, self.h, self.x, self.y) then
			local scale = calc_scale(self, 1)
			local x = 0
			local obj = r[1]
			obj.scale = scale
			obj.focus_target.scale = 1
			obj.focus_target.x = obj.x - card_w * (1-scale)
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
		discard.draw = desktop.draw_pile
		discard.discard = desktop.discard_pile
		update_region(self, "deck",1)
		update_discard(self)
		region.deck:draw(self.x, self.y)
		region.deck:clear()
		region.discard:draw(self.x, self.y)
	end
	
	local function calc_offx(self, name)
		local n = #region[name]
		if n == 0 then
			return
		end
		local x = 0
		local w = card_w * n + 3 * (n - 1)
		local offx
		if w > self.w then
			offx = (self.w - card_w) / (n - 1)
			w = self.w
		else
			x = (self.w - w) / 2
			offx = card_w + 3
		end
		return x, offx
	end
	
	function hud:float()
		region.float:animation_update()
		if region.float:update(self.w, self.h, self.x, self.y) then
			local x, offx = calc_offx(self, "float")
			if x then
				for _, obj in ipairs(region.float) do
					obj.x = x
					obj.scale = 1
					obj.focus_target.y = dy
					x = x + offx
				end
			end
		end
		region.float:draw(self.x, self.y)
	end

	function hud:hand()
		region.hand:animation_update()
		if region.hand:update(self.w, self.h, self.x, self.y) then
			local x, offx = calc_offx(self, "hand")
			if x == nil then
				return
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
	
	function hud:tips()
		vtips.draw(self)
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

-- todo : call update_hud_draw_list when changing localization
function M.flush(w, h)
	update_hud_draw_list(w, h)
end

local mouse_x = 0
local mouse_y = 0

local function focus_map_test(region_name, flag,  x, y, w, h)
	if flag then
		return flag
	end
	local c = region[region_name]:test(mouse_x, mouse_y, x, y)
	if c then
		focus.trigger(region_name, c)
		return c
	end
	-- lost focus
	focus.trigger(region_name)
end

local function map_focus(region_name, card)
	local r = region[region_name]
	if card then
		r:focus(card)
		if card.sector then
			vmap.focus(card.sector)
		end
	else
		r:focus(nil)
	end
end

local focus_func = {
	neutral = map_focus,
	homeworld = map_focus,
	colony = map_focus,
	hand = map_focus,
	discard = map_focus,
}

local test = {
	neutral = focus_map_test,
	homeworld = focus_map_test,
	colony = focus_map_test,
	hand = focus_map_test,
	discard = focus_map_test,
}

local hud_test_list

function M.mouse_move(x, y)
	mouse_x = x
	mouse_y = y
	widget.test(mouse_x, mouse_y, batch, hud_test_list)
	focus.dispatch(focus_func)
end

function M.draw(count)
	widget.draw(batch, hud_draw_list, focus.region())
end

function M.card_count(draw, discard)
	if draw ~= desktop.draw_pile or discard ~= desktop.discard_pile then
		desktop.draw_pile = draw
		desktop.discard_pile = discard
		vcard.flush(desktop.discard)
	end
end

function M.moving(where, c)
	return region[where]:moving(c)
end

function M.add(where, card)
	region[where]:add(card)
end

function M.transfer(from, card, to)
	local r = region[from]
	r:transfer(card, to)
end

function M.init(args)
	vcard.init(args)
	vmap.init(args)
	vtips.init(args)
	batch = args.batch
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
	region.discard:add(desktop.discard)
end

return M
