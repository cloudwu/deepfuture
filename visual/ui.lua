--[[
				name :
					text : hud.C
					size : 20
					width : 30
				grid :
					text : hud.mark
					env : mark_C1
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C2
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C3
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C4
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C5
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C6
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C7
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C8
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C9
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C10
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C11
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
				grid :
					text : hud.mark
					env : mark_C12
					text_align : C
					size : 20
					width : 30
					background : 0x40000000
				grid :
					text : hud.mark
					env : mark_C13
					text_align : C
					size : 20
					width : 30
					background : 0x40ffffff
]]


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
	0x40ffffff,
	0x40000000,
}

local scripts = {}

function scripts.hud(name)
	local r = {}
	local n = 1
	r[n] = "name"
	r[n+1] = table_to_list {
		text = "hud." .. name,
		size = 18,
		width = 25,
	}
	n = n + 2
	local mark_prefix = "mark_"..name
	local c = 1
	for i = 1, 13 do
		r[n] = "grid"
		r[n+1] = table_to_list {
			text = "hud.mark",
			env = mark_prefix .. i,
			text_align = "C",
			size = 18,
			width = 25,
			background = colors[c],
		}
		c = 3-c
		n = n + 2
	end
	return r	
end

return scripts
