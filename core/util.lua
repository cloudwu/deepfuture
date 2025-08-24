local util = {}

global type, getmetatable, setmetatable

-- todo: flush all cache (change localization)
function util.cache(f)
	local meta
	if type(f) == "function" then
		meta = {}
		function meta:__index(k)
			local v = f(k)
			self[k] = v
			return v
		end
	else
		meta = getmetatable(f)
	end
	
	return setmetatable({}, meta)
end

function util.map(func)
	return function(list)
		local r = {}
		for i = 1, #list do
			local key = list[i]
			r[key] = func(key)
		end
		return r
	end
end

local dirty_flag = {}

function util.dirty_update(f)
	local function update(...)
		if dirty_flag[update] then
			dirty_flag[update] = nil
			return f(...)
		end
	end
	dirty_flag[update] = true
	return update
end

function util.dirty_trigger(update)
	dirty_flag[update] = true
end

return util