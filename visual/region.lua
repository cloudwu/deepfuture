local util = require "core.util"
local vcard = require "visual.card"
local region = {}; region.__index = region

function region:add(c)
	self[#self+1] = {
		card = c,
		x = 0,
		y = 0,
		scale = 1,
		focus_target = {},
	}
	self._dirty = true
end

function region:replace(from, to)
	for i, card in ipairs(self) do
		if card.card == from then
			card.card = to
			return
		end
	end
end

function region:focus(c)
	self._focus = c
end

local FOCUS_TIME <const> = 20
local FOCUS_TIME_FACTOR <const> = 1 / FOCUS_TIME * math.pi / 2;
local TRANSFER = {}

function region:animation_update()
	for i = 1, #self do
		local obj = self[i]
		if self._focus == obj.card then
			if obj._focus_time then
				if obj._focus_time < FOCUS_TIME then
					obj._focus_time = obj._focus_time + 1
				end
			else
				obj._focus_time = 0
			end
		else
			if obj._focus_time then
				if obj._focus_time == 0 then
					obj._focus_time = nil
					obj._move = nil
				else
					obj._focus_time = obj._focus_time - 1
				end
			end
		end
	end
end

local function focus_args(obj)
	local base_scale = obj.scale
	local target = obj._move or obj.focus_target
	local target_scale = target.scale
	local fac = math.sin(obj._focus_time * FOCUS_TIME_FACTOR)
	local scale = target_scale and (base_scale + (target_scale - base_scale) * fac) or base_scale
	local x = target.x and (obj.x + (target.x - obj.x) * fac) or obj.x
	local y = target.y and (obj.y + (target.y - obj.y) * fac) or obj.y
	return x, y, scale
end

local function transfer(self, obj, rx, ry)
	local x, y, scale
	if obj._focus_time then
		x, y, scale = focus_args(obj)
	else
		x, y, scale = obj.x, obj.y, obj.scale
	end
	obj._focus_time = FOCUS_TIME
	obj.x = 0
	obj.y = 0
	obj.scale = 1
	obj.focus_target = {}
	obj._move = {
		x = x + rx,
		y = y + ry,
		scale = scale,
	}
	
	if self._focus == obj.card then
		self._focus = nil
	end
	
	local q = TRANSFER[obj._region]
	q[#q+1] = obj
end

function region:clear()
	local n = 1
	while true do
		local obj = self[n]
		if not obj then
			break
		end
		if obj._move == nil then
			table.remove(self, n)
		else
			n = n + 1
		end
	end
end

function region:moving(c)
	for i = 1, #self do
		local obj = self[i]
		if obj.card == c then
			return obj._move ~= nil
		end
	end
end

function region:update(w, h, x, y)
	local ww = self.w
	local hh = self.h
	local dirty = self._dirty
	self._dirty = nil
	
	if self._transfer then
		self._transfer = nil
		dirty = true
		local n = 1
		while true do
			local obj = self[n]
			if not obj then
				break
			end
			if obj._region then
				transfer(self, obj, x, y)
				table.remove(self, n)
			else
				n = n + 1
			end
		end
	end
	
	local q = TRANSFER[self._name]
	if q[1] then
		for i = 1, #q do
			local obj = q[i]
			obj._region = nil
			obj._move.x = obj._move.x - x
			obj._move.y = obj._move.y - y
			self[#self + 1] = obj
			q[i] = nil
		end
		dirty = true
	end
	
	if ww == w and hh == h then
		return dirty
	end
	self.x = x
	self.y = y
	self.w = w
	self.h = h
	
	return true
end

local function draw_card(obj)
	if obj._focus_time then
		vcard.draw(obj.card, focus_args(obj))
	else
		vcard.draw(obj.card, obj.x, obj.y, obj.scale)
	end
end

local function test_card(obj, mx, my)
	return obj._move == nil and vcard.test(mx, my, obj.x, obj.y, obj.scale)
end

function region:transfer(card, new_region)
	for i = 1, #self do
		local obj = self[i]
		if obj.card == card then
			obj._region = new_region
			self._transfer = true
			return
		end
	end
end

function region:draw(x, y)
	vcard.layer(x, y)
	local focus
	for i = 1, #self do
		local obj = self[i]
		if obj.card then
			if self._focus == obj.card then
				focus = obj
			else
				draw_card(obj)
			end
		end
	end
	if focus then
		draw_card(focus)
	end
	vcard.layer()
end

function region:test(mx, my)
	local r
	local focus
	for i = #self, 1, -1 do
		local obj = self[i]
		if obj.card == self._focus then
			focus = obj
		elseif r == nil and obj.card and test_card(obj, mx, my) then
			r = obj.card
		end
	end
	if focus then
		if test_card(focus, mx, my) then
			r = focus.card
		end
	end
	return r
end

local M = {}

function M.cards(name)
	assert(TRANSFER[name] == nil)
	TRANSFER[name] = {}
	return setmetatable({ _name = name }, region)
end

local rect_region = {}; rect_region.__index = rect_region

function rect_region:focus(on)
end

function rect_region:update(w, h, x, y)
	self._x1 = x
	self._y1 = y
	self._x2 = x + w
	self._y2 = y + h
end

function rect_region:test(mx, my)
	if mx >= self._x1 and my >= self._y1 and mx < self._x2 and my < self._y2 then
		return self
	end
end

function M.rect()
	return setmetatable({ _x1 = 0, _y1 = 0, _x2 = 0, _y2 = 0 }, rect_region)
end

return M
