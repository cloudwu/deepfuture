local soluna = require "soluna"
local widget = require "core.widget"
--local flow = require "core.flow"
local vdesktop = require "visual.desktop"

widget.scripts(require "visual.ui")

local initial = require "gameplay.initial"
local setup = require "gameplay.setup"
local card = require "gameplay.card"
local map = require "gameplay.map"
local persist = require "gameplay.persist"
local localization = require "core.localization"

local args = ...

local function font_init()
	local font = require "soluna.font"
	local text = require "soluna.text"
	local sysfont = require "soluna.font.system"
	font.import(assert(sysfont.ttfdata "微软雅黑"))
	text.init "asset/icons.dl"
	return font.name ""
end

local callback = {}

local function setup_desktop()
	vdesktop.add("hand", setup.draw_worlds())
	-- todo : choose a world
	local homeworld = setup.new_world()
	vdesktop.add("homeworld", { homeworld })
	local n = setup.neutral( homeworld )
	vdesktop.add("neutral", n)

	for _, card in ipairs(n) do
		map.add_neutral(card.sector, 3)
	end
	map.add_player(homeworld.sector, 3)
end

localization.load("localization/schinese.dl", "schinese")
soluna.set_window_title(localization.convert "app.title")

vdesktop.init {
	batch = args.batch,
	font_id = font_init(),
	sprites = soluna.load_sprites "asset/sprites.dl",
	width = args.width,
	height = args.height,
}

initial.new()
setup_desktop()

callback.window_resize = vdesktop.flush
callback.mouse_move = vdesktop.mouse_move

--function callback.mouse_button(btn, down)
--	if down == 1 then
--	end
--end

function callback.frame(count)
	vdesktop.card_count(card.count())
	map.update()
	vdesktop.draw(count)
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
