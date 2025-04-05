---@module 'rotation_manager'
---@version 0.0.1

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
---@field action function? custom action function
---@field style string? combat style to improvise in
---@field condition nil | fun():boolean whether to skip or use replacement instead of main step
---@field replacementLabel string?
---@field replacementAction function?
---@field replacementWait number?
---@field spendAdren boolean? spend adrenaline when improvising


---@class RotationManager
---@field name string
---@field rotation Step[]
---@field index integer
---@field timer Timer
---@field trailing boolean
function RotationManager.new(config)
    local self = setmetatable({}, RotationManager)
    self.improvising = false
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
    local success = false
    -- check it exists
    if API.GetABs_name(name, false) then -- check if ability exists
        if API.DoAction_Ability(name, 1, API.OFF_ACT_GeneralInterface_route, true) then
            success = true
        end
    else
        self.debugLog(string.format("Ability (%s) does not exist- Moving on.", name))
        return true
    end
    return success
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
    return API.DoAction_Inventory3(itemName, 0, 1, API.OFF_ACT_GeneralInterface_route)
end

function RotationManager:execute()
    -- do notion if we're out of steps
    if self.index > #self.rotation then
        self.debugLog("No more steps to "..self.name)
        return false
    end

    -- can execute
    if self.timer:canTrigger() then
        -- get step
        local step = self.rotation[self.index]
        self.debugLog("--# " .. self.index .. " -------------------------------------------")
        self.debugLog("# " .. step.label)
        self.debugLog("Tick: " .. API.Get_tick())
        self.debugLog("Time: " .. math.floor(os.time() * 1000))

        -- configure step defaults:
        step.type = step.type or "Ability"  -- type
        if step.useTicks == nil then        -- useTicks
            step.useTicks = true
        end
        step.wait = step.wait or (step.useTicks and 3 or 1800)
        self.debugLog("Wait: " .. step.wait)
        self.debugLog("UseTicks?: " .. ((step.useTicks and "Yes") or "No"))
        self.debugLog(" ")

        -- check for condition and if they are met
        if (step.condition and step.condition()) or not step.condition then
            if step.condition and step.condition() then
                self.debugLog("+ Step condition found and met")
            else
                self.debugLog("= No step condition found")
            end
            self.debugLog(" ")
            -- handle step types
            if step.type == "Ability" then
                self.debugLog("= Step type: Ability")
                if self:_useAbility(step.label) then
                    self.debugLog("+ Ability cast successful")
                else
                    self.debugLog("- Ability cast unsuccessful")
                end
            elseif step.type == "Inventory" then
                self.debugLog("= Step type: Inventory")
                if self:_useInventory(step.label) then
                    self.debugLog("+ Use from inventory successful")
                else
                    self.debugLog("- Use from inventory unsuccessful")
                end
            elseif step.type == "Custom" and step.action then
                self.debugLog("= Step type: Custom")
                if step.action() then
                    self.debugLog("+ Custom action executed successfully")
                else
                    self.debugLog("- Custom action was not successful")
                end
            elseif step.type == "Improvise" and step.style == "Necromancy" then
                self.debugLog("= Step type: Improvise")
                local ability = self:_improvise(step.spendAdren)
                self.debugLog("= Designated improvise ability: "..ability)
                if self:_useAbility(ability) then
                    self.debugLog("+ Ability cast was successful")
                else
                    self.debugLog("- Ability cast was unsuccessful")
                end
            end
            self.debugLog(" ")
            -- execute timer
            self.timer:reset()
            self.timer.cooldown = step.wait
            self.timer.useTicks = step.useTicks
            self.timer:execute()
            self.index = self.index + (step.type ~= "Improvise" and 1 or 0)
            self.debugLog("= Timer Data: ")
            self.debugLog("=== Last Triggered: "..self.timer.lastTriggered)
            self.debugLog("=== Last Time     : "..self.timer.lastTime)
            self.debugLog("=== Cooldown      : "..self.timer.cooldown)
            self.debugLog(" ")
            return true
        else
            self.debugLog("- Step condition found and NOT met")
            -- use replacements
            if step.replacementAction then
                if step.replacementLabel then
                    step.label = step.replacementLabel
                end
                if step.replacementAction() then
                    self.debugLog("+ Replacement action executed successfully")
                else
                    self.debugLog("- Replacement action was not executed successfully")
                end
                self.debugLog(" ")

                -- execute timer
                self.timer:reset()
                self.timer.cooldown = step.replacementWait or step.wait
                self.timer.useTicks = step.useTicks
                self.timer:execute()
                self.index = self.index + 1
                self.debugLog("= Timer Data: ")
                self.debugLog("=== Last Triggered: "..self.timer.lastTriggered)
                self.debugLog("=== Last Time     : "..self.timer.lastTime)
                self.debugLog("=== Cooldown      : "..self.timer.cooldown)
                self.debugLog(" ")
                return true
            elseif (step.type == "Ability") and step.replacementLabel then
                self.debugLog("= Step type: Ability")
                if self:_useAbility(step.replacementLabel) then
                    self.debugLog("+ Ability cast successful")
                else
                    self.debugLog("- Ability cast unsuccessful")
                end
                self.debugLog(" ")

                -- execute timer
                self.timer:reset()
                self.timer.cooldown = step.replacementWait or step.wait
                self.timer.useTicks = step.useTicks
                self.timer:execute()
                self.index = self.index + 1
                self.debugLog("= Timer Data: ")
                self.debugLog("=== Last Triggered: "..self.timer.lastTriggered)
                self.debugLog("=== Last Time     : "..self.timer.lastTime)
                self.debugLog("=== Cooldown      : "..self.timer.cooldown)
                self.debugLog(" ")
                return true
            else
                self.debugLog("= Skipping step")
                self.timer:reset()
                self.timer.cooldown = 0
                self.index = self.index + 1
                return false
            end
        end
    end

    return false
