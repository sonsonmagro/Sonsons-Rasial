--- @module "Sonson's Rasial"
--- @version 2.1.1
-- Title: Sonson's Rasial
-- Author: Sonson
-- Description: Automated Rasial boss script with GUI, presets, and death recovery
-- Version: 2.1.1
-- Category: PVM

---@diagnostic disable: undefined-global
------------------------------------------
-- # IMPORTS
------------------------------------------
local API               = require("api")
local GUI               = require("rasial.gui") -- file saved in Lua_Scripts/rasial

local RotationManager   = require("core.rotation_manager") -- file saved in Lua_Scripts/core
local PlayerManager     = require("core.player_manager") -- file saved in Lua_Scripts/core
local PrayerFlicker     = require("core.prayer_flicker") -- file saved in Lua_Scripts/core
local WarsRetreat       = require("core.wars_retreat") -- file saved in Lua_Scripts/core
local Player            = require("core.player") -- file saved in Lua_Scripts/core
local Utils             = require("core.helper") -- file saved in Lua_Scripts/core
local Timer             = require("core.timer") -- file saved in Lua_Scripts/core

------------------------------------------
-- # SCRIPT INITIALIZATION
------------------------------------------

Interact:SetSleep(0, 0, 0)
API.Write_fake_mouse_do(false)
API.ClearLog()

------------------------------------------
-- # GUI PRE-START CONFIGURATION
------------------------------------------

GUI.reset()
GUI.loadConfig()
GUI.loadStats() -- Load persistent statistics
ClearRender()

-- Show config GUI before starting
DrawImGui(function() if GUI.open then GUI.draw({}) end end)

API.printlua("Waiting for configuration...", 0, false)

-- Wait for user to click Start or Cancel
while API.Read_LoopyLoop() and not GUI.started do
    if not GUI.open then
        API.printlua("GUI closed before start", 0, false)
        ClearRender()
        return
    end
    if GUI.isCancelled() then
        API.printlua("Script cancelled by user", 0, false)
        ClearRender()
        return
    end
    API.RandomSleep2(100, 50, 0)
end

-- Get fully-resolved configuration from GUI
local config = GUI.getConfig()

-- Apply debug settings from GUI
local Debugging = {
    main = config.debug.main,
    timer = config.debug.timer,
    rotationManager = config.debug.rotation,
    playerManager = config.debug.player,
    prayerFlicker = config.debug.prayer,
    warsRetreat = config.debug.wars
}

API.printlua("Starting Rasial [Inv: " .. config.presetNames.inventory ..
                 " | Equip: " .. config.presetNames.equipment .. " | Rot: " ..
                 config.presetNames.rotation .. " | Buffs: " ..
                 config.presetNames.buffs .. "]", 0, false)
ClearRender()

local Common = {}
local RasialLobby = {}
local RasialFight = {}

Common.variables = {
    scriptVersion = "2.1.1",
    scriptStartTime = os.time(),
    --
    killCount = 0,
    gp = 0,
    deathCount = 0,
    --
    killData = {},
    uniquesLooted = {},
    --
    unknownLocationStartTime = nil, -- Tracking for emergency teleport
    isDead = false, -- Tracking for death recovery
    deathTime = nil -- Timestamp of death for logging
}

------------------------------------------
-- # LOOT
------------------------------------------

local LOOT = {
    COMMONS = {
        566, -- soul rune
        55319, -- noted super necromancy (3)
        31867, -- hydrix bolt tips
        9194, -- onyx bolt tips
        42954, -- onyx dust
        44814, -- light animica stone spirit
        44815, -- dark animica stone spirit
        57174, -- primal stone spirits
        54019, -- catalytic anima stone
        15271, -- noted Raw rocktail
        55630, -- noted Robust memento
        55632, -- noted Powerful memento
        5303, -- dwarf weed seed
        5304, -- torstol seed
        51104, -- noted Medium spiky orikalkum salvage
        53508, -- noted Large blunt necronium salvage
        990 -- noted Crystal key
    },

    -- Unique drops
    UNIQUES = {
        55480, -- omni guard
        55482, -- soulbound lantern
        55488, -- crown of the First Necromancer
        55490, -- robe top of the First Necromancer
        55492, -- robe bottom of the First Necromancer
        55494, -- hand wrap of the First Necromancer
        55496, -- foot wraps of the First Necromancer
        55674 -- miso's collar
    },

    -- Data regarding unique drops for discord embed notificaitons
    UNIQUES_DATA = {
        [55480] = {
            name = "Omni guard",
            prefix = "an ",
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
            thumbnail = "https://runescape.wiki/images/thumb/Robe_bottom_of_the_First_Necromancer_detail.png/76px-Robe_bottom_of_the_First_Necromancer_detail.png?5d7b4"
        },
        [55494] = {
            name = "Hand wrap of the First Necromancer",
            thumbnail = "https://runescape.wiki/images/thumb/Hand_wrap_of_the_First_Necromancer_detail.png/88px-Hand_wrap_of_the_First_Necromancer_detail.png?a0465"
        },
        [55496] = {
            name = "Foot wraps of the First Necromancer",
            prefix = "a pair of ",
            thumbnail = "https://runescape.wiki/images/thumb/Foot_wraps_of_the_First_Necromancer_detail.png/152px-Foot_wraps_of_the_First_Necromancer_detail.png?6b9d4"
        },
        [55674] = {
            name = "Miso's collar",
            thumbnail = "https://runescape.wiki/images/thumb/Miso%27s_collar_detail.png/102px-Miso%27s_collar_detail.png?4e63b"
        }
    }
}

------------------------------------------
-- # INITIALIZING INSTANCES
------------------------------------------

--  Initializing a Prayer Flicker object
local prayerFlicker = PrayerFlicker.new(config.prayerFlicker)

--  Initializing a Player Manager object
local playerManager = PlayerManager.new({
    health = config.playerManager.health,
    prayer = config.playerManager.prayer
})

--  Initializing a Timer object
local timer = Timer.new()
timer.debug = Debugging.timer

