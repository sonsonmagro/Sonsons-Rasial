--- @module "Sonson's War's Retreat"
--- @version 1.0.0

------------------------------------------
--# IMPORTS
------------------------------------------

local API           = require("api")
local Player        = require("core.player")
local Utils         = require("core.helper")

------------------------------------------
--# TYPE DEFINITIONS
------------------------------------------

--- @class WarsRetreatConfig
--- @field playerManager?       PlayerManager                   Player manager instance
--- @field rotationManager?     RotationManager                 Rotation manager instance
--- @field timer?               Timer                           Timer instance for task scheduling
--- @field bossData?            BossData                        Information about the targeted boss
--- @field userSettings?        UserSettings                    User configuration settings
--- @field prebuildSettings?    PrebuildSettings

--- @class UserSettings
--- @field bankPin?             integer                         Bank PIN for accessing the player's bank
--- @field preset?              PresetData                      Preset inventory and equipment data
--- @field surgeDiveChance?     number                          Chance (0-100) to use surge/bladed dive when navigating
--- @field bankIfInvFull?       boolean                         Whether to load last preset if inventory is full
--- @field summonConjures       boolean                         Whether to summon necromancy conjures
--- @field waitForFullHp?       boolean                         Whether to wait for full Hitpoints before continuing
--- @field useAdrenCrystal?     boolean                         Whether to use the adrenaline crystals to regain adrenaline
--- @field prebuildSettings?    PrebuildSettings                Settings for prebuilding
--- @field minimumValues?       MinimumValues                   The minimum values to check for in order to execute specific steps

--- @class MinimumValues
--- @field health?              integer                         The minimum health percent to have before continuing with the next steps
--- @field prayer?              integer                         The minimum prayer percent to have before continuing with the next steps
--- @field summoning?           integer                         The minimum summoning points percent to have before continuing wiht the next steps

--- @class PresetData
--- @field inventory?           table                           Items to equip from inventory
--- @field equipment?           table                           Equipment setup
--- @field spellbook?           string                          Active spellbook
--- @field aura?                string                          Active aura
--- @field buffs?               string                          Active buffs

--- @class BossData
--- @field name                 string                          Boss name
--- @field portalId             number                          Portal object ID for the boss
--- @field portalName           string                          Portal object name for the boss

--- @class PrebuildSettings
--- @field rotation             Step[]                          The prebuild rotaion to follow
--- @field useDummy             boolean                         Whether to use a dummy for prebuilding or not

--- @class WarsRetreat
--- @field playerManager?       PlayerManager                   Player manager instance
--- @field rotationManager?     RotationManager                 Rotation manager instance
--- @field timer?               Timer                           Timer instance
--- @field bossData?            BossData                        Data regarding the boss and boss portal IDs
--- @field preset?              PresetData                      Preset inventory and equipment data
--- @field userSettings?        UserSettings                    User configuration settings
--- @field constants            table<string, table>            Constant values used by the script
--- @field variables            table<string, any>              Variables that change during script execution
--- @field tasks                table[]                         List of scheduled tasks
--- Core methods
--- @field init                 fun(self, config?):WarsRetreat  Creates a new instance of War's Retreat
--- @field atLocation           fun(self):boolean               Whether or not the player is at War's Retreat
--- @field loadLastPreset       fun(self):boolean               Load's the last preset loaded by the player
--- @field standAtBankChest     fun(self):boolean               Stands one tile in front of the Bank chest
--- @field prayAtAltarOfWar     fun(self):boolean               Prays at the Altar of War
--- @field channelAdrenaline    fun(self):boolean               Channels adrenaline at an Adrenaline crystal
--- @field goThroughBossPortal  fun(self):boolean               Goes through the boss poral
--- @field reset                fun(self)                       Resets all War's Retreat related variables
--- Private methods
--- @field _initializeConfig    fun(self, config)               Initializes all config related data
--- @field _initializeData      fun(self)                       Initializes all War's Retreat related data
--- @field _initializeBossData  fun(self)                       Initializes all boss and boss portal related data
--- @field _createTimerTasks    fun(self)                       Creates and assigns tasks to the timer instance

------------------------------------------
--# ABILITIES WHITELIST
------------------------------------------

