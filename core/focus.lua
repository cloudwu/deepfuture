local focus = {}

local FOCUS_ACTIVE
local FOCUS_LOST
local FOCUS_OBJECT
local FOCUS_CLICK = {
	left = {},
	right = {},
}

function focus.trigger(region, object)
	if object then
		if FOCUS_ACTIVE ~= region then
			FOCUS_LOST = FOCUS_ACTIVE
			FOCUS_ACTIVE = region
		end
		FOCUS_OBJECT = object
	elseif FOCUS_ACTIVE == region then
		FOCUS_ACTIVE = nil
		FOCUS_LOST = region
		FOCUS_OBJECT = nil
	end
end

do
	local mouse_down
	local mouse_click
	function focus.mouse_button(btn, down)
		local state = FOCUS_CLICK[btn]
		if state then
			if down then
				state.focus = FOCUS_OBJECT
			else
				if state.focus == FOCUS_OBJECT then
					state.click = FOCUS_OBJECT
					state.focus = nil
				end
			end
		end
	end
end

function focus.region()
	return FOCUS_ACTIVE
end

function focus.click(btn)
	local state = FOCUS_CLICK[btn]
	if state then
		return state.click == FOCUS_OBJECT
	end
end

function focus.dispatch(f)
	if FOCUS_LOST then
		local lost = f[FOCUS_LOST]
		if lost then
			lost(FOCUS_LOST)
		end
	end
	if FOCUS_ACTIVE then
		local active = f[FOCUS_ACTIVE]
		if active then
			active(FOCUS_ACTIVE, FOCUS_OBJECT)
		end
	end
	for k,v in pairs(FOCUS_CLICK) do
		v.click = nil
	end
end

return focus
