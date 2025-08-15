local widget = require "core.widget"

local card = {}

local FONT_ID
local SPRITES
local BATCH

local function gen_draw_list(self, data)
	local draw = widget.draw_list("card", data, FONT_ID, SPRITES)
	self[data] = draw
	return draw
end

local card_draw_list = setmetatable({}, { __index = gen_draw_list })

function card.draw(c, x, y, scale)
	widget.draw(BATCH, card_draw_list[c], x, y, scale)
end

function card.init(batch, font_id, sprites)
	BATCH = assert(batch)
	FONT_ID = assert(font_id)
	SPRITES = assert(sprites)
end

return card
