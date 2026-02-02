--- @module 'rasial.config'
--- @version 2.0.0
--- Updated to support GUI configuration overrides

------------------------------------------
--# IMPORTS
------------------------------------------

local API           = require("api")
local Rotations     = require("rasial.rotations")

local Utils         = require("core.helper")
local Player        = require("core.player")
local PrayerFlicker = require("core.prayer_flicker")

------------------------------------------
--# USER CONFIGURATION
------------------------------------------

local Config        = {}

------------------------------------------
--# GUI CONFIG APPLICATION
------------------------------------------

--- Apply GUI configuration to override defaults
--- @param guiConfig table Configuration from RasialGUI.getConfig()
function Config.applyGUIConfig(guiConfig)
    if not guiConfig then return end

    -- Apply basic settings
    if guiConfig.bankPin then
        Config.userInput.bankPin = tonumber(guiConfig.bankPin) or Config.userInput.bankPin
    end
    if guiConfig.waitForFullHp ~= nil then
        Config.userInput.waitForFullHp = guiConfig.waitForFullHp
    end
    if guiConfig.useDiscord ~= nil then
        Config.userInput.useDiscord = guiConfig.useDiscord
    end

    -- Apply health thresholds
    if guiConfig.healthSolid then
        Config.userInput.playerManager.health.solid.value = guiConfig.healthSolid
        Config.userInput.playerManager.health.solid.type = "percent"
    end
    if guiConfig.healthJellyfish then
        Config.userInput.playerManager.health.jellyfish.value = guiConfig.healthJellyfish
    end
    if guiConfig.healthPotion then
        Config.userInput.playerManager.health.healingPotion.value = guiConfig.healthPotion
    end
    if guiConfig.healthSpecial then
        Config.userInput.playerManager.health.special.value = guiConfig.healthSpecial
    end

    -- Apply prayer thresholds
    if guiConfig.prayerNormal then
        Config.userInput.playerManager.prayer.normal.value = guiConfig.prayerNormal
    end
    if guiConfig.prayerCritical then
        Config.userInput.playerManager.prayer.critical.value = guiConfig.prayerCritical
    end
    if guiConfig.prayerSpecial then
        Config.userInput.playerManager.prayer.special.value = guiConfig.prayerSpecial
    end

    -- Apply rotation preset
    if guiConfig.rotationPreset and Rotations[guiConfig.rotationPreset] then
        Config.userInput.preset.rotations = Rotations[guiConfig.rotationPreset]
    end

    -- Apply War's Retreat options (stored for warsRetreat initialization)
    Config.userInput.warsRetreat = {
        summonConjures = guiConfig.summonConjures,
        useAdrenCrystal = guiConfig.useAdrenCrystal,
        surgeDiveChance = guiConfig.surgeDiveChance,
    }
end

------------------------------------------
--# DEFAULT CONFIGURATION
------------------------------------------

