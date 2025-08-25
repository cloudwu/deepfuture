local config = require "core.rules".ui

global pairs

local function table_to_list(tbl)
	local list = {}
	local n = 1
	for k,v in pairs(tbl) do
		list[n] = k
		list[n+1] = v
		n = n + 2
	end
	return list
end

local colors = {
	config.track.color1,
	config.track.color2,
}

local scripts = {}

function scripts.track(name)
	local r = {}
	local n = 1
	r[n] = "name"
	r[n+1] = table_to_list {
		text = "hud." .. name .. ".logo",
		text_align = "C",
		size = 18,
		width = 24,
	}
	n = n + 2
	local mark_prefix = "mark_"..name
	local c = 1
	for i = 1, 13 do
		local id = mark_prefix .. i
		r[n] = "grid"
		r[n+1] = table_to_list {
			id = id,
			text = "hud.mark",
			env = id,
			text_align = "C",
			size = config.track.size,
			width = 25,
			background = colors[c],
		}
		c = 3-c
		n = n + 2
	end
	r[n] = "logo"
	r[n+1] = table_to_list {
		text = "hud." .. name,
		text_align = "C",
		size = 16,
		width = 24,
	}
	return r	
end

return scripts
