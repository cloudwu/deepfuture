local mask = require "soluna.material.mask"
local math = math

global assert

local progress = {}

local BATCH
local SPRITES
local BACKGROUND
local FOREGROUND

local PI <const> = math.pi

function progress.draw(percent, x, y)
	BATCH:layer(x, y)
	if percent <= 0.5 then
		BATCH:add(BACKGROUND)
		BATCH:add(FOREGROUND)
		BATCH:layer(PI * 2 * percent)
		BATCH:add(BACKGROUND)
		BATCH:layer()
		BATCH:layer(PI)
		BATCH:add(BACKGROUND)
		BATCH:layer()
	else
		BATCH:layer(PI)
		BATCH:add(BACKGROUND)
		BATCH:layer()
		BATCH:layer(PI * 2 * (percent - 0.5))
		BATCH:add(FOREGROUND)
		BATCH:layer()
		BATCH:add(BACKGROUND)
		BATCH:add(FOREGROUND)
	end
	BATCH:layer()
end

function progress.init(args)
	BATCH = assert(args.batch)
	SPRITES = assert(args.sprites)
	BACKGROUND = mask.mask(SPRITES.arcb, 0xffffff)
	FOREGROUND = mask.mask(SPRITES.arcf, 0)
end

return progress
