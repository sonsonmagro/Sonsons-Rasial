--[[                                ╔═══════════════════════════════════════════════════╗
                                    ║    ██████╗ ██████╗ ███████╗███╗   ███╗███████╗    ║
                                    ║    ██╔══██╗██╔══██╗██╔════╝████╗ ████║██╔════╝    ║
                                    ║    ██████╔╝██║  ██║███████╗██╔████╔██║█████╗      ║
                                    ║    ██╔══██╗██║  ██║╚════██║██║╚██╔╝██║██╔══╝      ║
                                    ║    ██████╔╝██████╔╝███████║██║ ╚═╝ ██║███████╗    ║
                                    ║    ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝    ║
                                    ╠═══════════════════════════════════════════════════╣
                                    ║                  Discord handles                  ║
                                    ╠═════════════╦═══════════════════╦═════════════════╣
                                    ║ Dead(dea.d) ║ Sonson(.sonson._) ║Nocturnal(nctrl_)║
                                    ╠═════════════╩═══════════════════╩═════════════════╣
                                    ║We only publish here: https://github.com/BDSMe     ║
            ╔═══════════════════════╩═══════════════════════════════════════════════════╩═══════════════════════╗
            ║   Manages your actions and avoids spamming without having to use sleep                            ║
            ║                                                                                                   ║
            ║   File: timer.lua                                                                                 ║
            ║   Authors: BDSMe [Dead, Sonson, Nocturnal]                                                        ║
            ╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝
]]

--- @module 'BDSME Timer'
--- @version 2.0.0

------------------------------------------
--# IMPORTS
------------------------------------------

local API    = require("api")

------------------------------------------
--# TYPE DEFINITIONS
------------------------------------------

--- @class Timer.Task
--- @field name             string                      Unique task identifier.
--- @field action           fun():boolean               Function to perform task action.
--- @field condition        fun():boolean               Function that returns true if task may run.
--- @field cooldown?        integer                     Minimum wait between executions (optional).
--- @field useTicks?        boolean                     Use ticks instead of ms for cooldown (optional).
--- @field delay?           integer                     Additional wait after last run (optional).
--- @field delayTicks?      boolean                     Use ticks not ms for delay timing (optional).
--- @field priority?        integer                     Priority order; higher means execute earlier (optional).
--- @field parallel?        boolean                     Run immediately independent of priority (optional).
--- @field cooldownSkip?    boolean                     Skip task if still cooling down (optional).
--- @field executionData    Timer.TaskExecutionData     Tracks last execution time and run count.

--- @class Timer.ExecutionData
--- @field tick             integer                     Tick count at last task execution.
--- @field time             number                      Timestamp (ms) at last task execution.

--- @class Timer.TaskExecutionData
--- @field lastRun          integer                     Last run tick or timestamp.
--- @field count            integer                     Total number of executions.

--- @class Timer
--- @field tasks            table<string, Timer.Task>   Collection of tasks.
--- @field lastExecution    Timer.ExecutionData         Records last execution tick and time.
--- @field debug            boolean                     Enables debug logging.
--- @field addTask          fun(self, task:Timer.Task)  Adds a task to the timer's tasks
--- @field run              fun(self):boolean           Executes assigned tasks based on conditions, priority and type
--- @field getStatus        fun(self):string            Returns a string of all active tasks
--- @field getMetrics       fun(self):table             Returns a metrics table of active tasks

------------------------------------------
--# TIMER TASK CONFIGURATION
------------------------------------------

