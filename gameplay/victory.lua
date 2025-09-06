local card = require "gameplay.card"
local track = require "gameplay.track"
local map = require "gameplay.map"
local rules = require "core.rules".track
local persist = require "gameplay.persist"

local victory = {}

-- 胜利条件常量
local VICTORY_REQUIREMENTS = {
    TERRITORY_SECTORS = 12,  -- 领土胜利需要控制的星区数
    POPULATION_CUBES = 25,   -- 人口胜利需要的方块数
    REQUIRED_TECHS = 3,      -- 需要的完整技术数量
}

-- 检查是否有母星世界
local function has_homeworld()
    local homeworld = card.card("homeworld", 1)
    return homeworld and homeworld.type == "world"
end

-- 检查完整技术数量
local function count_complete_techs()
    local count = 0
    local n = 1
    while true do
        local c = card.card("homeworld", n)
        if not c then
            break
        end
        if c.type == "tech" and card.complete(c) then
            count = count + 1
        end
        n = n + 1
    end
    
    -- 检查殖民地中的技术
    n = 1
    while true do
        local c = card.card("colony", n)
        if not c then
            break
        end
        if c.type == "tech" and card.complete(c) then
            count = count + 1
        end
        n = n + 1
    end
    
    return count
end

-- 调试函数：手动触发胜利检查
function victory.debug_check()
    print("=== MANUAL VICTORY DEBUG CHECK ===")
    local result = victory.check()
    if result then
        print("Victory detected:", result.type, result.name)
    else
        print("No victory detected")
    end
    return result
end

-- 检查轨道胜利
local function check_track_victory()
    local TRACK = persist.get "track"
    print("TRACK data:", TRACK)
    if not TRACK then
        print("No TRACK data found")
        return nil
    end
    
    for track_type, position in pairs(TRACK) do
        local rule = rules[track_type]
        print("Checking track:", track_type, "position:", position, "win position:", rule and rule.win)
        if rule and rule.win and position == rule.win then
            print("VICTORY FOUND on track:", track_type)
            return track_type
        end
    end
    print("No track victory found")
    return nil
end

-- 检查领土胜利
local function check_territory_victory()
    local territory = map.territory()
    if not territory then
        return false
    end
    
    local sector_count = 0
    for _ in pairs(territory) do
        sector_count = sector_count + 1
    end
    
    return sector_count >= VICTORY_REQUIREMENTS.TERRITORY_SECTORS
end

-- 检查人口胜利
local function check_population_victory()
    local territory = map.territory()
    if not territory then
        return false
    end
    
    local total_cubes = 0
    for _, cubes in pairs(territory) do
        total_cubes = total_cubes + cubes
    end
    
    return total_cubes >= VICTORY_REQUIREMENTS.POPULATION_CUBES
end

-- 主胜利检查函数
function victory.check()
    print("=== VICTORY CHECK START ===")
    
    -- 检查基础要求
    local homeworld_ok = has_homeworld()
    print("Has homeworld:", homeworld_ok)
    if not homeworld_ok then
        print("=== VICTORY CHECK END: No homeworld ===")
        return nil
    end
    
    local tech_count = count_complete_techs()
    print("Tech count:", tech_count, "Required:", VICTORY_REQUIREMENTS.REQUIRED_TECHS)
    if tech_count < VICTORY_REQUIREMENTS.REQUIRED_TECHS then
        print("=== VICTORY CHECK END: Not enough techs ===")
        return nil
    end
    
    -- 检查各种胜利条件
    local track_win = check_track_victory()
    print("Track victory result:", track_win)
    if track_win then
        local result = {
            type = "track",
            track = track_win,
            name = track_win == "C" and "culture" or
                   track_win == "M" and "might" or
                   track_win == "S" and "stability" or
                   track_win == "X" and "xeno" or
                   "unknown"
        }
        print("=== VICTORY CHECK END: Track victory ===", result.name)
        return result
    end
    
    local territory_win = check_territory_victory()
    print("Territory victory result:", territory_win)
    if territory_win then
        print("=== VICTORY CHECK END: Territory victory ===")
        return {
            type = "territory",
            name = "territory"
        }
    end
    
    local population_win = check_population_victory()
    print("Population victory result:", population_win)
    if population_win then
        print("=== VICTORY CHECK END: Population victory ===")
        return {
            type = "population", 
            name = "population"
        }
    end
    
    print("=== VICTORY CHECK END: No victory conditions met ===")
    return nil
end

-- 获取胜利进度信息（用于UI显示）
function victory.progress()
    return {
        homeworld = has_homeworld(),
        tech_count = count_complete_techs(),
        required_techs = VICTORY_REQUIREMENTS.REQUIRED_TECHS,
        territory_count = map.territory() and (function()
            local count = 0
            for _ in pairs(map.territory()) do count = count + 1 end
            return count
        end)() or 0,
        territory_required = VICTORY_REQUIREMENTS.TERRITORY_SECTORS,
        population_count = map.territory() and (function()
            local total = 0
            for _, cubes in pairs(map.territory()) do total = total + cubes end
            return total
        end)() or 0,
        population_required = VICTORY_REQUIREMENTS.POPULATION_CUBES,
        tracks = persist.get "track"
    }
end

return victory
