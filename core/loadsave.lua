local ltask = require "ltask"
local persist = require "gameplay.persist"
local math = math

-- see service/save.lua
local SERVICE = ltask.uniqueservice "service.save"

global ipairs, print, print_r, require

local M = {}
local PROFILE

function M.load_game()
	local ok, data = ltask.call(SERVICE, "load_game", PROFILE)
	if ok then
		persist.init("deck", data.deck)
		persist.init("history", data.history)
		persist.init("game", data.game)
		persist.init("track", data.track)
		persist.init("galaxy", data.galaxy)
		persist.init("map", data.map)
		-- 加载卡片并重新生成描述信息
		local card = require "gameplay.card"
		card.load()
		local track = require "gameplay.track"
		track.load()
		local map = require "gameplay.map"
		map.load()
		-- 返回保存的游戏阶段
		return true, data.game.phase
	else
		return false
	end
end

function M.save_game()
	ltask.send(SERVICE, "save_game", PROFILE)
end

function M.sync_game(phase)
	local track = persist.get "track"
	local map = persist.get "galaxy"
	local game = persist.get "game"
	local seed = game.seed
	if not seed then
		seed = math.random(2^31)
	else
		-- seed from file, clear it
		game.seed = nil
	end
	math.randomseed(seed)
	-- todo : multiple profile
	ltask.send(SERVICE, "sync_game", PROFILE, {
		map = map,
		track = track,
		game = game,
		phase = phase,
		seed = seed,
	})
	M.save_game()
end

function M.sync_history()
	local history = persist.get "history"
	ltask.send(SERVICE, "sync_history", PROFILE, history)
end

function M.sync_card(...)
	ltask.send(SERVICE, "sync_card", PROFILE, ...)
end

function M.sync_map()
	local map = persist.get "map"
	ltask.send(SERVICE, "sync_map", PROFILE, map)
end

function M.init_deck()
	ltask.send(SERVICE, "init_deck", PROFILE)
end

function M.new_profile(name, filename)
	PROFILE = name
	ltask.send(SERVICE, "new_profile", name, filename)
end

return M
