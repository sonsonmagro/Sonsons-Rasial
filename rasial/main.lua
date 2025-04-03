---@version 1.0.0
local version = "1.0.0"
local API = require("api")

--[[

]]

local PlayerManager     = require("core.player_manager")        -- file saved in Lua_Scripts\core

local Config            = require("rasial.config")              -- file saved in Lua_Scripts\rasial
local Utils             = require("rasial.utils")               -- file saved in Lua_Scripts\rasial

API.Write_fake_mouse_do(false)
local scriptStartTime = os.time()
local playerManager, prayerFlicker = PlayerManager.new(Config.playerManager), Config.Instances.prayerFlicker

--#region tracking table generation
local function tracking(...)
    local args = { ... }
    local metrics = {
        { "Sonson's Rasial", "Version: " .. version },
        { "", "" },
        { "Metrics:",API.ScriptRuntimeString() },
        not Config.UserInput.debug and {"- Status: ", playerManager.state.status},
        not Config.UserInput.debug and {"- Location: ", playerManager.state.location},
        { "- Total Kills (/hr)", Config.Variables.killCount .. string.format(" (%s)", Utils.valuePerHour(Config.Variables.killCount, scriptStartTime)) },
        { "- Total Rares (/hr)", #Config.Data.lootedUniques .. string.format(" (%s)", Utils.valuePerHour(#Config.Data.lootedUniques, scriptStartTime)) },
        { "", "" },
        { "Kill Times:", "" },
        { "- Fastest Kill:", Utils.getKillStats(Config.TrackedKills).fastestKillDuration },
        { "- Slowest Kill:", Utils.getKillStats(Config.TrackedKills).slowestKillDuration },
        { "- Average Kill Time:", Utils.getKillStats(Config.TrackedKills).averageKillDuration }
    }
    local debuggingTable = {
        { "Debugging:" },
        --{ "- Spellbook",  Utils.getSpellbook() },
    }

    if #Config.Data.lootedUniques > 0 then
        Utils.tableConcat(metrics, { { "", "" } })
        Utils.tableConcat(metrics, { { "Drops:", "" } })
        Utils.tableConcat(metrics, { { "- Name", "Runtime" } })
        Utils.tableConcat(metrics, Config.Data.lootedUniques)
    end

    if Config.UserInput.debug then 
    for _, table in pairs(args) do
            Utils.tableConcat(metrics, { { "", "" } })
            Utils.tableConcat(metrics, table)
        end

        Utils.tableConcat(metrics, { { "", "" } })
        Utils.tableConcat(metrics, debuggingTable)
    end

    API.DrawTable(metrics) -- draw table pls
end
--#endregion

--#region main loop
while API.Read_LoopyLoop() do
    playerManager:update()
    if playerManager.state.location ~= "Rasial's Citadel (Boss Room)" then prayerFlicker:deactivatePrayer() end
    -- completely optional stats & metrics
    tracking(
        -- player manager tracking
        Config.UserInput.debug and playerManager:stateTracking(),
        Config.UserInput.debug and playerManager:managementTracking(),
        Config.UserInput.debug and playerManager:foodItemsTracking(),
        Config.UserInput.debug and playerManager:prayerItemsTracking(),
        Config.UserInput.debug and playerManager:activeBuffsTracking(),
        Config.UserInput.debug and playerManager:managedBuffsTracking(),
        --prayer flicker tracking
        Config.UserInput.debug and prayerFlicker:tracking()
    )
    -- very short zzz
    API.RandomSleep2(10, 10, 10)
end
--#endregion
