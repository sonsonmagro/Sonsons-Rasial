---@version 1.0.3
--[[
    File: prayer_flicker.lua
    Description: This class is designed for dynamic prayer switching based on various threat types
    Author: Sonson
]]
---@class PrayerFlicker
---@field config PrayerFlickerConfig
---@field state PrayerFlickerState
local PrayerFlicker = {}
PrayerFlicker.__index = PrayerFlicker

--#region example config
--[[
    an example config could look something like this
    local config = {
        prayers = {
            PrayerFlicker.PRAYERS.SOUL_SPLIT,           -- [1]
            PrayerFlicker.PRAYERS.DEFLECT_MELEE,        -- [2]
            PrayerFlicker.PRAYERS.DEFLECT_MAGIC,        -- [3]
            PrayerFlicker.PRAYERS.DEFLECT_RANGED,       -- [4]
        },
        defaultPrayer = config.prayers[1],
        projectiles = {
            {
                id = 7714,
                prayer = config.prayers[4],
                bypassCondition = function() return Utils.isDivertActive() end,
                priority = 2,
                activationDelay = 1,
                duration = 1
            },
            {
                id = 7718,
                prayer = config.prayers[3],
                bypassCondition = function() return Utils.isDivertActive() or Utils.isEdictAnimationActive() end,
                priority = 1,
                activationDelay = 1,
                duration = 1
            }
        },
        npcs = {
            {
                id = Constants.NPCS.ZAMORAK.ID,
                animations = {
                    {
                        animId = Constants.NPCS.ZAMORAK.ANIMATIONS.MELEE_ATTACK,
                        prayer = config.prayers[2],
                        activationDelay = 2,
                        duration = 4,
                        priority = 100
                    }
                }
            },
            {
                id = Constants.NPCS.CHAOS_WITCH.ID,
                animations = {
                    {
                        animId = Constants.NPCS.CHAOS_WITCH.ANIMATIONS.MAGIC_ATTACK,
                        prayer = config.prayers[3],
                        activationDelay = 0,
                        duration = 2,
                        priority = 1
                    }
                }
            }
        },
        conditionals = {
            {
                condition = function() return isNearChaosTrap(5) end,
                prayer = config.prayers[3],
                priority = 10,
                duration = 3
            }
        }
    }
]]
--#endregion

--#region luaCATS annotation
---@class Prayer
---@field name string
---@field buffId number

---@class PrayerFlickerConfig
---@field defaultPrayer Prayer | nil
---@field prayers Prayer[]
---@field projectiles Projectile[] | nil
---@field npcs PrayerFlickerNPC[] | nil
---@field conditionals Conditional[] | nil

---projectile threat data
---@class Projectile
---@field id projectileId
---@field prayer Prayer
---@field bypassCondition nil | fun(): boolean
---@field priority number
---@field activationDelay number
---@field duration number

---npc animation data
---@class PrayerFlickerNPC
---@field id npcId
---@field animations Animation[]

---animation threat data
---@class Animation
---@field animId animationId
---@field prayer Prayer
---@field activationDelay number
---@field bypassCondition nil | fun(): boolean
---@field duration number
---@field priority number

---conditional threat data
---@class Conditional
---@field condition fun(): boolean
---@field bypassCondition nil | fun(): boolean
---@field prayer Prayer
---@field priority number
---@field duration number

---@class PrayerFlickerState
---@field activePrayer Prayer
---@field lastPrayerTick number
---@field pendingActions Threat[]

---@class Threat
---@field type threatType
---@field projId projectileId
---@field animId animationId
---@field npcId npcId
---@field condition fun(): boolean
---@field prayer Prayer
---@field priority number
---@field activateTick gameTick
---@field expireTick gameTick

---@alias threatType
---| "projectile"
---| "animation"
---| "conditional"

---@alias gameTick number
---@alias projectileId number
---@alias npcId number
---@alias animationId number
--#endregion

local API = require("api")

---creates a new PrayerFlicker instance
---@param config PrayerFlickerConfig
---@return PrayerFlicker
function PrayerFlicker.new(config)
    local self = setmetatable({}, PrayerFlicker)
    -- terminate if no config
    if not config then
        print("[PRAYER_FLICKER]: You need to provide a configuration list when initializing.")
        print("[PRAYER_FLICKER]: Terminating your session.")
        API.Write_LoopyLoop(false)
    end

    self.config = {
        prayers = config.prayers,
        defaultPrayer = config.defaultPrayer or {},
        projectiles = config.projectiles or {},
        npcs = config.npcs or {},
        conditionals = config.conditionals or {}
    }

    self:_checkPrayersOnAbilityBars()

    self.state = {
        ---@diagnostic disable-next-line
        activePrayer = {},
        lastPrayerTick = 0,
        pendingActions = {}
    }

    return self
