---@module 'rotation_manager'
---@version 1.0.0

local RotationManager = {}
RotationManager.__index = RotationManager

local API = require("api")
local Timer = require("core.timer")

local debug = false

---@class Step
---@field label string step name or action identifier
---@field type string? step type ("Ability", "Inventory", "Custom", "Improvise")
---@field wait number? delay after execution (default: 3 ticks)
---@field useTicks boolean? use game ticks for wait (default: true)
---@field action fun(self: RotationManager)? custom action function
---@field style string? combat style to improvise in
---@field spendAdren boolean? spend adrenaline when improvising


---@class RotationManager
---@field name string
---@field rotation Step[]
---@field index integer
---@field timer Timer
---@field trailing boolean
function RotationManager.new(config)
    local self = setmetatable({}, RotationManager)
    self.trailing = false
    self.name = config.name or "Unnamed Rotation"
    self.rotation = config.rotation or {}
    self.index = 1
    self.timer = Timer.new({
        name = (config.name or "Rotation").." Timer",
        cooldown = 0,
        useTicks = true,
        condition = function() return true end,
        action = function() return true end
    })
    return self
end

function RotationManager.debugLog(message)
    if debug then
        print("[ROTATION]: "..message)
    end
end

function RotationManager:_formatTime()
    local seconds = os.time()
    local ms = math.floor((os.clock() % 1) * 1000)

    local hour = math.floor(seconds / 3600) % 24
    local minute = math.floor(seconds / 60) % 60
    local second = seconds % 60

    return string.format("%02d:%02d:%02d.%03d", hour, minute, second, ms)
end

function RotationManager:_useAbility(name)
    self.debugLog("Using ability: "..name)
    self.debugLog("Game tick: "..API.Get_tick())
    return API.DoAction_Ability(name, 1, API.OFF_ACT_GeneralInterface_route, true)
end

---checks if the player has a specific buff
---@param buffId number
---@return {found: boolean, remaining: number}
function RotationManager:getBuff(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    return {found = buff.found, remaining = (buff.found and API.Bbar_ConvToSeconds(buff)) or 0}
end

---checks if the player has a specific debuff
---@param debuffId number
---@return Bbar
function RotationManager:getDebuff(debuffId)
    local debuff = API.DeBuffbar_GetIDstatus(debuffId, false)
    return {found = debuff.found, remaining = (debuff.found and API.Bbar_ConvToSeconds(debuff)) or 0}
end

function RotationManager:_useInventory(itemName)
    self.debugLog("Using item: "..itemName)
    self.debugLog("Game tick: "..API.Get_tick())
    return API.DoAction_Inventory3(itemName, 0, 1, API.OFF_ACT_GeneralInterface_route)
end

function RotationManager:execute()
    -- do notion if we're out of steps
    if self.index > #self.rotation then
        self.debugLog("No more steps to "..self.name)
        return false
    end

    -- get previous step
    local previousStep = self.rotation[self.index-1] or {label = "", wait = (self.trailing and self.timer.wait) or 0, useTicks = (self.trailing and self.timer.useTicks) or true, index = 0}
    previousStep.wait = previousStep.wait or (previousStep.useTicks and 3 or 1800)

    -- get current step information
    local step = self.rotation[self.index]
    local stepType = step.type or "Ability"

    -- handle step types
    if stepType == "Ability" then
        self.timer.action = function() return self:_useAbility(step.label) end
    elseif stepType == "Inventory" then
        self.timer.action = function() return self:_useInventory(step.label) end
    elseif stepType == "Custom" and step.action then
        self.timer.action = function() return step.action(self) end
    elseif stepType == "Improvise" and step.style == "Necromancy" then
        self.timer.action = function() 
            local ability = self:_improvise(step.spendAdren)
            return self:_useAbility(ability)
        end
    end

    if stepType ~= "Improvise" then
        self.timer.cooldown = previousStep.wait or (previousStep.useTicks and 3 or 1800)
        self.timer.useTicks = previousStep.useTicks
    else
        self.timer.cooldown = 3
        self.timer.useTicks = true
    end

    if self.timer:canTrigger() then self.debugLog("Attempting to trigger: "..step.label) end

    --self.debugLog(self.name.." | ["..self.index.."] "..step.label.."-- Wait time: "..previousStep.wait or (previousStep.useTicks and 3 or 1800).." "..((previousStep.useTicks==false and "ms") or "ticks"))
    if self.timer:execute() then
        self.debugLog(step.label.." was successful")
        -- update timer values
        local currentTick = API.Get_tick()
        local currentTime = RotationManager:_formatTime()
        self.debugLog(self.name.." | Current tick: "..currentTick.." | Real time: "..currentTime)
        self.index = self.index + (step.type ~= "Improvise" and 1 or 0)
    end

    return false
end

function RotationManager:_improvise(spendAdren)
    local targetHealth, adren = API.ReadTargetInfo(true).Hitpoints, API.GetAdrenalineFromInterface()
    local soulStacks          = self:getBuff(30123).found and self:getBuff(30123).remaining or 0
    local necrosisStacks      = self:getBuff(30101).found and self:getBuff(30101).remaining or 0
    local ability    = "Basic<nbsp>Attack"

    -- with bis gear, equilib aura, elder ovl and t99 prayer
    -- finger can do 9-10k minimum damage
    -- volley can do 4-5k per soul minimum

    if soulStacks >= 3 and targetHealth <= 45000 then
        ability = "Volley of Souls"
    elseif targetHealth <= 40000 and (necrosisStacks*10 + adren >= 60) then
        ability = "Finger of Death"
    elseif not spendAdren and adren < 70 then
        if API.GetABs_name1("Touch of Death").cooldown_timer <= 1 then
            ability = "Touch of Death"
        elseif API.GetABs_name1("Soul Sap").cooldown_timer <= 1 then
            ability = "Soul Sap"
        else
            goto continue
        end
    elseif soulStacks == 5 then -- Residual Souls
        ability = "Volley of Souls"
    elseif necrosisStacks >= 10 then
        ability = "Finger of Death"
    elseif API.GetABs_name1("Command Putrid Zombie").enabled then
        ability = "Command Putrid Zombie"
    elseif API.GetABs_name1("Command Skeleton Warrior").enabled and API.GetABs_name1("Command Skeleton Warrior").cooldown_timer <= 1 then
        ability = "Command Skeleton Warrior"
    elseif necrosisStacks >= 6 then
        ability = "Finger of Death"
    elseif API.GetABs_name1("Touch of Death").cooldown_timer <= 1 then
        ability = "Touch of Death"
    elseif API.GetABs_name1("Soul Sap").cooldown_timer <= 1 then
        ability = "Soul Sap"
    end

    ::continue::
    self.debugLog("Using ability: "..ability)
    return ability
end

function RotationManager:reset()
    self.index = 1
    self.timer:reset()
end

return RotationManager