--  Initializing a Rotation Manager object
local rotationManager = RotationManager.new(30165,
                                            {debug = Debugging.rotationManager})

--  Initializing a War's Retreat Object
local warsRetreat = WarsRetreat:init({
    playerManager = playerManager,
    timer = timer,
    bossData = {
        name = "Rasial",
        portalId = 127138,
        portalName = "Portal (Rasial's Citadel)"
    },
    onWarning = function(msg)
        GUI.addWarning(msg)
        GUI.selectWarningsTab = true
    end,
    onWarningsClear = function()
        GUI.clearWarnings()
    end,
    userSettings = {
        bankPin = config.bankPin,
        waitForFullHp = config.waitForFullHp,
        summonConjures = config.warsRetreat.summonConjures,
        useAdrenCrystal = config.warsRetreat.useAdrenCrystal,
        bankIfInvFull = config.warsRetreat.bankIfInvFull,
        advancedMovement = config.warsRetreat.advancedMovement,
        surgeDiveChance = config.warsRetreat.surgeDiveChance,
        minimumValues = config.warsRetreat.minimumValues,
        taskOrder = config.warsRetreat.taskOrder,
        preset = {
            inventory = config.preset.inventory,
            equipment = config.preset.equipment
        }
    }
})

-- Validate preset items (pre-start check)
local warnings = warsRetreat:validatePreset()
if #warnings > 0 then GUI.selectWarningsTab = true end

------------------------------------------
-- # RASIAL LOBBY INITIALIZATION
------------------------------------------

RasialLobby = {
    constants = {
        location = {
            name = "Rasial's Citadel (Lobby)",
            ---@diagnostic disable-next-line: undefined-global
            coords = WPOINT.new(864, 1742, 0),
            range = 25
        },
        objects = {
            chamberDoorway = {name = "Chamber doorway", id = 127142, type = 12}
        }
    },
    variables = {
        instanceStartTime = 0,
        rejoinAttempts = 0,
        lastInstanceAttempt = 0, -- Tracks when instance creation was last attempted
        instanceAttemptCount = 0 -- Tracks consecutive instance attempts for timeout
    }
}

------------------------------------------
-- # RASIAL LOBBY TASKS
------------------------------------------

RasialLobby.tasks = {
    -- Task: Summon conjures if you can...
    {
        name = "Summoning conjures at Rasial Lobby",
        priority = 21,
        cooldown = 3,
        useTicks = true,
        condition = function()
            return RasialLobby:atLocation() and
                       Utils:canUseAbility("Conjure Undead Army") and
                       Utils:canUseAbility("Life Transfer") and
                       Player:getAnimation() ~= 35502 -- Conjure Undead Army animation
        end,
        action = function()
            return Utils:useAbility("Conjure Undead Army")
        end
    }, {
        name = "Life Transfer",
        priority = 10,
        cooldown = 5,
        useTicks = true,
        condition = function()
            return RasialLobby:atLocation() and
                       Utils:canUseAbility("Life Transfer")
        end,
        action = function() return Utils:useAbility("Life Transfer") end,
        delay = 2,
        delayTicks = true
    }, {
        name = "Handle instance",
        priority = 8,
        cooldown = 1,
        useTicks = true,
        condition = function() return RasialLobby:atLocation() end,
        action = function()
            -- Check for instance timeout
            local timeout = config.instanceTimeout or 30
            if RasialLobby.variables.lastInstanceAttempt > 0 then
                local elapsed = os.clock() -
                                    RasialLobby.variables.lastInstanceAttempt
                if elapsed > timeout then
                    Utils:log("Instance timeout reached after " ..
                                  math.floor(elapsed) .. " seconds", "error")
                    RasialLobby.variables.instanceAttemptCount =
                        RasialLobby.variables.instanceAttemptCount + 1

                    -- After 3 timeouts, teleport back to War's Retreat
                    if RasialLobby.variables.instanceAttemptCount >= 3 then
                        Utils:log(
                            "Max instance attempts reached, teleporting to War's Retreat",
                            "warn")
                        RasialLobby.variables.lastInstanceAttempt = 0
                        RasialLobby.variables.instanceAttemptCount = 0
                        return Utils:useAbility("War's Retreat Teleport")
                    end

                    -- Reset for retry
                    RasialLobby.variables.lastInstanceAttempt = 0
                end
            end

            if RasialLobby.variables.instanceStartTime == 0 or
                ((os.clock() - RasialLobby.variables.instanceStartTime) >
                    (58 * 60)) -- At least 58 minutes since last instance was created
            or RasialLobby.variables.rejoinAttempts > 3 then
                Utils:log("Starting new instance", "debug")
                return RasialLobby:startNewInstance()
            end
            return RasialLobby:rejoiningInstance()
        end,
        delay = 1,
        delayTicks = true
    }
}

------------------------------------------
-- # RASIAL LOBBY METHODS
------------------------------------------

---Checks if the player is outside of Rasial's Citadel
---@return boolean
function RasialLobby:atLocation()
    return Player:isAtCoordWithRadius(self.constants.location.coords,
                                      self.constants.location.range)
end

---Starts a new Rasial instance
---@return boolean
function RasialLobby:startNewInstance()
    -- Track instance attempt for timeout detection
    if self.variables.lastInstanceAttempt == 0 then
        self.variables.lastInstanceAttempt = os.clock()
    end

    if API.Check_Dialog_Open() then
        ---@diagnostic disable-next-line:missing-parameter
        return API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, 13, -1,
                                      API.OFF_ACT_GeneralInterface_Choose_option)
    elseif API.VB_FindPSettinOrder(2874).state == 18 then
        ---@diagnostic disable-next-line:missing-parameter
        if API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1,
                                  API.OFF_ACT_GeneralInterface_route) then
            self.variables.instanceStartTime = os.clock()
            self.variables.lastInstanceAttempt = 0 -- Reset timeout tracker on success
            self.variables.instanceAttemptCount = 0
            return true
        end
    else
        ---@diagnostic disable-next-line
        return Interact:Object("Chamber doorway", "Enter")
    end
    return false
end

