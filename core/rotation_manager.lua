--- @module "Sonson's Rotation Manager"
--- @version 0.0.1
------------------------------------------
-- # IMPORTS
------------------------------------------
local API = require("api")
local Player = require("core.player")
local Utils = require("core.helper")

------------------------------------------
-- # TYPE DEFINITIONS
------------------------------------------

--- @class Step
--- @field label                     string                      Unique identifier for this step, used in logging and debugging.
--- @field type?                     StepType                    The category of the step which determines how it is processed (e.g., "Ability", "Inventory", "Equip", "Target cycle", "Improvise", or "Custom").
--- @field wait?                     number                      The post-execution delay. When useTicks is true, this is in game ticks (default is 3 ticks); otherwise in milliseconds (default is 1800 ms).
--- @field useTicks?                 boolean                     Determines if the wait value uses game ticks (true) or milliseconds (false). Default is true.
--- @field action?                   function                    The primary execution logic for the step. Required for non-Improvise steps that do not use default utility functions.
--- @field style?                    CombatStyle                 For Improvise steps, indicates the combat style to use (e.g., "Necromancy", "Melee", "Range", or "Magic").
--- @field condition?                fun():boolean               A predicate function that must return true for the primary action to execute. If absent, the action is executed unconditionally.
--- @field replacementLabel?         string                      Alternate display name for the action when the condition check fails.
--- @field replacementAction?        function                    Alternate logic to execute when the condition function exists but evaluates to false.
--- @field replacementWait?          number                      A custom delay to use after performing the replacement action.
--- @field spend?                    boolean                     For Improvise steps, indicates whether adrenaline and other resources should be consumed. Defaults to false.
--- @field targetCycleKey?           number                      The hexadecimal key code used for target cycling actions (e.g., 0x09).
--- @field continueAfterImprovise?   boolean                     For Improvise steps, if true, increment index to continue rotation instead of looping on this step. Default is false.

--- @alias StepType
--- | "Ability"
--- | "Inventory"
--- | "Equip"
--- | "Target cycle"
--- | "Improvise"
--- | "Custom"

--- @alias CombatStyle
--- | "Necromancy"
--- | "Melee"
--- | "Range"
--- | "Magic"

--- @class RotationManager.RecentStep
--- @field label                 string                      The label of the executed step.
--- @field type                  StepType                    The type of the executed step.
--- @field index                 integer                     The rotation index at execution time.
--- @field timestamp             number                      Timestamp (ms) when the step was executed.
--- @field tick                  integer                     Game tick when the step was executed.
--- @field conditionMet          boolean?                    Whether the condition was met (nil if no condition).
--- @field actionSuccess         boolean                     Whether the action executed successfully.
--- @field wait                  number                      The wait duration used after this step.
--- @field useTicks              boolean                     Whether the wait used ticks (true) or milliseconds (false).

--- @class RotationManager
--- @field rotation              Step[]                      The list of steps that make up a rotation sequence.
--- @field rotationAddress       string                      A unique string representation of the current rotation (used to detect changes).
--- @field index                 integer                     The current position in the rotation sequence.
--- @field targetId?             number                      The identifier of the target, if applicable.
--- @field useTicks              boolean                     Indicates whether the step wait timings use game ticks.
--- @field cooldown              number                      The current wait duration before the next step can be executed.
--- @field lastTick              integer                     The game tick when the last step timer was started.
--- @field lastTime              number                      The precise time (in milliseconds) when the last step timer was started.
--- @field recentSteps           RotationManager.RecentStep[] Last 15 executed steps, newest first.
--- @field load                  fun(self, rotation: Step[]) Loads a new rotation and resets the index if the rotation is different.
--- @field execute               fun(self): boolean          Processes and executes the current step in the rotation; returns true if a step was executed.
--- @field getRecentSteps        fun(self, limit?: integer): RotationManager.RecentStep[] Returns recent steps (optionally limited).

------------------------------------------
-- # ROTATION STEP CONFIGURATION
------------------------------------------

