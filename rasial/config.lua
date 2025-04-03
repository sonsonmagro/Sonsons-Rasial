---@module 'rasial.config'
local Config = {}

local API = require("api")

local RotationManager = require("core.rotation_manager")
local PrayerFlicker = require("core.prayer_flicker")
local Timer = require("core.timer")

local Utils = require("rasial.utils")

--[[
    A friendly message:
    Hello! It's worth taking some time understanding how things work before playing around with some of the values.
    Feel free to bring all your questions and comments to the discord thread.

    Here's a quick breakdown of the configurations:

    - User Inputs
        - This is for the values that need to be defined by the user; includes values like:
            - Whether or not to use a bank pin
            - The value of said bank pin
            - The key pressed to target cycle (very important for clean rotations)
            - The health and prayer thresholds
                - Used by the player manager to know when to eat or use excalibur/elven ritual shard
            - The items in your loadout to check formatted before every kill

    - Rotation Manager Configuration
        You are invited to change and mess around without things here until you're happy with the result.
        - Will execute a rotation listed, one step at a time. (More details in rotation_manager.lua)
            - step = {
                label: string,                  Name of the ability or inventory item, needs to be accurate
                type: string,                   [OPTIONAL] Type of step used. Can be: "Ability" (default), "Inventory", "Improvise", or "Custom" (default: "Ability")
                action: function(): boolean,    [OPTIONAL] The function to execute with type = "Custom"
                wait: number,                   [OPTIONAL] The amount of time to wait before executing the next step (default 3 ticks)
                useTicks: boolean,              [OPTIONAL] Whether or not to use game ticks or real-time for waiting (default: true)
                style: string                   [OPTIONAL] Used for improvising: Only "Necromancy" is currently supported
                useAdren: boolean               [OPTIONAL] If true, will attempt to spend adrenaline as it sees fit
            }
        - You can have different rotations for different stages.

    - Buff Configuration
        - The values in this list are the ones that will be managed while inside the boss room
        - Feel free to add to the list or change existing values according to your preferences
        - buff = {
            buffName: string,                   The name of the buff
            buffId: number,                     The Bbar ID for checking if the buff is accurate
            execute: function()                 The function to execute in order to apply the buff
            canApply: function(any): boolean,   [OPTIONAL] Function to check if the buff should be applied
            toggle: boolean                     [OPTIONAL] Whether or not to toggle the buff off (re-execute) while not managed
            refreshAt: number                   [OPTIONAL] Number of seconds to refresh the buff at
        }

### WHAT YOU NEED TO KNOW:
    haw haw haw
]]

Config.Instances, Config.TrackedKills = {}, {}

Config.UserInput = {
    --set to true if you want to see debugging messages and metrics
    debug = false,
    -- essential
    useBankPin = false,
    bankPin = 1234,                 -- use ur own [0000 will spam your console]
    targetCycleKey = 0x09,          -- 0x09 is tab
    -- health and prayer thresholds (settings for player manager)
    healthThreshold = {
        normal = {type = "percent", value = 50},
        critical = {type = "percent", value = 25},
        special = {type = "percent", value = 75}  -- excal threshold
    },
    prayerThreshold = {
        normal = {type = "current", value = 200},
        critical = {type = "percent", value = 10},
        special = {type = "current", value = 600}  -- elven shard threshold
    },
    -- things to check in your inventory before fight
    presetChecks = {
        {id = 48951, amount = 10}, -- vuln bombs
        {id = 29448, amount = 4},  -- guthix rests
        {id = 42267, amount = 8},  -- blue blubbers
    },
    --discord (private method)
    discordNotifications = false,
    webhookUrl = "",
    mention = false,
    userId = ""
}

Config.Variables = {
    -- flags 
    initialCheck = false,
    conjuresSummoned = false,
    bossDead = false,
    -- attempts
    bankAttempts = 0,
    conjureAttempts = 0,
    killCount = 0,
    -- tiles
    adreCrystalTile = {x = 0, y = 0, z = 0},
    adreCrystalBDTile = {x = 0, y = 0, z = 0},
    poratlTile = {x = 0, y = 0, z = 0},
    lootTile = {x = 0, y = 0, z = 0},
    safeSpot = {x = 0, y =  0, range = 0},
    -- misc
    adrenCrystalSide = "East",
    gateTile = nil,
    finalZone = nil
}

