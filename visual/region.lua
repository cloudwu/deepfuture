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

function region:update(w, h)
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
	if self.animation then
		-- todo: update animation
	end
	vcard.layer(x, y)
	for i = 1, #self do
		local obj = self[i]
		if obj.card then
			vcard.draw(obj.card, obj.x, obj.y, obj.scale)
		end
	end
	vcard.layer()
end

return function()
	return setmetatable({}, region)
end