--[[

            ██████╗  ██████╗ ████████╗        ███████╗████████╗███████╗██████╗ ███████╗
            ██╔══██╗██╔═══██╗╚══██╔══╝        ██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝
            ██████╔╝██║   ██║   ██║           ███████╗   ██║   █████╗  ██████╔╝███████╗
            ██╔══██╗██║   ██║   ██║           ╚════██║   ██║   ██╔══╝  ██╔═══╝ ╚════██║
            ██║  ██║╚██████╔╝   ██║██╗        ███████║   ██║   ███████╗██║     ███████║
            ╚═╝  ╚═╝ ╚═════╝    ╚═╝╚═╝        ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚══════╝

    E S S E N T I A L   S T E P   P A R A M E T E R S :
    --------------------------------------------------------------------------------------------
    • label             (string)  Unique identifier for the step (required)
    • type              (string)  Step type - "Ability", "Inventory", "Equip", "Target cycle", "Improvise", or "Custom"
    • action            (function) Primary execution logic (required for non-Improvise steps that do not use default utility functions)
    • targetCycleKey    (number)  Hexadecimal key code for target cycling actions (e.g., 0x09)

    S T E P   T I M I N G   P A R A M E T E R S :
    --------------------------------------------------------------------------------------------
    • wait              (number)  Delay after execution (default: 3 ticks if useTicks == true; otherwise 1800 ms)
    • useTicks          (boolean) Use game ticks instead of milliseconds for wait (default: true)
    • replacementWait   (number)  Custom wait period when a replacement action is used

    C O N D I T I O N A L   E X E C U T I O N :
    --------------------------------------------------------------------------------------------
    • condition         (function) Predicate that must return true for the primary action to execute
    • replacementLabel  (string)  Alternate display name for the action when the condition check fails
    • replacementAction (function) Alternate logic to execute when condition exists but returns false

    I M P R O V I S E - S P E C I F I C :
    --------------------------------------------------------------------------------------------
    • style             (string)  Combat style - "Necromancy", "Melee", "Range", or "Magic"
    • spend             (boolean) Indicates whether adrenaline and other resources should be consumed (default: false)

    E X E C U T I O N   R U L E S :
    --------------------------------------------------------------------------------------------
    1. If a condition exists and returns false, then:
         - Execute replacementAction if provided, or
         - Use replacementLabel for Ability-type steps, or
         - Skip the step entirely if neither is provided.
    2. All steps honor their wait period before proceeding to the next step.
    3. Steps are processed sequentially in their declared order unless skipped.
]]

------------------------------------------
-- # CONSTANT VARIABLES
------------------------------------------

local CONSTANTS = {
    BUFFS = {SOULS = 30123, NECROSIS = 30101, DEATH_SPARK = 30127},
    DEBUFFS = {DEATH_GRASP = 55524}
}

------------------------------------------
-- # INITIALIZATION
------------------------------------------

local RotationManager = {}
RotationManager.__index = RotationManager

--- Creates a new rotation manager instance
--- @param targetId? number The target NPC ID for improvise targeting
--- @param options? table Optional configuration: { debug: boolean, loop: boolean }
function RotationManager.new(targetId, options)
    local self = setmetatable({}, RotationManager)
    options = options or {}

    -- Configuration
    self.debug = options.debug or false
    self.loop = options.loop or false
    self.cacheConditions = options.cacheConditions or false

    -- TODO: Allow for dynamic target selection
    self.targetId = targetId or nil
    if targetId then Utils:log("Target ID Initialized: " .. targetId) end

    -- Rotation data
    self.rotation, self.rotationAddress = {}, ""
    self.index = 1

    -- Timer data (stores timing mode with cooldown to prevent conflicts)
    self.cooldown = 0
    self.cooldownUseTicks = true -- Timing mode for current cooldown
    self.lastTick = 0
    self.lastTime = 0

    -- Condition cache (for performance optimization)
    self.conditionCache = {}
    self.lastCacheClearTick = 0

    -- Recent step execution tracking (for debugging)
    self.recentSteps = {}

    return self
end

function RotationManager:_useInventory(itemName)
    return API.DoAction_Inventory3(itemName, 0, 1,
                                   API.OFF_ACT_GeneralInterface_route)
end

