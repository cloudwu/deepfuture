local vcard = require "visual.card"
local region = {}; region.__index = region

function region:add(c)
	table.insert(self, {
		card = c,
		x = 0,
		y = 0,
		scale = 1,
		timeline = 0,
		animation = nil,
	})
end

function region:focus(c)
	self._focus = c
end

function region:update(w, h)
	if self.animation then
		-- todo: update animation
	end

	local ww = self.w
	local hh = self.h
	
	if ww == w and hh == h then
		return
	end
	self.x = x
	self.y = y
	self.w = w
	self.h = h
	
	return true
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
				vcard.draw(obj.card, obj.x, obj.y, obj.scale)
			end
		end
	end
	if focus then
		vcard.draw(focus.card, focus.x, focus.y, focus.scale)
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
		end
		if r == nil and obj.card and vcard.test(mx, my, obj.x, obj.y, obj.scale) then
			r = obj.card
		end
	end
	if focus and vcard.test(mx, my, focus.x, focus.y, focus.scale) then
		r = focus.card
	end
	return r
end

return function()
	return setmetatable({}, region)
end