Config.Data = {
    loot = {
        566,    -- soul rune
        55319,  -- noted super necromancy (3)
        31867,  -- hydrix bolt tips
        9194,   -- onyx bolt tips
        42954,  -- onyx dust
        44814,  -- light animica stone spirit
        44815,  -- dark animica stone spirit
        57174,  -- primal stone spirits
        54019,  -- catalytic anima stone
        15271,  -- noted Raw rocktail
        55630,  -- noted Robust memento
        55632,  -- noted Powerful memento
        5303,   -- dwarf weed seed
        5304,   -- torstol seed
        51104,  -- noted Medium spiky orikalkum salvage
        53508,  -- noted Large blunt necronium salvage
        990,    -- noted Crystal key
    },

    -- rare drops
    uniques = {
        55480,  -- omni guard
        55482,  -- soulbound lantern
        55488,  -- crown of the First Necromancer
        55490,  -- robe top of the First Necromancer
        55492,  -- robe bottom of the First Necromancer
        55494,  -- hand wrap of the First Necromancer
        55496,  -- foot wraps of the First Necromancer
        55674,  -- miso's collar
    },

    -- some quirky shit
    -- dw about it babe
    -- implemented later, but saved for now
    uniqueDropData = {
        [55480] = {
            name = "Omni guard",
            prefix = "an",
            thumbnail = "https://runescape.wiki/images/thumb/Omni_guard_detail.png/150px-Omni_guard_detail.png?201ac"
        },
        [55482] = {
            name = "Soulbound lantern",
            thumbnail = "https://runescape.wiki/images/thumb/Soulbound_lantern_detail.png/49px-Soulbound_lantern_detail.png?c7346"
        },
        [55488] = {
            name = "Crown of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Crown_of_the_First_Necromancer_detail.png/78px-Crown_of_the_First_Necromancer_detail.png?c607d"
        },
        [55490] = {
            name = "Robe top of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Robe_top_of_the_First_Necromancer_detail.png/128px-Robe_top_of_the_First_Necromancer_detail.png?25297"
        },
        [55492] = {
            name = "Robe bottom of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Robe_bottom_of_the_First_Necromancer_detail.png/76px-Robe_bottom_of_the_First_Necromancer_detail.png?5d7b4",
        },
        [55494] = {
            name = "Hand wrap of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Hand_wrap_of_the_First_Necromancer_detail.png/88px-Hand_wrap_of_the_First_Necromancer_detail.png?a0465",
        },
        [55496] = {
            name = "Foot wraps of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Foot_wraps_of_the_First_Necromancer_detail.png/152px-Foot_wraps_of_the_First_Necromancer_detail.png?6b9d4"
        },
        [55674] = {
            name = "Miso's collar",
            thumbnail = "https://runescape.wiki/images/thumb/Miso%27s_collar_detail.png/102px-Miso%27s_collar_detail.png?4e63b",
            message = "Meow meow meow meoooooow!"
        }
    },
    lootedUniques = {}
}


--#region rotation manager init
Config.RotationManager = {
    -- this rotation references and tries to match the equilibrium rotation listed on the PVME
    -- assumes t100 weapons and t99 prayers, amongst other best-in-slot items
    fightRotation = {
        name = "Fight Rotation",
        rotation = {
            --prefight steps
            {label = "Command Vengeful Ghost"},
            {label = "Invoke Death", wait = 1},
            {label = "Salve amulet (e)", type = "Custom", action = function() return Inventory:Equip("Salve amulet (e)") end, wait = 0},
            {label = "Surge"},
            {label = "Command Skeleton Warrior"},
            {label = "Target cycle", type = "Custom", action = function()
                print("Tick: "..API.Get_tick() - Config.Timer.handleInstance.lastTriggered)
                API.KeyboardPress2(Config.UserInput.targetCycleKey, 60, 0)
                return true
            end, wait = 0},
            --safety target cycle
            {label = "Target cycle", type = "Custom", action = function()
                if API.ReadTargetInfo(true).Hitpoints > 0 then
                    return true
                else
                    API.KeyboardPress2(Config.UserInput.targetCycleKey, 60, 0)
                    return true
                end
            end, wait = 0},
            {label = "Vulnerability bomb", type = "Inventory", wait = 0},
            {label = "Death Skulls"},
            --pre living death steps
            {label = "Soul Sap"},
            {label = "Touch of Death"},
            {label = "Basic<nbsp>Attack"},
            {label = "Soul Sap"},
            -- living death steps
            {label = "Living Death", wait = 0},
            {label = "Adrenaline renewal", type = "Inventory"}, -- can also not have type defined if it's on the ability bar
            {label = "Touch of Death"},
            {label = "Death Skulls", useTicks = true},
            {label = "Soul Sap", wait = 1, useTicks = true},
            {label = "Vengeance", wait = 2, useTicks = true},
            {label = "Split Soul"},
            {label = "Divert"},
            {label = "Bloat"},
            {label = "Soul Sap"},
            {label = "Command Skeleton Warrior", useTicks = true},
            {label = "Death Skulls", wait = 2, useTicks = true},
            {label = "Undead Slayer", wait = 1, useTicks = true},
            {label = "Finger of Death"},
            {label = "Touch of Death"},
            {label = "Soul Sap"},
            {label = "Volley of Souls"},
            {label = "Finger of Death"},
            {label = "Soul Sap"},
            {label = "Death Skulls"},
            -- post living death
            {label = "Bloat"},
            {label = "Soul Sap"},
            {label = "Touch of Death"},
            {label = "Basic<nbsp>Attack"},
            {label = "Soul Sap"},
            {label = "Improvise", type = "Improvise", style = "Necromancy", spendAdren = true}
        }
    },
    finalRotation = {
        name = "Final Phase Rotation",
        rotation = {
            --final phase steps
            {label = "Basic<nbsp>Attack"},
            {label = "Vulnerability bomb", type = "Inventory", wait = 0},
            {label = "Death Skulls"},
            {label = "Soul Sap"},
            {label = "Weapon Special Attack"},
            {label = "Volley of Souls"},
            {label = "Basic<nbsp>Attack"},
            {label = "Essence of Finality", type = "Custom", action = function() return Inventory:Equip("Essence of Finality") end, useTicks = false, wait = 0},
            {label = "Essence of Finality"},
            {label = "Salve amulet (e)", type = "Custom", action = function() return Inventory:Equip("Salve amulet (e)") end, wait = 0},
            {label = "Touch of Death"},
            {label = "Improvise", type = "Improvise", style = "Necromancy", spendAdren = true}
        }
    }
}

