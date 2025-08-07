local cache = {}

function cache.table(f)
	local meta = {}
	
	function meta:__index(k)
		local v = f(k)
		self[k] = v
		return v
	end
	
	return setmetatable({}, meta)
end

return cache