local WHITELIST     = {
    DEATH_SKULLS = "Death Skulls",
    LIVING_DEATH = "Living Death",
    SPLIT_SOUL = "Split Soul",
    BERSERK = "Berserk",
    OVERPOWER = "Overpower",
}

------------------------------------------
--# INITIALIZATION
------------------------------------------

local WarsRetreat   = {}
WarsRetreat.__index = WarsRetreat

-- Singleton instance
local instance      = nil

--- Initializes a new War's Retreat instance
--- @param config? WarsRetreatConfig Configuration options
--- @return WarsRetreat: Initialized WarsRetreat instance
function WarsRetreat:init(config)
    if instance then
        return instance
    end

    -- Create new instance if none exists
    --- @type WarsRetreat
    self = setmetatable({}, WarsRetreat)
    Utils:log("Initializing War's Retreat instance", "info")

    -- Set core components from config
    config = config or {}
    self.playerManager = config.playerManager or nil
    self.rotationManager = config.rotationManager or nil
    self.timer = config.timer or nil
    self.bossData = config.bossData or nil

    -- Setup user settings if provided
    if config.userSettings then
        self:_initializeConfig(config)
    end

    -- Initialize constant data and variables
    self:_initializeData()

    -- Setup boss portal data if boss provided
    if self.bossData then
        self:_initializeBossData()
    end

    -- Create and register tasks if required components exist
    if self.playerManager and self.timer then
        self:_createTimerTasks()
    end

    instance = self
    return instance
end

--- Configures user settings
--- @param config WarsRetreatConfig Configuration with user settings
--- @private
function WarsRetreat:_initializeConfig(config)
    Utils:log("Starting user settings initialization.", "info")

    -- Initialize all user settings with defaults if not provided
    self.userSettings = {
        -- Bank PIN for accessing presets
        bankPin = config.userSettings and config.userSettings.bankPin or 1234,

        -- Settings for ability prebuilding
        prebuildSettings = config.prebuildSettings or nil,

        -- Whether to bank when inventory is full
        bankIfInvFull = config.userSettings and config.userSettings.bankIfInvFull or false,

        -- Preset configuration for inventory, equipment and buffs
        preset = {
            inventory = config.userSettings.preset and config.userSettings.preset.inventory or {},
            equipment = config.userSettings.preset and config.userSettings.preset.equipment or {},
            buffs = config.userSettings.preset and config.userSettings.preset.buffs or {},
            aura = config.userSettings.preset and config.userSettings.preset.aura or {},
            spellbook = config.userSettings.preset and config.userSettings.preset.spellbook or {},
        },

        -- Chance to use Surge/Bladed Dive for movement
        surgeDiveChance = config.userSettings and config.userSettings.surgeDiveChance,

        -- Chance to use Surge/Bladed Dive for movement
        useAdrenCrystal = config.userSettings and config.userSettings.useAdrenCrystal,

        -- Whether to use necromancy conjures
        summonConjures = (config.userSettings and config.userSettings.summonConjures) or false,

        -- Whether to wait for full HP before continuing
        waitForFullHp = config.userSettings and config.userSettings.waitForFullHp or false,

        -- Minimum thresholds for prayer, summoning and health
        minimumValues = {
            prayer = config.userSettings and config.userSettings.minimumValues and
                config.userSettings.minimumValues.prayer or 80,
            summoning = config.userSettings and config.userSettings.minimumValues and
                config.userSettings.minimumValues.prayer or 80,
            health = config.userSettings and config.userSettings.minimumValues and
                config.userSettings.minimumValues.prayer or 80,
        }
    }
end

