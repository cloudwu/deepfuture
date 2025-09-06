local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local focus = require "core.focus"
local card = require "gameplay.card"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local victory = require "gameplay.victory"
local track = require "gameplay.track"
local map = require "gameplay.map"

local function clear(where)
	local n = 1
	while true do
		local c = card.card(where, n)
		if c == nil then
			return
		end
		n = n + 1
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
end

return function()
	loadsave.sync_game "win"
	sync()
	
	print("=== VICTORY! ===")
	
	-- 显示胜利屏幕
	vdesktop.show_victory(true)
	
	-- 从persist中获取胜利信息
	local persist = require "gameplay.persist"
	local victory_info = persist.get "victory_info"
	
	if not victory_info then
		print("ERROR: No victory_info found in persist!")
		-- 创建默认胜利信息
		victory_info = {
			type = "unknown",
			name = "unknown"
		}
	end
	
	if victory_info.type == "track" then
		print("Victory track:", victory_info.track)
	end
	
	-- 设置胜利信息显示
	local victory_text = "$(tips.victory." .. victory_info.name .. ")"
	if victory_info.type == "track" then
		victory_text = "$(tips.victory.track." .. victory_info.track .. ")"
	end
	
	vdesktop.set_text("phase", {
		text = "$(phase.victory)",
		extra = victory_text
	})
	
	-- 显示重新开始按钮
	local button = {
		text = "button.restart",
	}
	vdesktop.button_enable("button1", button)
	
	-- 等待玩家选择
	while true do
		local c, btn = focus.click "left"
		if btn == "button1" then
			break
		end
		flow.sleep(0)
	end
	
	vdesktop.button_enable("button1", nil)
	card.next_turn()
	vdesktop.set_text("phase", { extra = false })
	
	-- 清理牌区并重新设置
	clear "hand"
	clear "homeworld"
	clear "colony"
	clear "neutral"
	card.setup()
	track.setup()
	map.setup()
	
	-- 隐藏胜利屏幕
	vdesktop.show_victory(false)
	
	return "setup"
end
