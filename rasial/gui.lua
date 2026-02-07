--- @module 'rasial.gui'
--- @version 1.1.0
--- Rasial boss GUI — built on Sonson's GUI Library.
---@diagnostic disable: undefined-global
local API = require("api")
local Presets = require("rasial.presets")
local GUILib = require("core.gui_lib")

local RasialGUI = {}

------------------------------------------
-- # STATE MANAGEMENT
------------------------------------------

RasialGUI.open = true
RasialGUI.started = false
RasialGUI.paused = false
RasialGUI.stopped = false
RasialGUI.cancelled = false
RasialGUI.warnings = {}
RasialGUI.selectInfoTab = false
RasialGUI.selectWarningsTab = false

------------------------------------------
-- # CONFIGURATION STATE
------------------------------------------

RasialGUI.config = {
    -- Preset selections
    inventoryPresetIndex = 1, -- 1-based index into inventoryPresetNames
    equipmentPresetIndex = 1, -- 1-based index into equipmentPresetNames
    rotationPresetIndex = 1, -- 1-based index into rotationPresetNames
    buffsPresetIndex = 1, -- 1-based index into buffsPresetNames

    -- General settings
    bankPin = "",
    waitForFullHp = true,
    useDiscord = true,

    -- Health thresholds (percent)
    healthSolid = 0,
    healthJellyfish = 40,
    healthPotion = 40,
    healthSpecial = 60,

    -- Prayer thresholds
    prayerNormal = 200,
    prayerCritical = 10,
    prayerSpecial = 600,

    -- War's Retreat options
    summonConjures = true,
    useAdrenCrystal = true,
    bankIfInvFull = false,
    advancedMovement = false,
    surgeDiveChance = 100,
    minPrayer = 80,
    minSummoning = 80,
    minHealth = 80,

    -- Debug options
    debugMain = true,
    debugTimer = false,
    debugRotation = false,
    debugPlayer = false,
    debugPrayer = false,
    debugWars = false,

    -- War's Retreat task order
    warsTaskOrder = nil, -- Will be initialized to DEFAULT_TASK_ORDER in loadConfig
    warsTaskOrderSelectedIndex = 1
}

------------------------------------------
-- # PRESET LISTS
------------------------------------------

local inventoryPresetNames = Presets.getInventoryPresetNames()
local equipmentPresetNames = Presets.getEquipmentPresetNames()
local rotationPresetNames = Presets.getRotationPresetNames()
local buffsPresetNames = Presets.getBuffsPresetNames()

--------------------------------------------------------------------------------
-- GUI LIBRARY INSTANCE
--------------------------------------------------------------------------------

local ui = GUILib.new()

------------------------------------------
-- # STATE COLORS (dynamic per-state)
------------------------------------------

local STATE_COLORS = {
    ["War's Retreat"] = {0.3, 0.8, 0.4},
    ["Rasial Lobby"] = {0.6, 0.4, 0.8},
    ["Phase 1"] = {1.0, 0.8, 0.2},
    ["Phase 2"] = {1.0, 0.5, 0.3},
    ["Looting"] = {0.8, 0.5, 1.0},
    ["Teleporting"] = {0.6, 0.9, 1.0},
    ["Dead"] = {0.5, 0.5, 0.5},
    ["Idle"] = {0.7, 0.7, 0.7},
    ["Paused"] = {1.0, 0.8, 0.2},
    ["Entering Fight"] = {0.5, 0.3, 0.7}
}

------------------------------------------
-- # CONFIG FILE MANAGEMENT
------------------------------------------

local CONFIG_DIR = os.getenv("USERPROFILE") ..
                       "\\MemoryError\\Lua_Scripts\\configs\\"
local CONFIG_PATH = CONFIG_DIR .. "rasial.config.json"
local STATS_PATH = CONFIG_DIR .. "rasial.stats.json"
local PRESETS_DIR = os.getenv("USERPROFILE") ..
                        "\\MemoryError\\Lua_Scripts\\presets\\"

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveConfigToFile(cfg)
    local data = {
        InventoryPreset = inventoryPresetNames[cfg.inventoryPresetIndex],
        EquipmentPreset = equipmentPresetNames[cfg.equipmentPresetIndex],
        RotationPreset = rotationPresetNames[cfg.rotationPresetIndex],
        BuffsPreset = buffsPresetNames[cfg.buffsPresetIndex],
        BankPin = cfg.bankPin,
        WaitForFullHp = cfg.waitForFullHp,
        UseDiscord = cfg.useDiscord,
        HealthSolid = cfg.healthSolid,
        HealthJellyfish = cfg.healthJellyfish,
        HealthPotion = cfg.healthPotion,
        HealthSpecial = cfg.healthSpecial,
        PrayerNormal = cfg.prayerNormal,
        PrayerCritical = cfg.prayerCritical,
        PrayerSpecial = cfg.prayerSpecial,
        SummonConjures = cfg.summonConjures,
        UseAdrenCrystal = cfg.useAdrenCrystal,
        BankIfInvFull = cfg.bankIfInvFull,
        AdvancedMovement = cfg.advancedMovement,
        SurgeDiveChance = cfg.surgeDiveChance,
        MinPrayer = cfg.minPrayer,
        MinSummoning = cfg.minSummoning,
        MinHealth = cfg.minHealth,
        DebugMain = cfg.debugMain,
        DebugTimer = cfg.debugTimer,
        DebugRotation = cfg.debugRotation,
        DebugPlayer = cfg.debugPlayer,
        DebugPrayer = cfg.debugPrayer,
        DebugWars = cfg.debugWars,
        WarsTaskOrder = cfg.warsTaskOrder
    }
    local ok, json = pcall(API.JsonEncode, data)
    if not ok or not json then
        API.printlua("Failed to encode config JSON", 4, false)
        return
    end
    os.execute('mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" 2>nul')
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        API.printlua("Failed to open config file for writing", 4, false)
        return
    end
    file:write(json)
    file:close()
    API.printlua("Config saved", 0, false)
end

local function findPresetIndex(presetName, presetList)
    if not presetName then return 1 end
    for i, name in ipairs(presetList) do
        if name == presetName then return i end
    end
    return 1
end

------------------------------------------
-- # PRESET MANAGEMENT
------------------------------------------

--- Available configuration presets
local availablePresets = {"Default"}
local selectedPresetIndex = 1
local newPresetName = ""

--- Load preset names by scanning PRESETS_DIR for .json files
local function loadPresetList()
    availablePresets = {"Default"}
    local handle = io.popen('dir /b "' .. PRESETS_DIR .. 'rasial_*.json" 2>nul')
    if handle then
        for filename in handle:lines() do
            local name = filename:match("^rasial_(.+)%.json$")
            if name and name ~= "Default" then
                table.insert(availablePresets, name)
            end
        end
        handle:close()
    end
    table.sort(availablePresets)
end

