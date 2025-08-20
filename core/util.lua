local util = {}

function util.cache(f)
	local meta = {}
	
	function meta:__index(k)
		local v = f(k)
		self[k] = v
		return v
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

return util