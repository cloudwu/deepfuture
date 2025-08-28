local focus = {}

global pairs, print, next

local FOCUS_ACTIVE
local FOCUS_OBJECT
local FOCUS_CLICK = {
	left = {},
	right = {},
}
local FOCUS_QUEUE = {}

function focus.clear()
	if FOCUS_ACTIVE then
		FOCUS_ACTIVE = nil
		FOCUS_OBJECT = nil
	end
end

function focus.trigger(region, object)
	if object then
		-- new focus
		local last = FOCUS_QUEUE[region]
		if last ~= object then
			local n = #FOCUS_QUEUE
			FOCUS_QUEUE[n + 1] = region
			FOCUS_QUEUE[n + 2] = object
			FOCUS_QUEUE[region] = object
		end
	else
		-- clear focus
		FOCUS_QUEUE[region] = nil
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

local function get_current_focus()
	local n = #FOCUS_QUEUE - 1
	local focus, object
	for i = n, 1, -2 do
		local r = FOCUS_QUEUE[i]
		if FOCUS_QUEUE[r] then
			focus = r
			object = FOCUS_QUEUE[i+1]
			break
		end
	end
	if focus then
		-- new focus
		local lost = FOCUS_ACTIVE
		if lost == focus then
			lost = nil
		end
		return focus, object, lost
	else
		if FOCUS_QUEUE[FOCUS_ACTIVE] then
			-- no new focus
			return FOCUS_ACTIVE, FOCUS_OBJECT
		else
			return nil, nil, FOCUS_ACTIVE
		end
	end
end

function focus.get(state)
	local focus, object, lost = get_current_focus()
	state.lost = lost
	if not focus then
		state.object = nil
		return false
	end
	if state.active == focus and
		state.object == object then
		return false
	end
	state.active = focus
	state.object = object
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

function focus.press(btn, region)
	if region and region ~= FOCUS_ACTIVE then
		return
	end
	local state = FOCUS_CLICK[btn]
	if state and state.focus then
		return state.focus, FOCUS_ACTIVE
	end
end

function focus.frame()
	local focus, object = get_current_focus()
	if focus then
		FOCUS_ACTIVE = focus
		FOCUS_OBJECT = object
		if next(FOCUS_QUEUE) then
			FOCUS_QUEUE = {}
		end
		FOCUS_QUEUE = { [focus] = object }
	else
		FOCUS_ACTIVE = nil
		FOCUS_OBJECT = nil
		if next(FOCUS_QUEUE) then
			FOCUS_QUEUE = {}
		end
	end
	
	for k,v in pairs(FOCUS_CLICK) do
		v.click = nil
	end
end

return focus