--- Initializes constant values and variables
--- @private
function WarsRetreat:_initializeData()
    Utils:log("Starting data initialization", "info")
    -- Constants
    self.constants = {
        -- Location data
        LOCATION = {
            name = "War's Retreat",
            ---@diagnostic disable-next-line: undefined-global
            coords = WPOINT.new(3295, 10137, 0),
            range = 30,
        },
        -- Object data
        OBJECTS = {
            BANK_CHEST = {
                name = "Bank chest",
                id = 114750,
                type = 0,
            },
            ALTAR_OF_WAR = {
                name = "Altar of War",
                id = 114748,
                type = 0,
            },
            BOSS_PORTAL = {
                name = self.bossData and self.bossData.portalName or "NONE",
                id = self.bossData and self.bossData.portalId or nil,
                type = 0
            },
            ADRENALINE_CRYSTAL = {
                name = "Adrenaline crystal",
                id = 114749,
                type = 12
            },
            CAMPFIRE = {
                name = "Campfire",
                id = { 114756, 114758, 114755, 114752, 114754, 114757, 114753, 131888 },
                type = 0
            },
            TRAINING_DUMMY = {
                name = "Training Dummy",
                id = 16027,
                type = 1
            }
        },
        -- Relevant IDs
        IDS = {
            ADRENALINE_PREVENTION = 26094,
            CONJURE_SUMMONING_ANIMATION = 35502,
            PRAY_AT_ALTAR_ANIMATION = 22755,
        }
    }

    -- Variables
    self.variables = {
        bankAttempts = 0,
        conjureAttempts = 0,
        portalSide = nil,
        ---@diagnostic disable-next-line:undefined-global
        crystalDiveCoords = WPOINT.new(0, 0, 0),
        ---@diagnostic disable-next-line:undefined-global
        portalDiveCoords = WPOINT.new(0, 0, 0),
        -- Cached random roll for surge/dive chance (1-100), regenerated on bank interaction
        surgeDiveRoll = nil
    }
    Utils:log("Data initialization completed", "info")
end

--- Initialize boss and portal data
--- @private
function WarsRetreat:_initializeBossData()
    if self.constants.OBJECTS.BOSS_PORTAL.id == nil then return end
    if not self:atLocation() then return end

    -- Validate boss portal exists
    local bossPortals = Utils:findAll(
        self.constants.OBJECTS.BOSS_PORTAL.id,
        self.constants.OBJECTS.BOSS_PORTAL.type,
        60
    )

    --[[     if #bossPortals == 0 then
        Utils:terminate(self.constants.OBJECTS.BOSS_PORTAL.name .. " not found.")
        return
    end
 ]]
    -- Determine portal side based on crystal position
    local portal = Utils:find(
        self.constants.OBJECTS.BOSS_PORTAL.id,
        self.constants.OBJECTS.BOSS_PORTAL.type,
        60
    )

    -- Save portal side to War's Retreat table
    if portal then
        self.variables.portalSide = math.floor(portal.Tile_XYZ.x) == 3298
            and "East" or "West"

        -- Save adrenaline crystal dive coordinates
        self.variables.crystalDiveCoords = self.variables.portalSide == "West"
            ---@diagnostic disable-next-line: undefined-global
            and WPOINT.new(3290, 10148, 0) or WPOINT.new(3298, 10148, 0)

        -- Save boss portal dive coordinates
        self.variables.portalDiveCoords = self.variables.portalSide == "West"
            ---@diagnostic disable-next-line: undefined-global
            and WPOINT.new(3290, 10153, 0) or WPOINT.new(3298, 10153, 0)

        Utils:log(string.format("Portal side initialized: %s", self.variables.portalSide))
    end
end

------------------------------------------
--# CORE FUNCTIONALITY
------------------------------------------

--- Checks if player is at War's Retreat
--- @return boolean: True if player is at War's Retreat
function WarsRetreat:atLocation()
    if not self.constants then return false end
    return Player:isAtCoordWithRadius(self.constants.LOCATION.coords, self.constants.LOCATION.range)
end

--- Attempts to load last preset from bank
--- @return boolean: True if preset loading was attempted
function WarsRetreat:loadLastPreset()
    if self.variables.bankAttempts > 3 then
        Utils:terminate("Failed to load preset after 3 attempts")
        return false
    end

    -- Handle bank pin if the interface is open
    API.DoBankPin(self.userSettings.bankPin)

    if Interact:Object(self.constants.OBJECTS.BANK_CHEST.name, "Load Last Preset from", 30) then
        self.variables.bankAttempts = self.variables.bankAttempts + 1
        -- Generate a new random roll (1-100) for surge/dive chance decision
        self.variables.surgeDiveRoll = math.random(1, 100)
        Utils:log(string.format("Generated surge/dive roll: %d", self.variables.surgeDiveRoll), "info")
        return true
    end
    return false
