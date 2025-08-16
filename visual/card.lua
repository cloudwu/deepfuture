local widget = require "core.widget"
local cache = require "core.cache"

local card = {}

local FONT_ID
local SPRITES
local BATCH

local card_type = {
	world = "worldcard",
	blank = "blankcard",
}

local card_draw_list = cache.table(function(data)
	return widget.draw_list(card_type[data.type], data, FONT_ID, SPRITES)
end)

function card.draw(c, x, y, scale)
	widget.draw(BATCH, card_draw_list[c], x, y, scale)
end

function card.layer(...)
	BATCH:layer(...)
end

function card.init(batch, font_id, sprites)
	BATCH = assert(batch)
	FONT_ID = assert(font_id)
	SPRITES = assert(sprites)
end

return card
