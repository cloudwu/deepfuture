local soluna = require "soluna"
local widget = require "core.widget"
widget.scripts(require "visual.ui")
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local utf8 = utf8

global require, assert, print

local initial = require "gameplay.initial"
local card = require "gameplay.card"
local map = require "gameplay.map"
local persist = require "gameplay.persist"
local localization = require "core.localization"
local config = require "core.rules".ui
local test = require "gameplay.test"

local args = ...

local LANG <const> = "schinese"

local function font_init()
	local font = require "soluna.font"
	local text = require "soluna.text"
	local sysfont = require "soluna.font.system"
	font.import(assert(sysfont.ttfdata (config.lang[LANG].font)))
	text.init "asset/icons.dl"
	return font.name ""
end

local callback = {}

test.init()
localization.load("localization/schinese.dl", LANG)
soluna.set_window_title(localization.convert "app.title")

vdesktop.init {
	batch = args.batch,
	font_id = font_init(),
	sprites = soluna.load_sprites "asset/sprites.dl",
	width = args.width,
	height = args.height,
}

local game = {}

function game.init()
	initial.new()
	return "setup"
end

game.setup = require "gameplay.setup"
game.start = require "gameplay.start"
game.action = require "gameplay.action"

function game.idle()
	return "idle"
end

flow.load(game)
flow.enter "init"

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
	vdesktop.card_count(card.count "draw", card.count "discard")
	map.update()
	vdesktop.draw(count)
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