end

--- Moves player to bank chest position
--- @return boolean: True if movement was initiated
function WarsRetreat:standAtBankChest()
    ---@diagnostic disable-next-line: undefined-global
    return API.DoAction_WalkerW(WPOINT.new(3299, 10131, 0))
end

--- Performs prayer action at altar
--- @return boolean: True if prayer interaction was successful
function WarsRetreat:prayAtAltarOfWar()
    ---@diagnostic disable-next-line: return-type-mismatch
    return Interact:Object(self.constants.OBJECTS.ALTAR_OF_WAR.name, "Pray", 30)
end

--- Interacts with the adrenaline crystal closest to boss portal
--- @return boolean: True if crystal interaction was successful
function WarsRetreat:channelAdrenaline()
    ---@diagnostic disable-next-line: return-type-mismatch
    return Interact:Object(self.constants.OBJECTS.ADRENALINE_CRYSTAL.name, "Channel", 30)
end

--- Goes through the boss portal
--- @return boolean: True if portal interaction was successful
function WarsRetreat:goThroughBossPortal()
    assert(self.constants.OBJECTS.BOSS_PORTAL.id, "No boss portal specified")

    ---@diagnostic disable-next-line: return-type-mismatch
    return Interact:Object(self.constants.OBJECTS.BOSS_PORTAL.name, "Enter", 30)
end

--- Resets all War's Retreat variables
function WarsRetreat:reset()
    local variables = self.variables
    variables.bankAttempts = 0
    variables.conjureAttempts = 0
end

------------------------------------------
--# TASK MANAGEMENT
------------------------------------------

