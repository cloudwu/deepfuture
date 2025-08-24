local localization = require "core.localization"
local mattext = require "soluna.material.text"
local util = require "core.util"
local textconv = require "soluna.text"
local font = require "soluna.font"
local fontcobj = font.cobj()
local table = table

global assert, pairs

local tips = {}

local FONT_ID
local SPRITES
local BATCH
local TIPS_TEXT

local fontbox = {
	size = 14,
	color = 0,
	align = "LT",
}

local tips_cache = util.cache(function (text)
	text = textconv.convert[text]
	local block = mattext.block(fontcobj, FONT_ID, fontbox.size, fontbox.color, fontbox.align)
	local drawlist = block(text, fontbox.width, fontbox.height)
	return drawlist
end)

function tips.set(str, env)
	if str then
		TIPS_TEXT = localization.convert(str, env)
	else
		TIPS_TEXT = nil
	end
end

function tips.draw(region)
	if TIPS_TEXT == nil then
		return
	end
	if region.w ~= fontbox.width or region.h ~= fontbox.height then
		fontbox.width = region.w
		fontbox.height = region.h
		tips_cache = util.cache(tips_cache)	-- clear cache
	end
	BATCH:add(tips_cache[TIPS_TEXT], region.x, region.y)
end

local M = {}

local LAYER = {}

local function new_layer(name)
	local layer = {}
	function layer.push()
		table.insert(LAYER, 1, name)
	end
	function layer.pop()
		local last = table.remove(LAYER,1)
		assert(last == name, "Invalid layer")
	end
	for k, func in pairs(tips) do
		layer[k] = function(...)
			if name ~= LAYER[1] then
				return
			end
			func(...)
		end
	end
	return layer
end

local LAYER_OBJECT = util.cache(new_layer)

function M.layer(name)
	return LAYER_OBJECT[name]
end

function M.flush(args)
	if args then
		fontbox.size = args.size or fontbox.size
		fontbox.color = args.color or fontbox.color
		fontbox.align = args.size or fontbox.align
	end
	tips_cache = util.cache(tips_cache)	-- clear cache
end

function M.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return M
