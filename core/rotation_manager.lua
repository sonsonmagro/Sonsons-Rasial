--- @module "Sonson's Rotation Manager"
--- @version 0.0.1

------------------------------------------
--# IMPORTS
------------------------------------------

local API    = require("api")
local Player = require("core.player")
local Utils  = require("core.helper")

------------------------------------------
--# TYPE DEFINITIONS
------------------------------------------

--- @class Step
--- @field label                 string                      Unique identifier for this step, used in logging and debugging.
--- @field type?                 StepType                    The category of the step which determines how it is processed (e.g., "Ability", "Inventory", "Equip", "Target cycle", "Improvise", or "Custom").
--- @field wait?                 number                      The post-execution delay. When useTicks is true, this is in game ticks (default is 3 ticks); otherwise in milliseconds (default is 1800 ms).
--- @field useTicks?             boolean                     Determines if the wait value uses game ticks (true) or milliseconds (false). Default is true.
--- @field action?               function                    The primary execution logic for the step. Required for non-Improvise steps that do not use default utility functions.
--- @field style?                CombatStyle                 For Improvise steps, indicates the combat style to use (e.g., "Necromancy", "Melee", "Range", or "Magic").
--- @field condition?            fun():boolean               A predicate function that must return true for the primary action to execute. If absent, the action is executed unconditionally.
--- @field replacementLabel?     string                      Alternate display name for the action when the condition check fails.
--- @field replacementAction?    function                    Alternate logic to execute when the condition function exists but evaluates to false.
--- @field replacementWait?      number                      A custom delay to use after performing the replacement action.
--- @field spend?                boolean                     For Improvise steps, indicates whether adrenaline and other resources should be consumed. Defaults to false.
--- @field targetCycleKey?       number                      The hexadecimal key code used for target cycling actions (e.g., 0x09).

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

--- @class RotationManager
--- @field rotation              Step[]                      The list of steps that make up a rotation sequence.
--- @field rotationAddress       string                      A unique string representation of the current rotation (used to detect changes).
--- @field index                 integer                     The current position in the rotation sequence.
--- @field targetId?             number                      The identifier of the target, if applicable.
--- @field useTicks              boolean                     Indicates whether the step wait timings use game ticks.
--- @field cooldown              number                      The current wait duration before the next step can be executed.
--- @field lastTick              integer                     The game tick when the last step timer was started.
--- @field lastTime              number                      The precise time (in milliseconds) when the last step timer was started.
--- @field load                  fun(self, rotation: Step[]) Loads a new rotation and resets the index if the rotation is different.
--- @field execute               fun(self): boolean          Processes and executes the current step in the rotation; returns true if a step was executed.

------------------------------------------
--# ROTATION STEP CONFIGURATION
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
--# CONSTANT VARIABLES
------------------------------------------

local CONSTANTS = {
    BUFFS = {
        SOULS = 30123,
        NECROSIS = 30101,
        DEATH_SPARK = 30127
    },
    DEBUFFS = {
        DEATH_GRASP = 55524,
    }
}

------------------------------------------
--# INITIALIZATION
------------------------------------------

local RotationManager = {}
RotationManager.__index = RotationManager


function RotationManager.new(targetId)
    local self = setmetatable({}, RotationManager)
    -- TODO: Allow for dynamic target selection
    self.targetId = targetId or nil
    if targetId then Utils:log("Target ID Initialized: " .. targetId) end

    -- Rotation data
    self.rotation, self.rotationAddress = {}, ""
    self.index = 1

    -- Last step data
    self.useTicks = true
    self.cooldown = 0

    -- Execution data
    self.lastTick = 0
    self.lastTime = 0

    return self
end

function RotationManager:_useInventory(itemName)
    return API.DoAction_Inventory3(itemName, 0, 1, API.OFF_ACT_GeneralInterface_route)
end