--- Creates and registers timer tasks
--- @private
function WarsRetreat:_createTimerTasks()
    self.tasks = {
        -- Navigate around War's Retreat depending on the player's needs and instance settings
        {
            name = "Navigate",
            cooldown = 1,
            useTicks = true,
            parallel = true,
            condition = function()
                return self:atLocation() and not Player:isMoving()
            end,
            action = function()
                local step = self:_getCurrentStep()
                -- TODO: Implement random movement around War's Retreat

                -- Stands by bank if not close enough to load preset.
                if step == "BANK" then
                    if not self:_isPlayerByBankChest(10) and not Player:isMoving() and not Player:isAnimating() then
                        self:standAtBankChest()
                    end
                    return true
                end

                -- Stands by bank if health is below 95%
                if (step == "HEALING") and not self:_isPlayerByBankChest(1) then
                    return self:standAtBankChest()
                end


                if (step == "USE ALTAR") and (self:_isPlayerByExitPortal(3) and Player:getFacingDirection() == "East") then
                    return Utils:useAbility("Surge")
                end


                if step == "USE ALTAR" then
                    -- Not sure if we need to do anything here.
                    return true
                end

                -- Positions by bank chest for Surge + Dive angle
                if (self:_isPlayerByAltar(3) or Player:getAnimation() == self.constants.IDS.PRAY_AT_ALTAR_ANIMATION) then
                    if not self:_isPlayerByBankChest(1) and not Player:isMoving() then
                        return self:standAtBankChest()
                    end
                    return true
                end

                -- Does Surge + Dive to the adrenaline crystal or boss portal (based on surgeDiveChance)
                if self:_isPlayerByBankChest(1) and Player:getFacingDirection() == "Northwest" then
                    local targetCoords = ((step == "USE CRYSTAL") and self.variables.crystalDiveCoords) or
                    self.variables.portalDiveCoords
                    local surgeDiveChance = self.userSettings.surgeDiveChance or 0
                    local roll = self.variables.surgeDiveRoll or 100

                    if roll < surgeDiveChance then
                        -- Use surge/dive to get to target
                        return self:_doDiveAndSurge(targetCoords)
                    else
                        -- Walk to target instead
                        return API.DoAction_WalkerW(targetCoords)
                    end
                end

                -- Walking to Adrenaline crystals
                if step == "USE CRYSTAL" or step == "SUMMON CONJURES" or step == "PREBUILD" then
                    if (self:_isPlayerByStairs(3) and Player:getFacingDirection() == "South")
                        or (self:_isPlayerByExitPortal(3) and Player:getFacingDirection() == "East") then
                        return Utils:useAbility("Surge")
                    end
                    if not Player:isAnimating() and not self:_isPlayerByCrystals(6) then
                        return API.DoAction_WalkerW(self.variables.crystalDiveCoords)
                    end
                    return true
                end

                if step == "PREBUILD" then
                    if self.userSettings.prebuildSettings.useDummy then
                        -- TODO: Walk to dummies
                    end
                else
                    return true
                end

                -- Walking to boss portal
                if (step == "USE PORTAL" or step == "SUMMON CONJURES") and not Player:isAtCoordWithRadius(self.variables.portalDiveCoords, 10) and not Player:isMoving() then
                    return API.DoAction_WalkerW(self.variables.portalDiveCoords)
                end

                return false
            end,
            delay = 600,
            load = true,
        },
        -- Task: Load last preset
        {
            name = "Load last preset",
            priority = 30,
            cooldown = 10,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "LOAD PRESET")
            end,
            action = function()
                return self:loadLastPreset()
            end,
            load = true
        },
        -- Task: Pray at Altar of War
        {
            name = "Pray at Altar of War",
            priority = 28,
            cooldown = 10,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "USE ALTAR")
            end,
            action = function()
                return self:prayAtAltarOfWar()
            end,
            load = true
        },
        -- Task: Interact with adrenaline crystal
        {
            name = "Interacting with adrenaline crystal",
            priority = 25,
            cooldown = 2,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "USE CRYSTAL")
            end,
            action = function()
                if self:_isPlayerByCrystals(10) and Player:getAnimation() == 0 then
                    return self:channelAdrenaline()
                end
            end,
            delay = 300,
            delayTicks = false,
            load = self.bossData ~= nil
        },
        -- Task: Dismiss conjures when needed
        {
            name = "Dismissing conjures",
            priority = 23,
            cooldown = 3,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "REFRESH CONJURES")
            end,
            action = function()
                return self:_unequipLantern()
            end,
            load = self.userSettings.summonConjures
        },
        -- Task: Equip lantern for conjures
        {
            name = "Equipping lantern",
            priority = 22,
            cooldown = 3,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "EQUIP LANTERN")
            end,
            action = function()
                return self:_equipLantern()
            end,
            delay = 2,
            load = self.userSettings.summonConjures
        },
        -- Task: Summon conjures
        {
            name = "Summoning conjures",
            priority = 21,
            cooldown = 3,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "SUMMON CONJURES")
            end,
            action = function()
                if self:_isPlayerByCrystals(10) then
                    return Utils:useAbility("Conjure Undead Army")
                end
            end,
            disabledWhenOnCooldown = true,
            load = self.userSettings.summonConjures
        },
        {
            name = "Prebuild",
            priority = 20,
            cooldown = 0,
            parallel = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "PREBUILD")
            end,
            action = function()
                self.rotationManager:load(self.userSettings.prebuildSettings.rotation)
                self.rotationManager:execute()
                return true
            end,
            load = self.userSettings.prebuildSettings
        },
        -- Task: Go through boss portal
        {
            name = "Go through boss portal",
            priority = 10,
            cooldown = 2,
            useTicks = true,
            condition = function()
                return self:atLocation() and (self:_getCurrentStep() == "USE PORTAL")
            end,
            action = function()
                if self:_isPlayerByCrystals(10) and not Player:isMoving() then
                    return self:goThroughBossPortal()
                end
                return false
            end,
            load = self.bossData ~= nil
        }
    }

    -- Assign tasks to the timer
    if self.timer then
        for _, task in pairs(self.tasks) do
            if task.load then
                self.timer:addTask(task)
            end
        end
    end
end

------------------------------------------
--# LOCATION CHECK UTILITIES
------------------------------------------

