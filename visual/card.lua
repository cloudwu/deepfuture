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

local _, _, card_w, card_h = widget.get("blankcard", "card")

local card_draw_list = cache.table(function(data)
	return widget.draw_list(card_type[data.type], data, FONT_ID, SPRITES)
end)

function card.draw(c, x, y, scale)
	if x then
		BATCH:layer(scale or 1, x, y)
		widget.draw(BATCH, card_draw_list[c])
		BATCH:layer()
	else
		widget.draw(BATCH, card_draw_list[c])
	end
end

function card.test(mx, my, x, y, scale)
	local tx, ty
	if x then
		BATCH:layer(scale or 1, x , y)
		tx, ty = BATCH:point(mx, my)
		BATCH:layer()
	else
		tx, ty = BATCH:point(mx, my)
	end
	return tx >= 0 and tx < card_w and ty >= 0 and ty < card_h
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
