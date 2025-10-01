local flow = require "core.flow"
local menu = require "gameplay.menu"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local mattext = require "soluna.material.text"
local credits = require "core.rules".credits
local ui = require "core.rules".ui
local font = require "soluna.font"
local lang = require "core.language"
local localization = require "core.localization"
local textconv = require "soluna.text"

local table = table

global print_r, ipairs

local function gen_list(layout)
	local fontcobj = font.cobj()
	local fontid = lang.font_id()
	local fontsize = ui.credits.font_size
	local left_color = ui.credits.left_color
	local right_color = ui.credits.right_color
	local gap = ui.credits.gap
	
	local leftblock = mattext.block(fontcobj, fontid, fontsize, left_color, "TR")
	local rightblock = mattext.block(fontcobj, fontid, fontsize, right_color, "TL")
	local list = {}
	local i = 1
	local left_x, left_y, left_w, left_h = table.unpack(layout.left)
	local right_x, right_y, right_w, right_h = table.unpack(layout.right)
	for _, item in ipairs(credits) do
		local text = item[1]
		text = localization.convert("credits." .. text)
		text = textconv.convert[text]
		list[i] = {
			x = left_x,
			y = left_y,
			obj = leftblock(text, left_w, left_h),
		}
		i = i + 1
		for j = 2, #item do
			local text = item[j]
			local label, height = rightblock(text, right_w, right_h)
			local offy = height + gap
			left_y = left_y + offy
			list[i] = {
				x = right_x,
				y = right_y,
				obj = label,
			}
			i = i + 1
			right_y = right_y + offy
		end
	end
	left_y = left_y - gap
	local offy = (right_h - right_y) // 2
	for _, item in ipairs(list) do
		item.y = item.y + offy
	end
	
	return list
end

return function()
	local layout = vdesktop.describe_layout()
	local list = gen_list(layout)
	vdesktop.additional(list)
	vdesktop.describe {}
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		local c = mouse.click(focus_state, "left")
		if c then
			break
		end
		flow.sleep(0)
	end
	vdesktop.additional()
	vdesktop.describe(false)
	return flow.state.startmenu
end