---Rejoins the active Rasial encounter
function RasialLobby:rejoiningInstance()
    self.variables.rejoinAttempts = self.variables.rejoinAttempts + 1
    ---@diagnostic disable-next-line
    return Interact:Object("Chamber doorway", "Rejoin last instance")
end

-- Add tasks to timer object
for _, task in pairs(RasialLobby.tasks) do timer:addTask(task) end

------------------------------------------
-- # RASIAL FIGHT INITIALIZATION
------------------------------------------

RasialFight = {
    constants = {
        location = {
            name = "Rasial's Citadel (Boss Room)",
            detector = function() -- checks to see if instance timer exists
                return Utils:bossTimerExists()
            end
        },
        objects = {
            chamberDoorway = {name = "Chamber doorway", id = 127142, type = 12},
            rasial = {
                name = "Rasial, the First Necromancer",
                id = 30165,
                type = 1
            },
            lightning = {name = "", id = 6974, type = 4}
        }
    },
    variables = {
        phases = {[1] = false, [2] = false},
        jasProcCount = 0,
        currentlyCountingProc = false,
        bossDead = false,
        looted = false,
        gateTile = nil,
        finalZone = nil,
        lootTile = nil,
        safeSpot = nil
    }
}

------------------------------------------
-- # RASIAL FIGHT TASKS
------------------------------------------

RasialFight.tasks = {
    {
        name = "Registering important tiles",
        priority = 100,
        cooldown = 10,
        useTicks = true,
        condition = function()
            return
                RasialFight:atLocation() and RasialFight.variables.gateTile ==
                    nil and not RasialFight.variables.bossDead
        end,
        action = function() return RasialFight:gatherData() end
    }, {
        name = "Handle fight",
        priority = 99,
        cooldown = 0,
        parallel = true,
        condition = function() return RasialFight:atLocation() end,
        action = function() return RasialFight:handleFight() end
    }, {
        name = "Handle book swap",
        priority = 10,
        cooldown = 3,
        useTicks = true,
        parallel = true,
        condition = function()
            return Inventory:Contains("Erethdor's grimoire")
        end,
        action = function()
            return RasialFight:handlePocketSwitching(true)
        end
    }, {
        name = "Getting in position",
        priority = 20,
        cooldown = 2,
        useTicks = true,
        condition = function()
            return RasialFight:atLocation() and
                       not RasialFight.variables.gateTile ~= nil and
                       not RasialFight:isPlayerAtSafespot() and
                       not RasialFight.variables.phases[2]
        end,
        action = function()
            if not Player:isMoving() then
                return RasialFight:getInSafeSpot()
            end
            return true
        end,
        parallel = true
    }, {
        name = "Dodging lightning",
        priority = 10,
        cooldown = 1,
        useTicks = true,
        condition = function()
            return
                RasialFight:atLocation() and RasialFight.variables.gateTile ~=
                    nil and RasialFight:getBossInfo().health > 0 and
                    #RasialFight:getLightning(10) > 0 and
                    RasialFight.variables.phases[2]
        end,
        action = function() return RasialFight:dodgeLightning() end,
        parallel = true
    }, {
        name = "Getting in position for loot",
        priority = 11,
        cooldown = 3,
        useTicks = true,
        condition = function()
            return
                RasialFight:atLocation() and RasialFight.variables.gateTile ~=
                    nil and (RasialFight:getBossInfo().health <= 0) and
                    not RasialFight.variables.bossDead and
                    not RasialFight:isPlayerAtLootTile() and
                    RasialFight.variables.phases[2]
        end,
        action = function()
            if not Player:isMoving() then
                Utils:equipLuckRing()
                RasialFight:getInLootPosition()
                return true
            end
        end
    }, {
        name = "Waiting for loot",
        priority = 9,
        cooldown = 0,
        useTicks = true,
        condition = function()
            return RasialFight:atLocation() and
                       (RasialFight:getBossInfo().health <= 0 or
                           not (RasialFight:getBossInfo().found)) and
                       RasialFight.variables.gateTile ~= nil and
                       RasialFight.variables.phases[2] and
                       not RasialFight.variables.bossDead
        end,
        action = function() return RasialFight:logKillDetails() end
    }, {
        name = "Logging unique drop",
        priority = 20,
        cooldown = 30,
        useTicks = true,
        condition = function() return RasialFight:floorContainsRareLoot() end,
        action = function() return RasialFight:logUniqueDrop() end,
        parallel = true
    }, {
        name = "Looting",
        priority = 8,
        cooldown = 1,
        useTicks = true,
        condition = function()
            return
                RasialFight:atLocation() and RasialFight.variables.gateTile ~=
                    nil and RasialFight:getBossInfo().health <= 0 and
                    RasialFight:floorContainsLoot() and
                    RasialFight.variables.phases[2] and
                    RasialFight.variables.bossDead
        end,
        action = function() return RasialFight:pickUpLoot() end
    }, {
        name = "Teleporting back to War's Retreat",
        priority = 1,
        cooldown = 10,
        useTicks = true,
        condition = function()
            return
                RasialFight:atLocation() and RasialFight.variables.gateTile ~=
                    nil and RasialFight:getBossInfo().health <= 0 and
                    not RasialFight:floorContainsLoot() and
                    RasialFight.variables.bossDead
        end,
        action = function() return RasialFight:teleportToWarsRetreat() end,
        delay = 2,
        delayTicks = true
    }
}

------------------------------------------
-- # RASIAL FIGHT METHODS
------------------------------------------

-- Check if player is in the boss room by checking for instance timer
function RasialFight:atLocation() return self.constants.location.detector() end

