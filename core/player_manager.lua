--- @module "Sonson's Player Manager"
--- @version 2.1.0.0

------------------------------------------
--# IMPORTS
------------------------------------------

local API             = require("api")
local Player          = require("core.player")
local Utils           = require("core.helper")

------------------------------------------
--# TYPE DEFINITIONS
------------------------------------------

--- @class PlayerManagerConfig
--- @field health?                          HealthThreshold                                             Configuration for managing health thresholds
--- @field prayer?                          PrayerThreshold                                             Configuration for managing prayer thresholds
--- @field interval?                        integer                                                     The duration in which to wait before re-attempting an action
--- @field excaliburHealAction?             '1' | '2'                                                   1 for default behavior
--- @field preferJellyfishHighAdrenaline?   boolean                                                     If true, prefer jellyfish when adrenaline > 50% (default: false)
--- @field adrenalineThreshold?             integer                                                     Adrenaline percentage threshold for preferring jellyfish (default: 50)
--- @field debug?                           boolean                                                     True to show debugging

--- @class PrayerThreshold
--- @field normal?                          Threshold                                                   The standard threshold to maintain
--- @field critical?                        Threshold                                                   The critical threshold that triggers emergency actions if no items are available
--- @field special?                         Threshold                                                   The threshold that activates special items like Enhanced Excalibur or Ancient Elven Ritual Shard

--- @class HealthThreshold
--- @field solid?                           Threshold                                                   The threshold for solid food items
--- @field jellyfish?                       Threshold                                                   The threshold for jellyfish items
--- @field healingPotion?                   Threshold                                                   The threshold for drinkable healing items
--- @field special?                         Threshold                                                   The threshold that activates special items like Enhanced Excalibur or Ancient Elven Ritual Shard

--- @class Threshold
--- @field type                             "fixed" | "percent" | "current"                             Specifies whether the threshold is based on a fixed value or a percentage (Note: "current" is treated the same as "fixed")
--- @field value                            integer                                                     The minimum value that triggers the threshold

--- @class PMInventoryItem
--- @field name                             string                                                      The name of the inventory item
--- @field id                               number                                                      The unique identifier for the item
--- @field type                             string                                                      The category of the item (e.g., "food", "prayer")
--- @field count                            number                                                      The quantity of the item in the inventory

--- @class PMInventory
--- @field food                             PMInventoryItem[]                                           A list of food items in the inventory
--- @field prayer                           PMInventoryItem[]                                           A list of prayer-related items in the inventory

--- @class Timestamps
--- @field eat                              number                                                      The last tick when food was consumed
--- @field drink                            number                                                      The last tick when a prayer item was consumed
--- @field buff                             number                                                      The last tick when a buff was applied
--- @field excal                            number                                                      The last tick when Enhanced Excalibur was used
--- @field shard                            number                                                      The last tick when the Ancient Elven Ritual Shard was used
--- @field tele                             number                                                      The last tick when an emergency teleport was triggered

--- @class Buff
--- @field buffName                         string                                                      The name of the buff
--- @field buffId                           number                                                      The unique identifier for the buff
--- @field execute                          fun():boolean                                               A function to activate the buff
--- @field canApply?                        boolean | fun(self):boolean                                 Determines if the buff can be applied (boolean or function)
--- @field toggle?                          boolean                                                     Indicates if the buff is toggleable
--- @field refreshAt?                       number                                                      The remaining time at which the buff should be refreshed
--- @field priority?                        number                                                      Higher priority buffs are processed first (default: 0)

--- @class BuffState
--- @field requested                        table<number, Buff>                                         Buffs requested this frame { [buffId] = Buff }
--- @field lastProcessed                    Buff[]                                                      Snapshot of last frame's processed buffs (for tracking)
--- @field active                           table<number, boolean>                                      Quick lookup of currently active buff IDs
--- @field toggle                           Buff[]                                                      A list of toggleable buffs that are currently on
--- @field failures                         table<number, number>                                       Track failed applications { [buffId] = attemptCount }
--- @field timestamps                       table<number, number>                                       Per-buff cooldown tracking { [buffId] = lastAttemptTick }

