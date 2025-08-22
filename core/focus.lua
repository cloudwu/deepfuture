local focus = {}

local FOCUS_ACTIVE
local FOCUS_LOST
local FOCUS_OBJECT
local FOCUS_CLICK = {
	left = {},
	right = {},
}

function focus.clear()
	if FOCUS_ACTIVE then
		FOCUS_LOST = FOCUS_ACTIVE
		FOCUS_ACTIVE = nil
		FOCUS_OBJECT = nil
	end
end

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
					state.click = true
					state.focus = nil
				end
			end
		end
	end
end

function focus.region()
	return FOCUS_ACTIVE
end

function focus.get(state)
	state.lost = FOCUS_LOST
	if not FOCUS_ACTIVE then
		state.object = nil
		return false
	end
	if state.active == FOCUS_ACTIVE and
		state.object == FOCUS_OBJECT then
		return false
	end
	state.active = FOCUS_ACTIVE
	state.object = FOCUS_OBJECT
	return true
end

function focus.click(btn, region)
	if region and region ~= FOCUS_ACTIVE then
		return
	end
	local state = FOCUS_CLICK[btn]
	if state and state.click then
		return FOCUS_OBJECT, FOCUS_ACTIVE
	end
end

function focus.frame()
	for k,v in pairs(FOCUS_CLICK) do
		v.click = nil
	end
	FOCUS_LOST = nil
end

return focus