--- Save the current configuration as a preset
--- @param name string Preset name
--- @param config table Configuration to save
--- @return boolean success
local function saveConfigurationPreset(name, config)
    os.execute('mkdir "' .. PRESETS_DIR:gsub("/", "\\") .. '" 2>nul')
    local path = PRESETS_DIR .. "rasial_" .. name .. ".json"

    local presetData = {
        InventoryPreset = inventoryPresetNames[config.inventoryPresetIndex],
        EquipmentPreset = equipmentPresetNames[config.equipmentPresetIndex],
        RotationPreset = rotationPresetNames[config.rotationPresetIndex],
        BuffsPreset = buffsPresetNames[config.buffsPresetIndex],
        BankPin = config.bankPin,
        WaitForFullHp = config.waitForFullHp,
        UseDiscord = config.useDiscord,
        HealthSolid = config.healthSolid,
        HealthJellyfish = config.healthJellyfish,
        HealthPotion = config.healthPotion,
        HealthSpecial = config.healthSpecial,
        PrayerNormal = config.prayerNormal,
        PrayerCritical = config.prayerCritical,
        PrayerSpecial = config.prayerSpecial,
        SummonConjures = config.summonConjures,
        UseAdrenCrystal = config.useAdrenCrystal,
        BankIfInvFull = config.bankIfInvFull,
        AdvancedMovement = config.advancedMovement,
        SurgeDiveChance = config.surgeDiveChance,
        MinPrayer = config.minPrayer,
        MinSummoning = config.minSummoning,
        MinHealth = config.minHealth,
        DebugMain = config.debugMain,
        DebugTimer = config.debugTimer,
        DebugRotation = config.debugRotation,
        DebugPlayer = config.debugPlayer,
        DebugPrayer = config.debugPrayer
    }

    local ok, json = pcall(API.JsonEncode, presetData)
    if not ok or not json then
        API.printlua("Failed to encode preset JSON", 4, false)
        return false
    end

    local file = io.open(path, "w")
    if not file then
        API.printlua("Failed to open preset file for writing", 4, false)
        return false
    end

    file:write(json)
    file:close()
    loadPresetList()
    API.printlua("Configuration preset '" .. name .. "' saved", 0, false)
    return true
end