end


---@type table<any, Prayer>
---@enum prayers list of prayers to choose from
PrayerFlicker.PRAYERS = {
    SOUL_SPLIT          = { name = "Soul Split",     buffId = 26033 },
    DEFLECT_MELEE       = { name = "Deflect Melee",  buffId = 26040 },
    DEFLECT_MAGIC       = { name = "Deflect Magic",  buffId = 26041 },
    DEFLECT_RANGED      = { name = "Deflect Ranged", buffId = 26044 },
    DEFLECT_NECROMANCY  = { name = "Deflect Necromancy", buffId = 30745 }
}

---checks to see if the listed prayers exist on available ability bars
---@private
function PrayerFlicker:_checkPrayersOnAbilityBars()
    local missingPrayers = {}

    for _, prayer in pairs(self.config.prayers) do
        if #API.GetABs_names({prayer.name}) < 1 then
            table.insert(missingPrayers, prayer.name)
        end
    end

    if #missingPrayers >= 1 then
        print("[PRAYER FLICKER]: Missing prayers!")
        print("[PRAYER FLICKER]: Please make sure to add the following prayers to your ability bars.")
        print("[PRAYER FLICKER]: " .. table.concat(missingPrayers, ", "))
        print("[PRAYER FLICKER]: Terminating your session.")

        API.Write_LoopyLoop(false)
    end
end

---gets the active prayer
---@return Prayer
function PrayerFlicker:_getCurrentPrayer()
    for _, prayer in ipairs(self.config.prayers) do
        if API.Buffbar_GetIDstatus(prayer.buffId, false).found then
            return prayer
        end
    end
    return {}
end

--#region threat checks
---checks if the projectile threat still exists
---@private
---@param projectileId projectileId
---@return boolean
function PrayerFlicker:_projectileExists(projectileId)
    local projectiles = API.GetAllObjArray1({ projectileId }, 60, { 5 })
    return #projectiles > 0
end

---checks if the animation threat still exists
---@private
---@param npcId npcId
---@param animId animationId
---@return boolean
function PrayerFlicker:_animationExists(npcId, animId)
    local npcs = API.GetAllObjArray1({ npcId }, 60, { 1 })
    for _, npc in ipairs(npcs) do
        if npc.Id and npc.Anim == animId then return true end
    end
    return false
end

---checks if the conditional threat still exists
---@private
---@param condFn fun(): boolean
---@return boolean
function PrayerFlicker:_conditionalThreatExists(condFn)
    return condFn()
end

--#endregion

--#region threat scans
---checks for projectile threats and adds them to self.state.pendingActions
---@private
---@param currentTick gameTick
function PrayerFlicker:_scanProjectiles(currentTick)
    for _, proj in ipairs(self.config.projectiles) do
        if not (proj.bypassCondition and proj.bypassCondition()) then
            if self:_projectileExists(proj.id) then
                table.insert(self.state.pendingActions, {
                    type = "projectile",
                    projId = proj.id,
                    prayer = proj.prayer,
                    priority = proj.priority or 0,
                    activateTick = currentTick + (proj.activationDelay or 0),
                    expireTick = currentTick + (proj.activationDelay or 0) + (proj.duration or 1)
                })
            end
        end
    end
end

---checks for npcs and animations and adds them to self.state.pendingActions
---@private
---@param currentTick gameTick
function PrayerFlicker:_scanAnimations(currentTick)
    for _, npc in ipairs(self.config.npcs) do
        local npcs = API.GetAllObjArray1({ npc.id }, 60, { 1 })
        for _, npcObj in ipairs(npcs) do
            if npcObj.Id then
                for _, anim in ipairs(npc.animations) do
                    if not (anim.bypassCondition and anim.bypassCondition()) then
                        if npcObj.Anim == anim.animId then
                            table.insert(self.state.pendingActions, {
                                type = "animation",
                                npcId = npc.id,
                                animId = anim.animId,
                                prayer = anim.prayer,
                                priority = anim.priority or 0,
                                activateTick = currentTick + (anim.activationDelay or 0),
                                expireTick = currentTick + (anim.activationDelay or 0) + (anim.duration or 1)
                            })
                        end
                    end
                end
            end
        end
    end
end

---checks for conditional threats and adds them to self.state.pendingActions
---@private
---@param currentTick gameTick
function PrayerFlicker:_scanConditionals(currentTick)
    for _, cond in ipairs(self.config.conditionals) do
        if not(cond.bypassCondition and cond.bypassCondition()) then
            if cond.condition() then
                table.insert(self.state.pendingActions, {
                    type = "conditional",
                    condition = cond.condition,
                    prayer = cond.prayer,
                    priority = cond.priority,
                    activateTick = currentTick,
                    expireTick = currentTick + cond.duration
                })
            end
        end
    end