--- @class PlayerManager
--- @field debug                            boolean                                                     Whether debug mode is enabled
--- @field config                           PlayerManagerConfig                                         Configuration settings for the Player Manager
--- @field inventory                        PMInventory                                                 The player's inventory categorized by item type
--- @field buffs                            BuffState                                                   Buffs managed by the Player Manager
--- @field timestamps                       Timestamps                                                  Timestamps for the last actions performed
--- Core methods
--- @field update                           fun(self)                                                   Updates the player manager's state and inventory
--- @field manageHealth                     fun(self)                                                   Manages the player's health and maintains it above the defined normal threshold
--- @field useExcalibur                     fun(self):boolean                                           Uses Enhanced Excalibur if found
--- @field oneTickEat                       fun(self):boolean                                           Eats food in one tick (Solid -> Jellyfish -> Potion) FIXME: Wrong parameters
--- @field managePrayer                     fun(self)                                                   Manages the player's prayer points and maintains it above the defined normal threshold
--- @field useElvenShard                    fun(self):boolean                                           Uses Ancient Elven Ritual Shard if found
--- @field drink                            fun(self, potionId?: integer):boolean                       Drinks a potion if an ID is provided or will consume the first prayer restoring potion otherwise
--- @field dontDrink                        fun(self, ticks: number)                                    Sets a cooldown for drinking potions
--- @field requestBuffs                     fun(self, buffs: Buff[])                                    Requests buffs for the current frame (call each loop iteration)
--- @field deactivateAllToggleBuffs         fun(self)                                                   Immediately deactivates all toggle buffs
--- @field resetBuffTracking                fun(self)                                                   Resets buff failure counts and timestamps
--- @field updateConfig                     fun(self, config: PlayerManagerConfig)                      Updates configuration settings (thresholds, interval, etc.)
--- Metrics
--- @field stateTracking                    fun(self):table                                             Returns tracking metrics for the player's state
--- @field foodItemsTracking                fun(self):table                                             Returns tracking metrics for food items
--- @field prayerItemsTracking              fun(self):table                                             Returns tracking metrics for prayer items
--- @field buffConfigTracking               fun(self):table                                             Returns tracking metrics for configured buffs
--- @field toggleBuffsTracking              fun(self):table                                             Returns tracking metrics for toggleable buffs
--- @field activeBuffsTracking              fun(self):table                                             Returns tracking metrics for active buffs
--- @field buffFailuresTracking             fun(self):table                                             Returns tracking metrics for buff application failures
--- Private methods
--- @field _processInventory                fun(self)                                                   Scans the player's inventory and categorizes items
--- @field _filterFoodItems                 fun(self, type: string):PMInventoryItem[]                   Retrieves all food items of a specific type
--- @field _checkThreshold                  fun(self, resource: string, thresholdType: string):boolean  Checks if a resource threshold has been reached
--- @field _emergencyTeleport               fun(self, name?: string, critical?: string)                 Teleports in case of an emergency
--- @field _eat                             fun(self, type: string):boolean                             Eats the first type of food found
--- @field _checkCooldown                   fun(self, timestamp: integer):boolean                       Checks if an action can be performed based on cooldown
--- @field _canAttemptBuff                  fun(self, buffId: number):boolean                           Checks if enough time has passed to attempt applying a buff
--- @field _isBuffInTable                   fun(self, buffTable: Buff[], buffId: number):boolean        Checks if a buff ID exists in a given buff table
--- @field _addToToggleIfNeeded             fun(self, buff: Buff)                                       Adds a buff to the toggle list if it's a toggle buff
--- @field _canApplyBuff                    fun(self, buff: Buff):boolean                               Determines if a buff can be applied
--- @field _processBuff                     fun(self, buff: Buff)                                       Processes a buff, applying it if needed
--- @field _applyBuff                       fun(self, buff: Buff):boolean                               Attempts to apply a buff with failure tracking
--- @field _deactivateToggleBuff            fun(self, buff: Buff):boolean                               Deactivates a toggle buff that's no longer in config
--- @field _deactivateUnrequestedToggleBuffs fun(self)                                                   Deactivates toggle buffs not requested this frame

------------------------------------------
--# INITIALIZATION
------------------------------------------

local PlayerManager   = {}
PlayerManager.__index = PlayerManager

-- Singleton instance
local instance        = nil