Config.Instances.fightRotation = RotationManager.new(Config.RotationManager.fightRotation)
Config.Instances.finalRotation = RotationManager.new(Config.RotationManager.finalRotation)
--#endregion

Config.Buffs = {
    {
        buffName = "Ruination",
        buffId = 30769,
        canApply = function(self) return (self.state.prayer.current > 100) end,
        execute = function() return Utils.useAbility("Ruination") end,
        toggle = true
    },
    {
        buffName  = "Scripture of Ful",
        buffId = 52494,
        canApply = function(self) return API.GetEquipSlot(12).itemid1 == 52494 end,
        execute = function()
            return Utils.useAbility("Scripture of Ful")
        end,
        toggle = true
    },
    {
        buffName = "Lantadyme incense sticks",
        buffId = 47713,
        execute = function()
            local name = "Lantadyme incense sticks"
            if (API.Bbar_ConvToSeconds(API.Buffbar_GetIDstatus(47713, false)) > 0) and
            (API.InvItemcount_String(name) > 0) and (API.InvItemcountStack_String(name) >= 6) then
                return API.DoAction_Inventory3(name, 0, 1, API.OFF_ACT_GeneralInterface_route)
            else
                return API.DoAction_Inventory3(name, 0, 2, API.OFF_ACT_GeneralInterface_route)
            end
        end,
        refreshAt = 660
    },
    {
        buffName = "Elder overload",
        buffId = 49039,
        canApply = function(state) return (API.InvItemcount_String("Elder overload") > 0) and (API.Get_tick() - state.timestamp.buff > 1) end,
        execute = function()
            return API.DoAction_Inventory3("Elder overload", 0, 1, API.OFF_ACT_GeneralInterface_route)
        end,
        refreshAt = math.random(10, 20)
    },
    -- placeholder for summoning manager
    {
        buffName = "Binding contract (ripper demon)",
        buffId = 26095, -- summoning buff lol
        canApply = function(state) return not state:getBuff(26095).found end,
        execute = function() return API.DoAction_Inventory3("Binding contract (ripper demon)", 0, 1, API.OFF_ACT_GeneralInterface_route) end,
    }
}

--returns prayer flicker init
Config.prayerFlicker = {
    prayers = {
        PrayerFlicker.PRAYERS.SOUL_SPLIT,
        PrayerFlicker.PRAYERS.DEFLECT_NECROMANCY
    },
    defaultPrayer = PrayerFlicker.PRAYERS.SOUL_SPLIT,
    npcs = {
        {
            id = 30165, -- rasial
            animations = {
                {
                    animId = 35469,                                    -- true power
                    prayer = PrayerFlicker.PRAYERS.DEFLECT_NECROMANCY, -- deflect necromancy
                    priority = 1,
                    activationDelay = 0,
                    duration = 2
                }
            }
        }
    }
}

Config.Instances.prayerFlicker = PrayerFlicker.new(Config.prayerFlicker)
--#endregion

