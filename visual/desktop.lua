local vregion = require "visual.region"
local vmap = require "visual.map"
local vcard = require "visual.card"
local vtips = require "visual.tips"
local vtrack = require "visual.track"
local vbutton = require "visual.button"
local widget = require "core.widget"
local util = require "core.util"
local focus = require "core.focus"
local table = table

global ipairs, error, pairs, print, tostring

local DRAWLIST = {}
local TESTLIST = {}
local update_draw_list
local update_desc_list
local BATCH
local DESC
local VTIPS = {}

local M = {}

local desktop = {
	discard = { type = "back", text = "$(card.number)" },
	draw_pile = 0,
	discard_pile = 0,
	seen = 0,
}

local region = util.map (function(name)
	return vregion.cards(name) 
end) { "neutral", "homeworld", "colony", "hand", "discard", "deck", "float", "card" } 

region.background = vregion.rect()

local hud = {}
local describe = {}

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
		VTIPS.hud.draw(self)
	end
	
	function describe:tips()
		VTIPS.desc.draw(self)
	end

	function describe:background()
		region.background:update(self.w, self.h, self.x, self.y)
	end

	function describe:card()
		local c = region.card[1]
		if c then
			c.scale = self.w / card_w
			region.card:draw(self.x, self.y)
		end
	end
end

local layouts = { "hud", "describe" }
layouts.hud = hud
layouts.describe = describe

local function set_hud(w, h)
	for i = 1, #layouts do
		local name = layouts[i]
		widget.set(name, {
			screen = {
				width = w,
				height = h,
			}
		})
	end
end

-- todo : call update_draw_list when changing localization
function M.flush(w, h)
	update_draw_list(w, h)
end

local function focus_map_test(region_name, flag, mx, my)
	if flag then
		return flag
	end
	local r = region[region_name] or error ("No region " .. region_name)
	local c = r:test(mx, my)
	if c then
		focus.trigger(region_name, c)
		return c
	end
	-- lost focus
	focus.trigger(region_name)
end

local function map_focus(region_name, card)
	if region_name == nil then
		return
	end
	local r = region[region_name]
	if r == nil then
		return
	end
	if card then
		r:focus(card)
		-- todo :
		if card.sector then
			vmap.focus(card.sector)
		end
	else
		r:focus(nil)
	end
end

local test = {
	neutral = focus_map_test,
	homeworld = focus_map_test,
	colony = focus_map_test,
	hand = focus_map_test,
	discard = focus_map_test,
	background = focus_map_test,
	float = focus_map_test,
}

local mouse_x = 0
local mouse_y = 0

function M.set_text(key, args)
	key = "text." .. key
	local env = hud[key] or {}
	hud[key] = env
	for k,v in pairs(args) do
		if v then
			env[k] = v
		else
			env[k] = nil
		end
	end
	update_draw_list()
end

function M.describe(text)
	DESC = not not text
	focus.clear()
	if text then
		describe.text = text
		update_desc_list()
	else
		describe.text = nil
		widget.test(mouse_x, mouse_y, BATCH, TESTLIST.hud)
	end
end

local focus_state = {}

function M.mouse_move(x, y)
	mouse_x = x
	mouse_y = y
	widget.test(mouse_x, mouse_y, BATCH, DESC and TESTLIST.desc or TESTLIST.hud)
end

function M.draw(count)
	-- todo : find a better place to check unfocus :
	--		code trigger unfocus, rather than mouse move
	if focus.get(focus_state) then
		map_focus(focus_state.active, focus_state.object)
	end
	map_focus(focus_state.lost)
	widget.draw(BATCH, DRAWLIST.hud, focus.region())
	if DESC then
		widget.draw(BATCH, DRAWLIST.describe)
	end
	focus.frame()
end

function M.draw_pile_focus(enable)
	local c = desktop.discard
	vcard.mask(c, enable)
end

function M.card_count(draw, discard, seen)
	if draw ~= desktop.draw_pile or discard ~= desktop.discard_pile or seen ~= desktop.seen then
		desktop.seen = seen
		desktop.draw_pile = draw
		desktop.discard_pile = discard
		local c = desktop.discard
		c.draw = draw
		c.discard = discard
		c.seen = seen
		c.eye = seen > 0 and "$(card.seen)"
		vcard.flush(c)
	end
end

function M.moving(where, c)
	return region[where]:moving(c)
end

function M.add(where, card)
	region[where]:add(card)
end

function M.remove(where, card)
	region[where]:remove(card)
end

function M.replace(where, from, to)
	region[where]:replace(from, to)
end

function M.clear(where)
	region[where]:clear()
end

function M.transfer(from, card, to)
	local r = region[from]
	r:transfer(card, to)
end

local function update_test_list()
	TESTLIST.hud = widget.test_list("hud", test)
end

function M.button_enable(name, obj)
	vbutton.enable(name, obj)
	vbutton.register {
		draw = hud,
		test = test,
	}
	update_draw_list()
	update_test_list()
end

function M.tostring(where)
	local t = { where }
	for _, c in ipairs(region[where]) do
		t[#t+1] = tostring(c)
	end
	return table.concat(t, " ")
end

-- for test
function M.sync(where, pile)
	local r = region[where]
	r:update()
	local draw = {}
	local discard = {}
	for i, c in ipairs(r) do
		discard[c.card] = i
	end
	for _, c in ipairs(pile) do
		if discard[c] then
			discard[c] = nil
		else
			draw[#draw+1] = c
		end
	end
	local list = {}
	for c in pairs(discard) do
		list[#list+1] = c
	end
	if #draw == 0 and #list == 0 then
		return
	end
	return {
		draw = draw,
		discard = list,
	}
end

function M.init(args)
	vcard.init(args)
	vmap.init(args)
	vtips.init(args)
	vtrack.init(args)
	vbutton.init(args)
	VTIPS.hud = vtips.layer "hud"
	VTIPS.desc = vtips.layer "desc"
	VTIPS.hud.push()
	BATCH = args.batch
	local font_id = args.font_id
	local sprites = args.sprites
	local width = args.width
	local height = args.height
	function update_draw_list(w, h)
		w = w or width
		h = h or height
		set_hud(w, h)
		for i = 1, #layouts do
			local name = layouts[i]
			DRAWLIST[name] = widget.draw_list(name, layouts[name], font_id, sprites)
		end
	end
	function update_desc_list()
		DRAWLIST.describe = widget.draw_list("describe", layouts.describe, font_id, sprites)
	end
	region.discard:add(desktop.discard)
	local d = {
		draw = hud,
		test = test,
	}
	vtrack.register(d)
	vmap.register(d)
	
	TESTLIST.desc = widget.test_list("describe", test)
	update_draw_list()
	update_test_list()
end

return M