--- Start a new instance or return an existing instance
--- @param config? PlayerManagerConfig
--- @return PlayerManager
function PlayerManager.new(config)
    if instance then
        return instance
    end

    -- Create a new instance if none exists
    --- @type PlayerManager
    local self = setmetatable({}, PlayerManager)
    Utils:log("Initializing Player Manager instance", "info")

    -- Add defaults to config if not provided or partially missing
    self.config = {}
    Utils:log((config and "Config was found") or "No config was found")
    config = config or {}

    self.config.health = {
        solid         = (config and config.health and config.health.solid) or { type = "fixed", value = 100 },
        jellyfish     = (config and config.health and config.health.jellyfish) or { type = "percent", value = 70 },
        healingPotion = (config and config.health and config.health.healingPotion) or { type = "percent", value = 30 },
        special       = (config and config.health and config.health.special) or
            { type = "percent", value = 40 } -- Enhanced Excalibur threshold
    }
    self.config.prayer = {
        normal   = (config and config.prayer and config.prayer.normal) or { type = "fixed", value = 200 },
        critical = (config and config.prayer and config.prayer.critical) or { type = "percent", value = 10 },
        special  = (config and config.prayer and config.prayer.special) or
            { type = "fixed", value = 600 } -- Ancient elven ritual shard threshold
    }
    self.config.excaliburHealAction = (config and config.excaliburHealAction) or '1'
    self.config.interval = (config and config.interval) or 1
    self.config.preferJellyfishHighAdrenaline = (config and config.preferJellyfishHighAdrenaline) or false
    self.config.adrenalineThreshold = (config and config.adrenalineThreshold) or 50

    Utils:log("Solid: " .. self.config.health.solid.value)
    Utils:log("Jellyfish: " .. self.config.health.jellyfish.value)
    Utils:log("Potion: " .. self.config.health.healingPotion.value)
    if self.config.preferJellyfishHighAdrenaline then
        Utils:log("Adrenaline-aware eating enabled (threshold: " .. self.config.adrenalineThreshold .. "%)")
    end

    -- Timestamps of the last ticks in which the actions were used
    self.timestamps = {
        eat = 0,
        drink = 0,
        buff = 0,
        excal = 0,
        shard = 0,
        tele = 0,
        inventoryScan = 0  -- Track last inventory scan for cooldown
    }

    -- Contains information regarding inventory items
    self.inventory = {
        food = {},
        prayer = {}
    }

    -- Contains information regarding the player's managed buffs
    self.buffs = {
        requested = {},     -- Buffs requested this frame { [buffId] = Buff }
        lastProcessed = {}, -- Snapshot of last frame's processed buffs (for tracking)
        active = {},        -- Quick lookup of currently active buff IDs
        toggle = {},        -- Toggle buffs that are currently on
        failures = {},      -- Track failed applications { [buffId] = attemptCount }
        timestamps = {}     -- Per-buff cooldown tracking { [buffId] = lastAttemptTick }
    }

    -- Default debug values
    self.debug = self.config.debug or false

    instance = self
    return instance
end

------------------------------------------
--# CORE FUNCTIONALITY
------------------------------------------

--- Updates player manager data
function PlayerManager:update()
    -- Only scan inventory every 5 ticks to improve performance
    local currentTick = API.Get_tick()
    if currentTick - self.timestamps.inventoryScan > 5 then
        self:_processInventory()
        self.timestamps.inventoryScan = currentTick
    end
    self:_handleBuffs()
end