--[[

        ████████╗██╗███╗   ███╗███████╗██████╗     ████████╗ █████╗ ███████╗██╗  ██╗███████╗
        ╚══██╔══╝██║████╗ ████║██╔════╝██╔══██╗    ╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝██╔════╝
           ██║   ██║██╔████╔██║█████╗  ██████╔╝       ██║   ███████║███████╗█████╔╝ ███████╗
           ██║   ██║██║╚██╔╝██║██╔══╝  ██╔══██╗       ██║   ██╔══██║╚════██║██╔═██╗ ╚════██║
           ██║   ██║██║ ╚═╝ ██║███████╗██║  ██║       ██║   ██║  ██║███████║██║  ██╗███████║
           ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝       ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝


    E S S E N T I A L   T A S K   P A R A M E T E R S :
    ------------------------------------------------------------------------------------------------
    • name:       (string)  Unique identifier for the task (used for debugging and logging)
    • action:     (function) The main execution logic that runs when conditions are met (returns boolean)
    • condition:  (function) Returns boolean - must evaluate to true for task to run

    C O R E   T I M I N G   P A R A M E T E R S :
    ------------------------------------------------------------------------------------------------
    • cooldown:   (number)  Minimum delay (ticks/ms) before this task can execute again (default: 0)
    • useTicks:   (boolean) Use game ticks instead of milliseconds for cooldown (default: false)
    • delay:      (number)  Minimum wait after last timer action before executing (default: 0)
    • delayTicks: (boolean) Use ticks instead of milliseconds for delay timing (default: false)

    O P T I O N A L   P A R A M E T E R S :
    ------------------------------------------------------------------------------------------------
    • priority:               (number)  Execution order (higher = earlier, default: 0)
    • parallel:               (boolean) Ignore priority and execute when possible (default: false)
    • cooldownSkip:           (boolean) Skip task when on cooldown, even if conditions met (default: false)

    E X E C U T I O N   R U L E S :
    ------------------------------------------------------------------------------------------------
    1. Parallel tasks execute first when their cooldown expires and conditions are met
    2. Non-parallel tasks execute in priority order (highest first) when:
       - All conditions are met
       - Cooldown has expired
       - Delay requirement is met
    3. Within priority groups, tasks execute in declaration order
    4. Timer maintains single execution history for delay calculations
    5. Tasks with cooldownSkip skip execution checks while cooling down
    6. Action should return true on success to update execution tracking

    D E B U G G I N G   F E A T U R E S :
    ------------------------------------------------------------------------------------------------
    • Execution logs show: task name, priority, run count, and time since last execution
    • Time formats automatically convert between ticks and milliseconds
    • No console spamming - messages only show on actual executions
]]

------------------------------------------
--# INITIALIZATION
------------------------------------------

local Timer = {}
Timer.__index = Timer

--- Create a new Timer instance
--- @return Timer
function Timer.new()
    local self = setmetatable({}, Timer)
    self.tasks = {}
    self.lastExecution = {
        tick = 0,
        time = 0
    }
    self.debug = false
    return self
end

---Add a new task to the timer
---@param task Timer.Task
function Timer:addTask(task)
    -- Validate required fields
    if not task.name or not task.action then
        error("Tasks require at least name and action fields")
    end

    -- Set defaults
    ---@type Timer.Task
    local normalizedTask = {
        name            = task.name,
        action          = task.action,
        condition       = task.condition,
        priority        = task.priority or 0,
        cooldown        = task.cooldown or 0,
        delay           = task.delay or 0,
        useTicks        = task.useTicks or false,
        delayTicks      = task.delayTicks or false,
        parallel        = task.parallel or false,
        cooldownSkip    = task.cooldownSkip or false,
        executionData   = {
            lastRun = 0,
            count = 0
        }
    }

    self.tasks[normalizedTask.name] = normalizedTask
end

---Execute tasks based on priority and conditions
---@return boolean executed True if any task was executed
function Timer:run()
    local currentTick = API.Get_tick()
    local currentTime = os.clock() * 1000
    local executedAny = false

    -- Process parallel tasks first
    for _, task in pairs(self.tasks) do

        if task.parallel and self:_canExecute(task, currentTick, currentTime)
            and self:_isOffCooldown(task, currentTick, currentTime) then
            self:_execute(task, currentTick, currentTime)
            executedAny = true
        end
    end

    -- Process normal tasks by priority if no parallel tasks executed
    local candidates = {}
    local highestPriority = -math.huge

    -- Find eligible tasks and determine highest priority
    for _, task in pairs(self.tasks) do
        if not task.parallel
            and self:_canExecute(task, currentTick, currentTime)
            --and self:_checkDelay(task, currentTick, currentTime)
        then
            if task.priority > highestPriority then
                highestPriority = task.priority
                candidates = { task }
            elseif task.priority == highestPriority then
                table.insert(candidates, task)
            end
        end
    end

    -- Execute priority group
    if #candidates > 0 then
        for _, candidateTask in pairs(candidates) do
            if self:_isOffCooldown(candidateTask, currentTick, currentTime)
                and self:_checkDelay(candidateTask, currentTick, currentTime) then
                if self:_execute(candidateTask, currentTick, currentTime) then
                    executedAny = true
                end
            end
        end
    end

    return executedAny
