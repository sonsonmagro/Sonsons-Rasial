---@version 1.0.1
local version = "1.0.1"
local API = require("api")

--[[
    quick fix for debug
        - utils debug vs config debug
    fix for mentsions in discord webhook
    added extra wait tick before target cycling
    added more room for config execute
    fix kill logging (fastest/slowest kills)
    fiexed not equipping lotd


    TODO: 
    confirm drop alerts are fixed
    seedicide and spring cleaner support
]]

local PlayerManager     = require("core.player_manager")        -- file saved in Lua_Scripts\core

local Config            = require("rasial.config")              -- file saved in Lua_Scripts\rasial
local Utils             = require("rasial.utils")               -- file saved in Lua_Scripts\rasial

API.Write_fake_mouse_do(false)
local scriptStartTime = os.time()
local playerManager, prayerFlicker = PlayerManager.new(Config.playerManager), Config.Instances.prayerFlicker

--#region tracking table generation
local function tracking()
    local metrics = {
        { "Sonson's Rasial", "Version: " .. version },
        { "", "" },
        { "Metrics:",API.ScriptRuntimeString() },
        {"- Status: ", playerManager.state.status} or {},
        {"- Location: ", playerManager.state.location} or {},
        { "- Total Kills (/hr)", Config.Variables.killCount .. string.format(" (%s)", Utils.valuePerHour(Config.Variables.killCount, scriptStartTime)) },
        { "- Total Rares (/hr)", #Config.Data.lootedUniques .. string.format(" (%s)", Utils.valuePerHour(#Config.Data.lootedUniques, scriptStartTime)) },
        { "", "" },
        { "Kill Times:", "" },
        { "- Fastest Kill:", Utils.getKillStats(Config.TrackedKills).fastestKillDuration },
        { "- Slowest Kill:", Utils.getKillStats(Config.TrackedKills).slowestKillDuration },
        { "- Average Kill Time:", Utils.getKillStats(Config.TrackedKills).averageKillDuration }
    }

    -- change this depending on what you want to track whilst debugging
    local trackedDebuggingTables = {
        playerManager:stateTracking(),
        playerManager:managementTracking(),
        playerManager:foodItemsTracking(),
        playerManager:prayerItemsTracking(),
        playerManager:managedBuffsTracking()
    }

    if #Config.Data.lootedUniques > 0 then
        Utils.tableConcat(metrics, { { "", "" } })
        Utils.tableConcat(metrics, { { "Drops:", "" } })
        Utils.tableConcat(metrics, { { "- Name", "Runtime" } })
        Utils.tableConcat(metrics, Config.Data.lootedUniques)
    end

    --view kill details
    if Utils.debug and #Config.TrackedKills > 0 then
        Utils.tableConcat(metrics, { { "", "" } })
        Utils.tableConcat(metrics, { { "Kill Details:", "" } })
        for i, killData in pairs(Config.TrackedKills) do
            Utils.tableConcat(metrics, { { string.format("- [%s] %s", i, killData.runtime), killData.fightDuration } })
        end
    end

    if Utils.debug then 
        for _, table in pairs(trackedDebuggingTables) do
            Utils.tableConcat(metrics, { { "", "" } })
            Utils.tableConcat(metrics, table)
        end
    end

    API.DrawTable(metrics) -- draw table pls
end
--#endregion

--#region main loop
while API.Read_LoopyLoop() do
    playerManager:update()
    if playerManager.state.location ~= "Rasial's Citadel (Boss Room)" then prayerFlicker:deactivatePrayer() end
    -- completely optional stats & metrics
    tracking()
    -- very short zzz
    API.RandomSleep2(10, 10, 10)
end
--#endregion