--- Loads a new rotation and resets the index
--- @param rotaiton Step[]
function RotationManager:load(rotaiton)
    -- Check if rotation is different (failsafe: sorry Dead)
    local rotationAddress = tostring(rotaiton)
    if self.rotationAddress ~= rotationAddress then
        Utils:log("Rotation loaded successfully")
        Utils:log("Rotation address: " .. rotationAddress)
        self.index = 1
        self.rotation = rotaiton
        self.rotationAddress = rotationAddress
    end
end

--- Checks if the wait duration period has passed
function RotationManager:_canTrigger()
    if self.useTicks then
        return (API.Get_tick() - self.lastTick) >= self.cooldown    -- Using game ticks
    else
        return (os.clock() * 1000 - self.lastTime) >= self.cooldown -- Using milliseconds
    end
end

--- Starts the internal timer
--- @param step Step: The current step being executed
--- @param useReplacementWait? boolean: Whether to use the replacement wait time
function RotationManager:_startTimer(step, useReplacementWait)
    self.index = self.index + (step.type ~= "Improvise" and 1 or 0)
    self.cooldown = useReplacementWait and step.replacementWait or step.wait
    self.useTicks = step.useTicks
    self.lastTick = API.Get_tick()
    self.lastTime = os.clock() * 1000
    -- Timer debugging
    Utils:log("= Timer Information: ")
    Utils:log("=== Last Tick: " .. self.lastTick)
    Utils:log("=== Last Time: " .. self.lastTime)
    Utils:log("=== Cooldown : " .. self.cooldown)
    Utils:log("")
end

function RotationManager:execute()
    -- Do nothing if we're out of steps
    if self.index > #self.rotation then
        Utils:log("No more steps")
        return false
    end

    -- Check if the wait time has passed
    if self:_canTrigger() then
        -- Get step data
        local step = self.rotation[self.index]
        -- Step data debugging
        Utils:log("--# " .. self.index .. " -------------------------------------------")
        Utils:log("# " .. step.label)
        Utils:log("Tick: " .. API.Get_tick())
        Utils:log("Time: " .. math.floor(os.clock() * 1000))

        -- Configure step defaults
        step.type = step.type or "Ability" -- type
        if step.useTicks == nil then       -- useTicks
            step.useTicks = true
        end
        step.wait = step.wait or (step.useTicks and 3 or 1800)
        -- Cooldown debugging
        Utils:log("Wait: " .. step.wait)
        Utils:log("UseTicks?: " .. ((step.useTicks and "Yes") or "No"))
        Utils:log("")

        -- Check for conditions and whether or not they are met
        if (step.condition and step.condition()) or not step.condition then
            if step.condition and step.condition() then
                Utils:log("+ Step condition found and met")
            else
                Utils:log("= No step condition found")
            end
            Utils:log("")
            -- Handle step types
            if step.type == "Ability" then
                Utils:log("= Step type: Ability")
                if Utils:useAbility(step.label) then
                    Utils:log("+ Ability cast successful")
                else
                    Utils:log("- Ability cast unsuccessful")
                end
                Utils:log("")
            elseif step.type == "Inventory" then
                Utils:log("= Step type: Inventory")
                if self:_useInventory(step.label) then
                    Utils:log("+ Use from inventory successful")
                else
                    Utils:log("- Use from inventory unsuccessful")
                end
                Utils:log("")
            elseif step.type == "Equip" then
                Utils:log("= Step type: Equip")
                if Inventory:Equip(step.label) then
                    Utils:log("+ Equipping from inventory successful")
                else
                    Utils:log("- Equipping from inventory unsuccessful")
                end
                Utils:log("")
            elseif step.type == "Custom" and step.action then
                Utils:log("= Step type: Custom")
                if step.action() then
                    Utils:log("+ Custom action executed successfully")
                else
                    Utils:log("- Custom action was not successful")
                end
            elseif step.type == "Improvise" and step.style == "Necromancy" then
                Utils:log("= Step type: Improvise")
                Utils:log("")
                local ability = self:_improvise(step.style, step.spend, self.targetId)
                Utils:log("= Designated improvise ability: " .. ability)
                if Utils:useAbility(ability) then
                    Utils:log("+ Ability cast was successful")
                else
                    Utils:log("- Ability cast was unsuccessful")
                end
                Utils:log("")
            elseif step.type == "Target cycle" then
                Utils:log("= Step type: Target cycle")
                API.KeyboardPress2(step.targetCycleKey, 60, 0)
                Utils:log("+ Target cycled")
                Utils:log("")
            end

            -- Start timer
            self:_startTimer(step)
            return true
        else
            Utils:log("- Step condition found and NOT met")
            -- Use replacements
            if step.replacementAction then
                if step.replacementLabel then
                    step.label = step.replacementLabel
                end
                if step.replacementAction() then
                    Utils:log("+ Replacement action executed successfully\n")
                else
                    Utils:log("- Replacement action was not executed successfully\n")
                end

                -- Start timer
                self:_startTimer(step, true)
                return true
            elseif (step.type == "Ability") and step.replacementLabel then
                Utils:log("= Step type: Ability")
                Utils:log("=== Replacement Ability: " .. step.replacementLabel)
                if Utils:useAbility(step.replacementLabel) then
                    Utils:log("+ Ability cast successful\n")
                else
                    Utils:log("- Ability cast unsuccessful\n")
                end

                -- Start timer
                self:_startTimer(step)
                return true
            else
                -- Skip this step
                Utils:log("= Skipping step")
                self.cooldown = 0
                self.index = self.index + 1
                return false
            end
        end
    end

    return false