-- Gather and store essential location data for the fight
function RasialFight:gatherData()
    Utils:log("Gathering instance data...", "warn")
    local gate = Utils:findAll(self.constants.objects.chamberDoorway.id,
                               self.constants.objects.chamberDoorway.type, 50)

    if #gate > 0 then
        Utils:log("++ Gate found", "debug")
        local gateTile = gate[1].Tile_XYZ

        -- Skip if wrong gate detected
        if gateTile.x == 864.5 and gateTile.y == 1745.5 then
            Utils:debugLog("-- Registered the wrong gate.", "error")
            return false
        end
        Utils:log(("++ Gate tile: (%s, %s, 0)"):format(gateTile.x, gateTile.y))

        -- Calculate safe spot relative to gate
        ---@type WPOINT
        ---@diagnostic disable-next-line:undefined-global
        self.variables.safeSpot = WPOINT.new(gateTile.x - 1, gateTile.y + 28, 0)
        if self.variables.safeSpot then
            Utils:log(("++ Safe spot tile: (%s, %s, 0)"):format(self.variables
                                                                    .safeSpot.x,
                                                                self.variables
                                                                    .safeSpot.y))
        else
            Utils:log("++ Failed to register safe spot tile", "error")
            return false
        end

        -- Set loot collection position
        ---@diagnostic disable-next-line:undefined-global
        self.variables.lootTile = WPOINT.new(gateTile.x - 1, gateTile.y + 26, 0)

        -- Define final phase fighting zone
        self.variables.finalZone = {
            {x = gateTile.x - 3, y = gateTile.y + 27},
            {x = gateTile.x + 2, y = gateTile.y + 28}
        }

        self.variables.gateTile = gateTile

        Utils:log(("++ Gate tile saved in memory: (%s, %s, 0)"):format(
                      self.variables.gateTile.x, self.variables.gateTile.y))
        return true
    end
    return false
end

