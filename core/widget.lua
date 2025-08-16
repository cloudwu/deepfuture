local layout = require "soluna.layout"
local cache = require "core.cache"
local mattext = require "soluna.material.text"
local matquad = require "soluna.material.quad"
local font = require "soluna.font"
local textconv = require "soluna.text"
local localization = require "core.localization"

local widget = {}

local doms = cache.table(function(k)
	local filename = "asset/"..k..".dl"
	local dom = layout.load (filename)
	return dom
end)

local fontcobj = font.cobj()

function widget.set(dom, attribs)
	local d = doms[dom]
	for k,v in pairs(attribs) do
		local obj = d[k]
		for k,v in pairs(v) do
			obj[k] = v
		end
	end
end

function widget.get(dom, id)
	local d = doms[dom]
	layout.calc(d)
	return d[id]:get()
end

function widget.draw_list(dom, texts, font_id, sprites)
	local pos = layout.calc(doms[dom])
	local r = {}
	local n = 1
	for idx, obj in ipairs(pos) do
		if obj.background then
			r[n] = { matquad.quad(obj.w, obj.h, obj.background), obj.x, obj.y }; n= n + 1
		end
		if obj.image then
			r[n] = { sprites[obj.image], obj.x, obj.y }; n = n + 1
		elseif obj.text then
			local env = texts
			if obj.env then
				env = texts[obj.env]
			end
			if env then
				local label = localization.convert(obj.text, env)
				label = textconv.convert[label]
				local block = mattext.block(fontcobj, font_id, obj.size or 16, obj.color or 0, obj.text_align)
				local label = block(label, obj.w, obj.h)
				r[n] = { label, obj.x, obj.y }; n = n + 1
			end
		elseif obj.region then
			local f = texts[obj.region]
			if f then
				r[n] = { f, obj }; n = n + 1
			end
		end
	end
	return r
end

function widget.draw(batch, list, x, y, scale)
	batch:layer(scale or 1, x or 0 , y or 0)
	for _, obj in ipairs(list) do
		local o, x, y = table.unpack(obj)
		if type(o) == "function" then
			o(x)
		else
			batch:add(o, x, y)
		end
	end
	batch:layer()
end

return widget