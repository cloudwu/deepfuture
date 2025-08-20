local vcard = require "visual.card"
local region = {}; region.__index = region

function region:add(c)
	table.insert(self, {
		card = c,
		x = 0,
		y = 0,
		scale = 1,
		focus_target = {}
	})
	self._dirty = true
end

function region:focus(c)
	self._focus = c
end

local FOCUS_TIME <const> = 12
local FOCUS_TIME_FACTOR <const> = 1 / FOCUS_TIME * math.pi / 2;

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
				else
					obj._focus_time = obj._focus_time - 1
				end
			end
		end
	end
end

function region:update(w, h)
	local ww = self.w
	local hh = self.h
	local dirty = self._dirty
	self._dirty = nil
	
	if ww == w and hh == h then
		return dirty
	end
	self.x = x
	self.y = y
	self.w = w
	self.h = h
	
	return true
end

local function focus_args(obj)
	local base_scale = obj.scale
	local target_scale = obj.focus_target.scale
	local fac = math.sin(obj._focus_time * FOCUS_TIME_FACTOR)
	local scale = target_scale and (base_scale + (target_scale - base_scale) * fac) or base_scale
	local x = obj.focus_target.x and (obj.x + (obj.focus_target.x - obj.x) * fac) or obj.x
	local y = obj.focus_target.y and (obj.y + (obj.focus_target.y - obj.y) * fac) or obj.y
	return x, y, scale
end

local function draw_card(obj)
	if obj._focus_time then
		vcard.draw(obj.card, focus_args(obj))
	else
		vcard.draw(obj.card, obj.x, obj.y, obj.scale)
	end
end

local function test_card(obj, mx, my)
	return vcard.test(mx, my, obj.x, obj.y, obj.scale)
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

function region:test(mx, my, x, y)
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

return function()
	return setmetatable({}, region)
end