--- Validates a single step and returns error message if invalid
--- @param step Step
--- @param index number
--- @return boolean, string?
function RotationManager:_validateStep(step, index)
    -- Check for required label
    if not step.label or type(step.label) ~= "string" or step.label == "" then
        return false, string.format("Step %d: Missing or invalid 'label' field",
                                    index)
    end

    -- Validate type if provided
    local validTypes = {
        ["Ability"] = true,
        ["Inventory"] = true,
        ["Equip"] = true,
        ["Target cycle"] = true,
        ["Improvise"] = true,
        ["Custom"] = true
    }
    if step.type and not validTypes[step.type] then
        return false, string.format("Step %d ('%s'): Invalid type '%s'", index,
                                    step.label, step.type)
    end

    -- Validate Custom type has action
    if step.type == "Custom" and not step.action then
        return false,
               string.format(
                   "Step %d ('%s'): Custom type requires 'action' function",
                   index, step.label)
    end

    -- Validate Improvise has style
    if step.type == "Improvise" and not step.style then
        return false,
               string.format(
                   "Step %d ('%s'): Improvise type requires 'style' field",
                   index, step.label)
    end

    -- Validate Target cycle has targetCycleKey
    if step.type == "Target cycle" and not step.targetCycleKey then
        return false, string.format(
                   "Step %d ('%s'): Target cycle type requires 'targetCycleKey' field",
                   index, step.label)
    end

    -- Validate numeric fields if present
    if step.wait and type(step.wait) ~= "number" then
        return false, string.format("Step %d ('%s'): 'wait' must be a number",
                                    index, step.label)
    end
    if step.replacementWait and type(step.replacementWait) ~= "number" then
        return false,
               string.format(
                   "Step %d ('%s'): 'replacementWait' must be a number", index,
                   step.label)
    end

    -- Validate boolean fields if present
    if step.useTicks ~= nil and type(step.useTicks) ~= "boolean" then
        return false, string.format(
                   "Step %d ('%s'): 'useTicks' must be a boolean", index,
                   step.label)
    end
    if step.spend ~= nil and type(step.spend) ~= "boolean" then
        return false, string.format("Step %d ('%s'): 'spend' must be a boolean",
                                    index, step.label)
    end

    -- Validate function fields if present
    if step.action and type(step.action) ~= "function" then
        return false, string.format(
                   "Step %d ('%s'): 'action' must be a function", index,
                   step.label)
    end
    if step.condition and type(step.condition) ~= "function" then
        return false,
               string.format("Step %d ('%s'): 'condition' must be a function",
                             index, step.label)
    end
    if step.replacementAction and type(step.replacementAction) ~= "function" then
        return false,
               string.format(
                   "Step %d ('%s'): 'replacementAction' must be a function",
                   index, step.label)
    end

    return true
end