end

--#endregion

---cleans up self.state.pendingActions, keeping only active threats
---@private
---@param currentTick gameTick
function PrayerFlicker:_cleanupPendingActions(currentTick)
    for i = #self.state.pendingActions, 1, -1 do
        local action = self.state.pendingActions[i]

        -- only remove if expired
        if action.expireTick <= currentTick then
            table.remove(self.state.pendingActions, i)

            -- remove if threat no longer exists and not active
        elseif action.activateTick > currentTick then
            if action.type == "projectile" and not self:_projectileExists(action.projId) then
                table.remove(self.state.pendingActions, i)
            elseif action.type == "animation" and not self:_animationExists(action.npcId, action.animId) then
                table.remove(self.state.pendingActions, i)
            elseif action.type == "condition" and not self:_conditionalThreatExists(action.condition) then
                table.remove(self.state.pendingActions, i)
            end
        end
    end
end

---determines the prayer to use based on threat priorities
---@private
---@param currentTick gameTick
---@return Prayer
function PrayerFlicker:_determineActivePrayer(currentTick)
    -- sort threats by priority (highest first)
    table.sort(self.state.pendingActions, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)

    for _, action in ipairs(self.state.pendingActions) do
        if action.activateTick <= currentTick and action.expireTick > currentTick then
            return action.prayer
        end
    end

    return self.config.defaultPrayer
end

---@private
---@param prayer Prayer
---@return boolean
function PrayerFlicker:_switchPrayer(prayer)
    if not prayer then return false end
    local currentPrayer = self:_getCurrentPrayer()

    -- check if prayer in use
    if (self.state.activePrayer.buffId == prayer.buffId and self.state.lastPrayerTick + 4 > API.Get_tick()) or (currentPrayer.buffId == prayer.buffId) then
        return false
    end

    -- flick prayer
    local success = API.DoAction_Ability(
        prayer.name,
        1,
        API.OFF_ACT_GeneralInterface_route,
        true
    )

    if success then
        self.state.lastPrayerTick = API.Get_tick()
        self.state.activePrayer = prayer
    end

    return success
end

---disables active prayer or selected prayer
---@param prayer? Prayer optional if you want to turn off a specific prayer
---@return boolean
function PrayerFlicker:deactivatePrayer(prayer)
    local currentTick = API.Get_tick()
    prayer = prayer or self:_getCurrentPrayer()
    if not prayer.name or ((currentTick - self.state.lastPrayerTick < 1) and not self.state.activePrayer.name) then return false end

    local success = API.DoAction_Ability(
        prayer.name,
        1,
        API.OFF_ACT_GeneralInterface_route,
        true
    )

    if success then
        self.state.lastPrayerTick = API.Get_tick()
        ---@diagnostic disable-next-line
        self.state.activePrayer = {}
    end

    return success
end

---updates PrayerFlicker instance
---@return boolean
function PrayerFlicker:update()
    local currentTick = API.Get_tick()
    local requiredPrayer = self:_determineActivePrayer(currentTick)

    if self.config.projectiles and #self.config.projectiles > 0 then
        self:_scanProjectiles(currentTick)
    end
    if self.config.npcs and #self.config.npcs > 0 then
        self:_scanAnimations(currentTick)
    end
    if self.config.conditionals and #self.config.conditionals > 0 then
        self:_scanConditionals(currentTick)
    end
    self:_cleanupPendingActions(currentTick)

    return self:_switchPrayer(requiredPrayer)
end

---can use with API.DrawTable(PrayerFlicker:tracking()) to check metrics
---@return table
function PrayerFlicker:tracking()
    local metrics = {
        { "Prayer Flicker:", "" },
        { "-- Active",       self:_getCurrentPrayer() and self:_getCurrentPrayer().name or "None" },
        { "-- Last Used",    self.state.activePrayer and self.state.activePrayer.name or "None" },
        { "-- Required",     self:_determineActivePrayer(API.Get_tick()).name },
    }
    return metrics
end

return PrayerFlicker

--[[
Changelog:
    - v1.0.4:
        - Checks for prayers on ability bars when initializing
            - Terminates script if prayers are not found & outputs missing prayers
        - Added prayerFlicker.PRAYERS as enum for users to choose prayers from
            - Currently only has data for curses
        - Improved fail safes

    - v1.0.3:
        - Added bypass condition to NPCs and Conditional threats
        - Fixed bypass condition luaCATS annotation

    - v1.0.2 :
        - Fixes and improvements to conditional threat detection

    - v1.0.1:
        - Added PrayerFlicker:deactivatePrayer()
        - update() and & _switchPrayer() now return true when prayer is switched

    - v1.0.0:
        -Initial release
]]
