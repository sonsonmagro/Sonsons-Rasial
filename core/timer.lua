---@module 'Timer'
---@version 1.0.1
--[[
    File: timer.lua
    Description : Manages your actions and avoids spamming without having to use sleep
    Author: Sonson
]]

---@class Timer
---@field name string
---@field cooldown integer
---@field useTicks boolean
---@field condition fun():boolean
---@field action function
---@field lastTriggered integer
---@field lastTime number
---@field cycleCount integer
local Timer = {}
Timer.__index = Timer

local API = require("api")
local debug = false

---@class TimerConfig
---@field name string
---@field cooldown integer
---@field useTicks boolean?
---@field condition nil | fun(any): boolean
---@field action fun(param: any?): boolean
---@field args any?

-- if debug == true, prints messages in console
---@param message string
function Timer:_debugLog(message)
    if debug then
        print(
            "[TIMER]:",
            self.name .. " | " .. message
        )
    end
end

---initializes a new timer
---@param config TimerConfig
---@return Timer
function Timer.new(config)
    local self = setmetatable({}, Timer)

    if not config then
        print("[TIMER]: No config found when initializing.")
        print("[TIMER]: Terminating your session.")
        API.Write_LoopyLoop(false)
    end

    self.name = config.name or "Unnamed Timer"
    self.cooldown = config.cooldown or 0
    self.useTicks = true
    if config.useTicks ~= nil then
        self.useTicks = config.useTicks
    end
    self.condition = config.condition or function() return false end
    self.action = config.action
    self.lastTriggered = 0
    self.lastTime = 0
    return self
end

---checks to see if timer can be triggered
---compares cooldown and timer condition
---@param ... unknown so far only tested with playerManager instance and nil
---@return boolean
function Timer:canTrigger(...)
    local currentTick = API.Get_tick()
    local currentTime = os.clock() * 1000
    local delta = (self.useTicks and (currentTick - self.lastTriggered)) or (currentTime - self.lastTime)
    local args = {...}

    -- handle empty arguments safely
    if #args == 0 then
        return (delta >= self.cooldown) and self.condition()
    end

    return (delta >= self.cooldown) and self.condition(table.unpack(...))
end

---executes the action provided with the timer after checking if it can be triggered
---@param ... unknown so far only tested with playerManager instance and nil
---@return boolean if action has been executed (assumes action returns a boolean)
function Timer:execute(...)
    local args = {...}
    if self:canTrigger(args) then
        local func = function() if #args == 0 then return self.action() else return self.action(table.unpack(args)) end end

        if func() then
            self:_debugLog("Action successful.")
            if self.useTicks then
                self:_debugLog("Game tick: "..API.Get_tick())
            else
                self:_debugLog("Time: ".. os.clock() * 1000)
            end
            self.lastTriggered = API.Get_tick()
            self.lastTime = os.clock() * 1000
            return true
        end
    end
    return false
end

---resets the timer's last triggered
function Timer:reset()
    self.lastTriggered = 0
    self.lastTime = 0
end

return Timer
