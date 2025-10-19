local layout = require "soluna.layout"
local util = require "core.util"
local mattext = require "soluna.material.text"
local matquad = require "soluna.material.quad"
local font = require "soluna.font"
local textconv = require "soluna.text"
local localization = require "core.localization"
local table = table

global pairs, ipairs, type, print

local widget = {}
local scripts = {}

function widget.scripts(t)
	scripts = t
end

local doms = util.cache(function(k)
	local filename = "asset/layout/"..k..".dl"
	local dom = layout.load (filename, scripts[k])
	return dom
end)

local fontcobj = font.cobj()

local layout_pos = util.cache(function(k)
	return (layout.calc(doms[k]))
end)

function widget.set(dom, attribs)
	local d = doms[dom]
	layout_pos[dom] = nil
	for k,v in pairs(attribs) do
		local obj = d[k]
		for k,v in pairs(v) do
			obj[k] = v
		end
	end
end

function widget.get(dom, id)
	local pos = layout_pos[dom]
	local d = doms[dom]
	return d[id]
end

function widget.draw_list(dom, texts, font_id, sprites)
	local pos = layout_pos[dom]
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
				local last = label
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

function widget.draw(batch, list, focus)
	local delay
	for _, obj in ipairs(list) do
		local o, x, y = table.unpack(obj)
		if type(o) == "function" then
			if focus and focus[x.region] then
				local f = o
				local arg = x
				local last = delay
				if delay then
					delay = function()
						last()
						f(arg)
					end
				else
					delay = function()
						f(arg)
					end
				end
			else
				o(x)
			end
		else
			batch:add(o, x, y)
		end
	end
	if delay then
		delay()
	end
end

function widget.test_list(dom, funcs)
	local pos = layout_pos[dom]
	local r = {}
	local n = 1
	for idx, obj in ipairs(pos) do
		if obj.region then
			local f = funcs[obj.region]
			if f then
				r[n] = { f, obj }; n = n + 1
			end
		end
	end
	return r
end

function widget.test(mx, my, batch, list, x, y, scale)
	batch:layer(scale or 1, x or 0 , y or 0)
	local flag = nil
	for i = #list, 1, -1 do
		local obj = list[i]
		local r = obj[2]
		batch:layer(r.x, r.y)
		flag = obj[1](r.region, flag, mx, my, r.w, r.h)
		batch:layer()
	end
	batch:layer()
end

return widget