local mouse = require "core.mouse"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local card = require "gameplay.card"
local ui = require "core.rules".ui.cardlist

local table = table
local math = math
global print, print_r

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
		list[i] = {
			widget = true,
			obj = vcard.object(deck[i]),
			x = pos_x,
			y = pos_y,
		}
		pos_x = pos_x + w
		j = j + 1
	end
	return list, pos_y + h - layout.left[4] + layout.left[2]
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
			break
		end
		scroll_target(mouse.z * SPEED - scroll)
		flow.sleep(0)
	end
	vdesktop.additional()
	vdesktop.describe(false)
end
