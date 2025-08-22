local soluna = require "soluna"
local widget = require "core.widget"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"

widget.scripts(require "visual.ui")

local initial = require "gameplay.initial"
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

localization.load("localization/schinese.dl", "schinese")
soluna.set_window_title(localization.convert "app.title")

vdesktop.init {
	batch = args.batch,
	font_id = font_init(),
	sprites = soluna.load_sprites "asset/sprites.dl",
	width = args.width,
	height = args.height,
}

local game = {}

function game.start()
	initial.new()
	return "setup"
end

game.setup = require "gameplay.setup"
game.player = require "gameplay.player"
game.action = require "gameplay.action"
game.desc = require "gameplay.desc"

function game.idle()
	return "idle"
end

flow.load(game)
flow.enter "start"

callback.window_resize = vdesktop.flush
callback.mouse_move = vdesktop.mouse_move

local mouse_btn = {
	[0] = "left",
	[1] = "right",
	[2] = "mid",
}

function callback.mouse_button(btn, state)
	focus.mouse_button(mouse_btn[btn], state == 1)
end

function callback.frame(count)
	flow.update()
	vdesktop.card_count(card.count())
	map.update()
	vdesktop.draw(count)
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