end

function RotationManager:_improvise(spendAdren)
    local targetHealth, adren = API.ReadTargetInfo(true).Hitpoints, tonumber(API.GetAdrenalineFromInterface())
    local soulStacks = self:getBuff(30123).found and self:getBuff(30123).remaining or 0
    local necrosisStacks = self:getBuff(30101).found and self:getBuff(30101).remaining or 0
    local possibleFingers = math.floor((adren + necrosisStacks*10) / 60)
    local ability = "Basic<nbsp>Attack"

    self.debugLog("[IMPROV]: = Target Health:    "..targetHealth)
    self.debugLog("[IMPROV]: = Soul stacks:      "..soulStacks)
    self.debugLog("[IMPROV]: = Necrosis stacks:  "..necrosisStacks)
    self.debugLog("[IMPROV]: = Possible fingers: "..possibleFingers)

    local canExecute = false
    if (targetHealth - 30000) <= ((soulStacks*7000) + possibleFingers*15000) then canExecute = true end
    self.debugLog("[IMPROV]: ".. (canExecute and "+ Target is within execute range" or "- Target is not within execute range"))

    -- execution checks
    -- volley into finger
    if (soulStacks >= 3) and (possibleFingers >= 1) and (targetHealth - 30000 <= (soulStacks * 8000) + 15000) then
        ability = "Volley of Souls"
    -- fingers of death
    else
        if targetHealth - 30000 <= possibleFingers * 15000 then
            ability = "Finger of Death"
        end
    end

    if not spendAdren and (ability == "Basic<nbsp>Attack")  and (adren < 64) then
        if (soulStacks < 5) and (API.GetABs_name1("Soul Sap").cooldown_timer <= 1) then
            ability = "Soul Sap"
        elseif (necrosisStacks < 12) and (API.GetABs_name1("Touch of Death").cooldown_timer <= 1) then
            ability = "Touch of Death"
        else
            goto continue
        end
    end

    -- If no execute, use basic rotation
    if ability == "Basic<nbsp>Attack" then
        if soulStacks == 5 then
            ability = "Volley of Souls"
        elseif necrosisStacks >= 6 then
            ability = "Finger of Death"
        elseif API.GetABs_name1("Command Putrid Zombie").enabled then
            ability = "Command Putrid Zombie"
        elseif API.GetABs_name1("Command Skeleton Warrior").enabled and API.GetABs_name1("Command Skeleton Warrior").cooldown_timer <= 1 then
            ability = "Command Skeleton Warrior"
        elseif API.GetABs_name1("Touch of Death").cooldown_timer <= 1 then
            ability = "Touch of Death"
        elseif API.GetABs_name1("Soul Sap").cooldown_timer <= 1 then
            ability = "Soul Sap"
        end
    end

    ::continue::
    return ability
end

function RotationManager:reset()
    self.index = 1
    self.improvising = false
    self.timer:reset()
end

return RotationManager
