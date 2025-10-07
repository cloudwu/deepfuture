local mouse = require "core.mouse"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local card = require "gameplay.card"
local ui = require "core.rules".ui.cardlist
local keyboard = require "core.keyboard"
local lang = require "core.language"
local loadsave = require "core.loadsave"
local font = require "soluna.font"

local table = table
local math = math
global print, print_r, ipairs

local SPEED <const> = ui.scroll

local function get_era(c)
	local t = c.type
	if t == "tech" then
		if card.complete(c) then
			return math.max(c.adv1.era, c.adv2.era, c.adv3.era)
		else
			return -1
		end
	elseif t == "world" or t == "civ" then
		return c.era
	else
		return -2
	end
end

local priority = {
	tech = 3,
	civ = 2,
	world = 1,
}

local function sort_card(a, b)
	local era_a = get_era(a)
	local era_b = get_era(b)
	if era_a ~= era_b then
		return era_a > era_b
	end
	local t_a = priority[a.type] or 0
	local t_b = priority[b.type] or 0
	if t_a ~= t_b then
		return t_a > t_b
	end
	return a._id > b._id
end

local function gen_list()
	local w, h = vcard.size()
	local layout = vdesktop.describe_layout()
	local gap = layout.right[1] - layout.left[1] - layout.left[3]
	local n = (layout.left[3] + gap) // (w + gap)
	local deck = card.deck()
	table.sort(deck, sort_card)
	local list = {}
	w = w + gap
	h = h + gap
	local left = layout.right[1] - w * n
	local pos_x = left
	local pos_y = layout.left[2]
	n = n * 2
	local j = 0
	for i = 1, #deck do
		if j >= n then
			pos_x = left
			pos_y = pos_y + h
			j = 0
		end
		local c = deck[i]
		list[i] = {
			widget = true,
			card = c,
			obj = vcard.object(c),
			x = pos_x,
			y = pos_y,
		}
		pos_x = pos_x + w
		j = j + 1
	end
	return list, pos_y + h - layout.left[4] + layout.left[2]
end

local function click_card(list)
	local x, y = mouse.x, mouse.y
	local w, h = vcard.size()
	x = x - list.x
	y = y - list.y
	for _, item in ipairs(list) do
		if x >= item.x and x < item.x + w and y >= item.y and y < item.y + h then
			return item
		end
	end
end

local can_edit = {
	world = true,
	tech = true,
	civ = true,
}

local function edit(text, x, y, w, h, list, editbox, item)
	local attribs = editbox:attribs()
	local _, view_h = vdesktop.screen_size()
	local fontid = lang.font_id()
	local fontsize = attribs.size or 16	-- see widget
	local fontattr = font.size(fontid, fontsize)
	local desc = {
		text = text or "",
		align = attribs.text_align,
		fontsize = fontsize,
		fontid = fontid,
		fontname = lang.font_name(),
		width = w,
		height = h,
		ime_x = x + list.x,
		ime_y = view_h - (y + list.y + fontattr.ascent),
	}
	local list_n = #list + 1
	local text_label = {
		x = x,
		y = y,
	}
	local cursor = {}
	list[list_n] = text_label
	local result
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		local c = mouse.click(focus_state, "left")
		if c and c ~= item then
			result = true
			break
		end
		if mouse.click(focus_state, "right") then
			result = false
			break
		end
		result = keyboard.editbox(desc)
		if result ~= nil then
			break
		end
		text_label.obj = desc.label
		if desc.cursor_quad then
			cursor.x = x + desc.cursor_x
			cursor.y = y + desc.cursor_y
			cursor.obj = desc.cursor_quad
			list[list_n + 1] = cursor
		else
			list[list_n + 1] = nil
		end
		flow.sleep(0)
	end
	list[list_n] = nil
	list[list_n+1] = nil
	if result then
		-- enter
		return desc.text
	else
		-- escape
		return text
	end
end

local function edit_card(item, list)
	local c = item.card
	if not can_edit[c.type] then
		return
	end
	if c.type == "tech" and not card.complete(c) then
		return
	end
	local sector
	if c.type == "world" then
		sector = c.sector
		c.sector = nil
	end
	if c.type == "civ" then
		c._name = "${name|}"
	end
	local editbox = vcard.editbox(c)
	local x, y, w, h = editbox:get()
	local text = c.name
	c.name = nil
	vcard.flush(c)
	item.obj = vcard.object(c)
	
	text = edit(text, item.x + x, item.y + y, w, h, list, editbox, item)
	
	c.name = text
	if sector then
		c.sector = sector
	end
	if c.type == "civ" then
		c._name = "$(card.civ.name.final)"
	end
	vcard.flush(c)
	if c.type ~= "civ" then
		-- sync civ card
		for i = 1, #list do
			local _item = list[i]
			local c = _item.card
			if c and c.type == "civ" then
				card.gen_desc(c)
				vcard.flush(c)
				_item.obj = vcard.object(c)
				print("Flush", _item.card, _item.obj)
			end
		end
	end
	item.obj = vcard.object(c)
	card.sync(c)
	loadsave.save_deck()	
end

return function()
	local list, height = gen_list()
	list.x = 0
	list.y = 0
	local scroll = mouse.z
	local top = -height
	local function scroll_target(p)
		if p < top then
			scroll = scroll + p - top
			p = top
		elseif p > 0 then
			scroll = scroll + p
			p = 0
		end
		local diff = p - list.y
		if diff == 0 then
			return
		end
		list.y = list.y + diff * 0.2
	end
	
	vdesktop.describe {}
	vdesktop.additional(list)
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		local c = mouse.click(focus_state, "left")
		if c then
			c = click_card(list)
			if not c then
				break
			else
				edit_card(c, list)
			end
		end
		local c = mouse.click(focus_state, "right")
		if c then
			break
		end
		scroll_target(mouse.z * SPEED - scroll)
		flow.sleep(0)
	end
	vdesktop.additional()
	vdesktop.describe(false)
end