--- Handles the player's health and maintains it above the defined normal threshold
function PlayerManager:manageHealth()
    -- Check to see if any thresholds are met
    local solidFoodThreshold     = self:_checkThreshold("health", "solid")
    local jellyfishThreshold     = self:_checkThreshold("health", "jellyfish")
    local healingPotionThreshold = self:_checkThreshold("health", "healingPotion")
    local specialThreshold       = self:_checkThreshold("health", "special")

    -- Execute actions according to reached threhsolds
    if specialThreshold then self:useExcalibur() end
    if (solidFoodThreshold or jellyfishThreshold or healingPotionThreshold) and (#self.inventory.food > 0) then
        self:oneTickEat(solidFoodThreshold, jellyfishThreshold, healingPotionThreshold)
        return
    end

    -- Uses emergency teleport if out of food and critical threshold is met
    if (solidFoodThreshold or jellyfishThreshold or healingPotionThreshold) and (#self.inventory.food == 0) then
        Utils:log("Emergency teleport triggered (HEALTH)", "warn")
        self:_emergencyTeleport("War's Retreat Teleport", "health")
    end
end

--- Uses Enhanced Excalibur if found
--- @return boolean
function PlayerManager:useExcalibur()
    local currentTick = API.Get_tick()
    local excaliburIds = { 14632, 36619 }
    local excaliburAction = tonumber(self.config.excaliburHealAction) or 1

    -- Exits the funciton if action is on cooldown or debuff is found
    if not (self:_checkCooldown(self.timestamps.excal))
        or Player:getDebuff(14632).found
    then
        return false
    end

    for _, id in ipairs(excaliburIds) do
        -- Use from inventory
        if Inventory:Contains(id) then
            if Inventory:DoAction(id, excaliburAction, API.OFF_ACT_GeneralInterface_route) then
                self.timestamps.excal = currentTick
                return true
            end
        end
        -- Use from off-hand
        if Equipment:GetOffhand().id == id then
            ---@diagnostic disable-next-line
            if Equipment:DoAction(id, excaliburAction + 1) then
                self.timestamps.excal = currentTick
                return true
            end
        end
    end
    return false
end

--- Eats all food in one tick
--- @param solidFoodThreshold boolean: Whether to eat solid food items
--- @param jellyfishThreshold boolean: Whether to eat jellyfish items
--- @param healingPotionThreshold boolean: Whether to drink healing potions
--- @return boolean: Whether the player attempted to restore health
function PlayerManager:oneTickEat(solidFoodThreshold, jellyfishThreshold, healingPotionThreshold)
    local currentTick = API.Get_tick()
    -- Check if action was recently executed
    if not self:_checkCooldown(self.timestamps.eat) then
        return false
    end

    local success = false

    -- Adrenaline-aware eating: prefer jellyfish when adrenaline is high
    if self.config.preferJellyfishHighAdrenaline then
        local currentAdrenaline = Player:getAdrenaline()
        local hasJellyfish = #self:_filterFoodItems("jellyfish") > 0
        local hasSolidFood = #self:_filterFoodItems("food") > 0

        -- If adrenaline is above threshold and we have jellyfish, prioritize it
        if currentAdrenaline >= self.config.adrenalineThreshold and hasJellyfish and jellyfishThreshold then
            if self:_eat("jellyfish") then
                self.timestamps.eat = currentTick
                success = true
                Utils:log(("Adrenaline-aware: ate jellyfish (adr: %d%%)"):format(currentAdrenaline), "debug")
            end
            -- Skip solid food to preserve adrenaline
            solidFoodThreshold = false
        end
    end

    if solidFoodThreshold then
        if #self:_filterFoodItems("food") > 0 then
            if self:_eat("food") then
                self.timestamps.eat = currentTick
                success = true
            end
        end
    end
    if jellyfishThreshold then
        if #self:_filterFoodItems("jellyfish") > 0 then
            if self:_eat("jellyfish") then
                self.timestamps.eat = currentTick
                success = true
            end
        end
    end
    -- Check if action was recently executed
    if not self:_checkCooldown(self.timestamps.drink) then return false end
    if healingPotionThreshold then
        if #self:_filterFoodItems("potion") > 0 then
            if self:_eat("potion") then
                self.timestamps.drink = currentTick
                success = true
            end
        end
    end
    return success
end

--- Manages the player's prayer points and maintains it above the deined normal threshold
function PlayerManager:managePrayer()
    -- Checks to see if any thresholds are met
    local normalThreshold   = self:_checkThreshold("prayer", "normal")
    local criticalThreshold = self:_checkThreshold("prayer", "critical")
    local specialThreshold  = self:_checkThreshold("prayer", "special")

    -- Execute actions according to reached thresholds
    if specialThreshold then self:useElvenShard() end
    if normalThreshold and #self.inventory.prayer > 0 then
        self:drink()
        return
    end

    -- Uses emergency teleport if out of prayer items and critical threshold is met
    if criticalThreshold and #self.inventory.prayer == 0 then
        self:_emergencyTeleport("War's Retreat Teleport", "prayer")
    end
end

--- Uses Ancient elven ritual shard if found
function PlayerManager:useElvenShard()
    -- Exits the function if Ritual shard isn not found, action is on cooldown or debuff is found
    if not Inventory:Contains(43358)
        or Player:getDebuff(43358).found
        or not self:_checkCooldown(self.timestamps.shard)
    then
        return false
    end

    if Inventory:DoAction(43358, 1, API.OFF_ACT_GeneralInterface_route) then
        self.timestamps.shard = API.Get_tick()
        return true
    else
        return false
    end
end

--- Consumes the potion with the provided potion id; if no id is given, consumes the first available prayer item
--- @param potionId? number: The ID of the potion to consume
--- @return boolean
function PlayerManager:drink(potionId)
    local currentTick = API.Get_tick()
    local itemId = potionId or self.inventory.prayer[1].id

    -- Exits function if still on cooldown
    if not self:_checkCooldown(self.timestamps.drink) or not Inventory:Contains(itemId) then
        return false
    end

    if Inventory:DoAction(itemId, 1, API.OFF_ACT_GeneralInterface_route) then
        self.timestamps.drink = currentTick
        -- Removed blocking sleep - cooldown system handles timing
        return true
    else
        return false
    end
end

--- Sets a cooldown period during which the player cannot drink potions.
--- @param ticks integer: The number of ticks to set the cooldown for drinking potions
function PlayerManager:dontDrink(ticks)
    self.timestamps.drink = API.Get_tick() + ticks
end

--- Requests buffs to be managed for the current frame.
--- Call this every loop iteration for each set of buffs that should be active.
--- Can be called multiple times per frame — requests accumulate.
--- Toggle buffs that are not requested on a given frame are automatically deactivated.
--- @param buffs Buff[]: A list of buffs to request
function PlayerManager:requestBuffs(buffs)
    for _, buff in ipairs(buffs or {}) do
        self.buffs.requested[buff.buffId] = buff
    end
end

--- Immediately deactivates all toggle buffs and clears the toggle list
function PlayerManager:deactivateAllToggleBuffs()
    Utils:log("Deactivating all toggle buffs", "debug")

    -- Iterate backwards to safely remove items
    for i = #self.buffs.toggle, 1, -1 do
        local buff = self.buffs.toggle[i]
        if self:_deactivateToggleBuff(buff) then
            Utils:log(("Deactivated: %s"):format(buff.buffName), "debug")
        else
            Utils:log(("Failed to deactivate: %s"):format(buff.buffName), "warn")
        end
        table.remove(self.buffs.toggle, i)
    end

    Utils:log("All toggle buffs deactivated", "info")
end

--- Resets buff failure counts and timestamps
function PlayerManager:resetBuffTracking()
    Utils:log("Resetting buff tracking (failures and timestamps)", "info")
    self.buffs.failures = {}
    self.buffs.timestamps = {}
end

--- Updates configuration settings without recreating the instance
--- @param config PlayerManagerConfig: New configuration values to merge
function PlayerManager:updateConfig(config)
    if not config then
        Utils:log("updateConfig called with nil config", "warn")
        return
    end

    Utils:log("Updating PlayerManager configuration", "info")

    -- Update health thresholds if provided
    if config.health then
        if config.health.solid then
            self.config.health.solid = config.health.solid
        end
        if config.health.jellyfish then
            self.config.health.jellyfish = config.health.jellyfish
        end
        if config.health.healingPotion then
            self.config.health.healingPotion = config.health.healingPotion
        end
        if config.health.special then
            self.config.health.special = config.health.special
        end
    end

    -- Update prayer thresholds if provided
    if config.prayer then
        if config.prayer.normal then
            self.config.prayer.normal = config.prayer.normal
        end
        if config.prayer.critical then
            self.config.prayer.critical = config.prayer.critical
        end
        if config.prayer.special then
            self.config.prayer.special = config.prayer.special
        end
    end

    -- Update other settings if provided
    if config.excaliburHealAction then
        self.config.excaliburHealAction = config.excaliburHealAction
    end

    if config.interval then
        self.config.interval = config.interval
    end

    if config.debug ~= nil then
        self.debug = config.debug
    end

    if config.preferJellyfishHighAdrenaline ~= nil then
        self.config.preferJellyfishHighAdrenaline = config.preferJellyfishHighAdrenaline
    end

    if config.adrenalineThreshold then
        self.config.adrenalineThreshold = config.adrenalineThreshold
    end

    Utils:log("Configuration updated successfully", "info")
end

--- Main buff processing loop - called from update()
--- Processes all buffs requested this frame via requestBuffs(), then
--- deactivates any toggle buffs that were not requested.
function PlayerManager:_handleBuffs()
    -- Build sorted processing list from requested buffs
    local toProcess = {}
    for _, buff in pairs(self.buffs.requested) do
        table.insert(toProcess, buff)
    end
    table.sort(toProcess, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)

    -- Update active buff lookup
    self.buffs.active = {}
    for _, buff in ipairs(toProcess) do
        if Player:getBuff(buff.buffId).found then
            self.buffs.active[buff.buffId] = true
        end
    end

    -- Process all requested buffs (apply if inactive/expired)
    for _, buff in ipairs(toProcess) do
        self:_processBuff(buff)
    end

    -- Deactivate toggle buffs that were NOT requested this frame
    self:_deactivateUnrequestedToggleBuffs()

    -- Save snapshot for tracking, then clear for next frame
    self.buffs.lastProcessed = toProcess
    self.buffs.requested = {}
end

------------------------------------------
--# PLAYER MANAGEMENT HELPER FUNCTIONS
------------------------------------------

--- Checks if an action can be performed based on
--- @param timestamp integer: The timestamp to check current tick against
function PlayerManager:_checkCooldown(timestamp)
    return (API.Get_tick() - timestamp > self.config.interval)
end

--- Scans the player's inventory, categorizes items, and merges duplicate entries.
--- @private
function PlayerManager:_processInventory()
    -- Define item categories with matching name patterns.
    local categories = {
        {
            name = "prayer",
            patterns = {
                "Prayer", "Super restore", "Sanfew",
                "Super prayer", "Spiritual prayer", "Extreme prayer",
                "Blessed flask"
            }
        },
        {
            name = "potion",
            patterns = {
                "Guthix rest", "Super Guthix brew", "Saradomin brew"
            }
        },
        {
            name = "jellyfish",
            patterns = {
                "Blue blubber jellyfish", "2/3 blue blubber jellyfish", "1/3 blue blubber jellyfish",
                "Green blubber jellyfish", "2/3 green blubber jellyfish", "1/3 green blubber jellyfish"
            }
        },
        {
            name = "food",
            patterns = {
                "Kebab", "Bread", "Doughnut", "Roll", "Square sandwich",
                "Crayfish", "Shrimps", "Sardine", "Herring", "Mackerel",
                "Anchovies", "Cooked chicken", "Cooked meat", "Trout", "Cod",
                "Pike", "Salmon", "Tuna", "Bass", "Lobster", "Swordfish",
                "Desert sole", "Catfish", "Monkfish", "Beltfish", "Ghostly sole",
                "Cooked eeligator", "Shark", "Sea turtle", "Great white shark", "Cavefish",
                "Manta ray", "Rocktail", "Tiger shark", "Sailfish", "Baron shark",
                "Potato with cheese", "Tuna potato", "Great maki", "Great gunkan",
                "Rocktail soup", "Sailfish soup", "Fury shark", "Primal feast"
            }
        }
    }

    -- Temporary tables to store raw items by category.
    local HealthItems = {}
    local PrayerItems = {}

    -- Scan through each item in the player's inventory.
    for _, item in ipairs(Inventory:GetItems()) do
        ---@cast item InventoryItem
        -- Skip empty slots or items with a stack size not equal to 1.
        if item.id == -1 or item.amount ~= 1 then goto continue end

        -- Remove formatting from the item's name.
        local cleanName = item.name:gsub("<col=f8d56b>", "")
        local matchedType = nil

        -- Determine item's type by checking if its name matches a known pattern.
        for _, category in ipairs(categories) do
            for _, pattern in ipairs(category.patterns) do
                if cleanName:find(pattern) then
                    matchedType = category.name
                    goto match_found
                end
            end
        end
        ::match_found::

        -- If a matching category is found, create an entry.
        if matchedType then
            local entry = {
                name = cleanName,
                id = item.id,
                type = matchedType,
                count = 1
            }
            if matchedType == "prayer" then
                table.insert(PrayerItems, entry)
            else
                table.insert(HealthItems, entry)
            end
        end

        ::continue::
    end

    -- Helper function to merge duplicate entries.
    -- TODO: Add to SonsonUtils
    local function mergeDuplicates(items)
        local merged = {}
        local seen = {}
        for _, item in ipairs(items) do
            local key = item.id .. ":" .. item.name
            if seen[key] then
                seen[key].count = seen[key].count + 1
            else
                seen[key] = {
                    name = item.name,
                    id = item.id,
                    type = item.type,
                    count = 1
                }
                table.insert(merged, seen[key])
            end
        end
        return merged
    end

    -- Merge duplicates for both food and prayer items.
    self.inventory.food = mergeDuplicates(HealthItems)
    self.inventory.prayer = mergeDuplicates(PrayerItems)
end

--- Retrieves all food items of a specific type
--- @param type "food" | "jellyfish" | "potion"
--- @return PMInventoryItem[]
--- @private
function PlayerManager:_filterFoodItems(type)
    local filteredFoodItems = {}
    for _, item in ipairs(self.inventory.food) do
        if item.type == type then
            table.insert(filteredFoodItems, item)
        end
    end
    return filteredFoodItems
end

--- Checks if the specified resource threshold has been reached
--- @param resource "health" | "prayer": The type of resource to check for
--- @param thresholdType "normal" | "critical" | "special" | "solid" | "jellyfish" | "healingPotion": The type of threshold to check for
--- @return boolean
--- @private
function PlayerManager:_checkThreshold(resource, thresholdType)
    local healthStat = { percent = Player:getHpPercent(), current = Player:getHP() }
    local prayerStat = { percent = Player:getPrayerPercent(), current = Player:getPrayerPoints() }
    local stat = resource == "health" and healthStat or prayerStat
    local threshold = self.config[resource][thresholdType]

    local compareValue = threshold.type == "percent"
        and stat.percent or stat.current

    return compareValue <= threshold.value
end

--- Teleports in case of an emergency
--- @param name? string: The name of the emergency teleport
--- @param critical? "prayer" | "health" | "UNKNOWN": The critical criteria
function PlayerManager:_emergencyTeleport(name, critical)
    name = name or "War's Retreat Teleport"
    critical = critical or "UNKNOWN"
    local currentTick = API.Get_tick()

    -- Fixed: Corrected timing check (was: self.timestamps.tele - currentTick < 10)
    if currentTick - self.timestamps.tele > 10 then
        if Utils:useAbility(name) then
            Utils:log(("Emergency teleport initiated" .. (" (%s)"):format(critical)), "warn")
            self.timestamps.tele = currentTick
        end
    end
end

------------------------------------------
--# HEALTH MANAGEMENT FUNCTIONS
------------------------------------------

--- Eats first type of food found returns true if action taken
--- @param type string
--- @return boolean
function PlayerManager:_eat(type)
    -- Gets the first food item of the specified type
    local item = self:_filterFoodItems(type)[1]

    -- Eat found food of specified type.
    if Inventory:DoAction(item.id, 1, API.OFF_ACT_GeneralInterface_route) then
        -- Removed blocking sleep - the game client handles action spacing within a tick
        return true
    else
        return false
    end
end

------------------------------------------
--# BUFF MANAGEMENT HELPER FUNCTIONS
------------------------------------------

local MAX_BUFF_FAILURES = 5 -- Stop retrying after this many consecutive failures

--- Checks if enough time has passed to attempt applying a specific buff
--- @param buffId number The ID of the buff to check
--- @return boolean True if enough time has passed since last attempt
function PlayerManager:_canAttemptBuff(buffId)
    local lastAttempt = self.buffs.timestamps[buffId] or 0
    return (API.Get_tick() - lastAttempt) > self.config.interval
end

--- Checks if a buff ID exists in a given buff table
--- @param buffTable Buff[] The table of buffs to search
--- @param buffId number The ID of the buff to check
--- @return boolean True if the buff ID exists in the table, false otherwise
function PlayerManager:_isBuffInTable(buffTable, buffId)
    for _, buff in ipairs(buffTable) do
        if buff.buffId == buffId then
            return true
        end
    end
    return false
end

--- Adds a buff to the toggle list if it's a toggle buff and not already present
--- @param buff Buff The buff to potentially add
function PlayerManager:_addToToggleIfNeeded(buff)
    if buff.toggle and not self:_isBuffInTable(self.buffs.toggle, buff.buffId) then
        table.insert(self.buffs.toggle, buff)
    end
end

--- Determines if a buff can be applied based on its canApply property
--- @param buff Buff The buff to check
--- @return boolean|fun():boolean True if the buff can be applied, false otherwise
function PlayerManager:_canApplyBuff(buff)
    if buff.canApply == nil then
        return true
    end

    if type(buff.canApply) == "function" then
        return buff.canApply()
    end
    return buff.canApply
end

--- Processes a single buff - checks state and applies if needed
--- @param buff Buff The buff to process
function PlayerManager:_processBuff(buff)
    local buffState = Player:getBuff(buff.buffId)
    local refreshAt = buff.refreshAt or -1

    -- Buff is active and doesn't need refresh
    if buffState.found and buffState.remaining > refreshAt then
        self:_addToToggleIfNeeded(buff)
        return
    end

    -- Buff needs to be applied or refreshed
    self:_applyBuff(buff)
end

--- Attempts to apply a buff with per-buff cooldown and failure tracking
--- @param buff Buff The buff to apply
--- @return boolean True if the buff was successfully applied
function PlayerManager:_applyBuff(buff)
    -- Check per-buff cooldown
    if not self:_canAttemptBuff(buff.buffId) then
        return false
    end

    -- Check if we've exceeded max failures
    local failures = self.buffs.failures[buff.buffId] or 0
    if failures >= MAX_BUFF_FAILURES then
        return false -- Stop trying, already logged warning
    end

    -- Check if buff can be applied (e.g., has required items)
    if not self:_canApplyBuff(buff) then
        return false
    end

    -- Attempt to apply the buff
    self.buffs.timestamps[buff.buffId] = API.Get_tick()

    if buff.execute() then
        -- Success - reset failure counter and add to toggle if needed
        self.buffs.failures[buff.buffId] = 0
        self:_addToToggleIfNeeded(buff)
        return true
    else
        -- Failure - increment counter and warn if max reached
        self.buffs.failures[buff.buffId] = failures + 1
        if self.buffs.failures[buff.buffId] >= MAX_BUFF_FAILURES then
            Utils:log(("Buff '%s' failed %d times, will stop retrying"):format(
                buff.buffName, MAX_BUFF_FAILURES), "warn")
        end
        return false
    end
end

--- Deactivates a toggle buff by calling its execute function again
--- @param buff Buff The toggle buff to deactivate
--- @return boolean True if the buff was deactivated
function PlayerManager:_deactivateToggleBuff(buff)
    -- If buff is already off, consider it deactivated
    if not Player:getBuff(buff.buffId).found then
        return true
    end

    -- Toggle it off by calling execute again
    if buff.execute() then
        Utils:log(("Deactivated toggle buff: %s"):format(buff.buffName), "debug")
        return true
    end
    return false
end

--- Deactivates toggle buffs that were not requested this frame
function PlayerManager:_deactivateUnrequestedToggleBuffs()
    for i = #self.buffs.toggle, 1, -1 do
        local buff = self.buffs.toggle[i]
        if not self.buffs.requested[buff.buffId] then
            if self:_deactivateToggleBuff(buff) then
                table.remove(self.buffs.toggle, i)
            end
        end
    end
end

------------------------------------------
--# TRACKING & METRICS
------------------------------------------

---returns tracking metrics for the player state
---@return table
function PlayerManager:stateTracking()
    local metrics = {
        { "Player State:", "" },
        -- stats
        { "- Health",      Player:getHP() .. "/" .. Player:getMaxHP() .. " (" .. Player:getHpPercent() .. "%)" },
        { "- Prayer",      Player:getPrayerPoints() .. "/" .. Player:getMaxPrayerPoints() .. " (" .. Player:getPrayerPercent() .. "%)" },
        { "- Summoning",   Player:getSummoningPoints() .. "/" .. Player:getMaxSummoningPoints() .. " (" .. Player:getSummoningPointsPercent() .. "%)" },
        { "- Adrenaline",  Player:getAdrenaline() },
        -- location
        { "- Location",    "DEPRECATED" },
        { "- Direction",   Player:getFacingDirection() .. " (" .. Player:getOrientation() .. "°)" },
        { "- Coordinates", string.format("(%s, %s, %s)",
            Player:getCoords().x,
            Player:getCoords().y,
            Player:getCoords().z) },
        -- animations
        { "- Animation",     (not Player:isAnimating() and "Idle") or Player:getAnimation() },
        { "- Is Moving?",    Player:isMoving() and "Yes" or "No" },
        { "- Is In Combat?", Player:isInCombat() and "Yes" or "No" },
        -- TODO: Add more stuff here
    }
    return metrics
end

---@return table
function PlayerManager:foodItemsTracking()
    local metrics = { { "- Food Items:", "" } }

    if #self.inventory.food < 1 then
        table.insert(metrics, { "-- No foods found", "" })
    else
        for _, i in ipairs(self.inventory.food) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

---@return table
function PlayerManager:prayerItemsTracking()
    local metrics = { { "- Prayer Items:", "" } }

    if #self.inventory.prayer < 1 then
        table.insert(metrics, { "-- No prayer items found", "" })
    else
        for _, i in ipairs(self.inventory.prayer) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

---@return table
function PlayerManager:buffConfigTracking()
    local metrics = { { "Managed Buffs:", "" } }
    local buffs = self.buffs.lastProcessed or {}

    if #buffs < 1 then
        table.insert(metrics, { "- No buffs requested", "" })
    else
        for _, buff in ipairs(buffs) do
            local isActive = self.buffs.active[buff.buffId] and "Active" or "Inactive"
            local buffType = buff.toggle and "toggle" or "static"
            local priority = buff.priority or 0
            table.insert(metrics, {
                string.format("- [%d] %s", buff.buffId, buff.buffName),
                string.format("%s | %s | Pri:%d", isActive, buffType, priority)
            })
        end
    end
    return metrics
end

---@return table
function PlayerManager:buffFailuresTracking()
    local metrics = { { "Buff Failures:", "" } }

    local hasFailures = false
    for buffId, count in pairs(self.buffs.failures) do
        if count > 0 then
            hasFailures = true
            -- Find buff name from last processed snapshot
            local buffName = "Unknown"
            for _, buff in ipairs(self.buffs.lastProcessed or {}) do
                if buff.buffId == buffId then
                    buffName = buff.buffName
                    break
                end
            end
            table.insert(metrics, {
                string.format("- [%d] %s", buffId, buffName),
                string.format("Failures: %d/%d", count, MAX_BUFF_FAILURES)
            })
        end
    end

    if not hasFailures then
        table.insert(metrics, { "- No failures recorded", "" })
    end
    return metrics
end

---@return table
function PlayerManager:toggleBuffsTracking()
    local metrics = { { "Toggle Buffs:", "" } }

    if #self.buffs.toggle < 1 then
        table.insert(metrics, { "- No buffs found", "" })
    else
        for _, i in pairs(self.buffs.toggle) do
            table.insert(metrics,
                { string.format("- [%d] %s (%s)", i.buffId, i.buffName, i.toggle and "toggle" or "static"), "Active: " ..
                tostring(Player:getBuff(i.buffId).found) })
        end
    end
    return metrics
end

---@return table
function PlayerManager:activeBuffsTracking()
    local metrics = { { "Active Buffs:", "" } }
    local activeBuffs = API.Buffbar_GetAllIDs(false)

    if #activeBuffs < 1 then
        table.insert(metrics, { "- No buffs found", "" })
    else
        for _, i in pairs(activeBuffs) do
            table.insert(metrics,
                { "- " .. i.id, "Text (conv): " .. i.text .. " (" .. i.conv_text .. ")" })
        end
    end
    return metrics
end

------------------------------------------
--# FIN
------------------------------------------

return PlayerManager
