local focus = require "core.focus"
local util = require "core.util"
local config = require "core.rules".ui.button
local matquad = require "soluna.material.quad"
local mattext = require "soluna.material.text"
local font = require "soluna.font"
local textconv = require "soluna.text"
local localization = require "core.localization"
local math = math
local sin = math.sin

global pairs, assert, print

local states = {}
local button = {}
local BATCH
local FONT_ID
local TEXT
local TEXT_DISABLE
local SCALE_TIME <const> = 10
local SCALE_FACTOR <const> = 0.1
local SCALE_SIN <const> = 1 / SCALE_TIME * math.pi / 2

local NORMAL_COLOR <const> = config.normal
local FOCUS_COLOR <const> = config.hover

local function update_text(obj, key)
	local str = obj[key]
	if not str then
		return
	end
	local label = localization.convert(str, obj)
	return textconv.convert[label]
end

local function update_all(obj)
	obj.color = NORMAL_COLOR
	obj.text = update_text(obj._env, "text")
	obj._text = nil
	return obj
end

function button.enable(name, text)
	if text == nil then
		states[name] = false
		focus.trigger(name)
		return
	end
	states[name] = update_all { _env = text }
end

function button.update(name)
	update_all(states[name])
end

function button.register(args)
	local ui = args.draw
	local test = args.test
	for k,v in pairs(states) do
		if v then
			ui[k] = function (self)
				button.draw(k, self.x, self.y, self.w, self.h)
			end
			test[k] = button.test
		else
			ui[k] = nil
			test[k] = nil
		end
	end
end

function button.draw(name, x, y, w, h)
	local obj = states[name]
	if not obj then
		return
	end
	BATCH:add(matquad.quad(w, h, obj.color), x, y)
	local label = obj._text
	local disable = obj._env.disable
	if w ~= obj.w or h ~= obj.h or label == nil then
		obj.w = w
		obj.h = h
		local func = disable and TEXT_DISABLE or TEXT
		label = func(obj.text, w, h)
		obj._text = label
	end
	local press = focus.press("left", name)
	local scale = obj.scale
	if scale then
		-- already scaled
		if not press or disable then
			-- restore
			scale = scale - 1
			if scale <= 0 then
				scale = nil
				obj.scale = nil
			else
				obj.scale = scale
			end
		else
			-- pressed
			scale = scale + 1
			obj.scale = scale
		end
	elseif press and not disable then
		-- pressed
		scale = 1
		obj.scale = 1
	end
	if scale then
		if scale > SCALE_TIME then
			scale = SCALE_TIME
			obj.scale = SCALE_TIME
		end
		local s = sin(scale * SCALE_SIN) * SCALE_FACTOR
		BATCH:layer(1 - s, x + w * s * 0.5, y + h * s * 0.5)
		BATCH:add(label)
		BATCH:layer()
	else
		BATCH:add(label, x, y)
	end
end

function button.test(name, flag, mx, my, w, h)
	if flag then
		return flag
	end
	local obj = states[name]
	if not obj then
		focus.trigger(name)
		return false
	end
	local x, y = BATCH:point(mx, my)
	if x >= 0 and x < w and y >= 0 and y < h then
		if not obj._env.disable then
			obj.color = FOCUS_COLOR
		end
		focus.trigger(name, true)
		return true
	end
	obj.color = NORMAL_COLOR
	focus.trigger(name)
	return false
end

--function button.click(name, btn)
--end

function button.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	TEXT = mattext.block(font.cobj(), FONT_ID, config.font_size, config.color, "CV")
	TEXT_DISABLE = mattext.block(font.cobj(), FONT_ID, config.font_size, config.font_disable, "CV")
end

return button