end

--- Improvises the next ability in the rotaiton
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

    --#region Necromancy improvisation
    if style == "Necromancy" then
        -- Define default ability
        ability = "Basic<nbsp>Attack"

        -- Get resources
        local souls = Player:getBuff(CONSTANTS.BUFFS.SOULS)
        local necrosis = Player:getBuff(CONSTANTS.BUFFS.NECROSIS)

        local soulStacks = (souls.found and souls.remaining > 3) and souls.remaining or 0
        local necrosisStacks = (necrosis.found and necrosis.remaining) or 0

        local possibleFingers = math.floor((adrenaline + necrosisStacks * 10) / 60)

        -- Improvisation debugging
        Utils:log("[IMPROV] Target Health:    " .. targetHealth)
        Utils:log("[IMPROV] Adrenaline:       " .. adrenaline)
        Utils:log("[IMPROV] Soul stacks:      " .. soulStacks)
        Utils:log("[IMPROV] Necrosis stacks:  " .. necrosisStacks)
        Utils:log("[IMPROV] Possible fingers: " .. possibleFingers)
        Utils:log("")

        if targetHealth > 30000 then
            local canExecute = (targetHealth - 30000) <= ((soulStacks * 7000) + possibleFingers * 14000)
            Utils:log("[IMPROV] " ..
                (canExecute and "+ Target is within execute range" or "- Target is not within execute range"))
            -- Checks if the target can be executed
            -- Volley + Finger damage check
            if (soulStacks >= 3) and (possibleFingers >= 1) and (targetHealth - 30000 <= (soulStacks * 7000) + 14000) then
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
                if not Player:getDebuff(CONSTANTS.DEBUFFS.DEATH_GRASP).found and (#Inventory:GetItem("Essence of Finality") > 0)
                    and (adrenaline > 23)
                then
                    Inventory:Equip("Essence of Finality")
                    --API.RandomSleep2(60, 40, 20)
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
            if Player:getBuff(34177).found and Utils:canUseAbility("Command Putrid Zombie") then
                ability = "Command Putrid Zombie"
                goto continue
            end
            if Player:getBuff(34179).found and Utils:canUseAbility("Command Skeleton Warrior") then
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
    --#endregion
end

-- Reset
function RotationManager:unload()
    self.rotation = {}
    self.rotationAddress = ""
    self.index = 1
end

return RotationManager