-- Get current boss information (health, position, animation)
function RasialFight:getBossInfo()
    local rasial = Utils:findAll(self.constants.objects.rasial.id,
                                 self.constants.objects.rasial.type, 50)
    return {
        found = #rasial > 0,
        health = ((#rasial > 0) and rasial[1].Life) or -1,
        animation = ((#rasial > 0) and rasial[1].Anim) or -1,
        ---@diagnostic disable-next-line:undefined-global
        tile = ((#rasial > 0) and rasial[1].Tile_XYZ) or FFPOINT.new(0, 0, 0)
    }
end

-- Check if player is at the designated safe spot
function RasialFight:isPlayerAtSafespot()
    if not self.variables.gateTile or not self.variables.safeSpot then
        return false
    end
    return Player:isAtCoordWithRadius(self.variables.safeSpot, 1)
end

-- Move player to safe spot
function RasialFight:getInSafeSpot()
    if self.variables.safeSpot ~= nil then
        return API.DoAction_WalkerW(self.variables.safeSpot)
    end
    return false
end

-- Find lightning hazards within range
function RasialFight:getLightning(range)
    return Utils:findAll(self.constants.objects.lightning.id,
                         self.constants.objects.lightning.type, range)
end

-- Handle lightning dodge mechanics
function RasialFight:dodgeLightning()
    local lightning = self:getLightning(20)
    local onLightning = false

    if not lightning then return end

    -- Check if player is standing on lightning
    for _, obj in ipairs(lightning) do
        local centerX = math.floor(obj.Tile_XYZ.x)
        local centerY = math.floor(obj.Tile_XYZ.y)
        ---@diagnostic disable-next-line:undefined-global
        if Player:isAtCoord(WPOINT.new(centerX, centerY, 1)) then
            onLightning = true
        end
    end

    if onLightning then
        -- Generate list of possible safe tiles
        local tiles = {}
        local startX, endX = self.variables.finalZone[1].x,
                             self.variables.finalZone[2].x
        local startY, endY = self.variables.finalZone[1].y,
                             self.variables.finalZone[2].y

        for x = startX, endX do
            for y = startY, endY do
                table.insert(tiles, {x = math.floor(x), y = math.floor(y)})
            end
        end

        -- Mark unsafe tiles
        local unsafe = {}
        for _, obj in ipairs(lightning) do
            local centerX = math.floor(obj.Tile_XYZ.x)
            local centerY = math.floor(obj.Tile_XYZ.y)
            unsafe[centerX .. "_" .. centerY] = true
        end

        -- Find safe tiles
        local safeTiles = {}
        for _, tile in ipairs(tiles) do
            if not unsafe[tile.x .. "_" .. tile.y] then
                table.insert(safeTiles, tile)
            end
        end

        -- Find closest safe tile
        local bestDist, bestTile = math.huge, nil
        for _, tile in ipairs(safeTiles) do
            local dx = tile.x - Player:getCoords().x
            local dy = tile.y - Player:getCoords().y
            local dist = dx * dx + dy * dy
            if dist < bestDist then bestDist, bestTile = dist, tile end
        end

        if bestTile then
            ---@diagnostic disable-next-line
            return API.DoAction_WalkerW(WPOINT.new(bestTile.x, bestTile.y, 0))
        end
    end
    return false
end

function RasialFight:handlePocketSwitching(bool)
    if bool then
        local jasProc = Player:getBuff(15146).found

        if jasProc then
            if not self.variables.currentlyCountingProc then
                self.variables.jasProcCount = self.variables.jasProcCount + 1
                self.variables.currentlyCountingProc = true
            end
        else
            self.variables.currentlyCountingProc = false
        end

        if ((self.variables.jasProcCount >= 2 and jasProc and
            not (API.Container_Get_all(94)[18].item_id == 42787)) or
            self.variables.phases[2]) and
            Inventory:Contains("Erethdor's grimoire") then
            return Inventory:Equip("Erethdor's grimoire")
        end
    end
end

-- Main fight management function
function RasialFight:handleFight()
    if not self.variables.bossDead then
        -- Phase 1 initialization
        if self:atLocation() and not self.variables.phases[1] then
            Utils:log("----- FIGHT INITIATED -----")
            self.variables.phases[1] = true
            Utils:log("- Loading fight rotation.")
            rotationManager:load(config.preset.rotations.fightRotation)
        end

        -- Phase 2 initialization
        if (self:getBossInfo().health <= 199000) and self:getBossInfo().found and
            not self.variables.phases[2] then
            Utils:log("----- FINAL PHASE INITIATED -----")
            self.variables.phases[2] = true
            Utils:log("- Loading final rotation.")
            rotationManager:load(config.preset.rotations.finalRotation)
        end
    end

    -- Combat management
    if (self.variables.phases[1] and not self.variables.phases[2]) or
        (self.variables.phases[2] and self:getBossInfo().health > 0) then
        playerManager:requestBuffs(config.preset.buffs)
        prayerFlicker:update()

        -- Execute rotation with error handling
        local success, err = pcall(function() rotationManager:execute() end)

        if not success then
            Utils:log("Rotation execution error: " .. tostring(err), "error")
            -- Continue combat without rotation - player manager and prayer flicker still active
        end
    else
        prayerFlicker:deactivatePrayer()
    end

    playerManager:manageHealth()
    playerManager:managePrayer()

    return true
end

-- Check if player is at loot collection position
function RasialFight:isPlayerAtLootTile()
    if not self.variables.lootTile then return false end
    return Player:isAtCoordWithRadius(self.variables.lootTile, 1)
end

-- Move to loot collection position
function RasialFight:getInLootPosition()
    if not self.variables.lootTile then return false end
    if self.variables.lootTile ~= nil then
        return API.DoAction_WalkerW(self.variables.lootTile)
    end
    return false
end

-- Record kill time and update statistics
function RasialFight:logKillDetails()
    local killTime = "UNKNOWN"
    for _, chat in ipairs(API.GatherEvents_chat_check()) do
        if string.find(chat.text, "Completion Time") then
            killTime = chat.text:gsub("<col=2DBA14>Completion Time:</col> ", "")
        end
    end
    if killTime ~= "UNKNOWN" then
        Common.variables.killCount = Common.variables.killCount + 1
        Common.variables.killData[Common.variables.killCount] = {
            runtime = API.ScriptRuntimeString(),
            fightDuration = killTime,
            lootValue = 0 -- Will be updated when loot is picked up
        }
        self.variables.bossDead = true

        -- Record to persistent stats
        local killTimeMs = Utils:parseCompletionTime(killTime)
        GUI.recordKill(killTimeMs, 0) -- GP will be added separately when looting
    end
    return true
end

-- Log unique (rare) drops
function RasialFight:logUniqueDrop()
    local uniqueDrops = Utils:findAll(LOOT.UNIQUES, 3, 30)

    if uniqueDrops then
        RasialFight:logKillDetails()
        for _, drop in pairs(uniqueDrops) do
            local killData = Common.variables.killData[Common.variables
                                 .killCount]
            local dropData = LOOT.UNIQUES_DATA[drop.Id]
            table.insert(Common.variables.uniquesLooted, ({
                "-- [" .. Common.variables.killCount .. "] " .. dropData.name,
                killData.runtime
            }))

            -- Record to persistent stats
            GUI.recordUniqueDrop(dropData.name)

            -- Send Discord notification
            if config.useDiscord then
                --- @diagnostic disable-next-line
                local embed = DiscordEmbed.new():SetTitle(string.format(
                                                              "Congratulations! You found %s%s",
                                                              dropData.prefix or
                                                                  (dropData.name ~=
                                                                      "Miso's collar") and
                                                                  "a " or "",
                                                              dropData.name))
                                  :SetDescription(
                                      "You've managed to strip Rasial of a shiny **" ..
                                          dropData.name .. "**!")
                                  :SetColor(10181046):SetTimestamp(tostring(
                                                                       os.time())) --- @diagnostic disable-next-line
                    :SetThumbnail(EmbedImage.new(dropData.thumbnail,
                                                 dropData.thumbnail, 50, 50)) --- @diagnostic disable-next-line
                    :SetAuthor(EmbedAuthor.new(string.format(
                                                   "[%s] Sonson's Rasial",
                                                   Common.variables
                                                       .scriptVersion), "",
                                               "https://runescape.wiki/images/thumb/The_First_Necromancer_chathead.png/90px-The_First_Necromancer_chathead.png?dea03",
                                               "")) --- @diagnostic disable-next-line
                    :AddField(EmbedField.new("Kill Count",
                                             Common.variables.killCount, true)) --- @diagnostic disable-next-line
                    :AddField(EmbedField.new("Fight Duration",
                                             killData.fightDuration, true)) --- @diagnostic disable-next-line
                    :AddField(EmbedField.new("Runtime", killData.runtime, true)) --- @diagnostic disable-next-line
                    :SetFooter(EmbedFooter.new(
                                   "Thank you for using Sonson's Scripts",
                                   "https://runescape.wiki/images/thumb/The_First_Necromancer_chathead.png/90px-The_First_Necromancer_chathead.png?dea03",
                                   ""))

                Discord:SendEmbedEx(embed, true)
            end
        end
    end
    return true
end

-- Get all lootable items
function RasialFight:getLoot()
    return API.GetAllObjArray1(Utils:virtualTableConcat(LOOT.COMMONS,
                                                        LOOT.UNIQUES), 70, {3})
end

-- Check if there are items to loot
function RasialFight:floorContainsLoot() return #self:getLoot() > 0 end

-- Checks if there is a rare item to loot
function RasialFight:floorContainsRareLoot()
    return #Utils:findAll(LOOT.UNIQUES, 3, 30) > 0
end

-- Collect loot from ground
function RasialFight:pickUpLoot()
    -- If loot window isn't open, interacts with floor items
    if not API.LootWindowOpen_2() and self:floorContainsLoot() then
        return API.DoAction_G_Items1(0x45, Utils:virtualTableConcat(
                                         LOOT.COMMONS, LOOT.UNIQUES), 30)
    end

    -- If loot window is open, clicks on "Loot All"
    if API.LootWindowOpen_2() and self:floorContainsLoot() then
        if API.DoAction_LootAll_Button() then
            local gpLooted = Utils:getLootWindowAmount()
            Common.variables.gp = Common.variables.gp + gpLooted

            -- Update loot value for this kill
            if Common.variables.killData[Common.variables.killCount] then
                Common.variables.killData[Common.variables.killCount].lootValue =
                    gpLooted
            end

            -- Update all-time GP stats and save to file
            GUI.allTimeStats.totalGP = GUI.allTimeStats.totalGP + gpLooted
            GUI.allTimeStats.lastUpdated = os.time()
            -- Note: Stats are auto-saved in GUI.recordKill(), so we only update here

            self.variables.looted = true
            return true
        end
    end
end

-- Teleport player to War's Retreat
function RasialFight:teleportToWarsRetreat()
    return Utils:useAbility("War's Retreat Teleport")
end

-- Add tasks to timer object
for _, task in pairs(RasialFight.tasks) do timer:addTask(task) end

------------------------------------------
-- # COMMON TASKS
------------------------------------------

-- Timer task to reset everything if the player is at War's Retreat and the gate tile is set
timer:addTask({
    name = "Resetting variables",
    priority = 420,
    cooldown = 10,
    useTicks = true,
    condition = function()
        return (warsRetreat:atLocation() and RasialFight.variables.gateTile ~=
                   nil)
    end,
    action = function()
        Utils:log("- Resetting all variables", "warn")
        -- Rasial Fight variables
        RasialFight.variables.bossDead = false
        RasialFight.variables.jasProcCount = 0
        RasialFight.variables.gateTile = nil
        RasialFight.variables.finalZone = nil
        RasialFight.variables.lootTile = nil
        RasialFight.variables.safeSpot = nil
        RasialFight.variables.looted = false
        RasialFight.variables.phases[1] = false
        RasialFight.variables.phases[2] = false

        -- Rasial Lobby variables
        RasialLobby.variables.rejoinAttempts = 0
        RasialLobby.variables.lastInstanceAttempt = 0
        RasialLobby.variables.instanceAttemptCount = 0

        -- Instances
        rotationManager:unload()
        warsRetreat:reset()

        return true
    end,
    executionData = {lastRun = 0, count = 0}
})

-- Timer to activate Scripture of Jas after loading preset
timer:addTask({
    name = "Activating Scripture of Jas",
    priority = 69,
    cooldown = 10,
    useTicks = true,
    parallel = true,
    condition = function()
        return warsRetreat:atLocation() and
                   (API.Container_Get_all(94)[18].item_id == 51814) and
                   not Player:getBuff(51814).found
    end,
    action = function() return Utils:useAbility("Scripture of Jas") end,
    executionData = {lastRun = 0, count = 0}
})

-- Emergency task: Teleport to War's Retreat if stuck in unknown location for over 20 seconds
timer:addTask({
    name = "Emergency teleport to War's Retreat",
    priority = 500, -- Higher priority than reset task
    cooldown = 5,
    useTicks = true,
    parallel = true,
    condition = function()
        -- Check if player is in an unknown location
        local inKnownLocation = RasialLobby:atLocation() or
                                    RasialFight:atLocation() or
                                    warsRetreat:atLocation()

        if not inKnownLocation then
            -- Start tracking if not already tracking
            if not Common.variables.unknownLocationStartTime then
                Common.variables.unknownLocationStartTime = os.clock()
                Utils:log(
                    "Player in unknown location - starting emergency timer",
                    "warn")
            end

            -- Check if been in unknown location for over 20 seconds
            local timeInUnknownLocation = os.clock() -
                                              Common.variables
                                                  .unknownLocationStartTime
            return timeInUnknownLocation > 5
        else
            -- Reset timer if back in known location
            if Common.variables.unknownLocationStartTime then
                Common.variables.unknownLocationStartTime = nil
            end
            return false
        end
    end,
    action = function()
        Utils:log(
            "EMERGENCY: Player stuck in unknown location for 20+ seconds - teleporting to War's Retreat",
            "error")

        -- Reset the timer
        Common.variables.unknownLocationStartTime = nil

        -- Teleport to War's Retreat
        local success = Utils:useAbility("War's Retreat Teleport")

        if success then
            Utils:log("- Emergency teleport initiated", "warn")
            API.RandomSleep2(3000, 500, 1000)

            -- Reset War's Retreat object
            warsRetreat:reset()
            Utils:log("- War's Retreat object reset", "warn")

            -- Reset fight variables
            RasialFight.variables.bossDead = false
            RasialFight.variables.jasProcCount = 0
            RasialFight.variables.gateTile = nil
            RasialFight.variables.finalZone = nil
            RasialFight.variables.lootTile = nil
            RasialFight.variables.safeSpot = nil
            RasialFight.variables.looted = false
            RasialFight.variables.phases[1] = false
            RasialFight.variables.phases[2] = false

            -- Reset lobby variables
            RasialLobby.variables.rejoinAttempts = 0
            RasialLobby.variables.lastInstanceAttempt = 0
            RasialLobby.variables.instanceAttemptCount = 0

            -- Unload rotation
            rotationManager:unload()

            Utils:log("- All variables reset after emergency teleport", "warn")
        else
            Utils:log("- Failed to teleport to War's Retreat", "error")
        end

        return success
    end,
    executionData = {lastRun = 0, count = 0}
})

-- Death recovery task: Detect death and automatically recover
timer:addTask({
    name = "Death recovery handler",
    priority = 600, -- Highest priority - run before everything else
    cooldown = 5,
    useTicks = true,
    parallel = true,
    condition = function()
        -- Detect death
        local playerHP = Player:getHP()
        local inDeathOffice = API.IsInDeathOffice()

        -- Player just died
        if (playerHP == 0 or inDeathOffice) and not Common.variables.isDead then
            Common.variables.isDead = true
            Common.variables.deathTime = os.time()
            Common.variables.deathCount = Common.variables.deathCount + 1
            Utils:log(string.format("DEATH DETECTED! Death count: %d",
                                    Common.variables.deathCount), "error")

            -- Send Discord notification if enabled
            if config.useDiscord then
                local embed = DiscordEmbed.new():SetTitle("Death Notification")
                                  :SetDescription(
                                      "Your character has died during the Rasial fight.")
                                  :SetColor(15158332) -- Red color
                    :SetTimestamp(tostring(os.time())):SetAuthor(
                                      EmbedAuthor.new(string.format(
                                                          "[%s] Sonson's Rasial",
                                                          Common.variables
                                                              .scriptVersion),
                                                      "",
                                                      "https://runescape.wiki/images/thumb/The_First_Necromancer_chathead.png/90px-The_First_Necromancer_chathead.png?dea03",
                                                      ""))
                                  :AddField(EmbedField.new("Death Count",
                                                           Common.variables
                                                               .deathCount, true))
                                  :AddField(EmbedField.new("Kill Count",
                                                           Common.variables
                                                               .killCount, true))
                                  :AddField(EmbedField.new("Runtime",
                                                           API.ScriptRuntimeString(),
                                                           true)):SetFooter(
                                      EmbedFooter.new("Recovery in progress...",
                                                      "https://runescape.wiki/images/thumb/The_First_Necromancer_chathead.png/90px-The_First_Necromancer_chathead.png?dea03",
                                                      ""))

                Discord:SendEmbedEx(embed, true)
            end

            return false -- Don't run recovery yet, wait for respawn
        end

        -- Player has respawned and we're ready to recover
        if Common.variables.isDead and playerHP > 0 and not inDeathOffice then
            return true
        end

        return false
    end,
    action = function()
        Utils:log("Death recovery: Initiating recovery sequence", "warn")

        -- Wait a moment to ensure respawn is complete
        API.RandomSleep2(2000, 300, 500)

        -- Check if already at War's Retreat
        if warsRetreat:atLocation() then
            Utils:log("- Already at War's Retreat, skipping teleport", "info")
        else
            -- Teleport to War's Retreat
            Utils:log("- Teleporting to War's Retreat", "warn")
            local success = Utils:useAbility("War's Retreat Teleport")

            if success then
                Utils:log("- Teleport initiated successfully", "info")
                API.RandomSleep2(3000, 500, 1000)
            else
                Utils:log("- Failed to teleport to War's Retreat", "error")
                -- Try again next cycle
                return false
            end
        end

        -- Reset all script state
        Utils:log("- Resetting script state after death", "warn")

        -- Reset War's Retreat object
        warsRetreat:reset()

        -- Reset fight variables
        RasialFight.variables.bossDead = false
        RasialFight.variables.jasProcCount = 0
        RasialFight.variables.gateTile = nil
        RasialFight.variables.finalZone = nil
        RasialFight.variables.lootTile = nil
        RasialFight.variables.safeSpot = nil
        RasialFight.variables.looted = false
        RasialFight.variables.phases[1] = false
        RasialFight.variables.phases[2] = false

        -- Reset lobby variables
        RasialLobby.variables.rejoinAttempts = 0
        RasialLobby.variables.lastInstanceAttempt = 0
        RasialLobby.variables.instanceAttemptCount = 0

        -- Unload rotation
        rotationManager:unload()

        -- Clear death state
        Common.variables.isDead = false
        Common.variables.deathTime = nil

        Utils:log(
            "- Death recovery complete - script will resume from War's Retreat",
            "info")

        return true
    end,
    executionData = {lastRun = 0, count = 0}
})

------------------------------------------
-- # DEBUGGING AND TRACKING
------------------------------------------

local function buildGUIData()
    -- Location calculation
    local location = "Unknown"
    local state = "Idle"

    if RasialLobby:atLocation() then
        location = RasialLobby.constants.location.name
        state = "Rasial Lobby"
    elseif RasialFight:atLocation() then
        location = RasialFight.constants.location.name
        if RasialFight.variables.bossDead then
            state = "Looting"
        elseif RasialFight.variables.phases[2] then
            state = "Phase 2"
        elseif RasialFight.variables.phases[1] then
            state = "Phase 1"
        else
            state = "Entering Fight"
        end
    elseif warsRetreat:atLocation() then
        location = warsRetreat.constants.LOCATION.name
        state = "War's Retreat"
    end

    -- KC/hr calculations
    local killcount = Common.variables.killCount
    local killcountPerHour = Utils:valuePerHour(killcount, Common.variables
                                                    .scriptStartTime)

    -- GP/hr calculations
    local perHour = Utils:valuePerHour(Common.variables.gp,
                                       Common.variables.scriptStartTime)
    local perHourNumber = tonumber(perHour) or 0

    -- Kill data calculations
    local fastestKill, slowestKill, averageKill = Utils:getKillStats(
                                                      Common.variables.killData)

    -- Boss info
    local bossInfo = RasialFight:getBossInfo()

    -- Build active buffs list
    local activeBuffs = {}
    for _, buff in ipairs(config.preset.buffs) do
        if Player:getBuff(buff.id).found then
            table.insert(activeBuffs, buff.name)
        end
    end

    -- Build debugging data (only if debug flags are enabled)
    local debugData = {
        state = state,
        location = location,
        status = timer:getStatus(),
        bossHealth = bossInfo.health > 0 and bossInfo.health or nil,
        bossMaxHealth = 800000,
        killCount = killcount,
        killsPerHour = killcountPerHour,
        gp = Common.variables.gp,
        gpPerHour = perHourNumber,
        deathCount = Common.variables.deathCount,
        fastestKill = fastestKill,
        slowestKill = slowestKill,
        averageKill = averageKill,
        uniquesLooted = Common.variables.uniquesLooted,
        activeBuffs = activeBuffs,
        phases = RasialFight.variables.phases,
        killData = Common.variables.killData,
        warsLastAction = warsRetreat.lastAction
    }

    -- Add main debug data if enabled
    if Debugging.main then
        debugData.mainDebug = {
            scriptVersion = Common.variables.scriptVersion,
            rasialFightVariables = RasialFight.variables,
            rasialLobbyVariables = RasialLobby.variables,
            bossInfo = bossInfo
        }
    end

    -- Add timer debug data if enabled
    if Debugging.timer then
        -- Get recent actions from timer (last 15)
        local recentActions = timer:getRecentActions(15)

        -- Get active tasks (tasks with conditions met)
        local activeTasks = {}
        for _, task in pairs(timer.tasks) do
            if task.condition() then
                table.insert(activeTasks, {
                    name = task.name,
                    priority = task.priority,
                    count = task.executionData.count,
                    parallel = task.parallel
                })
            end
        end

        -- Sort by priority (highest first)
        table.sort(activeTasks, function(a, b)
            if a.priority == b.priority then return a.name < b.name end
            return a.priority > b.priority
        end)

        debugData.timerDebug = {
            recentActions = recentActions,
            activeTasks = activeTasks
        }
    end

    -- Add rotation manager debug data if enabled
    if Debugging.rotationManager then
        -- Get recent steps from rotation manager (last 7)
        local recentSteps = rotationManager:getRecentSteps(7)

        debugData.rotationDebug = {
            currentIndex = rotationManager.index,
            totalSteps = #rotationManager.rotation,
            isLoaded = #rotationManager.rotation > 0,
            recentSteps = recentSteps
        }
    end

    -- Add War's Retreat debug data if enabled
    if Debugging.warsRetreat then
        debugData.warsDebug = warsRetreat:getDebugInfo()
    end

    return debugData
end

local function tracking()
    local debugging = Debugging.main

    -- Location calculation:
    local location = "UNKNOWN"
    if RasialLobby:atLocation() then
        location = RasialLobby.constants.location.name
    elseif RasialFight:atLocation() then
        location = RasialFight.constants.location.name
    elseif warsRetreat:atLocation() then
        location = warsRetreat.constants.LOCATION.name
    end

    -- KC/hr calculations
    local killcount = Common.variables.killCount
    local killcountPerHour = Utils:valuePerHour(killcount, Common.variables
                                                    .scriptStartTime)

    -- Rares/hr calculations
    local uniquesLooted = #Common.variables.uniquesLooted
    local uniquesLootedPerHour = Utils:valuePerHour(uniquesLooted,
                                                    Common.variables
                                                        .scriptStartTime)

    -- GP/hr calculations
    local currentGp = Utils:formatNumber(Common.variables.gp)
    local perHour = Utils:valuePerHour(Common.variables.gp,
                                       Common.variables.scriptStartTime)
    local perHourNumber = tonumber(perHour) or 0
    local gpPerHour = Utils:formatNumber(perHourNumber)

    -- Kill data calculations
    local fastestKill, slowestKill, averageKill = Utils:getKillStats(
                                                      Common.variables.killData)
    local formattedKillData = {}
    for i, killData in pairs(Common.variables.killData) do
        Utils:tableConcat(formattedKillData, {
            {
                string.format("- [%s] %s", i, killData.runtime),
                killData.fightDuration
            }
        })
    end

    -- Separator for tables
    local separator = {"", ""}

    -- Standard metric stable
    local metrics = {
        {
            string.format("[%s] Sonson's Rasial", Common.variables.scriptVersion),
            API.ScriptRuntimeString()
        }, separator, {"Metrics:", ""}, {"- Status", timer:getStatus()},
        {"- Location", location},
        {
            "- Total Kills (/hr)",
            string.format("%s (%s)", killcount, killcountPerHour)
        }, {
            "- Total Rares (/hr)",
            string.format("%s (%s)", uniquesLooted, uniquesLootedPerHour)
        }, {"- Total GP (/hr)", string.format("%s (%s)", currentGp, gpPerHour)},
        separator, {"Kill Times:", ""}, {"- Fastest Kill:", fastestKill},
        {"- Slowest Kill:", slowestKill}, {"- Average Kill Time:", averageKill}
    }

    -- Add unique drops to the metrics table
    if #Common.variables.uniquesLooted > 0 then
        Utils:multiTableConcat(metrics, {
            separator, {"Unique Drops:", ""}, {"- Name", "Runtime"}
        }, Common.variables.uniquesLooted)
    end

    -- Kill details tracking
    if debugging and #Common.variables.killData > 0 then
        Utils:multiTableConcat(metrics, {separator, {"Kill Details:", ""}},
                               formattedKillData)
    end

    -- Tables for tracking several variables across instances
    local rasialFightVariables = Utils:generateTable("Rasial Fight Variables:",
                                                     RasialFight.variables)
    local rasialLobbyVariables = Utils:generateTable("Rasial Lobby Variables:",
                                                     RasialLobby.variables)
    local warsRetreatVariables = Utils:generateTable("War's Retreat Variables:",
                                                     warsRetreat.variables)
    local commonVariables = Utils:generateTable("Common Variables:",
                                                Common.variables)

    -- General information regarding Rasial
    local rasialInfo = {
        {"Rasial Information:", ""},
        {"- Found", tostring(RasialFight:getBossInfo().found)},
        {"- Health", tostring(RasialFight:getBossInfo().health)}, {
            "- Tile", tostring(RasialFight:getBossInfo().tile.x .. ", " ..
                                   RasialFight:getBossInfo().tile.y)
        }, {"- Animation", tostring(RasialFight:getBossInfo().animation)}
    }

    -- You can add from the tables above what you want to track and monitor
    local trackedDebuggingTables = {
        timer:getMetrics()
        -- playerManager:stateTracking(),
        -- playerManager:buffConfigTracking(),
        -- playerManager:toggleBuffsTracking(),
        -- playerManager:activeBuffsTracking(),
        -- playerManager:buffFailuresTracking(),
    }

    if debugging and #trackedDebuggingTables > 0 then
        for _, table in pairs(trackedDebuggingTables) do
            Utils:multiTableConcat(metrics, {separator}, table)
        end
    end

    -- Use ImGui GUI instead of DrawTable
    GUI.draw(buildGUIData())
end

------------------------------------------
-- MAIN LOOP
------------------------------------------

-- Set up ImGui rendering for main loop
DrawImGui(function() if GUI.open then GUI.draw(buildGUIData()) end end)

-- Switch to Info tab now that we're running
GUI.selectInfoTab = true

while API.Read_LoopyLoop() do
    -- Check for stop request
    if GUI.isStopped() then
        API.printlua("Script stopped by user", 0, false)
        break
    end

    -- Check for pause - skip main logic but keep GUI responsive
    if not GUI.isPaused() then
        -- NOTE: Timer actions should run before Player Manager
        timer:run()
        playerManager:update()
        API.SetDrawLogs(Debugging.main and not GUI.isPaused())
    end

    API.RandomSleep2(30, 10, 10)
end

------------------------------------------
-- FIN
------------------------------------------