--#region timers init
Config.Timer = {
    flexTimer = Timer.new(
        {
            name = "Flex timer",
            cooldown = 600,
            useTicks = false,
            condition = function() return true end,
            action = function() return true end
        }
    ),
    loadLastPreset = Timer.new(
        {
            name = "Load last preset",
            cooldown = 3,
            condition = function(state) return Utils.playerIsIdle(state) end,
            action = function(state)
                if not Utils.hasAllItems(Config.UserInput.presetChecks) then
                    if Config.Variables.bankAttempts <= 3 then
                        if API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ 114750 },50) then
                            Config.Variables.bankAttempts = Config.Variables.bankAttempts + 1
                            return true
                        end
                    else
                        Utils.terminate(
                            "Attempts at loading appropriate preset failed.",
                            "Make sure your last loaded preset has all items."
                        )
                    end
                end
                return false
            end
        }
    ),
    standByBankChest = Timer.new(
        {
            name = "Bankstand",
            cooldown = 3,
            condition = function(state) return Utils.playerIsIdle(state) end,
            action = function(state)
                local bankChest = Utils.find(114750, 12, 20)
                if not Utils.atLocation(bankChest.Tile_XYZ.x, bankChest.Tile_XYZ.y -1, 1) then
                    ---@diagnostic disable-next-line
                    return API.DoAction_WalkerW(WPOINT.new(bankChest.Tile_XYZ.x, bankChest.Tile_XYZ.y - 1, 0))
                end
                return false
            end
        }
    ),
    prayAtAltar = Timer.new(
        {
            name = "Pray at Altar of War",
            cooldown = 6,
            condition = function(state) return Utils.playerIsIdle(state) end,
            action = function(state) return API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0, { 114748 }, 50) end
        }
    ),
    -- TODO: fix implementation to be cleaner when NOT going to bank -> altar
    navigate = Timer.new(
        {
            name = "Navigate",
            cooldown = 1,
            useTicks = true,
            condition = function(state) return true end,
            action = function(state)
                --[[
                    navigation cases:
                    1. at altar: best case scenario
                        - click on tile in front of bank chest
                        - flexTimer: reset
                    2. at bank chest
                        - check direction facing
                        - if surge direction
                            - yes: has dive/bd?
                                - yes: need adren?
                                    - yes: bd surge to appropriate adren crystal tile
                                    - no: bd surge to appropriate portal tile
                                - no: surge & flexTimer:reset()
                            - no: goto continue
                        - yes: surge & flexTimer:reset()
                        - no: goto continue
                    3. at stairs:
                        - facing portals?
                            - yes:    1. surge
                                    2. flexTimer:reset()
                                    3. return
                            - no: goto continue
                    ::continue::
                    4. else
                        - need adren?
                            - yes: click on adren crystal
                            - no: click on portal
                ]]

                ---@diagnostic disable-next-line
                local coords = (Config.Variables.adrenCrystalSide == "West" and WPOINT.new(3290, 10148,0)) or WPOINT.new(3298,10148, 0)
                --flexTimer.useTicks = true

                if Utils.atLocation(3304, 10127, 3) then -- at altar
                    Config.Timer.flexTimer.name = "Moving next to bank"
                    Config.Timer.flexTimer.cooldown = 300
                    Config.Timer.flexTimer.useTicks = false
                    -- click on tile infornt of bank chest
                    ---@diagnostic disable-next-line
                    Config.Timer.flexTimer.action = function(state) return API.DoAction_WalkerW(WPOINT.new(3299, 10131, 0)) end
                elseif Utils.atLocation(3299, 10132, 3) and not Utils.atLocation(3294, 10134, 2) and state.state.orientation >= 300 then -- at bank chest and not at stairs and facing nw
                    Config.Timer.flexTimer.cooldown = 1
                    Config.Timer.flexTimer.name = "Dive & Surge to adrenaline crystals"
                    Config.Timer.flexTimer.action = function(state)
                        -- surge bd to appropriate adren crystal
                        if Utils.useAbility("Surge") then
                            API.RandomSleep2(50, 30, 30)
                            if API.DoAction_Dive_Tile(coords) then
                                return true
                            end
                        end
                        return false
                    end
                    Config.Timer.flexTimer:reset()
                elseif Utils.atLocation(3294, 10134, 2) and state.state.orientation == 0 then -- at stairs facing north
                    Config.Timer.flexTimer.name = "Dive & Surge at stairs"
                    -- uses surge when at stairs
                    Config.Timer.flexTimer.action = function(state)
                        if Utils.useAbility("Surge") then
                            API.RandomSleep2(50, 30, 30)
                            if API.DoAction_Dive_Tile(coords) then
                                return true
                            end
                        end
                        return false
                    end
                elseif Utils.playerIsIdle(state) then
                    Config.Timer.flexTimer.name = "Walking around portals and crystals"
                    ---@diagnostic disable-next-line
                    Config.Timer.flexTimer.action = function(state) return API.DoAction_WalkerW(WPOINT.new(3293 + math.random(-2, 2), 10148 + math.random(-2, 2), 0)) end
                end

                local success = Config.Timer.flexTimer:execute(state)
                Config.Timer.flexTimer.cooldown = 1
                Config.Timer.flexTimer.action = function() end
                if Config.Timer.flexTimer.name == "Surging at stairs" then Config.Timer.flexTimer:reset() end
                if Config.Timer.flexTimer.name == "Moving next to bank" then Config.Timer.flexTimer:reset() end

                return success
            end
        }
    ),
    channelAdren = Timer.new(
        {
            name = "Channel Adrenaline",
            cooldown = 3,
            condition = function(state) return Utils.playerIsIdle(state) end,
            action = function(state)
                ---@diagnostic disable-next-line
                local coords = (Config.Variables.adrenCrystalSide == "West" and WPOINT.new(3290, 10148,0)) or WPOINT.new(3298,10148, 0)
                return API.DoAction_Object_r(0x29, API.OFF_ACT_GeneralObject_route0, {114749}, 40, coords, 3)
            end
        }
    ),
    summonConjures = Timer.new(
        {
            name = "Summon conjures",
            cooldown = 300,         -- 300 ms
            useTicks = false,       -- uses real time instead of game ticks
            condition = function() return true end,
            action = function(playerManager)
                --checks if conjures are summoned or animation matches summoning animation
                local zombieGhostSkellyCheck = playerManager:getBuff(34177).found and playerManager:getBuff(34178).found and playerManager:getBuff(34179).found
                if (playerManager.state.animation == 35502) or zombieGhostSkellyCheck then
                    Config.Variables.conjuresSummoned = true
                end
    
                -- reset flexTimer in case it was used elswhere
                -- override flexTimer configuration
                if not ((Config.Timer.flexTimer.name == "Summoning conjures") or (Config.Timer.flexTimer.name == "Excalibur in off-hand -> Equipping lantern")) then
                    Config.Timer.flexTimer.cooldown = 1
                    Config.Timer.flexTimer.useTicks = true
                    Config.Timer.flexTimer:reset()
                end
    
                --equip lantern if excal is in off-hand
                if playerManager:_hasExcalibur() and playerManager:_hasExcalibur().location == "equipped" then
                    Config.Timer.flexTimer.action = function(playerManager) return Inventory:Equip("Augmented Soulbound lantern") end
                    Config.Timer.flexTimer.name = "Excalibur in off-hand -> Equipping lantern"
                    Config.Timer.flexTimer:execute(playerManager)
                    return true -- exits out of sequence and activates summonConjure's timer
                end
    
                if Config.Timer.flexTimer:canTrigger(playerManager) then
                    if Config.Variables.conjureAttempts <= 5 then
                        --overrides flexTimer's name, cooldowns and actions
                        Config.Timer.flexTimer.action = function() return Utils.useAbility("Conjure Undead Army") end
                        Config.Timer.flexTimer.name = "Summoning conjures"
                        if Config.Timer.flexTimer:execute() then
                            Config.Timer.flexTimer.cooldown = 600
                            Config.Variables.conjureAttempts = Config.Variables.conjureAttempts + 1
                            return true
                        end
                    else
                        Utils.terminate(
                            "Too many summoning conjures attempts failed.",
                            "Make sure you have enough runes in your nexus."
                        )
                    end
                end
                return false
            end
        }
    ),
    goThroughPortal = Timer.new(
        {
            name = "Go through Rasial portal",
            cooldown = 4,
            condition = function() return true end,
            action = function()
                if API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 127138 },50) then
                    Config.Variables.bankAttempts = 0
                    Config.Variables.conjureAttempts = 0
                    return true
                end
                return false
            end
        }
    ),
    useLifeTransfer = Timer.new(
        {
            name = "Use Life Transfer",
            cooldown = 5,
            condition = function() return true end,
            action = function() return Utils.useAbility("Life Transfer") end
        }
    ),
    --dummy instance timer
    instanceTimer = Timer.new(
        {
            name = "Instance timer",
            cooldown = 58*10000, -- 58 minutes I hope
            useTicks = false,
            condition = function () return true end,
            action = function() return true end
        }
    ),
    handleInstance = Timer.new(
        {
            name = "Handle Rasial instance",
            cooldown = 1,
            condition = function() return true end,
            action = function(state)
                Config.Timer.flexTimer.useTicks = true
                Config.Timer.flexTimer.cooldown = 1

                if (Config.Timer.instanceTimer.lastTriggered == 0) or Config.Timer.instanceTimer:canTrigger() then
                    if API.Check_Dialog_Open() then
                        Config.Timer.flexTimer.name = "Selecting Rasial encounter"
                        ---@diagnostic disable-next-line
                        Config.Timer.flexTimer.action = function() return API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188 , 13, -1, API.OFF_ACT_GeneralInterface_Choose_option) end
                    elseif API.VB_FindPSettinOrder(2874).state == 18 then -- boss interface is open
                        Config.Timer.flexTimer.name = "Starting private instance"
                        Config.Timer.flexTimer.action = function()
                            ---@diagnostic disable-next-line
                            if API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1, API.OFF_ACT_GeneralInterface_route) then
                                Config.Timer.instanceTimer:execute(state)
                                return true
                            end
                        end
                    else
                        Config.Timer.flexTimer.name = "Entering through citadel gate"
                        Config.Timer.flexTimer.action = function() return API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 127142 },50) end
                    end
                else
                    Config.Timer.flexTimer.name = "Rejoining instance"
                    Config.Timer.flexTimer.action = function() return API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route2,{ 127142 },50) end
                end

                local success = Config.Timer.flexTimer:execute(state)
                return success
            end
        }
    ),
    getInPosition = Timer.new(
        {
            name = "Get in position (safe spot)",
            cooldown = 2,
            condition = function(state) return not state.state.moving end,
            action = function(state)
                ---@diagnostic disable-next-line
                return API.DoAction_WalkerW(WPOINT.new(Config.Variables.safeSpot.x, Config.Variables.safeSpot.y, 0))
            end
        }
    ),
    dodge = Timer.new(
        {
            name = "Dodge",
            cooldown = 1,
            condition = function(state) return (#Utils.findAll(6974, 4, 10) > 1) and not state.state.isMoving end, -- in danger
            action = function(state)
                local lightning = Utils.findAll(6974, 4, 20)
                local onLightning = false

                for _, obj in ipairs(lightning) do
                    local centerX = math.floor(obj.Tile_XYZ.x)
                    local centerY = math.floor(obj.Tile_XYZ.y)
                    if Utils.atLocation(centerX, centerY, 1) then
                        onLightning = true
                    end
                end

                if onLightning then 
                    local tiles = {}
                    local startX, endX = Config.Variables.finalZone[1].x, Config.Variables.finalZone[2].x
                    local startY, endY = Config.Variables.finalZone[1].y, Config.Variables.finalZone[2].y

                    for x = startX, endX do
                        for y = startY, endY do
                            table.insert(tiles, {x = math.floor(x), y = math.floor(y)})
                        end
                    end

                    local unsafe = {}
                    for _, obj in ipairs(lightning) do
                        local centerX = math.floor(obj.Tile_XYZ.x)
                        local centerY = math.floor(obj.Tile_XYZ.y)
                        unsafe[centerX.."_"..centerY] = true
                    end

                    local safeTiles = {}
                    for _, tile in ipairs(tiles) do
                        if not unsafe[tile.x.."_"..tile.y] then
                            table.insert(safeTiles, tile)
                        end
                    end

                    local bestDist, bestTile = math.huge, nil
                    for _, tile in ipairs(safeTiles) do
                        local dx = tile.x - state.state.coords.x
                        local dy = tile.y - state.state.coords.y
                        local dist = dx*dx + dy*dy
                        if dist < bestDist then
                            bestDist, bestTile = dist, tile
                        end
                    end

                    if bestTile then
                        ---@diagnostic disable-next-line
                        return API.DoAction_WalkerW(WPOINT.new(bestTile.x, bestTile.y, 0))
                    end
                end
                return false
            end
        }
    ),
    equipLuckRing = Timer.new(
        {
            name = "Equip T4 luck ring",
            cooldown = 3,
            condition = function() return true end,
            action = function() return Inventory:Equip("Luck of the Dwarves") or Inventory:Equip("Hazelmere's signet ring") end
        }
    ),
    getInLootPosition = Timer.new(
        {
            name = "Get in position (loot tile)",
            cooldown = 1,
            condition = function(state) return not state.state.moving end,
            action = function(state)
                ---@diagnostic disable-next-line
                return API.DoAction_WalkerW(WPOINT.new(Config.Variables.lootSpot.x, Config.Variables.lootSpot.y, 0))
            end
        }
    ),
    -- lazy way of doing it without checks i guess idk...
    collectDeath = Timer.new(
        {
            name = "Log kill details",
            cooldown = 10000,   -- 10 seconds
            useTicks = false,   -- real time check
            condition = function() return true end,
            action = function()
                local killTime = "UNKNOWN"
                for _, chat in ipairs(API.GatherEvents_chat_check()) do
                    if string.find(chat.text, "Completion Time") then
                        killTime = chat.text:gsub("<col=2DBA14>Completion Time:</col> ", "")
                        print(killTime)
                    end
                end
                Config.Variables.killCount = Config.Variables.killCount + 1
                Config.TrackedKills[Config.Variables.killCount] = {
                    runtime = API.ScriptRuntimeString(),
                    fightDuration = killTime
                }
                Config.Variables.bossDead = true
                return true
            end
        }
    ),
    uniqueDropped = Timer.new(
        {
            name = "Unique dropped: sending discord message",
            cooldown = 20,
            condition = function() return #API.GetAllObjArray1(Config.Data.uniques, 30, {3}) > 0 end,
            action = function()
                ---@type AllObject[]
                local uniqueDrops, success = API.GetAllObjArray1(Config.Data.uniques, 30, {3}), false

                if uniqueDrops and Config.UserInput.discordNotifications then
                    -- double drops are 1/40k-ish
                    for _, drop in pairs(uniqueDrops) do
                        local killData = Config.TrackedKills[Config.Variables.killCount]
                        local dropData = Config.Data.uniqueDropData[drop.Id]
                        Utils.sendDiscordWebhook((Config.UserInput.mention and "<@"..Config.UserInput.userId..">") or "", Config.UserInput.webhookUrl, {
                            embeds = {
                                {
                                    title = string.format("Congratulations! You found %s%s", dropData.prefix or (dropData.name ~= "Miso's collar") and "a " or "", dropData.name),
                                    description = dropData.message or ("You've managed to strip Rasial of a shiny **"..dropData.name.."**!"),
                                    color = 10181046,
                                    author = {
                                        name = "Sonson's Rasial",
                                        icon_url = "https://runescape.wiki/images/thumb/The_First_Necromancer_chathead.png/90px-The_First_Necromancer_chathead.png?dea03"
                                    },
                                    thumbnail = {url = dropData.thumbnail},
                                    fields = {
                                        {name = "Kill Number", value = tostring(Config.Variables.killCount), inline = true},
                                        {name = "Fight Duration", value = killData.killDuration, inline = true},
                                        {name = "Runtime", value = killData.runtime, inline = true},
                                    }
                                }
                            }
                        })
                        API.RandomSleep2(50, 40, 40)
                    end
                end

            return success
        end
        }
    ),
    pickupLoot = Timer.new(
        {
            name = "Picking up loot",
            cooldown = 1,
            condition = function() return true end,
            action = function(state)
                Config.Timer.uniqueDropped:execute()
                if API.DoAction_Loot_w(Utils.virtualTableConcat(Config.Data.loot, Config.Data.uniques), 30, API.PlayerCoordfloat(), 30) then
                    Config.Timer.collectDeath:execute()
                    return true
                end
                return false
            end
        }
    ),
    teleportToWars = Timer.new(
        {
            name = "War's Retreat Teleport",
            cooldown = 10,
            condition = function(state) return Utils.playerIsIdle(state) end,
            action = function(state) return Utils.useAbility("War's Retreat Teleport") end
        }
    )
}
--#endregion

