local soluna = require "soluna"
local widget = require "core.widget"
widget.scripts(require "visual.ui")
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local initial = require "gameplay.initial"
local card = require "gameplay.card"
local map = require "gameplay.map"
local persist = require "gameplay.persist"
local language = require "core.language"
local localization = require "core.localization"
local config = require "core.rules".ui
local test = require "gameplay.test"
local loadsave = require "core.loadsave"
local track = require "gameplay.track"
local vbutton = require "visual.button"
local mouse = require "core.mouse"
local text = require "soluna.text"
local setting =require "core.setting"

local utf8 = utf8
local math = math
local io = io
global require, assert, print

local args = ...

text.init "asset/icons.dl"
language.init()
local app_setting = setting.load()

local LANG <const> = app_setting.language or language.get_default()

local callback = {}

language.switch(LANG)
soluna.set_window_title(localization.convert "app.title")

vdesktop.init {
	batch = args.batch,
	font_id = language.font_id(LANG),
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
	
	return flow.state.setup
end

function game.load()
	local dir = setting.path()
	card.profile("GAME", dir .. "save.txt")
	local ok, phase = loadsave.load_game()
	if ok then
		return phase or "start"
	else
		flow.enter "init"
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
game.freeadvance = require "gameplay.freeadvance"
game.win = require "gameplay.win"
game.nextgame = require "gameplay.nextgame"
game.chooselang = require "gameplay.chooselang"

function game.idle()
	return flow.state.idle
end

flow.load(game)

local function run_game()
	if test.init() then
		-- don't touch savefile when test
		card.profile "TEST"
		flow.enter "init"
		return
	end
	if app_setting.language == nil then
		flow.enter "chooselang"
	else
		flow.enter "load"
	end
end

run_game()

callback.window_resize = vdesktop.flush
function callback.mouse_move(x, y)
	mouse.mouse_move(x, y)
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
	vdesktop.set_mouse(x, y)
	flow.update()
	-- todo :  don't flush card here
	vdesktop.card_count(card.count "draw", card.count "discard", card.seen())
	map.update()
	vdesktop.draw(count)
	mouse.frame()
end

function callback.char(c)
	local c = utf8.char(c)
	if c == "e" then
		language.switch_flush "english"
	elseif c == "c" then
		language.switch_flush "schinese"
	end
-- todo : name card
--	print("Char", c)
end

return callback