end

---Check if a task can be executed
---@private
---@param task Timer.Task
---@param currentTick integer
---@param currentTime number
---@return boolean
function Timer:_canExecute(task, currentTick, currentTime)
    -- Check if task is disabled when on cooldown
    if task.cooldownSkip and not self:_isOffCooldown(task, currentTick, currentTime) then
        return false
    end

    return task.condition()
        --and self:_isOffCooldown(task, currentTick, currentTime)
end

---Check if task is off cooldown
---@private
---@param task Timer.Task
---@param currentTick integer
---@param currentTime number
---@return boolean
function Timer:_isOffCooldown(task, currentTick, currentTime)
    local elapsed = (task.useTicks and (currentTick - task.executionData.lastRun))
        or (currentTime - task.executionData.lastRun)

    return elapsed >= task.cooldown
end

---Check if task delay has been met
---@private
---@param task Timer.Task
---@param currentTick integer
---@param currentTime number
---@return boolean
function Timer:_checkDelay(task, currentTick, currentTime)
    if task.delay <= 0 then return true end

    local elapsed = task.delayTicks
        and (currentTick - self.lastExecution.tick)
        or (currentTime - self.lastExecution.time)

    return elapsed >= task.delay
end

---Execute a task and update tracking data
---@private
---@param task Timer.Task
---@param currentTick integer
---@param currentTime number
---@return boolean
function Timer:_execute(task, currentTick, currentTime)
    if task.action() then
        task.executionData.lastRun = task.useTicks and currentTick or currentTime
        task.executionData.count = task.executionData.count + 1

        -- Update last execution data for delay calculations
        if not task.parallel then
            self.lastExecution.tick = currentTick
            self.lastExecution.time = currentTime
        end

        return true
    end
    return false
end

---Returns a metrics table showing tasks currently meeting their conditions
---@return table
function Timer:getMetrics()
    local metrics = {}

    -- Collect and sort parallel tasks
    local parallelTasks = {}
    for _, task in pairs(self.tasks) do
        if task.parallel and task.condition() then
            table.insert(parallelTasks, task)
        end
    end
    table.sort(parallelTasks, function(a, b)
        if a.priority == b.priority then
            return a.name < b.name
        end
        return a.priority > b.priority
    end)

    -- Add parallel section
    table.insert(metrics, { "Parallel Tasks:", "" })
    for _, task in ipairs(parallelTasks) do
        table.insert(metrics, {
            string.format("[%d] %s:", task.priority, task.name),
            string.format("Run Count: %d", task.executionData.count or 0)
        })
    end

    -- Add separator
    table.insert(metrics, { "", "" })

    -- Collect and sort normal tasks
    local normalTasks = {}
    for _, task in pairs(self.tasks) do
        if not task.parallel and task.condition() then
            table.insert(normalTasks, task)
        end
    end
    table.sort(normalTasks, function(a, b)
        if a.priority == b.priority then
            return a.name < b.name
        end
        return a.priority > b.priority
    end)

    -- Add normal section
    table.insert(metrics, { "Normal Tasks:", "" })
    for _, task in ipairs(normalTasks) do
        table.insert(metrics, {
            string.format("[%d] %s:", task.priority, task.name),
            string.format("Run Count: %d", task.executionData.count or 0)
        })
    end

    return metrics
end

---Returns a concatenated status string of all active tasks meeting their conditions
---@return string
function Timer:getStatus()
    local activeTasks = {}

    -- Collect all tasks with met conditions
    for _, task in pairs(self.tasks) do
        if task.condition() then
            table.insert(activeTasks, task)
        end
    end

    if #activeTasks == 0 then
        return "No active tasks"
    end

    -- Sort by priority (descending) then name (ascending)
    table.sort(activeTasks, function(a, b)
        if a.priority == b.priority then
            return a.name < b.name
        end
        return a.priority > b.priority
    end)

    -- Format into strings
    local statusParts = {}
    for _, task in ipairs(activeTasks) do
        table.insert(statusParts, string.format("%s", task.name))
    end

    return table.concat(statusParts, "\n")
end

---Retrieve execution data for a specific task
---@param taskName string
---@return Timer.TaskExecutionData|nil
function Timer:getTaskExecutionData(taskName)
    local task = self.tasks[taskName]
    if task then
        return task.executionData
    end
    return nil
end

return Timer
