--[[=========================================================================
  DurabilityAnchor  v1.9
  修理不降低耐久上限。

  原理：
    UE5.6 的耐久上限不存盘（物品 CurrentStats 里 Durability 的 MaxValue 恒为 -1），
    而是每次修理时由 URepairRules::GetRepairPenalty 现算：
        惩罚   = RepairPenaltyBaseValue(默认 5) × RepairPenaltyCurve(默认 1.0)
        新上限 = 100 − 惩罚
    本 mod 只在内存里把 RepairPenaltyBaseValue 置 0，并每 1.5 秒巡检一次
    （重进地图 / 重载资源后会被重置，所以需要反复确认）。
    不挂任何 hook —— 该版本 UE4SS 对蓝图函数的 post 回调会崩游戏。

  规则对象：/Game/Blueprints/InventorySystem/Data/Repair/DA_RepairSettings
            BP_RepairRules_Weapons_C、BP_RepairRules_Gear_C（都继承 Master）
=========================================================================]]

local MOD_NAME = "DurabilityAnchor"
local VERSION = "1.9"

-- 日志：直接 print，UE4SS 会写进 ue4ss/UE4SS.log（无需任何路径推导）
local function Log(fmt, ...)
    local msg
    if select('#', ...) > 0 then
        local ok, s = pcall(string.format, fmt, ...)
        msg = ok and s or (tostring(fmt) .. " <fmt err>")
    else
        msg = tostring(fmt)
    end
    pcall(print, "[" .. MOD_NAME .. "] " .. msg .. "\n")
end

local function Try(fn, ...)
    local r = { pcall(fn, ...) }
    if r[1] then return true, r[2] end
    return false, r[2]
end

local function Num(v)
    if type(v) == "number" then return v end
    if type(v) == "userdata" then
        local ok, val = pcall(function() return v:get() end)
        if ok and type(val) == "number" then return val end
    end
    return nil
end

local function ArrLen(a)
    local ok, n = Try(function() return #a end)
    if ok and type(n) == "number" and n > 0 then return n end
    local ok2, n2 = Try(function() return a:GetArrayNum() end)
    if ok2 and type(n2) == "number" then return n2 end
    return 0
end

local function ArrGet(a, i)
    local ok, v = Try(function() return a[i] end)
    if ok and v ~= nil then return v end
    local ok2, v2 = Try(function() return a:Get(i) end)
    if ok2 then return v2 end
    return nil
end

local function FullName(u)
    local ok, s = Try(function() return u:GetFullName() end)
    return ok and tostring(s) or "?"
end

---------------------------------------------------------------- 核心
local CLASSES = { "RepairRules", "BP_RepairRules_Master_C", "BP_RepairRules_Weapons_C", "BP_RepairRules_Gear_C" }

local function FixRules()
    local changed = 0
    for _, cn in ipairs(CLASSES) do
        local ok, arr = Try(FindAllOf, cn)
        if ok and arr then
            local n = ArrLen(arr)
            for i = 1, n do
                local u = ArrGet(arr, i)
                if u then
                    local okb, base = Try(function() return u.RepairPenaltyBaseValue end)
                    local bn = Num(base)
                    if okb and bn and bn > 0 then
                        Try(function() u.RepairPenaltyBaseValue = 0.0 end)
                        local _, after = Try(function() return u.RepairPenaltyBaseValue end)
                        Log("[FIX] %s  惩罚基数 %.3f -> %s",
                            FullName(u), bn, tostring(Num(after) or "?"))
                        changed = changed + 1
                    end
                end
            end
        end
    end
    return changed
end

---------------------------------------------------------------- 启动
Log("============ %s v%s 载入 ============", MOD_NAME, VERSION)

local round = 0
local total = 0
LoopAsync(1500, function()
    round = round + 1
    local c = FixRules()
    total = total + c
    if c > 0 and round > 2 then
        Log("[T] 第 %d 轮重新清零 %d 处", round, c)
    end
    return false
end)