--- Load a configuration preset by name
--- @param name string Preset name
--- @return table|nil Loaded preset data or nil
local function loadConfigurationPreset(name)
    if name == "Default" then return nil end

    local path = PRESETS_DIR .. "rasial_" .. name .. ".json"
    local file = io.open(path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end

    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

--- Delete a configuration preset
--- @param name string Preset name
--- @return boolean success
local function deleteConfigurationPreset(name)
    if name == "Default" then return false end

    local path = PRESETS_DIR .. "rasial_" .. name .. ".json"
    local result = os.remove(path)
    if result then
        loadPresetList()
        API.printlua("Configuration preset '" .. name .. "' deleted", 0, false)
    end
    return result ~= nil
end

------------------------------------------
-- # PUBLIC FUNCTIONS
------------------------------------------

function RasialGUI.reset()
    RasialGUI.open = true
    RasialGUI.started = false
    RasialGUI.paused = false
    RasialGUI.stopped = false
    RasialGUI.cancelled = false
    RasialGUI.warnings = {}
    RasialGUI.selectInfoTab = false
    RasialGUI.selectWarningsTab = false
end

--- Migrates old task order format (DISMISS/EQUIP/SUMMON) to new format (CONJURES)
--- @param taskOrder string[] Old task order
--- @return string[] Migrated task order
local function migrateTaskOrder(taskOrder)
    if not taskOrder then return nil end

    local migrated = {}
    local skipNext = false
    local conjuresAdded = false

    for i, key in ipairs(taskOrder) do
        if skipNext then
            skipNext = false
            goto continue
        end

        -- Replace old conjure keys with new CONJURES key
        if key == "DISMISS" or key == "EQUIP" or key == "SUMMON" then
            if not conjuresAdded then
                migrated[#migrated + 1] = "CONJURES"
                conjuresAdded = true
            end
            -- Skip EQUIP and SUMMON if they follow DISMISS
            if key == "DISMISS" and i < #taskOrder then
                if taskOrder[i + 1] == "EQUIP" then
                    skipNext = true
                end
            end
        else
            migrated[#migrated + 1] = key
        end

        ::continue::
    end

    return migrated
end

function RasialGUI.loadConfig()
    -- Reload preset list
    loadPresetList()

    -- Initialize task order to default if not set
    local WarsRetreat = require("core.wars_retreat")
    if not RasialGUI.config.warsTaskOrder then
        RasialGUI.config.warsTaskOrder = {}
        for i, v in ipairs(WarsRetreat.DEFAULT_TASK_ORDER) do
            RasialGUI.config.warsTaskOrder[i] = v
        end
    end

    local saved = loadConfigFromFile()
    if not saved then return end

    local c = RasialGUI.config
    c.inventoryPresetIndex = findPresetIndex(saved.InventoryPreset,
                                             inventoryPresetNames)
    c.equipmentPresetIndex = findPresetIndex(saved.EquipmentPreset,
                                             equipmentPresetNames)
    c.rotationPresetIndex = findPresetIndex(saved.RotationPreset,
                                            rotationPresetNames)
    c.buffsPresetIndex = findPresetIndex(saved.BuffsPreset, buffsPresetNames)
    if type(saved.BankPin) == "string" then c.bankPin = saved.BankPin end
    if type(saved.WaitForFullHp) == "boolean" then
        c.waitForFullHp = saved.WaitForFullHp
    end
    if type(saved.UseDiscord) == "boolean" then
        c.useDiscord = saved.UseDiscord
    end
    if type(saved.HealthSolid) == "number" then
        c.healthSolid = saved.HealthSolid
    end
    if type(saved.HealthJellyfish) == "number" then
        c.healthJellyfish = saved.HealthJellyfish
    end
    if type(saved.HealthPotion) == "number" then
        c.healthPotion = saved.HealthPotion
    end
    if type(saved.HealthSpecial) == "number" then
        c.healthSpecial = saved.HealthSpecial
    end
    if type(saved.PrayerNormal) == "number" then
        c.prayerNormal = saved.PrayerNormal
    end
    if type(saved.PrayerCritical) == "number" then
        c.prayerCritical = saved.PrayerCritical
    end
    if type(saved.PrayerSpecial) == "number" then
        c.prayerSpecial = saved.PrayerSpecial
    end
    if type(saved.SummonConjures) == "boolean" then
        c.summonConjures = saved.SummonConjures
    end
    if type(saved.UseAdrenCrystal) == "boolean" then
        c.useAdrenCrystal = saved.UseAdrenCrystal
    end
    if type(saved.BankIfInvFull) == "boolean" then
        c.bankIfInvFull = saved.BankIfInvFull
    end
    if type(saved.AdvancedMovement) == "boolean" then
        c.advancedMovement = saved.AdvancedMovement
    end
    if type(saved.SurgeDiveChance) == "number" then
        c.surgeDiveChance = saved.SurgeDiveChance
    end
    if type(saved.MinPrayer) == "number" then c.minPrayer = saved.MinPrayer end
    if type(saved.MinSummoning) == "number" then
        c.minSummoning = saved.MinSummoning
    end
    if type(saved.MinHealth) == "number" then c.minHealth = saved.MinHealth end
    if type(saved.DebugMain) == "boolean" then c.debugMain = saved.DebugMain end
    if type(saved.DebugTimer) == "boolean" then
        c.debugTimer = saved.DebugTimer
    end
    if type(saved.DebugRotation) == "boolean" then
        c.debugRotation = saved.DebugRotation
    end
    if type(saved.DebugPlayer) == "boolean" then
        c.debugPlayer = saved.DebugPlayer
    end
    if type(saved.DebugPrayer) == "boolean" then
        c.debugPrayer = saved.DebugPrayer
    end
    if type(saved.DebugWars) == "boolean" then c.debugWars = saved.DebugWars end
    if type(saved.WarsTaskOrder) == "table" then
        -- Migrate old task order format if needed
        local migrated = migrateTaskOrder(saved.WarsTaskOrder)
        c.warsTaskOrder = migrated or saved.WarsTaskOrder
    end
end

function RasialGUI.getConfig()
    local c = RasialGUI.config
    local PrayerFlicker = require("core.prayer_flicker")

    local inventoryPresetName = inventoryPresetNames[c.inventoryPresetIndex]
    local equipmentPresetName = equipmentPresetNames[c.equipmentPresetIndex]
    local rotationPresetName = rotationPresetNames[c.rotationPresetIndex]
    local buffsPresetName = buffsPresetNames[c.buffsPresetIndex]

    return {
        -- Core settings
        bankPin = tonumber(c.bankPin) or c.bankPin,
        waitForFullHp = c.waitForFullHp,
        useDiscord = c.useDiscord,
        instanceTimeout = 30,

        -- Player Manager thresholds
        playerManager = {
            health = {
                solid = {type = "percent", value = c.healthSolid},
                jellyfish = {type = "percent", value = c.healthJellyfish},
                healingPotion = {type = "percent", value = c.healthPotion},
                special = {type = "percent", value = c.healthSpecial}
            },
            prayer = {
                normal = {type = "current", value = c.prayerNormal},
                critical = {type = "percent", value = c.prayerCritical},
                special = {type = "current", value = c.prayerSpecial}
            }
        },

        -- Prayer Flicker configuration (Rasial-specific)
        prayerFlicker = {
            defaultPrayer = PrayerFlicker.CURSES.SOUL_SPLIT,
            threats = {
                {
                    name = "True Power",
                    type = "Animation",
                    priority = 10,
                    prayer = PrayerFlicker.CURSES.DEFLECT_NECROMANCY,
                    npcId = 30165,
                    id = 35469,
                    delay = 1,
                    duration = 2
                }
            }
        },

        -- Resolved preset data
        preset = {
            aura = "Equilibrium",
            inventory = Presets.Inventory[inventoryPresetName] or {},
            equipment = Presets.Equipment[equipmentPresetName] or {},
            rotations = Presets.Rotations[rotationPresetName] or {},
            buffs = Presets.Buffs[buffsPresetName] or {}
        },

        -- War's Retreat settings
        warsRetreat = {
            summonConjures = c.summonConjures,
            useAdrenCrystal = c.useAdrenCrystal,
            bankIfInvFull = c.bankIfInvFull,
            advancedMovement = c.advancedMovement,
            surgeDiveChance = c.advancedMovement and c.surgeDiveChance or 0,
            taskOrder = c.warsTaskOrder,
            minimumValues = {
                prayer = c.minPrayer,
                summoning = c.minSummoning,
                health = c.minHealth
            }
        },

        -- Debug flags
        debug = {
            main = c.debugMain,
            timer = c.debugTimer,
            rotation = c.debugRotation,
            player = c.debugPlayer,
            prayer = c.debugPrayer,
            wars = c.debugWars
        },

        -- Preset names (for display/logging)
        presetNames = {
            inventory = inventoryPresetName,
            equipment = equipmentPresetName,
            rotation = rotationPresetName,
            buffs = buffsPresetName
        }
    }
end

function RasialGUI.addWarning(msg)
    RasialGUI.warnings[#RasialGUI.warnings + 1] = msg
    if #RasialGUI.warnings > 50 then table.remove(RasialGUI.warnings, 1) end
end

function RasialGUI.clearWarnings() RasialGUI.warnings = {} end

------------------------------------------
-- # STATISTICS PERSISTENCE
------------------------------------------

-- Statistics state (loaded from file on startup)
RasialGUI.allTimeStats = {
    totalKills = 0,
    totalGP = 0,
    fastestKillMs = nil,
    slowestKillMs = nil,
    totalKillTimeMs = 0,
    uniqueDrops = {},
    lastUpdated = nil
}

RasialGUI.sessionStats = {kills = 0, gp = 0, killData = {}, uniquesLooted = {}}

local function loadStatsFromFile()
    local file = io.open(STATS_PATH, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveStatsToFile(stats)
    local ok, json = pcall(API.JsonEncode, stats)
    if not ok or not json then
        API.printlua("Failed to encode stats JSON", 4, false)
        return false
    end
    os.execute('mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" 2>nul')
    local file = io.open(STATS_PATH, "w")
    if not file then
        API.printlua("Failed to open stats file for writing", 4, false)
        return false
    end
    file:write(json)
    file:close()
    return true
end

function RasialGUI.loadStats()
    local saved = loadStatsFromFile()
    if not saved then return end

    RasialGUI.allTimeStats.totalKills = saved.totalKills or 0
    RasialGUI.allTimeStats.totalGP = saved.totalGP or 0
    RasialGUI.allTimeStats.fastestKillMs = saved.fastestKillMs
    RasialGUI.allTimeStats.slowestKillMs = saved.slowestKillMs
    RasialGUI.allTimeStats.totalKillTimeMs = saved.totalKillTimeMs or 0
    RasialGUI.allTimeStats.uniqueDrops = saved.uniqueDrops or {}
    RasialGUI.allTimeStats.lastUpdated = saved.lastUpdated
end

--- Records a kill to session and all-time stats
--- @param killTimeMs number Kill time in milliseconds
--- @param gpValue number GP value from loot
function RasialGUI.recordKill(killTimeMs, gpValue)
    -- Update session stats
    RasialGUI.sessionStats.kills = RasialGUI.sessionStats.kills + 1
    RasialGUI.sessionStats.gp = RasialGUI.sessionStats.gp + gpValue

    -- Update all-time stats
    local stats = RasialGUI.allTimeStats
    stats.totalKills = stats.totalKills + 1
    stats.totalGP = stats.totalGP + gpValue
    stats.totalKillTimeMs = stats.totalKillTimeMs + killTimeMs

    if not stats.fastestKillMs or killTimeMs < stats.fastestKillMs then
        stats.fastestKillMs = killTimeMs
    end
    if not stats.slowestKillMs or killTimeMs > stats.slowestKillMs then
        stats.slowestKillMs = killTimeMs
    end

    stats.lastUpdated = os.time()

    -- Save to file
    saveStatsToFile(stats)
end

--- Records a unique drop
--- @param dropName string Name of the unique drop
function RasialGUI.recordUniqueDrop(dropName)
    local stats = RasialGUI.allTimeStats
    if not stats.uniqueDrops then stats.uniqueDrops = {} end

    stats.uniqueDrops[#stats.uniqueDrops + 1] = {
        name = dropName,
        timestamp = os.time(),
        killCount = stats.totalKills
    }

    stats.lastUpdated = os.time()
    saveStatsToFile(stats)
end

--- Resets all-time statistics
function RasialGUI.resetAllTimeStats()
    RasialGUI.allTimeStats = {
        totalKills = 0,
        totalGP = 0,
        fastestKillMs = nil,
        slowestKillMs = nil,
        totalKillTimeMs = 0,
        uniqueDrops = {},
        lastUpdated = nil
    }
    saveStatsToFile(RasialGUI.allTimeStats)
end

--- Returns formatted all-time stats for display
function RasialGUI.getAllTimeStatsForDisplay()
    local stats = RasialGUI.allTimeStats
    local avgMs = stats.totalKills > 0 and
                      (stats.totalKillTimeMs / stats.totalKills) or 0
    return {
        totalKills = stats.totalKills,
        totalGP = stats.totalGP,
        fastestKill = stats.fastestKillMs,
        slowestKill = stats.slowestKillMs,
        averageKill = avgMs,
        uniqueDrops = #(stats.uniqueDrops or {})
    }
end

function RasialGUI.isPaused() return RasialGUI.paused end

function RasialGUI.isStopped() return RasialGUI.stopped end

function RasialGUI.isCancelled() return RasialGUI.cancelled end

------------------------------------------
-- # TAB DRAWING FUNCTIONS
------------------------------------------

--------------------------------------------------------------------------------
-- PRESET MANAGEMENT SECTION
--------------------------------------------------------------------------------

local function drawPresetManagement()
    ui:sectionHeader("Configuration Presets",
                     "Save and load complete combat setups.")

    -- Load preset dropdown
    ui:text("Load Configuration", "label")
    ui:spacing(1)
    local newIndex = ui:combo("##loadPreset", selectedPresetIndex,
                              availablePresets)
    if newIndex ~= selectedPresetIndex then
        selectedPresetIndex = newIndex
        if availablePresets[selectedPresetIndex] ~= "Default" then
            local loaded = loadConfigurationPreset(
                               availablePresets[selectedPresetIndex])
            if loaded then
                -- Apply loaded preset to current config
                local c = RasialGUI.config
                c.inventoryPresetIndex =
                    findPresetIndex(loaded.InventoryPreset, inventoryPresetNames)
                c.equipmentPresetIndex =
                    findPresetIndex(loaded.EquipmentPreset, equipmentPresetNames)
                c.rotationPresetIndex = findPresetIndex(loaded.RotationPreset,
                                                        rotationPresetNames)
                c.buffsPresetIndex = findPresetIndex(loaded.BuffsPreset,
                                                     buffsPresetNames)
                if type(loaded.BankPin) == "string" then
                    c.bankPin = loaded.BankPin
                end
                if type(loaded.WaitForFullHp) == "boolean" then
                    c.waitForFullHp = loaded.WaitForFullHp
                end
                if type(loaded.UseDiscord) == "boolean" then
                    c.useDiscord = loaded.UseDiscord
                end
                if type(loaded.HealthSolid) == "number" then
                    c.healthSolid = loaded.HealthSolid
                end
                if type(loaded.HealthJellyfish) == "number" then
                    c.healthJellyfish = loaded.HealthJellyfish
                end
                if type(loaded.HealthPotion) == "number" then
                    c.healthPotion = loaded.HealthPotion
                end
                if type(loaded.HealthSpecial) == "number" then
                    c.healthSpecial = loaded.HealthSpecial
                end
                if type(loaded.PrayerNormal) == "number" then
                    c.prayerNormal = loaded.PrayerNormal
                end
                if type(loaded.PrayerCritical) == "number" then
                    c.prayerCritical = loaded.PrayerCritical
                end
                if type(loaded.PrayerSpecial) == "number" then
                    c.prayerSpecial = loaded.PrayerSpecial
                end
                if type(loaded.SummonConjures) == "boolean" then
                    c.summonConjures = loaded.SummonConjures
                end
                if type(loaded.UseAdrenCrystal) == "boolean" then
                    c.useAdrenCrystal = loaded.UseAdrenCrystal
                end
                if type(loaded.BankIfInvFull) == "boolean" then
                    c.bankIfInvFull = loaded.BankIfInvFull
                end
                if type(loaded.AdvancedMovement) == "boolean" then
                    c.advancedMovement = loaded.AdvancedMovement
                end
                if type(loaded.SurgeDiveChance) == "number" then
                    c.surgeDiveChance = loaded.SurgeDiveChance
                end
                if type(loaded.MinPrayer) == "number" then
                    c.minPrayer = loaded.MinPrayer
                end
                if type(loaded.MinSummoning) == "number" then
                    c.minSummoning = loaded.MinSummoning
                end
                if type(loaded.MinHealth) == "number" then
                    c.minHealth = loaded.MinHealth
                end
                if type(loaded.DebugMain) == "boolean" then
                    c.debugMain = loaded.DebugMain
                end
                if type(loaded.DebugTimer) == "boolean" then
                    c.debugTimer = loaded.DebugTimer
                end
                if type(loaded.DebugRotation) == "boolean" then
                    c.debugRotation = loaded.DebugRotation
                end
                if type(loaded.DebugPlayer) == "boolean" then
                    c.debugPlayer = loaded.DebugPlayer
                end
                if type(loaded.DebugPrayer) == "boolean" then
                    c.debugPrayer = loaded.DebugPrayer
                end
                API.printlua("Loaded configuration: " ..
                                 availablePresets[selectedPresetIndex], 0, false)
            end
        end
    end

    ui:spacing(1)

    -- Save preset section
    ui:text("Save Current Setup", "label")
    ui:spacing(1)
    newPresetName = ui:inputText("##newPresetName", newPresetName)
    ui:spacing(1)
    if ui:button("Save Configuration##saveBtn", 28) then
        if newPresetName ~= "" and newPresetName ~= "Default" then
            if saveConfigurationPreset(newPresetName, RasialGUI.config) then
                -- Update selected index to the newly saved preset
                for i, name in ipairs(availablePresets) do
                    if name == newPresetName then
                        selectedPresetIndex = i
                        break
                    end
                end
                newPresetName = ""
            end
        end
    end

    -- Delete preset button (only if not Default)
    if selectedPresetIndex > 1 then
        ui:spacing(1)
        if ui:buttonDanger("Delete: " .. availablePresets[selectedPresetIndex],
                           26) then
            local presetToDelete = availablePresets[selectedPresetIndex]
            if deleteConfigurationPreset(presetToDelete) then
                selectedPresetIndex = 1 -- Reset to Default
            end
        end
    end

    ui:separator()
end

--------------------------------------------------------------------------------
-- TAB CONTENT: PRESETS
--------------------------------------------------------------------------------

local function drawPresetsTab(cfg)
    ui:spacing(1)
    ui:sectionHeader("Combat Presets",
                     "Select inventory, equipment, rotation, and buffs.")

    -- 2x2 Grid Layout
    if ui:beginColumns("##presetGrid", {1, 1}) then
        -- Row 1: Inventory | Equipment
        ui:nextRow()

        -- Inventory
        cfg.inventoryPresetIndex = ui:labeledCombo("Inventory",
                                                   "##inventoryPreset",
                                                   cfg.inventoryPresetIndex,
                                                   inventoryPresetNames)

        ui:nextColumn()

        -- Equipment
        cfg.equipmentPresetIndex = ui:labeledCombo("Equipment",
                                                   "##equipmentPreset",
                                                   cfg.equipmentPresetIndex,
                                                   equipmentPresetNames)

        -- Row 2: Rotation | Buffs
        ui:nextRow()

        -- Rotation
        cfg.rotationPresetIndex = ui:labeledCombo("Rotation",
                                                  "##rotationPreset",
                                                  cfg.rotationPresetIndex,
                                                  rotationPresetNames)

        ui:nextColumn()

        -- Buffs
        cfg.buffsPresetIndex = ui:labeledCombo("Buffs", "##buffsPreset",
                                               cfg.buffsPresetIndex,
                                               buffsPresetNames)

        ui:endColumns()
    end

    ui:spacing(1)
end

--------------------------------------------------------------------------------
-- TAB CONTENT: GENERAL SETTINGS
--------------------------------------------------------------------------------

local function drawGeneralTab(cfg)
    ui:spacing(1)
    ui:sectionHeader("General Settings",
                     "Configure banking and notification preferences.")

    cfg.bankPin = ui:labeledInput("Bank PIN", "##bankpin", cfg.bankPin)

    -- Show warning if bank PIN is not set
    if cfg.bankPin == "" or cfg.bankPin == nil then
        ui:statusText("Bank PIN required for preset loading", "warning", true)
    end

    cfg.waitForFullHp = ui:checkbox("Wait for Full HP##waitfullhp",
                                    cfg.waitForFullHp)

    ui:separator()

    ui:sectionHeader("Notifications", "Configure alerts and notifications.")

    cfg.useDiscord = ui:checkbox("Discord Notifications##discord",
                                 cfg.useDiscord)
end

--------------------------------------------------------------------------------
-- TAB CONTENT: WAR'S RETREAT
--------------------------------------------------------------------------------

local function drawWarsRetreatTab(cfg)
    ui:spacing(1)
    ui:sectionHeader("War's Retreat", "Pre-fight preparation at War's Retreat.")

    cfg.summonConjures = ui:checkbox("Summon Conjures##summonconjures",
                                     cfg.summonConjures)
    cfg.useAdrenCrystal = ui:checkbox("Use Adrenaline Crystal##useadren",
                                      cfg.useAdrenCrystal)
    cfg.bankIfInvFull = ui:checkbox("Bank if Inventory Full##bankinvfull",
                                    cfg.bankIfInvFull)
    ui:text("Re-load last preset if inventory is full on return.", "hint")

    ui:separator()

    ui:sectionHeader("Minimum Thresholds",
                     "Minimum values before continuing to the next step.")

    cfg.minPrayer = ui:labeledSliderInt("Prayer (%)", "##minPrayer",
                                        cfg.minPrayer, 0, 100, "%d%%")
    cfg.minSummoning = ui:labeledSliderInt("Summoning (%)", "##minSummoning",
                                           cfg.minSummoning, 0, 100, "%d%%")
    cfg.minHealth = ui:labeledSliderInt("Health (%)", "##minHealth",
                                        cfg.minHealth, 0, 100, "%d%%")
    ui:text("Pray at altar if prayer or summoning falls below threshold.",
            "hint")

    ui:separator()

    ui:sectionHeader("Movement", "Configure surge and dive behavior.")

    cfg.advancedMovement = ui:checkbox("Advanced Movement##advancedmovement",
                                       cfg.advancedMovement)
    ui:text("Enable Surge and Bladed Dive for faster navigation.", "hint")

    if cfg.advancedMovement then
        ui:spacing(1)
        cfg.surgeDiveChance = ui:labeledSliderInt("Surge/Dive Chance",
                                                  "##surgeDiveChance",
                                                  cfg.surgeDiveChance, 0, 100,
                                                  "%d%%")
        ui:text("Probability of using Surge/Bladed Dive per navigation.", "hint")
    end
end

--------------------------------------------------------------------------------
-- TAB CONTENT: WAR'S RETREAT TASK ORDER
--------------------------------------------------------------------------------

local function drawWarsTaskOrderTab(cfg)
    local WarsRetreat = require("core.wars_retreat")

    ui:spacing(1)
    ui:sectionHeader("Task Execution Order",
                     "Customize the order of War's Retreat preparation steps.")

    ui:text(
        "Click a task to select it, then use ↑/↓ buttons to reorder. " ..
            "Tasks controlled by settings (Crystal, Conjures, Prebuild) are hidden when disabled.",
        "hint")
    ui:spacing(2)

    -- Build display items list with metadata
    local displayItems = {}
    for _, taskKey in ipairs(cfg.warsTaskOrder) do
        local metadata = WarsRetreat.TASK_METADATA[taskKey]
        if not metadata then goto continue end

        -- Check if task is disabled by settings
        local disabled = false
        if metadata.conditionalLoad then
            local setting = cfg[metadata.loadSetting]
            disabled = not setting
        end

        displayItems[#displayItems + 1] = {
            key = taskKey,
            label = metadata.displayName,
            disabled = disabled
        }

        ::continue::
    end

    -- Render reorderable list
    local newIndex, action = ui:reorderableList("##warsTaskOrder", displayItems,
                                                cfg.warsTaskOrderSelectedIndex)

    cfg.warsTaskOrderSelectedIndex = newIndex

    -- Handle reordering actions
    if action then
        if action.type == "move_up" and action.index > 1 then
            -- Swap with previous item
            local temp = cfg.warsTaskOrder[action.index]
            cfg.warsTaskOrder[action.index] =
                cfg.warsTaskOrder[action.index - 1]
            cfg.warsTaskOrder[action.index - 1] = temp
            cfg.warsTaskOrderSelectedIndex = action.index - 1

        elseif action.type == "move_down" and action.index < #cfg.warsTaskOrder then
            -- Swap with next item
            local temp = cfg.warsTaskOrder[action.index]
            cfg.warsTaskOrder[action.index] =
                cfg.warsTaskOrder[action.index + 1]
            cfg.warsTaskOrder[action.index + 1] = temp
            cfg.warsTaskOrderSelectedIndex = action.index + 1
        end
    end

    ui:spacing(2)
    ui:separator()
    ui:spacing(1)

    -- Reset to default button
    if ui:buttonWarning("Reset to Default Order##resetOrder", 26) then
        cfg.warsTaskOrder = {
            "BANK", "ALTAR", "CRYSTAL", "CONJURES", "PREBUILD", "PORTAL"
        }
        cfg.warsTaskOrderSelectedIndex = 1
    end

    ui:spacing(1)
    ui:text(
        "Default: Bank → Altar → Crystal → Pre-Summon Conjures → Prebuild → Portal",
        "hint")
end

--------------------------------------------------------------------------------
-- TAB CONTENT: PLAYER MANAGER
--------------------------------------------------------------------------------

local function drawPlayerManagerTab(cfg)
    ui:spacing(1)
    ui:sectionHeader("Health Thresholds",
                     "When to consume food and healing items.")

    cfg.healthSolid = ui:labeledSliderInt("Solid Food (%)", "##healthSolid",
                                          cfg.healthSolid, 0, 100, "%d%%")
    cfg.healthJellyfish = ui:labeledSliderInt("Jellyfish (%)",
                                              "##healthJellyfish",
                                              cfg.healthJellyfish, 0, 100,
                                              "%d%%")
    cfg.healthPotion = ui:labeledSliderInt("Healing Potion (%)",
                                           "##healthPotion", cfg.healthPotion,
                                           0, 100, "%d%%")
    cfg.healthSpecial = ui:labeledSliderInt("Enhanced Excalibur (%)",
                                            "##healthSpecial",
                                            cfg.healthSpecial, 0, 100, "%d%%")

    ui:separator()

    ui:sectionHeader("Prayer Thresholds", "When to restore prayer points.")

    cfg.prayerNormal = ui:labeledSliderInt("Normal Restore (points)",
                                           "##prayerNormal", cfg.prayerNormal,
                                           0, 999, "%d")
    cfg.prayerCritical = ui:labeledSliderInt(
                             "Critical (%) - Emergency Teleport",
                             "##prayerCritical", cfg.prayerCritical, 0, 100,
                             "%d%%")
    cfg.prayerSpecial = ui:labeledSliderInt("Elven Shard (points)",
                                            "##prayerSpecial",
                                            cfg.prayerSpecial, 0, 999, "%d")
end

--------------------------------------------------------------------------------
-- TAB CONTENT: DEBUG
--------------------------------------------------------------------------------

local function drawDebugTab(cfg)
    ui:spacing(1)
    ui:sectionHeader("Debugging Options", "Enable logging for troubleshooting.")

    cfg.debugMain = ui:checkbox("Main Script##debugmain", cfg.debugMain)
    cfg.debugTimer = ui:checkbox("Timer System##debugtimer", cfg.debugTimer)
    cfg.debugRotation = ui:checkbox("Rotation Manager##debugrotation",
                                    cfg.debugRotation)
    cfg.debugPlayer =
        ui:checkbox("Player Manager##debugplayer", cfg.debugPlayer)
    cfg.debugPrayer =
        ui:checkbox("Prayer Flicker##debugprayer", cfg.debugPrayer)
    cfg.debugWars = ui:checkbox("War's Retreat##debugwars", cfg.debugWars)

    ui:separator(1, 2)
    ui:text(
        "Enable debug flags to see live debugging tabs during script execution.",
        "hint")
end

--------------------------------------------------------------------------------
-- TAB CONTENT: MAIN DEBUG
--------------------------------------------------------------------------------

local function drawMainDebugTab(data)
    ui:spacing(1)
    ui:textColored("Main Debug Information", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##maindebug", 0.3) then
        ui:tableRow("Script Version", data.mainDebug and
                        data.mainDebug.scriptVersion or "Unknown")
        ui:tableRow("Current State", data.state or "Unknown")
        ui:tableRow("Location", data.location or "Unknown")
        ui:tableRow("Kill Count", tostring(data.killCount or 0))
        ui:tableRow("Total GP", GUILib.formatNumber(data.gp or 0))
        ui:endColumns()
    end

    if data.mainDebug and data.mainDebug.rasialFightVariables then
        ui:separator(1, 2)
        ui:textColored("Rasial Fight Variables", {0.93, 0.77, 0.40, 1.0})

        if ui:beginInfoTable("##rasialfight", 0.4) then
            local vars = data.mainDebug.rasialFightVariables
            ui:tableRow("Boss Dead", tostring(vars.bossDead or false))
            ui:tableRow("Phase 1",
                        tostring(vars.phases and vars.phases[1] or false))
            ui:tableRow("Phase 2",
                        tostring(vars.phases and vars.phases[2] or false))
            ui:tableRow("Jas Proc Count", tostring(vars.jasProcCount or 0))
            ui:tableRow("Looted", tostring(vars.looted or false))
            ui:endColumns()
        end
    end

    if data.mainDebug and data.mainDebug.rasialLobbyVariables then
        ui:separator(1, 2)
        ui:textColored("Rasial Lobby Variables", {0.93, 0.77, 0.40, 1.0})

        if ui:beginInfoTable("##rasiallobby", 0.4) then
            local vars = data.mainDebug.rasialLobbyVariables
            ui:tableRow("Instance Start Time",
                        tostring(vars.instanceStartTime or 0))
            ui:tableRow("Rejoin Attempts", tostring(vars.rejoinAttempts or 0))
            ui:endColumns()
        end
    end

    if data.mainDebug and data.mainDebug.bossInfo then
        ui:separator(1, 2)
        ui:textColored("Boss Information", {0.93, 0.77, 0.40, 1.0})

        if ui:beginInfoTable("##bossinfo", 0.4) then
            local boss = data.mainDebug.bossInfo
            ui:tableRow("Found", tostring(boss.found or false))
            ui:tableRow("Health", tostring(boss.health or -1))
            ui:tableRow("Animation", tostring(boss.animation or -1))
            if boss.tile then
                ui:tableRow("Position", string.format("(%.1f, %.1f)",
                                                      boss.tile.x, boss.tile.y))
            end
            ui:endColumns()
        end
    end
end

--------------------------------------------------------------------------------
-- TAB CONTENT: TIMER DEBUG
--------------------------------------------------------------------------------

local function drawTimerDebugTab(data)
    ui:spacing(1)

    if not data.timerDebug then
        ui:text("Timer debugging data not available.", "hint")
        return
    end

    -- Recent Actions Section
    ui:textColored("Recent Actions", {0.93, 0.77, 0.40, 1.0})
    ui:text("Last 15 executed tasks (newest first):", "hint")

    if data.timerDebug.recentActions and #data.timerDebug.recentActions > 0 then
        if ui:beginColumns("##recentactions", {0.5, 0.25, 0.25}) then
            ui:nextRow()
            ui:text("Task Name", "hint")
            ui:nextColumn()
            ui:text("Tick", "hint")
            ui:nextColumn()
            ui:text("Time (ms)", "hint")

            for i = 1, math.min(15, #data.timerDebug.recentActions) do
                local action = data.timerDebug.recentActions[i]
                ui:nextRow()
                ui:text(action.name)
                ui:nextColumn()
                ui:text(tostring(action.tick))
                ui:nextColumn()
                ui:text(string.format("%.0f", action.timestamp))
            end

            ui:endColumns()
        end
    else
        ui:text("No recent actions recorded.", "hint")
    end

    -- Active Tasks Section
    ui:separator(1, 2)
    ui:textColored("Active Tasks", {0.93, 0.77, 0.40, 1.0})
    ui:text("Tasks currently meeting their conditions:", "hint")

    if data.timerDebug.activeTasks and #data.timerDebug.activeTasks > 0 then
        if ui:beginColumns("##activetasks", {0.6, 0.2, 0.2}) then
            ui:nextRow()
            ui:text("Task Name", "hint")
            ui:nextColumn()
            ui:text("Priority", "hint")
            ui:nextColumn()
            ui:text("Run Count", "hint")

            for _, task in ipairs(data.timerDebug.activeTasks) do
                ui:nextRow()
                ui:text(task.name)
                ui:nextColumn()
                ui:text(tostring(task.priority))
                ui:nextColumn()
                ui:text(tostring(task.count))
            end

            ui:endColumns()
        end
    else
        ui:text("No active tasks at this moment.", "hint")
    end
end

--------------------------------------------------------------------------------
-- TAB CONTENT: ROTATION DEBUG
--------------------------------------------------------------------------------

local function drawRotationDebugTab(data)
    ui:spacing(1)

    if not data.rotationDebug then
        ui:text("Rotation debugging data not available.", "hint")
        return
    end

    -- Current Rotation State
    ui:textColored("Rotation State", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##rotstate", 0.3) then
        ui:tableRow("Current Index",
                    tostring(data.rotationDebug.currentIndex or 1))
        ui:tableRow("Total Steps", tostring(data.rotationDebug.totalSteps or 0))
        ui:tableRow("Rotation Loaded",
                    tostring(data.rotationDebug.isLoaded or false))
        ui:endColumns()
    end

    -- Recent Steps Section
    ui:separator(1, 2)
    ui:textColored("Recent Steps", {0.93, 0.77, 0.40, 1.0})
    ui:text("Last 7 executed steps (newest first):", "hint")

    if data.rotationDebug.recentSteps and #data.rotationDebug.recentSteps > 0 then
        for i = 1, math.min(7, #data.rotationDebug.recentSteps) do
            local step = data.rotationDebug.recentSteps[i]

            -- Step header with index and label
            ui:textColored(string.format("[%d] %s", step.index or 0,
                                         step.label or "Unknown"),
                           {0.93, 0.77, 0.40, 1.0})

            if ui:beginInfoTable("##step" .. i, 0.35) then
                ui:tableRow("Type", step.type or "Unknown")
                ui:tableRow("Condition Met", tostring(
                                step.conditionMet ~= nil and step.conditionMet or
                                    "N/A"))
                ui:tableRow("Success", tostring(step.actionSuccess or false))
                ui:tableRow("Wait", string.format("%d %s", step.wait or 0,
                                                  step.useTicks and "ticks" or
                                                      "ms"))
                ui:tableRow("Tick", tostring(step.tick or 0))
                ui:endColumns()
            end

            if i < math.min(7, #data.rotationDebug.recentSteps) then
                ui:separator(1, 1)
            end
        end
    else
        ui:text("No recent steps recorded.", "hint")
    end
end

--------------------------------------------------------------------------------
-- TAB CONTENT: WAR'S RETREAT DEBUG
--------------------------------------------------------------------------------

local function drawWarsDebugTab(data)
    ui:spacing(1)

    if not data.warsDebug then
        ui:text("War's Retreat debugging data not available.", "hint")
        return
    end

    local wd = data.warsDebug

    -- Current State
    ui:textColored("Current State", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##warsstate", 0.35) then
        ui:tableRow("At War's Retreat", tostring(wd.atLocation or false))
        ui:tableRow("Current Step", wd.currentStep or "UNKNOWN")
        ui:tableRow("Last Action", wd.lastAction or "None")
        ui:endColumns()
    end

    ui:separator(1, 2)

    -- Task Order
    ui:textColored("Task Order & Status", {0.93, 0.77, 0.40, 1.0})
    ui:text("Current execution order (✓ = active step):", "hint")

    if wd.taskOrder and #wd.taskOrder > 0 then
        if ui:beginColumns("##warstaskorder", {0.07, 0.42, 0.3, 0.21}) then
            ui:nextRow()
            ui:text("#", "hint")
            ui:nextColumn()
            ui:text("Task", "hint")
            ui:nextColumn()
            ui:text("Step", "hint")
            ui:nextColumn()
            ui:text("Priority", "hint")

            for _, task in ipairs(wd.taskOrder) do
                ui:nextRow()
                local prefix = task.active and "✓" or " "
                local color = task.active and {0.3, 0.85, 0.45, 1.0} or nil

                ui:text(tostring(task.index))
                ui:nextColumn()
                ui:text(prefix .. " " .. task.name, color and "label" or "label")
                ui:nextColumn()
                ui:text(task.step, "hint")
                ui:nextColumn()
                ui:text(tostring(task.priority or 0))
            end

            ui:endColumns()
        end
    else
        ui:text("No task order configured.", "hint")
    end

    ui:separator(1, 2)

    -- Variables
    ui:textColored("Variables", {0.93, 0.77, 0.40, 1.0})

    if wd.variables and ui:beginInfoTable("##warsvars", 0.35) then
        ui:tableRow("Bank Attempts", tostring(wd.variables.bankAttempts or 0))
        ui:tableRow("Conjure Attempts",
                    tostring(wd.variables.conjureAttempts or 0))
        ui:tableRow("Portal Side", wd.variables.portalSide or "Unknown")
        ui:tableRow("Use Adv Movement",
                    tostring(wd.variables.useAdvMovement or false))
        ui:tableRow("Positioning", tostring(wd.variables.positioning or false))
        ui:tableRow("Preset Validated",
                    tostring(wd.variables.presetValidated or false))
        ui:endColumns()
    end

    ui:separator(1, 2)

    -- Condition Checks
    ui:textColored("Condition Checks", {0.93, 0.77, 0.40, 1.0})

    if wd.checks and ui:beginInfoTable("##warschecks", 0.35) then
        ui:tableRow("Inventory Matches",
                    tostring(wd.checks.inventoryMatches or false))
        ui:tableRow("Prayer",
                    string.format("%d%%", wd.checks.prayerPercent or 0))
        ui:tableRow("Summoning",
                    string.format("%d%%", wd.checks.summoningPercent or 0))
        ui:tableRow("Health",
                    string.format("%d%%", wd.checks.healthPercent or 0))
        ui:tableRow("Adrenaline",
                    string.format("%.1f/%.1f", wd.checks.adrenaline or 0,
                                  wd.checks.maxAdrenaline or 100))
        ui:tableRow("Active Summons",
                    tostring(wd.checks.hasActiveSummons or false))
        ui:tableRow("Should Refresh",
                    tostring(wd.checks.shouldRefreshConjures or false))
        ui:endColumns()
    end

    ui:separator(1, 2)

    -- Settings
    ui:textColored("Settings", {0.93, 0.77, 0.40, 1.0})

    if wd.settings and ui:beginInfoTable("##warssettings", 0.35) then
        ui:tableRow("Summon Conjures",
                    tostring(wd.settings.summonConjures or false))
        ui:tableRow("Use Adren Crystal",
                    tostring(wd.settings.useAdrenCrystal or false))
        ui:tableRow("Wait for Full HP",
                    tostring(wd.settings.waitForFullHp or false))
        ui:tableRow("Bank if Inv Full",
                    tostring(wd.settings.bankIfInvFull or false))
        ui:tableRow("Advanced Movement",
                    tostring(wd.settings.advancedMovement or false))
        if wd.settings.advancedMovement then
            ui:tableRow("Surge/Dive Chance",
                        string.format("%d%%", wd.settings.surgeDiveChance or 0))
        end
        ui:endColumns()
    end
end

local function drawInfoTab(data)
    -- State banner
    local stateText = (data.state ..
                          (data.state == "War's Retreat" and ": " ..
                              data.warsLastAction or "")) or "Idle"
    if RasialGUI.paused then stateText = "Paused" end
    local sc = STATE_COLORS[stateText] or {0.7, 0.7, 0.7}
    ui:progressBar(1.0, 22, stateText, sc)

    ui:separator(1, 2)

    -- Boss health bar
    if data.bossHealth and data.bossMaxHealth and data.bossHealth > 0 then
        local pct = math.max(0,
                             math.min(1, data.bossHealth / data.bossMaxHealth))
        local hc = GUILib.getHealthColor(pct * 100)
        local healthText = string.format("%s / %s",
                                         GUILib.formatNumber(data.bossHealth),
                                         GUILib.formatNumber(data.bossMaxHealth))
        ui:labeledProgressBar(pct, 28, healthText, hc)

        ui:separator(1, 2)
    end

    -- Overview
    ui:textColored("Overview", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##info", 0.3) then
        ui:tableRow("Location", data.location or "Unknown")
        ui:tableRow("Status", data.status or "Idle")
        if data.killTimer then ui:tableRow("Kill Timer", data.killTimer) end
        ui:endColumns()
    end

    -- Active buffs
    if data.activeBuffs and #data.activeBuffs > 0 then
        ui:separator(1, 2)

        ui:textColored("Active Buffs", {0.93, 0.77, 0.40, 1.0})

        for _, buff in ipairs(data.activeBuffs) do
            ui:textColored(buff, {0.33, 0.75, 0.42, 1.0})
        end
    end

    ui:separator(1, 2)

    -- Metrics
    ui:textColored("Metrics", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##metrics", 0.3) then
        ui:tableRow("Kills", string.format("%d (%s/hr)", data.killCount or 0,
                                           data.killsPerHour or "0"))
        ui:tableRow("GP",
                    string.format("%s (%s/hr)",
                                  GUILib.formatNumber(data.gp or 0),
                                  GUILib.formatNumber(data.gpPerHour or 0)))
        ui:tableRow("Deaths", tostring(data.deathCount or 0),
                    {1.0, 0.5, 0.5, 1.0})
        ui:endColumns()
    end

    ui:separator(1, 2)

    -- Kill times (Session)
    ui:textColored("Kill Times (Session)", {0.93, 0.77, 0.40, 1.0})

    if ui:beginInfoTable("##killtimes", 0.3) then
        ui:tableRow("Fastest", data.fastestKill or "--", {0.3, 0.85, 0.45, 1.0})
        ui:tableRow("Slowest", data.slowestKill or "--", {1.0, 0.5, 0.3, 1.0})
        ui:tableRow("Average", data.averageKill or "--")
        ui:endColumns()
    end

    -- All-time stats section
    local allTime = RasialGUI.getAllTimeStatsForDisplay()
    if allTime.totalKills > 0 then
        ui:separator(1, 2)
        ui:textColored("All-Time Statistics", {0.93, 0.77, 0.40, 1.0})

        if ui:beginInfoTable("##alltimestats", 0.3) then
            ui:tableRow("Total Kills", tostring(allTime.totalKills))
            ui:tableRow("Total GP", GUILib.formatNumber(allTime.totalGP))
            if allTime.fastestKill then
                local Utils = require("core.helper")
                ui:tableRow("Best Kill",
                            Utils:formatKillDuration(allTime.fastestKill),
                            {0.3, 0.85, 0.45, 1.0})
            end
            ui:tableRow("Unique Drops", tostring(allTime.uniqueDrops))
            ui:endColumns()
        end
        --[[
        ui:spacing(2)
        if ui:buttonSecondary("Reset All-Time Stats##resetstats") then
            RasialGUI.resetAllTimeStats()
        end
    ]]
    end

    -- Recent kills
    if data.killData and #data.killData > 0 then
        ui:separator(1, 2)

        ui:textColored("Recent Kills", {0.93, 0.77, 0.40, 1.0})

        if ui:beginColumns("##recentkills", {0.15, 0.45, 0.25, 0.15}) then
            ui:nextRow()
            ui:text("#", "hint")
            ui:nextColumn()
            ui:text("Runtime", "hint")
            ui:nextColumn()
            ui:text("Duration", "hint")
            ui:nextColumn()
            ui:text("GP", "hint")

            for i = #data.killData, math.max(1, #data.killData - 4), -1 do
                local kill = data.killData[i]
                ui:nextRow()
                ui:text(tostring(i), "hint")
                ui:nextColumn()
                ui:text(kill.runtime or "--")
                ui:nextColumn()
                ui:text(kill.fightDuration or "--")
                ui:nextColumn()
                ui:text(
                    kill.lootValue and GUILib.formatNumber(kill.lootValue) or
                        "--")
            end

            ui:endColumns()
        end
    end

    -- Unique drops
    if data.uniquesLooted and #data.uniquesLooted > 0 then
        ui:separator(1, 2)

        ui:textColored("Unique Drops", {0.93, 0.77, 0.40, 1.0})

        for _, drop in ipairs(data.uniquesLooted) do
            ui:textColored(drop[1], {0.93, 0.77, 0.40, 1.0})
        end
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ui:text("No warnings.", "hint")
        return
    end

    for _, warning in ipairs(gui.warnings) do
        ui:text("[!] " .. warning, "warning")
        ui:spacing(1)
    end

    ui:separator(1, 1)

    if ui:buttonWarning("Dismiss Warnings##clear", 25) then gui.warnings = {} end
end

local function drawConfigContent(gui)
    drawPresetManagement()

    if ui:beginTabBar("##configtabs") then
        if ui:beginTab("Presets###presets") then
            drawPresetsTab(gui.config)
            ui:endTab()
        end

        if ui:beginTab("General###general") then
            drawGeneralTab(gui.config)
            ui:endTab()
        end

        if ui:beginTab("War's Retreat###warsretreat") then
            drawWarsRetreatTab(gui.config)
            ui:endTab()
        end

        if ui:beginTab("Task Order###taskorder") then
            drawWarsTaskOrderTab(gui.config)
            ui:endTab()
        end

        if ui:beginTab("Player Manager###playermanager") then
            drawPlayerManagerTab(gui.config)
            ui:endTab()
        end

        if ui:beginTab("Debug###debug") then
            drawDebugTab(gui.config)
            ui:endTab()
        end

        ui:endTabBar()
    end

    ui:separator(3, 3)

    if ui:button("Start Rasial##start", 32) then
        saveConfigToFile(gui.config)
        gui.started = true
    end
    ui:spacing(1)
    if ui:buttonSecondary("Cancel##cancel") then gui.cancelled = true end
end

local function drawRuntimeContent(data, gui)
    if ui:beginTabBar("##runtimetabs") then
        local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or
                              0
        gui.selectInfoTab = false
        if ui:beginTab("Info###info", infoFlags) then
            ui:spacing(1)
            drawInfoTab(data)
            ui:endTab()
        end

        if gui.config.debugMain and ui:beginTab("Main Debug###maindebug") then
            drawMainDebugTab(data)
            ui:endTab()
        end

        if gui.config.debugTimer and ui:beginTab("Timer Debug###timerdebug") then
            drawTimerDebugTab(data)
            ui:endTab()
        end

        if gui.config.debugRotation and
            ui:beginTab("Rotation Debug###rotationdebug") then
            drawRotationDebugTab(data)
            ui:endTab()
        end

        if gui.config.debugWars and ui:beginTab("War's Debug###warsdebug") then
            drawWarsDebugTab(data)
            ui:endTab()
        end

        if #gui.warnings > 0 then
            local warningLabel = "Warnings (" .. #gui.warnings .. ")###warnings"
            local warnFlags = gui.selectWarningsTab and
                                  ImGuiTabItemFlags.SetSelected or 0
            if ui:beginTab(warningLabel, warnFlags) then
                gui.selectWarningsTab = false
                ui:spacing(1)
                drawWarningsTab(gui)
                ui:endTab()
            end
        end

        ui:endTabBar()
    end

    ui:separator(3, 3)

    if gui.paused then
        if ui:buttonSuccess("Resume Script##resume") then
            gui.paused = false
        end
    else
        if ui:buttonSecondary("Pause Script##pause") then
            gui.paused = true
        end
    end
    ui:spacing(1)
    if ui:buttonDanger("Stop Script##stop") then gui.stopped = true end
end

------------------------------------------
-- # MAIN DRAW FUNCTION
------------------------------------------

function RasialGUI.draw(data)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(540, 0, ImGuiCond.Always)
    local colorCount, styleCount = ui:pushTheme()

    local titleText = "Rasial - " .. API.ScriptRuntimeString() .. " - K: " ..
                          tostring(data.killData and #data.killData or 0) ..
                          "###Rasial"
    local visible = ui:beginWindow(titleText, 64) -- AlwaysAutoResize

    if visible then
        local ok, err
        if not RasialGUI.started then
            ok, err = pcall(drawConfigContent, RasialGUI)
        else
            ok, err = pcall(drawRuntimeContent, data, RasialGUI)
        end
        if not ok then ui:text("Error: " .. tostring(err), "error") end
    end

    ui:endWindow()
    ui:popTheme(colorCount, styleCount)

    return RasialGUI.open
end

------------------------------------------
-- # INITIALIZATION
------------------------------------------

-- Load available presets on module load
loadPresetList()

return RasialGUI