--- Loads a new rotation and resets the index
--- @param rotation Step[]
function RotationManager:load(rotation)
    -- Validate rotation is a table
    if type(rotation) ~= "table" then
        Utils:log("ERROR: Rotation must be a table", "error")
        return
    end

    -- Validate rotation is not empty
    if #rotation == 0 then
        Utils:log("WARNING: Rotation is empty", "warn")
        return
    end

    -- Validate all steps
    for i, step in ipairs(rotation) do
        local valid, errorMsg = self:_validateStep(step, i)
        if not valid then
            Utils:log("ERROR: " .. errorMsg, "error")
            Utils:log(
                "Rotation load failed - fix the above errors and try again",
                "error")
            return
        end
    end

    -- Check if rotation is different (failsafe: sorry Dead)
    local rotationAddress = tostring(rotation)
    if self.rotationAddress ~= rotationAddress then
        Utils:log("Rotation loaded successfully (" .. #rotation .. " steps)")
        if self.debug then
            Utils:log("Rotation address: " .. rotationAddress)
        end
        self.index = 1
        self.rotation = rotation
        self.rotationAddress = rotationAddress
    end
end

--- Checks if the wait duration period has passed
--- Uses the timing mode that was active when the timer was started
function RotationManager:_canTrigger()
    if self.cooldownUseTicks then
        return (API.Get_tick() - self.lastTick) >= self.cooldown -- Using game ticks
    else
        return (os.clock() * 1000 - self.lastTime) >= self.cooldown -- Using milliseconds
    end
end

--- Evaluates a condition function with optional caching
--- @param condition function The condition function to evaluate
--- @return boolean, boolean success (pcall result), conditionResult (true/false)
function RotationManager:_evaluateCondition(condition)
    if not self.cacheConditions then
        -- No caching, evaluate directly
        return pcall(condition)
    end

    -- Clear cache every game tick to prevent stale results
    local currentTick = API.Get_tick()
    if currentTick ~= self.lastCacheClearTick then
        self.conditionCache = {}
        self.lastCacheClearTick = currentTick
    end

    -- Use function address as cache key
    local cacheKey = tostring(condition)

    -- Check cache
    if self.conditionCache[cacheKey] ~= nil then
        if self.debug then Utils:log("[CACHE] Condition cache hit") end
        return true, self.conditionCache[cacheKey]
    end

    -- Evaluate and cache
    local success, result = pcall(condition)
    if success then self.conditionCache[cacheKey] = result end

    return success, result
end

--- Starts the internal timer
--- @param step Step: The current step being executed
--- @param useReplacementWait? boolean: Whether to use the replacement wait time
function RotationManager:_startTimer(step, useReplacementWait)
    -- Determine if we should increment index
    local shouldIncrement = true
    if step.type == "Improvise" then
        -- Check if step has continueAfterImprovise flag, otherwise use default (don't increment)
        shouldIncrement = step.continueAfterImprovise or false
    end

    self.index = self.index + (shouldIncrement and 1 or 0)
    self.cooldown = useReplacementWait and step.replacementWait or step.wait
    self.cooldownUseTicks = step.useTicks -- Store timing mode with cooldown
    self.lastTick = API.Get_tick()
    self.lastTime = os.clock() * 1000

    -- Timer debugging (only if debug is enabled)
    if self.debug then
        Utils:log("= Timer Information: ")
        Utils:log("=== Last Tick: " .. self.lastTick)
        Utils:log("=== Last Time: " .. self.lastTime)
        Utils:log("=== Cooldown : " .. self.cooldown)
        Utils:log("=== Use Ticks: " .. tostring(self.cooldownUseTicks))
        Utils:log("=== Increment: " .. tostring(shouldIncrement))
        Utils:log("")
    end
end

--- Records step execution for debugging purposes
--- @param step Step The step that was executed
--- @param stepIndex integer The rotation index at execution time
--- @param conditionMet boolean? Whether the condition was met (nil if no condition)
--- @param actionSuccess boolean Whether the action executed successfully
function RotationManager:_recordStepExecution(step, stepIndex, conditionMet,
                                              actionSuccess)
    -- Track in recent steps (newest first, max 15)
    table.insert(self.recentSteps, 1, {
        label = step.label,
        type = step.type,
        index = stepIndex,
        timestamp = os.clock() * 1000,
        tick = API.Get_tick(),
        conditionMet = conditionMet,
        actionSuccess = actionSuccess,
        wait = step.wait,
        useTicks = step.useTicks
    })

    -- Remove oldest if exceeds 15
    if #self.recentSteps > 15 then table.remove(self.recentSteps) end
end

function RotationManager:execute()
    -- Check if we're out of steps
    if self.index > #self.rotation then
        if self.loop then
            -- Loop back to beginning
            if self.debug then
                Utils:log("Rotation complete, looping back to start")
            end
            self:reset()
        else
            if self.debug then Utils:log("No more steps") end
            return false
        end
    end

    -- Check if the wait time has passed
    if self:_canTrigger() then
        -- Get step data
        local step = self.rotation[self.index]

        -- Step data debugging (only if debug is enabled)
        if self.debug then
            Utils:log("--# " .. self.index ..
                          " -------------------------------------------")
            Utils:log("# " .. step.label)
            Utils:log("Tick: " .. API.Get_tick())
            Utils:log("Time: " .. math.floor(os.clock() * 1000))
        end

        -- Configure step defaults
        step.type = step.type or "Ability" -- type
        if step.useTicks == nil then -- useTicks
            step.useTicks = true
        end
        step.wait = step.wait or (step.useTicks and 3 or 1800)

        -- Cooldown debugging (only if debug is enabled)
        if self.debug then
            Utils:log("Wait: " .. step.wait)
            Utils:log("UseTicks?: " .. ((step.useTicks and "Yes") or "No"))
            Utils:log("")
        end

        -- Check for conditions and whether or not they are met
        local conditionMet = false
        if step.condition then
            local success, result = self:_evaluateCondition(step.condition)
            if not success then
                Utils:log("ERROR: Condition function failed for step '" ..
                              step.label .. "': " .. tostring(result), "error")
                -- Skip to next step on error
                self.cooldown = 0
                self.index = self.index + 1
                return false
            end
            conditionMet = result
        else
            conditionMet = true -- No condition = always execute
        end

        if conditionMet then
            if self.debug then
                if step.condition then
                    Utils:log("+ Step condition found and met")
                else
                    Utils:log("= No step condition found")
                end
                Utils:log("")
            end
            -- Handle step types (wrapped in pcall for safety)
            local executeSuccess = true
            local executeResult = false

            if step.type == "Ability" then
                if self.debug then
                    Utils:log("= Step type: Ability")
                end
                local success, result = pcall(Utils.useAbility, Utils,
                                              step.label)
                if not success then
                    Utils:log("ERROR: Ability execution failed: " ..
                                  tostring(result), "error")
                    executeSuccess = false
                elseif result then
                    if self.debug then
                        Utils:log("+ Ability cast successful")
                    end
                    executeResult = true
                else
                    if self.debug then
                        Utils:log("- Ability cast unsuccessful")
                    end
                end
                if self.debug then Utils:log("") end
            elseif step.type == "Inventory" then
                if self.debug then
                    Utils:log("= Step type: Inventory")
                end
                local success, result = pcall(self._useInventory, self,
                                              step.label)
                if not success then
                    Utils:log("ERROR: Inventory action failed: " ..
                                  tostring(result), "error")
                    executeSuccess = false
                elseif result then
                    if self.debug then
                        Utils:log("+ Use from inventory successful")
                    end
                    executeResult = true
                else
                    if self.debug then
                        Utils:log("- Use from inventory unsuccessful")
                    end
                end
                if self.debug then Utils:log("") end
            elseif step.type == "Equip" then
                if self.debug then
                    Utils:log("= Step type: Equip")
                end
                local success, result = pcall(Inventory.Equip, Inventory,
                                              step.label)
                if not success then
                    Utils:log(
                        "ERROR: Equip action failed: " .. tostring(result),
                        "error")
                    executeSuccess = false
                elseif result then
                    if self.debug then
                        Utils:log("+ Equipping from inventory successful")
                    end
                    executeResult = true
                else
                    if self.debug then
                        Utils:log("- Equipping from inventory unsuccessful")
                    end
                end
                if self.debug then Utils:log("") end
            elseif step.type == "Custom" and step.action then
                if self.debug then
                    Utils:log("= Step type: Custom")
                end
                local success, result = pcall(step.action)
                if not success then
                    Utils:log("ERROR: Custom action failed: " ..
                                  tostring(result), "error")
                    executeSuccess = false
                elseif result then
                    if self.debug then
                        Utils:log("+ Custom action executed successfully")
                    end
                    executeResult = true
                else
                    if self.debug then
                        Utils:log("- Custom action was not successful")
                    end
                end
            elseif step.type == "Improvise" and step.style == "Necromancy" then
                if self.debug then
                    Utils:log("= Step type: Improvise")
                    Utils:log("")
                end
                local success, ability =
                    pcall(self._improvise, self, step.style, step.spend,
                          self.targetId)
                if not success then
                    Utils:log("ERROR: Improvise failed: " .. tostring(ability),
                              "error")
                    executeSuccess = false
                else
                    if self.debug then
                        Utils:log("= Designated improvise ability: " .. ability)
                    end
                    local abilSuccess, abilResult =
                        pcall(Utils.useAbility, Utils, ability)
                    if not abilSuccess then
                        Utils:log("ERROR: Improvised ability cast failed: " ..
                                      tostring(abilResult), "error")
                        executeSuccess = false
                    elseif abilResult then
                        if self.debug then
                            Utils:log("+ Ability cast was successful")
                        end
                        executeResult = true
                    else
                        if self.debug then
                            Utils:log("- Ability cast was unsuccessful")
                        end
                    end
                end
                if self.debug then Utils:log("") end
            elseif step.type == "Target cycle" then
                if self.debug then
                    Utils:log("= Step type: Target cycle")
                end
                local success, result = pcall(API.KeyboardPress2,
                                              step.targetCycleKey, 60, 0)
                if not success then
                    Utils:log(
                        "ERROR: Target cycle failed: " .. tostring(result),
                        "error")
                    executeSuccess = false
                else
                    if self.debug then
                        Utils:log("+ Target cycled")
                    end
                    executeResult = true
                end
                if self.debug then Utils:log("") end
            end

            -- Record step execution for debugging
            self:_recordStepExecution(step, self.index, conditionMet,
                                      executeResult)

            -- Start timer (even if action failed, to prevent getting stuck)
            self:_startTimer(step)
            return true
        else
            if self.debug then
                Utils:log("- Step condition found and NOT met")
            end
            -- Use replacements (wrapped in pcall for safety)
            if step.replacementAction then
                if step.replacementLabel then
                    step.label = step.replacementLabel
                end
                local success, result = pcall(step.replacementAction)
                if not success then
                    Utils:log("ERROR: Replacement action failed: " ..
                                  tostring(result), "error")
                    -- Continue to next step even on error
                    self:_recordStepExecution(step, self.index, false, false)
                    self:_startTimer(step, true)
                    return true
                elseif result then
                    if self.debug then
                        Utils:log("+ Replacement action executed successfully\n")
                    end
                else
                    if self.debug then
                        Utils:log(
                            "- Replacement action was not executed successfully\n")
                    end
                end

                -- Record replacement action execution
                self:_recordStepExecution(step, self.index, false,
                                          result or false)

                -- Start timer
                self:_startTimer(step, true)
                return true
            elseif (step.type == "Ability") and step.replacementLabel then
                if self.debug then
                    Utils:log("= Step type: Ability")
                    Utils:log("=== Replacement Ability: " ..
                                  step.replacementLabel)
                end
                local success, result = pcall(Utils.useAbility, Utils,
                                              step.replacementLabel)
                if not success then
                    Utils:log("ERROR: Replacement ability failed: " ..
                                  tostring(result), "error")
                elseif result then
                    if self.debug then
                        Utils:log("+ Ability cast successful\n")
                    end
                else
                    if self.debug then
                        Utils:log("- Ability cast unsuccessful\n")
                    end
                end

                -- Record replacement ability execution
                self:_recordStepExecution(step, self.index, false,
                                          result or false)

                -- Start timer
                self:_startTimer(step)
                return true
            else
                -- Skip this step
                if self.debug then Utils:log("= Skipping step") end
                self.cooldown = 0
                self.index = self.index + 1
                return false
            end
        end
    end

    return false
end

--- Improvises the next ability in the rotation
--- @param style string The combat style to improvise in
--- @param spendResources boolean Whether or not resources should be spent
--- @param targetId integer The AllObject Identifier of the target
--- @return string
function RotationManager:_improvise(style, spendResources, targetId)
    -- Determine target (prioritize target info)
    local target = Utils:find(targetId, 1, 20) or nil
    local targetHealth = 0
    if API.ReadTargetInfo99(true).Hitpoints > 0 then
        targetHealth = API.ReadTargetInfo99(true).Hitpoints
    elseif target then
        targetHealth = target.Life
    end

    local adrenaline = Player:getAdrenaline()
    local ability = ""

    -- #region Necromancy improvisation
    if style == "Necromancy" then
        -- Define default ability
        ability = "Basic<nbsp>Attack"

        -- Get resources
        local souls = Player:getBuff(CONSTANTS.BUFFS.SOULS)
        local necrosis = Player:getBuff(CONSTANTS.BUFFS.NECROSIS)

        local soulStacks = (souls.found and souls.remaining > 3) and
                               souls.remaining or 0
        local necrosisStacks = (necrosis.found and necrosis.remaining) or 0

        local possibleFingers = math.floor(
                                    (adrenaline + necrosisStacks * 10) / 60)

        -- Improvisation debugging (only if debug is enabled)
        if self.debug then
            Utils:log("[IMPROV] Target Health:    " .. targetHealth)
            Utils:log("[IMPROV] Adrenaline:       " .. adrenaline)
            Utils:log("[IMPROV] Soul stacks:      " .. soulStacks)
            Utils:log("[IMPROV] Necrosis stacks:  " .. necrosisStacks)
            Utils:log("[IMPROV] Possible fingers: " .. possibleFingers)
            Utils:log("")
        end

        if targetHealth > 30000 then
            local canExecute = (targetHealth - 30000) <=
                                   ((soulStacks * 7000) + possibleFingers *
                                       14000)
            if self.debug then
                Utils:log("[IMPROV] " ..
                              (canExecute and "+ Target is within execute range" or
                                  "- Target is not within execute range"))
            end
            -- Checks if the target can be executed
            -- Volley + Finger damage check
            if (soulStacks >= 3) and (possibleFingers >= 1) and
                (targetHealth - 30000 <= (soulStacks * 7000) + 14000) then
                ability = "Volley of Souls"
                -- Finger(s) of Death damage check
            elseif targetHealth - 30000 <= possibleFingers * 14000 then
                ability = "Finger of Death"
            end
        end

        -- If target is not within execute range, use these conditions to evaluate next ability
        if ability == "Basic<nbsp>Attack" then
            -- Are we spending our resources?
            if spendResources then
                if not Player:getDebuff(CONSTANTS.DEBUFFS.DEATH_GRASP).found and
                    (#Inventory:GetItem("Essence of Finality") > 0) and
                    (adrenaline > 23) then
                    Inventory:Equip("Essence of Finality")
                    -- API.RandomSleep2(60, 40, 20)
                    ability = "Essence of Finality"
                    goto continue
                else
                    -- Equip salve (e) if found in the player's inventory
                    if #Inventory:GetItem("Salve amulet (e)") > 0 then
                        Inventory:Equip("Salve amulet (e)")
                    end
                end
                if possibleFingers > 0 then
                    ability = "Finger of Death"
                    goto continue
                end
            end
            -- Guess not...
            if Player:getBuff(34177).found and
                Utils:canUseAbility("Command Putrid Zombie") then
                ability = "Command Putrid Zombie"
                goto continue
            end
            if Player:getBuff(34179).found and
                Utils:canUseAbility("Command Skeleton Warrior") then
                ability = "Command Skeleton Warrior"
                goto continue
            end
            if spendResources and (soulStacks == 5) then
                ability = "Volley of Souls"
                goto continue
            end
            if necrosisStacks >= (spendResources and 6 or 12) then
                ability = "Finger of Death"
                goto continue
            end
            if Player:getBuff(CONSTANTS.BUFFS.DEATH_SPARK).found then
                goto continue
            end
            if Utils:canUseAbility("Touch of Death") then
                ability = "Touch of Death"
                goto continue
            end
            if Utils:canUseAbility("Soul Sap") then
                ability = "Soul Sap"
                goto continue
            end
        end
    end

    ::continue::
    return ability
    -- #endregion
end

--- Resets the rotation to the beginning without clearing it
function RotationManager:reset()
    self.index = 1
    self.cooldown = 0
    self.lastTick = 0
    self.lastTime = 0
    if self.debug then Utils:log("Rotation reset to beginning") end
end

--- Sets or updates the target ID for improvise targeting
--- @param targetId number The NPC ID to target
function RotationManager:setTarget(targetId)
    self.targetId = targetId
    if self.debug then Utils:log("Target ID updated to: " .. targetId) end
end

--- Inserts a step at the specified index
--- @param index number The position to insert at (1-based, existing steps shift right)
--- @param step Step The step to insert
--- @return boolean True if successful, false if validation fails
function RotationManager:insertStep(index, step)
    -- Validate index
    if index < 1 or index > #self.rotation + 1 then
        Utils:log("ERROR: Cannot insert at index " .. index ..
                      " - out of bounds (rotation has " .. #self.rotation ..
                      " steps)", "error")
        return false
    end

    -- Validate the step
    local valid, errorMsg = self:_validateStep(step, index)
    if not valid then
        Utils:log("ERROR: " .. errorMsg, "error")
        return false
    end

    -- Insert the step
    table.insert(self.rotation, index, step)

    -- Adjust current index if needed (if we inserted before current position)
    if index <= self.index then self.index = self.index + 1 end

    if self.debug then
        Utils:log("Inserted step '" .. step.label .. "' at index " .. index)
    end

    return true
end

--- Removes the step at the specified index
--- @param index number The position to remove from (1-based)
--- @return boolean True if successful, false if index out of bounds
function RotationManager:removeStep(index)
    if index < 1 or index > #self.rotation then
        Utils:log("ERROR: Cannot remove step at index " .. index ..
                      " - out of bounds (rotation has " .. #self.rotation ..
                      " steps)", "error")
        return false
    end

    local removedLabel = self.rotation[index].label
    table.remove(self.rotation, index)

    -- Adjust current index if needed
    if index < self.index then
        self.index = self.index - 1
    elseif index == self.index then
        -- If we removed current step, clear cooldown so next step executes immediately
        self.cooldown = 0
    end

    if self.debug then
        Utils:log("Removed step '" .. removedLabel .. "' from index " .. index)
    end

    return true
end

--- Replaces the step at the specified index with a new step
--- @param index number The position to replace (1-based)
--- @param step Step The new step
--- @return boolean True if successful, false if validation fails or index out of bounds
function RotationManager:replaceStep(index, step)
    if index < 1 or index > #self.rotation then
        Utils:log("ERROR: Cannot replace step at index " .. index ..
                      " - out of bounds (rotation has " .. #self.rotation ..
                      " steps)", "error")
        return false
    end

    -- Validate the new step
    local valid, errorMsg = self:_validateStep(step, index)
    if not valid then
        Utils:log("ERROR: " .. errorMsg, "error")
        return false
    end

    local oldLabel = self.rotation[index].label
    self.rotation[index] = step

    -- If we replaced current step, clear cooldown so it executes with new logic
    if index == self.index then self.cooldown = 0 end

    if self.debug then
        Utils:log("Replaced step at index " .. index .. " ('" .. oldLabel ..
                      "' -> '" .. step.label .. "')")
    end

    return true
end

--- Jumps to a specific step index in the rotation
--- @param index number The step index to jump to (1-based)
--- @return boolean True if jump was successful, false if index out of bounds
function RotationManager:jumpToStep(index)
    if index < 1 or index > #self.rotation then
        Utils:log("ERROR: Cannot jump to step " .. index ..
                      " - out of bounds (rotation has " .. #self.rotation ..
                      " steps)", "error")
        return false
    end

    self.index = index
    self.cooldown = 0 -- Clear cooldown so next step executes immediately
    self.lastTick = 0
    self.lastTime = 0

    if self.debug then
        Utils:log("Jumped to step " .. index .. " (" ..
                      self.rotation[index].label .. ")")
    end

    return true
end

--- Jumps to the first step with matching label
--- @param label string The step label to find and jump to
--- @return boolean True if jump was successful, false if label not found
function RotationManager:jumpToLabel(label)
    for i, step in ipairs(self.rotation) do
        if step.label == label then return self:jumpToStep(i) end
    end

    Utils:log("ERROR: Cannot jump to label '" .. label ..
                  "' - not found in rotation", "error")
    return false
end

--- Unloads and clears the current rotation
function RotationManager:unload()
    self.rotation = {}
    self.rotationAddress = ""
    self.index = 1
    if self.debug then Utils:log("Rotation unloaded") end
end

--- Retrieve recent step executions (up to 15, newest first)
--- @param limit? integer Optional limit to return fewer than all recent steps
--- @return RotationManager.RecentStep[]
function RotationManager:getRecentSteps(limit)
    if not limit or limit > #self.recentSteps then return self.recentSteps end

    local limited = {}
    for i = 1, math.min(limit, #self.recentSteps) do
        limited[i] = self.recentSteps[i]
    end
    return limited
end

return RotationManager