---@type PlayerManagerConfig
Config.playerManager = {
    locations = {
        {
            name   = "War's Retreat",
            coords = { x = 3295, y = 10137, range = 30 }
        },
        {
            name = "Rasial's Citadel (Lobby)",
            coords = { x = 864, y = 1742, range = 12 }
        },
        {
            name = "Rasial's Citadel (Boss Room)",
            detector = function() -- checks to see if instance timer exists
                local timer = {
                    { 861, 0, -1, -1, 0 }, { 861, 2, -1, 0, 0 },
                    { 861, 4, -1, 2,  0 }, { 861, 8, -1, 4, 0 }
                }
                local result = API.ScanForInterfaceTest2Get(false, timer)
                return result and #result > 0 and #result[1].textids > 0
            end
        },
        {
            name = "Death's Office",
            detector = function() return #Utils.findAll(27299, 1, 30) > 1 end
        },
    },
    -- status = {name: string, priority: number, condition: fun(self):boolean, execute: fun(self)}
    statuses = {
        -- general statuses
        {
            name = "Initializing",
            condition = function(self) return Config.Variables.initialCheck == false end,
            execute =  function(self)
                if not Config.Variables.initialCheck then
                    if self.state.location ~= "War's Retreat" then
                        Utils.terminate(
                            "Unfamiliar starting location.",
                            "Please start the script at War's Retreat."
                        )
                        return
                    end
                    if #Utils.findAll(127138, 0, 60) == 0 then -- rasial portal
                        Utils.terminate("Portal to Rasial's Citadel not found.")
                        return
                    end
                    Config.Variables.adrenCrystalSide = (math.floor(Utils.find(127138, 0, 60).Tile_XYZ.x) == 3298) and "East" or "West"
                    Utils.debugLog("Portal & Adrenaline crystal side: "..Config.Variables.adrenCrystalSide)
                    Config.Variables.initialCheck = true
                end
            end,
            priority = 100
        },
        {
            name = "Resetting tracked Config.Variables",
            condition = function(self) return Config.Variables.bossDead and self.state.location == "War's Retreat" end,
            execute = function(self)
                Utils.debugLog("Resetting everything")
                    -- reset everything
                    Config.Variables.conjuresSummoned = false
                    Config.Variables.bankAttempts = 0
                    Config.Variables.conjureAttempts = 0
                    Config.Variables.safeSpot = {x = 0, y =  0, range = 0}
                    Config.Variables.gateTile = nil
                    Config.Variables.finalZone = nil
                    Config.Variables.bossDead = false
            end,
            priority = 90,
        },
        -- statuses at war's retreat
        {
            name = "Doing Bank PIN",
            condition = function(self) 
                if self.state.location == "War's Retreat" then
                    if API.DoBankPin(Config.UserInput.bankPin) then
                        if not Config.UserInput.useBankPin then
                            Utils.terminate(
                                "No bankpin provided while being bankpin required.",
                                "Make sure your bankpin is initialized under Config.userInput.bankPin."
                            )
                        else
                            return true
                        end
                    end
                end
                return false
            end,
            execute = function(self) end,
            priority = 11
        },
        {
            name = "Loading last preset",
            condition = function(self) return (self.state.location == "War's Retreat") and not Utils.hasAllItems(Config.UserInput.presetChecks) end,
            execute = function(self)
                Config.Timer.loadLastPreset:execute(self)
            end,
            priority = 10
        },
        {
            name = "Waiting for health to regenerate",
            condition = function(self) return self.state.location == "War's Retreat" and self.state.health.percent < 90 end,
            execute = function(self) Config.Timer.standByBankChest:execute(self) end,
            priority = 9
        },
        {
            name = "Interacting with Altar of War",
            condition = function(self) return self.state.location == "War's Retreat" and self.state.prayer.percent < 90 end,
            execute = function(self)
                Config.Instances.prayerFlicker:deactivatePrayer()
                Config.Timer.prayAtAltar:execute(self) end,
            priority = 8
        },
        {
            name = "Navigate to Adrenaline crytals",
            condition = function(self)
                if self.state.adrenaline >= 100 then return false end
                if Utils.find(114749, 12, 60) then
                    local crystal = Utils.find(114749, 12, 60).Tile_XYZ
                    return self.state.location == "War's Retreat" and not Utils.atLocation(crystal.x, crystal.y, 6)
                end
                return false
            end,
            execute = function(self) Config.Timer.navigate:execute(self) end,
            priority = 7
        },
        {
            name = "Channeling adrenaline",
            condition = function(self) return self.state.location == "War's Retreat" and self.state.adrenaline < 100 end,
            execute = function(self) Config.Timer.channelAdren:execute(self) end,
            priority = 6
        },
        {
            name = "Approaching portal",
            condition = function(self) return self.state.location == "War's Retreat" and not Utils.atLocation(3293, 10148, 12) end,
            execute = function(self) Config.Timer.navigate:execute(self) end,
            priority = 5
        },
        {
            name = "Summoning conjures",
            condition = function(self) return self.state.location == "War's Retreat" and not Config.Variables.conjuresSummoned end,
            execute = function(self) Config.Timer.summonConjures:execute(self) end,
            priority = 4
        },
        {
            name = "Going through portal",
            condition = function(self) return self.state.location == "War's Retreat" end,
            execute = function(self) Config.Timer.goThroughPortal:execute(self) end,
            priority = 3
        },
        -- statuses at citadel lobby
        {
            name = "Extending conjure duration",
            condition = function(self) return self.state.location == "Rasial's Citadel (Lobby)" and (API.GetABs_name1("Life Transfer").cooldown_timer <= 1) end,
            execute = function(self) Config.Timer.useLifeTransfer:execute(self) end,
            priority = 10
        },
        {
            name = Config.Variables.hasInstance and "Rejoining instance" or "Starting new instance",
            condition = function(self) return self.state.location == "Rasial's Citadel (Lobby)" end,
            execute = function(self) Config.Timer.handleInstance:execute(self) end,
            priority = 9
        },
        -- statuses at citadel boss room
        -- initializing everything
        {
            name = "Locking in!",
            condition = function(self) return self.state.location == "Rasial's Citadel (Boss Room)" and not Config.Variables.gateTile end,
            execute = function(self)
                local gate = Utils.findAll(127142, 12, 50)
                if #gate > 0 then
                    local gateTile = gate[1].Tile_XYZ
                    if gateTile.x == 864.5 and gateTile.y == 1745.5 then
                        Utils.debugLog("Registered the wrong gate.")
                        return
                    end
                    Config.Variables.safeSpot = {x = gateTile.x - 1, y = gateTile.y + 28, range = 0}
                    Config.Variables.lootSpot = {x = gateTile.x - 1, y = gateTile.y + 26, range = 0}
                    Utils.debugLog(string.format("Safe spot tile: (%s, %s, 0)", Config.Variables.safeSpot.x, Config.Variables.safeSpot.y))
                    Config.Variables.finalZone = {
                        {x = gateTile.x - 3, y = gateTile.y + 27},
                        {x = gateTile.x + 2, y = gateTile.y + 28}
                    }
                    Config.Variables.gateTile = gateTile
                end
            end,
            priority = 40
        },
        -- pre-fight
        {
            name = "Getting in position",
            condition = function(self)
                local rasial = self.state.location == "Rasial's Citadel (Boss Room)" and (not Utils.find(30165, 1, 20) or (Utils.find(30165, 1, 20) and Utils.find(30165, 1, 20).Life > 0))
                return not Config.Variables.bossDead and rasial and not Utils.atLocation(Config.Variables.safeSpot.x, Config.Variables.safeSpot.y, 1)
            end,
            execute = function(self)
                Config.Timer.getInPosition:execute(self)    -- timer
                Config.Instances.fightRotation:execute()    -- rotation_manager
                self:manageHealth()                         -- player manager [health manager]
                self:managePrayer()                         -- player manager [prayer manager]
                self:manageBuffs(Config.Buffs)              -- player manager [buff manager]
            end,
            priority = 4
        },
        {
            name = "Waiting for Boss...",
            condition = function(self)
                return not Config.Variables.bossDead and (self.state.location == "Rasial's Citadel (Boss Room)") and (#Utils.findAll(30165, 1, 20) == 0)
            end,
            execute = function(self)
                Config.Instances.fightRotation:execute()    -- rotation_manager
                self:manageHealth()
                self:managePrayer()
                self:manageBuffs(Config.Buffs)
            end,
            priority = 1
        },
        -- fight stuff
        {
            name = "Fighting Boss (Final Phase)",
            condition = function(self)
                local rasial = self.state.location == "Rasial's Citadel (Boss Room)"
                    and Utils.find(30165, 1, 20)
                    return not Config.Variables.bossDead and rasial and rasial.Life <= 199000 and rasial.Life > 0
            end,
            execute = function(self)
                if Config.Instances.finalRotation.index == 1 then
                    Utils.debugLog("Transferring cooldowns...")
                    Config.Instances.finalRotation.timer.lastTriggered = Config.Instances.fightRotation.timer.lastTriggered
                    Config.Instances.finalRotation.timer.lastTime = Config.Instances.fightRotation.timer.lastTime
                    Config.Instances.finalRotation.timer.cooldown = Config.Instances.fightRotation.timer.cooldown
                    Config.Instances.finalRotation.trailing = true
                end
                Config.Instances.finalRotation:execute()      -- rotation_manager
                Config.Timer.dodge:execute(self)
                self:manageHealth()
                self:managePrayer()
                self:manageBuffs(Config.Buffs)
                Config.Instances.prayerFlicker:update() -- how tf
                if Utils.find(30165, 1, 20) and Utils.find(30165, 1, 20).Life <= 30000 then Config.Timer.equipLuckRing:execute() end
            end,
            priority = 5
        },
        {
            name = "Fighting Boss",
            condition = function(self)
                local rasial = self.state.location == "Rasial's Citadel (Boss Room)"
                and Utils.find(30165, 1, 20)
                return rasial and true or false
            end,
            execute = function(self)
                Config.Instances.fightRotation:execute()      -- rotation_manager
                self:manageHealth()
                self:managePrayer()
                self:manageBuffs(Config.Buffs)
                Config.Instances.prayerFlicker:update()
            end,
            priority = 3
        },
        -- post fight
        {
            name = "Getting in position for loot",
            condition = function(self)
                local rasial = self.state.location == "Rasial's Citadel (Boss Room)" and Utils.find(30165, 1, 20) and Utils.find(30165, 1, 20).Life == 0
                return not Config.Variables.bossDead and rasial and not Utils.atLocation(Config.Variables.lootSpot.x, Config.Variables.lootSpot.y, 1)
            end,
            execute = function(self) Config.Timer.getInLootPosition:execute(self) end,
            priority = 5
        },
        {
            name = "Looting",
            condition = function() return (#API.GetAllObjArray1(Utils.virtualTableConcat(Config.Data.loot, Config.Data.uniques), 70, {3}) > 0) end,
            execute = function() Config.Timer.pickupLoot:execute() end,
            priority = 10
        },
        {
            name = "Teleport to War's",
            condition = function(self) return Config.Variables.bossDead and #API.GetAllObjArray1(Utils.virtualTableConcat(Config.Data.loot, Config.Data.uniques), 70, {3}) == 0 end,
            execute = function(self)
                Config.Timer.teleportToWars:execute(self)
                Config.Instances.fightRotation:reset()
                Config.Instances.finalRotation:reset()
                end,
            priority = 1
        }
    },
    health = Config.UserInput.healthThreshold,
    prayer = Config.UserInput.prayerThreshold
}

return Config