--- Returns the appropriate step based on the player's current state and location.
--- @return
--- |"UNKOWN"
--- |"LOAD PRESET"
--- |"HEALING"
--- |"USE ALTAR"
--- |"USE CRYSTAL"
--- |"REFRESH CONJURES"
--- |"EQUIP LANTERN"
--- |"SUMMON CONJURES"
--- |"PREBUILD"
--- |"USE PORTAL": Step name indicating the current action to be taken.
function WarsRetreat:_getCurrentStep()
    if not self:atLocation() then return "UNKOWN" end
    local prebuild = self.userSettings.prebuildSettings ~= nil

    if not self:_inventoryMatchCheck() or (self.userSettings.bankIfInvFull and API.InvFull_()) then
        return "LOAD PRESET"
    end
    if self.userSettings.waitForFullHp and Player:getHpPercent() < self.userSettings.minimumValues.health then
        return "HEALING"
    end
    -- TODO: Add support for familar health and cooldowns
    if (Player:getPrayerPercent() < self.userSettings.minimumValues.prayer) or (Player:getSummoningPointsPercent() < self.userSettings.minimumValues.summoning) or self:_whitelistCooldownCheck() then
        return "USE ALTAR"
    end

    if
        ((Player:getAdrenaline() < Player:getMaxAdrenaline())
            or Player:getDebuff(self.constants.IDS.adrenalinePrevention).found)
        and ((self.bossData ~= nil) and self.userSettings.useAdrenCrystal)
    then
        if prebuild and (self.rotationManager.index ~= 1) and (self.rotationManager.index <= #self.userSettings.prebuildSettings.rotation) then
            goto continue
        end
        return "USE CRYSTAL"
    end
    ::continue::

    -- Summoning handling
    if self.userSettings.summonConjures then
        if self:_hasActiveSummons() and self:_shouldRefreshConjures() then
            return "REFRESH CONJURES"
        end
        if self:_checkForItem("lantern") and not self:_hasActiveSummons() then
            return "EQUIP LANTERN"
        end
        if not self:_hasActiveSummons() and not (Player:getAnimation() == self.constants.IDS.CONJURE_SUMMONING_ANIMATION) then
            return "SUMMON CONJURES"
        end
    end

    -- Prebuild handling
    if prebuild and self.rotationManager.index <= #self.userSettings.prebuildSettings.rotation then
        return "PREBUILD"
    end

    if self.bossData and self.bossData.portalId then
        return "USE PORTAL"
    end

    return "UNKOWN"
end

--- Checks if player is by the Bank chest
--- @param range? integer Distance from the Bank chest
--- @return boolean: True if player is close to the Bank chest
--- @private
function WarsRetreat:_isPlayerByBankChest(range)
    ---@diagnostic disable-next-line: undefined-global
    local tile = WPOINT.new(3299, 10131, 0)
    return Player:isAtCoordWithRadius(tile, range or 1)
end

--- Checks if the player is by the Altar of War
--- @param range integer? The distance between the player and the altar
--- @return boolean: True if player is close to the altar
--- @private
function WarsRetreat:_isPlayerByAltar(range)
    ---@diagnostic disable-next-line: undefined-global
    local tile = WPOINT.new(3304, 10129, 0)
    return Player:isAtCoordWithRadius(tile, range or 3)
end

--- Checks if the player is by the stairs at War's Retreat
--- @param range? integer The distance between the player and the stairs
--- @return boolean: True if player is close to the stairs
--- @private
function WarsRetreat:_isPlayerByStairs(range)
    ---@diagnostic disable-next-line: undefined-global
    local tile = WPOINT.new(3294, 10137, 0)
    return Player:isAtCoordWithRadius(tile, range or 2)
end

--- Checks if player is by the adrenaline crystals
--- @param range? integer The distance check range
--- @return boolean: True if player is close to the crystals
--- @private
function WarsRetreat:_isPlayerByCrystals(range)
    assert(self.variables.crystalDiveCoords, "Crystal coordinates not initialized")
    return Player:isAtCoordWithRadius(self.variables.crystalDiveCoords, range or 6)
end

--- Checks if player is by the adrenaline crystals
--- @param range? integer The distance check range
--- @return boolean: True if player is close to the crystals
--- @private
function WarsRetreat:_isPlayerByBossPortal(range)
    assert(self.variables.portalDiveCoords, "Boss portal coordinates not initialized")
    return Player:isAtCoordWithRadius(self.variables.portalDiveCoords, range or 6)
end

--- Checks if the player is by exit portal
--- @param range? integer The distance check range
--- @return boolean: True if palyer is close to exit portal
--- @private
function WarsRetreat:_isPlayerByExitPortal(range)
    ---@diagnostic disable-next-line: undefined-global
    local tile = WPOINT.new(3294, 10127, 9)
    return Player:isAtCoordWithRadius(tile, range or 3)
end

------------------------------------------
--# INVENTORY AND EQUIPMENT UTILITIES
------------------------------------------

--- Checks player inventory against preset loadout
--- @return boolean: True if inventory matches preset
--- @private
function WarsRetreat:_inventoryMatchCheck()
    assert(self.userSettings, "User settings not initialized")
    assert(self.userSettings.preset, "Preset not initialized")
    assert(self.userSettings.preset.inventory, "Preset inventory not initialized")

    local invent = self.userSettings.preset.inventory
    if not invent then
        Utils:terminate("Preset inventory not initialized")
        return false
    end

    return Utils:inventoryMatchCheck(invent)
end

--#  TODO: Create and implement equipment checking

--- Checks player inventory against preset loadout
--- @return boolean: True if inventory matches preset
--- @private
function WarsRetreat:_equipmentMatchCheck()
    return true
end

--# TODO: Move this to Utils perhaps?

--- Checks if an item exists in your inventory
--- @param name string Item name to search for
--- @return boolean: True if item is found in inventory
--- @private
function WarsRetreat:_checkForItem(name)
    local found = false
    for _, item in pairs(Inventory:GetItems()) do
        if string.find(item.name, name) then
            found = true
            break
        end
    end
    return found
end

--- Equips a lantern from inventory
--- @return boolean: True if lantern was equipped
--- @private
function WarsRetreat:_equipLantern()
    -- TODO: make this safer, as people will have flanking lanterns for some bosses - 0xBOBABABE
    return Inventory:Equip("lantern")
end

--- Unequips your off-hand (lantern)
--- @return boolean: True if lantern was unequipped
--- @private
function WarsRetreat:_unequipLantern()
    local offhand = Equipment:GetOffhand()
    return offhand and Equipment:Unequip(offhand.id)
end

------------------------------------------
--# ABILITY UTILITIES
------------------------------------------

--- Checks if any of the whitelisted abilities are on cooldown
--- @return boolean: True if any ability is on cooldown
--- @private
function WarsRetreat:_whitelistCooldownCheck()
    for _, ability in pairs(WHITELIST) do
        if API.GetABs_name(ability, true).cooldown_timer > 0 then
            return true
        end
    end
    return false
end

--- Checks if conjures need to be refreshed
--- @return boolean: True if conjures need refreshing
--- @private
function WarsRetreat:_shouldRefreshConjures()
    local zombieExpiring = (Player:getBuff(34177).remaining < 59) and (Player:getBuff(34177).remaining > 0)
    local ghostExpiring = (Player:getBuff(34178).remaining < 59) and (Player:getBuff(34178).remaining > 0)
    local skeletonExpiring = (Player:getBuff(34179).remaining < 59) and (Player:getBuff(34179).remaining > 0)

    local conjuresExpiring = zombieExpiring or ghostExpiring or skeletonExpiring

    return conjuresExpiring
end

--- Checks if the player has active summons (Ghost: 34178, Skeleton: 34179)
--- @return boolean: True if player has active summons
--- @private
function WarsRetreat:_hasActiveSummons()
    return Player:getBuff(34178).found or Player:getBuff(34179).found
end

--# TODO: Move this to Utils perhaps

--- Dive + Surge to specific location
--- @param tile? WPOINT Target coordinates
--- @return boolean: True if abilities were used
--- @private
function WarsRetreat:_doDiveAndSurge(tile)
    if Utils:useAbility("Surge") then
        if Utils:canUseAbility("Dive") and tile then
            return API.DoAction_Dive_Tile(tile)
        end
        if Utils:canUseAbility("Bladed Dive") and tile then
            return API.DoAction_BDive_Tile(tile)
        end
        return true
    end
    return false
end

return WarsRetreat
