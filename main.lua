local soluna = require "soluna"
local widget = require "core.widget"
widget.scripts(require "visual.ui")
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local initial = require "gameplay.initial"
local card = require "gameplay.card"
local map = require "gameplay.map"
local persist = require "gameplay.persist"
local localization = require "core.localization"
local config = require "core.rules".ui
local test = require "gameplay.test"
local loadsave = require "core.loadsave"
local track = require "gameplay.track"
local vbutton = require "visual.button"
local mouse = require "core.mouse"

local utf8 = utf8
local math = math
local io = io
global require, assert, print

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
	
	card.setup()
	track.setup()
	map.setup()
	
	return "setup"
end

function game.load()
	card.load()
	track.load()
	map.load()
	local game = persist.get "game"
	if game then
		return game.phase
	else
		return "setup"
	end
end

game.setup = require "gameplay.setup"
game.start = require "gameplay.start"
game.action = require "gameplay.action"
game.payment = require "gameplay.payment"
game.challenge = require "gameplay.challenge"
game.loss = require "gameplay.loss"
game.power = require "gameplay.power"
game.advance = require "gameplay.advance"
game.grow = require "gameplay.grow"
game.settle = require "gameplay.settle"
game.battle = require "gameplay.battle"
game.expand = require "gameplay.expand"
game.freepower = require "gameplay.freepower"
game.freeadvance = require "gameplay.advance"
game.win = require "gameplay.win"

function game.idle()
	return "idle"
end

flow.load(game)

local function run_game()
	print("Xhacker test run game log");
	if test.init() then
		-- don't touch savefile when test
		card.profile "TEST"
		flow.enter "init"
		return
	end
	local dir = soluna.gamedir "deepfuture"
	card.profile("GAME", dir .. "save.txt")
	local ok, phase = loadsave.load_game()
	if ok then
		flow.enter(phase or "start")
	else
		flow.enter "init"
	end
end

run_game()

callback.window_resize = vdesktop.flush
function callback.mouse_move(x, y)
	mouse.mouse_move(x, y)
--	vdesktop.mouse_move(x, y)
end

local mouse_btn = {
	[0] = "left",
	[1] = "right",
	[2] = "mid",
}

function callback.mouse_button(btn, state)
	btn = mouse_btn[btn]
	state = state == 1
	mouse.mouse_button(btn, state)
end

function callback.frame(count)
	local x, y = mouse.sync(count)
	vdesktop.mouse_move(x, y)
	flow.update()
	vdesktop.card_count(card.count "draw", card.count "discard", card.seen())
	map.update()
	vdesktop.draw(count)
	mouse.frame()
end

function callback.char(c)
	print("Char", c, utf8.char(c))
end

return callback
