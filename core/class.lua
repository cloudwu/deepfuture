local class = {}; setmetatable(class, class)

function class:__index(name)
	local class_methods = {}; class_methods.__index = class_methods
	local class_object = {}
	local class_meta = {
		__newindex = class_methods,
		__index = class_methods,
		__call = function(self, init)
			return setmetatable(init or {}, class_methods)
		end
	}
	class[name] = setmetatable(class_object, class_meta)
	return class_object
end

local class = { __index = class }; setmetatable(class, class)

function class:__call(name)
	return self[name]
end

local function container_next(self, k)
	local nk, v = next(self, k)
	if nk == false then
		return next(self, false)
	else
		return nk, v
	end
end

function class.container(name)
	local container_class = class[name]
	function container_class:__pairs()
		return container_next, self
	end
	return container_class	
end

return class