Config.userInput = {
    -- Core settings
    waitForFullHp = true,
    bankPin = 1234, -- Make sure to use your own
    useDiscord = true,

    -- Player Manager thresholds for health and prayer
    playerManager = {
        health = {
            solid         = { type = "fixed", value = 0 },    -- Solid food threshold
            jellyfish     = { type = "percent", value = 40 }, -- Jellyfish threshold
            healingPotion = { type = "percent", value = 40 }, -- Healing potions threshold
            special       = { type = "percent", value = 60 }  -- Enhanced Excalibur threshold
        },
        prayer = {
            normal   = { type = "current", value = 200 }, -- Regular prayer restore threshold
            critical = { type = "percent", value = 10 },  -- Emergency prayer restore threshold
            special  = { type = "current", value = 600 }  -- Ancient elven ritual shard threshold
        }
    },

    -- Prayer Flicker configuration
    prayerFlicker = {
        defaultPrayer = PrayerFlicker.CURSES.SOUL_SPLIT,
        threats = {
            {
                name     = "True power",
                type     = "Animation",
                priority = 10,
                prayer   = PrayerFlicker.CURSES.DEFLECT_NECROMANCY,
                npcId    = 30165,
                id       = 35469,
                delay    = 1,
                duration = 2
            }
        }
    },

    -- Equipment, inventory and combat rotation presets
    preset = {
        aura = "Equilibrium",
        -- Required inventory items (script terminates if missing)
        inventory = {
            { id = 48951, amount = 10 }, -- Vulnerability bombs
            { id = 29448, amount = 4 },  -- Guthix rest flasks (6)
            { id = 42267, amount = 8 },  -- Blue blubber jellyfish
        },

        -- Required equipment items (script terminates if missing)
        -- Equipment slots:
        -- 0 = Head,    1 = Cape,   2 = Neck,   3 = Main-hand,  4 = Body,   5 = Off-hand
        -- 6 = Bottom,  7 = Gloves, 8 = Boots,  9 = Ring,      10 = Ammo,  12 = Pocket
        equipment = {
            { id = 52494, slot = 12 }, -- Scripture of ful
        },

        -- Combat rotations                        -- Change the rotation to a preset of your choosing
        rotations = Rotations["BIS Equilibrium"], -- You can even mix and match or create your own rotations

        -- Buffs to maintain during combat
        buffs = {
            {
                buffName = "Ruination",
                buffId = 30769,
                canApply = function()
                    return true
                end,
                execute = function()
                    return Utils:useAbility("Ruination")
                end,
                toggle = true
            },
            {
                buffName = "Scripture of Ful",
                buffId   = 52494,
                canApply = function()
                    return API.Container_Get_all(94)[18].item_id == 52494
                end,
                execute  = function()
                    if API.Container_Get_all(94)[18].item_id == 52494 then
                        return Utils:useAbility("Scripture of Ful")
                    end
                end,
                toggle   = true
            },
            {
                buffName = "Scripture of Jas",
                buffId   = 51814,
                canApply = function()
                    return API.Container_Get_all(94)[18].item_id == 51814
                end,
                execute  = function()
                    if API.Container_Get_all(94)[18].item_id == 51814 then
                        return Utils:useAbility("Scripture of Jas")
                    end
                end,
            },
            {
                buffName = "Erethdor's grimoire",
                buffId   = 42787,
                canApply = function()
                    return API.Container_Get_all(94)[18].item_id == 42787
                end,
                execute  = function()
                    if API.Container_Get_all(94)[18].item_id == 42787 then
                        return Utils:useAbility("Erethdor's grimoire")
                    end
                end,
            },
            {
                buffName = "Lantadyme incense sticks",
                buffId = 47713,
                execute = function()
                    local name = "Lantadyme incense sticks"
                    if Player:getBuff(47713).found and (Inventory:Contains(name)) and (Inventory:InvItemcountStack_Strings({ name }) >= 6) then
                        return API.DoAction_Inventory3(name, 0, 2, API.OFF_ACT_GeneralInterface_route)
                    else
                        return API.DoAction_Inventory3(name, 0, 1, API.OFF_ACT_GeneralInterface_route)
                    end
                end,
                refreshAt = 660
            },
            {
                buffName = "Elder overload",
                buffId = 49039,
                canApply = function()
                    return (Inventory:Contains("Elder overload"))
                end,
                execute = function()
                    return Inventory:DoAction("Elder overload", 1, API.OFF_ACT_GeneralInterface_route)
                end,
                refreshAt = math.random(10, 20)
            },
            {
                buffName = "Binding contract (ripper demon)",
                buffId = 26095,
                canApply = function()
                    return Inventory:Contains("Binding contract (ripper demon)")
                end,
                execute = function()
                    return Inventory:DoAction("Binding contract (ripper demon)", 1, API.OFF_ACT_GeneralInterface_route)
                end,
                refreshAt = 10
            },
            {
                buffName = "Binding contract (kal'gerion demon)",
                buffId = 26095,
                canApply = function()
                    return Inventory:Contains("Binding contract (kal'gerion demon)")
                end,
                execute = function()
                    return Inventory:DoAction("Binding contract (kal'gerion demon)", 1,
                        API.OFF_ACT_GeneralInterface_route)
                end,
                refreshAt = 10
            }
        }
    },
}

return Config
