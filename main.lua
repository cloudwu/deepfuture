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

-- 解析启动参数中的语言设置，默认使用schinese
local function parse_language()
	local settings = soluna.settings()
	local lang = settings.lang or "schinese"  -- 默认语言
	
	-- 检查语言文件是否存在
	local file = io.open("localization/" .. lang .. ".dl", "r")
	if file then
		file:close()
		print("Using language: " .. lang)
		return lang
	else
		print("Language file not found: " .. lang .. ".dl, falling back to schinese")
		return "schinese"
	end
end

local LANG <const> = parse_language()

local function font_init()
	local font = require "soluna.font"
	local text = require "soluna.text"
	local sysfont = require "soluna.font.system"
	font.import(assert(sysfont.ttfdata (config.lang[LANG].font)))
	text.init "asset/icons.dl"
	return font.name ""
end

local callback = {}

localization.load("localization/" .. LANG .. ".dl", LANG)
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
game.nextgame = require "gameplay.nextgame"

function game.idle()
	return "idle"
end

flow.load(game)

local function run_game()
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
-- todo : name card
--	print("Char", c, utf8.char(c))
end

return callback
