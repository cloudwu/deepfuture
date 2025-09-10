local widget = require "core.widget"
local util = require "core.util"
local mask = require "soluna.material.mask"
local config = require "core.rules".ui
local vprogress = require "visual.progress"

global assert, print, print_r

local card = {}

local FONT_ID
local SPRITES
local BATCH

local card_type = {
	world = "worldcard",
	blank = "blankcard",
	tech = "techcard",
	back = "cardback",
	civ = "civcard",
}

local mask_color <const> = config.card.mask_normal

local _, _, card_w, card_h = widget.get("blankcard", "card")
local center_x = card_w / 2
local center_y = card_h / 2

local function flush_card(data)
	local ct = card_type[data.type]
	if ct == nil then
		print_r("Invalid card", data)
	end
	return widget.draw_list(ct, data, FONT_ID, SPRITES)
end

local card_draw_list = util.cache(flush_card)

function card.flush(c)
	card_draw_list[c] = flush_card(c)
end

function card.draw(c, x, y, scale)
	local color = c._active
	BATCH:layer(scale or 1, x or 0 , y or 0)
	widget.draw(BATCH, card_draw_list[c])
	if color then
		BATCH:add(mask.mask(SPRITES.cardblank, color))
	end
	local p = c._progress
	if p then
		vprogress.draw(p, center_x, center_y)
	end
	BATCH:layer()
end

function card.mask(c, color)
	if color == true then
		color = mask_color
	end
	c._active = color
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

function card.focus_adv(c, index, enable)
	local adv = c["adv" .. index]
	if adv then
		if enable then
			adv._stage = adv._stage_focus
		elseif enable == false then
			adv._stage = adv._stage_use
		else
			adv._stage = adv._stage_normal
		end
		card.flush(c)
	end
end

function card.layer(...)
	BATCH:layer(...)
end

function card.adv_info(c, index)
	local adv = c["adv" .. index]
	if adv then
		return adv._name, adv._desc
	end
end

function card.init(args)
	BATCH = assert(args.batch)
	FONT_ID = assert(args.font_id)
	SPRITES = assert(args.sprites)
end

return card
