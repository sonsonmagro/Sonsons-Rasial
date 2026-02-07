--- @module "Sonson's Helper"
--- @version 1.0.0

------------------------------------------
--# IMPORTS
------------------------------------------

local API = require("api")

------------------------------------------
--# MODULE DEFINITION
------------------------------------------

local Utils = {}

------------------------------------------
--# TABLE OPERATIONS
------------------------------------------

--- Concatenates t2 into t1 (modifies t1)
--- @param t1 any[]
--- @param t2 any[]
function Utils:tableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
end

--- Returns new table containing both tables' contents
--- @param t1 any[]
--- @param t2 any[]
--- @return any[]
function Utils:virtualTableConcat(t1, t2)
    local temp = {}
    table.move(t1, 1, #t1, 1, temp)
    table.move(t2, 1, #t2, #t1 + 1, temp)
    return temp
end

--- Concatenates multiple tables into the first one
--- @param t1 any[] # Target table to modify
--- @param ... any[] # Variable number of tables to concatenate
function Utils:multiTableConcat(t1, ...)
    local args = { ... }
    for _, t2 in ipairs(args) do
        for i = 1, #t2 do
            t1[#t1 + 1] = t2[i]
        end
    end
end

--- Checks if a table contains the specified value
--- @param table table
--- @param needle any
--- @return boolean
function Utils:contains(table, needle)
    for _, value in pairs(table) do
        if value == needle then
            return true
        end
    end
    return false
end

------------------------------------------
--# LOGGING & ERROR HANDLING
------------------------------------------

--- Logs messages with different severity levels
--- @param message string
--- @param logType? "warn"|"error"|"debug"|"info"|"lua"
function Utils:log(message, logType)
    local debugLogTypes = {
        warn = API.logWarn,
        error = API.logError,
        debug = API.logDebug,
        info = API.logInfo,
        lua = print
    }

    logType = logType or "debug"
    local logFunction = debugLogTypes[logType] or debugLogTypes.debug
    logFunction(message)
end

--- Terminates the script with optional error messages
--- @param ... string # Error messages to display
function Utils:terminate(...)
    local args = { ... }
    if #args > 0 then
        for _, message in ipairs(args) do
            self:log(message, "warn")
        end
    end

    API.SetDrawLogs(true)
    self:log("Terminating session", "error")
    API.Write_LoopyLoop(false)
end

------------------------------------------
--# ABILITY HANDLING
------------------------------------------

--  FIXME: Needs further revision and testing
--- Checks if ability can be used
--- @param abilityName string
--- @return boolean
function Utils:canUseAbility(abilityName)
    local ability = API.GetABs_name(abilityName, true)
    if not ability then
        return false
    end

    -- Special case handling
    if abilityName == "Volley of Souls" then
        return ability.enabled and (ability.slot > 0)
    elseif abilityName == "Death Skulls" then
        return (ability.cooldown_timer <= 1) and (ability.slot > 0)
    end
    return ability.enabled and (ability.cooldown_timer <= 1) and (ability.slot > 0)
end

--- Uses ability from ability bar
--- @param abilityName string
--- @return boolean
function Utils:useAbility(abilityName)
    return API.DoAction_Ability(abilityName, 1, API.OFF_ACT_GeneralInterface_route, true)
end

------------------------------------------
--# OBJECTS & ENTITIES
------------------------------------------

--- Finds first object matching criteria
--- @param objID number|number[]
--- @param objType number
--- @param distance? number
--- @return AllObject?
function Utils:find(objID, objType, distance)
    local id = type(objID) == "table" and objID or { objID }
    return API.GetAllObjArrayFirst(id, distance or 25, { objType }) or nil
end

--- Finds all objects matching criteria
--- @param objID number|number[]
--- @param objType number
--- @param distance? number
--- @return AllObject[]
function Utils:findAll(objID, objType, distance)
    local id = type(objID) == "table" and objID or { objID }
    return API.GetAllObjArray1(id, distance or 25, { objType }) or {}
end

--- @class EntityInfo
--- @field found      boolean    -- true if the boss was detected
--- @field health     integer    -- current HP, –1 if not found
--- @field id         integer    -- entity ID, –1 if not found
--- @field name       string     -- boss name or "UNKNOWN"
--- @field animation  integer    -- current animation ID, –1 if not found
--- @field tile       WPOINT     -- map-tile coordinates

--- Retrieves structured info about an entity
--- @param objId integer | integer[]
--- @param type integer
--- @param distance integer
--- @return EntityInfo
function Utils:getEntityInfo(objId, type, distance)
    local entity = Utils:findAll(objId, type, distance)
    return {
        found     = (#entity > 0),
        uniqueId  = (#entity > 0) and entity[1].Unique_Id or -1,
        name      = (#entity > 0) and entity[1].Name or "UNKNOWN",
        health    = (#entity > 0) and entity[1].Life or -1,
        animation = (#entity > 0) and entity[1].Anim or -1,
        --- @diagnostic disable-next-line: undefined-global
        tile      = (#entity > 0) and entity[1].Tile_XYZ or WPOINT.new(0, 0, 0)
    }
end

--- Get all lootable items
--- @param ... table
function Utils:getLoot(...)
    local lootTable = {}
    self:multiTableConcat(lootTable, table.unpack(...))

    return API.GetAllObjArray1(lootTable, 70, { 3 })
end

------------------------------------------
--# INVENTORY MANAGEMENT
------------------------------------------

--- Checks if inventory matches required loadout
--- @param loadout table[] # Array of {id: number, amount: number} or {ids: number[], amount: number}
--- @return boolean
function Utils:inventoryMatchCheck(loadout)
    for _, item in ipairs(loadout) do
        -- Support both single ID and array of IDs
        local itemIds = {}
        if item.ids then
            -- Array of IDs (e.g., for items with multiple doses)
            itemIds = item.ids
        elseif item.id then
            -- Single ID
            itemIds = { item.id }
        else
            self:terminate("Undefined item ID in inventory preset")
            return false
        end

        -- Check if any of the valid IDs match the required amount
        local found = false
        for _, id in ipairs(itemIds) do
            local count = Inventory:InvItemcount(id)
            local stack = Inventory:InvStackSize(id)
            if count >= item.amount or stack >= item.amount then
                found = true
                break
            end
        end

        if not found then
            return false
        end
    end
    return true
end

--- Equips highest tier luck ring from inventory
--- @return boolean # Success status
function Utils:equipLuckRing()
    local t4LuckRingIds = {
        39812, -- Luck of the Dwarves
        44559, -- Luck of the Dwarves (i)
        39814, -- Hazelmere's signet ring
        44560, -- Hazelmere's signet ring (i)
    }

    for _, id in ipairs(t4LuckRingIds) do
        if Inventory:Contains(id) then
            return Inventory:Equip(id) -- Changed to Roblox-style API call
        end
    end
    return false
end

------------------------------------------
--# SPELLBOOK & COMBAT
------------------------------------------

--- Gets current spellbook type
--- @return "Normal"|"Ancients"|"Lunars"|"UNKNOWN"
function Utils:getSpellbook()
    local bitPattern = API.VB_FindPSettinOrder(4).state & 0x3
    return ({
        [0] = "Normal",
        [1] = "Ancients",
        [2] = "Lunars"
    })[bitPattern] or "UNKNOWN"
end

------------------------------------------
--# TIME CALCULATIONS
------------------------------------------

--- Formats milliseconds to [00:00.0] time string
--- @param ms integer
--- @return string
function Utils:formatKillDuration(ms)
    local minutes = math.floor(ms / 60000)
    ms = ms % 60000
    local seconds = math.floor(ms / 1000)
    local hundredths = math.floor((ms % 1000) / 100)

    -- Handle overflow conditions
    if hundredths >= 10 then
        seconds = seconds + 1
        hundredths = hundredths - 10
    end
    if seconds >= 60 then
        minutes = minutes + 1
        seconds = seconds - 60
    end

    return string.format("%02d:%02d.%1d", minutes, seconds, hundredths)
end

--- Calculates value per hour rate
--- @param value number
--- @param startTime number # os.time() timestamp
--- @return string
function Utils:valuePerHour(value, startTime)
    local elapsed = os.time() - startTime
    return elapsed > 0 and string.format("%.2f", value / (elapsed / 3600)) or "0.00"
end

function Utils:formatNumber(number)
    -- convert to string and split into whole and decimal parts
    local str = string.format("%.2f", number)
    local whole, decimal = str:match("^(%d+)%.(%d+)$")
    if not whole then
        -- if no decimal, just format the whole number
        return string.format("%d", number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    -- format the whole number part with commas
    local formatted = string.format("%d", tonumber(whole)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return formatted
end

function Utils:getLootWindowAmount()
    local text = API.ScanForInterfaceTest2Get(false,
    ---@diagnostic disable-next-line
        { { 1622, 4, -1, 0 }, { 1622, 6, -1, 0 }, { 1622, 2, -1, 0 }, { 1622, 3, -1, 0 } })
    if text and #text > 0 and text[1].textids then
        local value = string.match(text[1].textids, "Value: <col=[0-9A-F]+>([%d,]+[KMB]?)") -- matches numbers with commas and optional M/B suffix, with any color code
        if value then
            value = string.gsub(value, ",", "")                                             -- remove commas before converting to number
            value = string.gsub(value, "K", "000")                                          -- convert K to 000
            value = string.gsub(value, "M", "000000")                                       -- convert M to 000000
            value = string.gsub(value, "B", "000000000")                                    -- convert B to 000000000
        else
            self:log("No value found in loot window text", "debug")
        end
        return tonumber(value) or 0
    else
        self:log("No loot window text data available", "debug")
    end
    return 0
end

---Parses kill duration into from string to number
---@param time string
---@return integer
function Utils:parseCompletionTime(time)
    local minutes, seconds, hundredths = time:match("(%d+):(%d+)%.?(%d?)")
    if not minutes then return 0 end

    minutes = tonumber(minutes) or 0
    seconds = tonumber(seconds) or 0
    hundredths = tonumber(hundredths) or 0 -- will be 0 if empty string

    return (minutes * 60 * 1000) + (seconds * 1000) + (hundredths * 100)
end

---Returns fastest, slowest and average kill times
---@param log table
---@return string, string, string
function Utils:getKillStats(log)
    -- handle empty data
    if #log == 0 then
        return "N/A", "N/A", "N/A"
    end

    local durations = {}
    local total = 0
    local validKills = 0 -- counter for kills with known durations

    for _, kill in ipairs(log) do
        -- Skip kills with unknown duration
        if kill.fightDuration ~= "UNKNOWN" then
            local ms = self:parseCompletionTime(kill.fightDuration)
            table.insert(durations, ms)
            total = total + ms
            validKills = validKills + 1
        end
    end

    -- Handle case where all kills were unknown
    if validKills == 0 then
        return "N/A", "N/A", "N/A"
    end

    local fastestMs = math.min(table.unpack(durations))
    local slowestMs = math.max(table.unpack(durations))
    local averageMs = total / validKills

    return self:formatKillDuration(fastestMs),
        self:formatKillDuration(slowestMs),
        self:formatKillDuration(averageMs)
end

------------------------------------------
--# INTERFACE CHECKS
------------------------------------------

--- Checks for active boss instance timer
--- @return boolean
function Utils:bossTimerExists()
    local instanceTimer = {
        { 861, 0, -1, -1, 0 }, { 861, 2, -1, 0, 0 },
        { 861, 4, -1, 2,  0 }, { 861, 8, -1, 4, 0 }
    }
    local result = API.ScanForInterfaceTest2Get(false, instanceTimer)
    return result and #result > 0 and #result[1].textids > 0
end

------------------------------------------
--# UI & DATA FORMATTING
------------------------------------------

--- Generates display table from variables
--- @param title string
--- @param variables table
--- @return table
function Utils:generateTable(title, variables)
    local result = { { title, "" } }

    local function processTable(tbl, path, res)
        for k, v in pairs(tbl) do
            local keyPath = type(k) == "number" and path .. "[" .. k .. "]" or
                (path ~= "" and path .. "." .. tostring(k)) or tostring(k)

            if type(v) == "table" then
                if not Utils:isArray(v) then
                    processTable(v, keyPath, res)
                end
            else
                table.insert(res, { "- " .. keyPath, tostring(v) })
            end
        end
    end

    processTable(variables, "", result)
    return result
end

--- Checks if table is an array
--- @param tbl table
--- @return boolean
function Utils:isArray(tbl)
    if type(tbl) ~= "table" then return false end
    local count = 0
    for k in pairs(tbl) do
        if type(k) ~= "number" or k ~= count + 1 then
            return false
        end
        count = count + 1
    end
    return true
end

------------------------------------------
--# DISCORD
------------------------------------------

function Utils:sendDiscord(send, mention, bossName, dropData, killData, scriptVersion, authorImage)
    if send then
        --- @diagnostic disable-next-line
        local embed = DiscordEmbed.new()
            :SetTitle(string.format("Congratulations! You found %s %s", dropData.prefix and "a" or "", dropData.name))
            :SetDescription("You've managed to strip " .. bossName .. " of a shiny **" .. dropData.name .. "**!")
            :SetColor(10181046)
            :SetTimestamp(tostring(os.time()))
            --- @diagnostic disable-next-line
            :SetThumbnail(EmbedImage.new(dropData.thumbnail, dropData.thumbnail, 50, 50))
            --- @diagnostic disable-next-line
            :SetAuthor(EmbedAuthor.new(string.format("[%s] Sonson's %s", scriptVersion, bossName), "",
                authorImage or "https://avatars.githubusercontent.com/u/206812154?s=200&v=4", ""))
            --- @diagnostic disable-next-line
            :AddField(EmbedField.new("Kill Count", killData.killCount, true))
            --- @diagnostic disable-next-line
            :AddField(EmbedField.new("Fight Duration", killData.fightDuration, true))
            --- @diagnostic disable-next-line
            :AddField(EmbedField.new("Runtime", killData.runtime, true))
            --- @diagnostic disable-next-line
            :SetFooter(EmbedFooter.new("Thank you for using Sonson's scripts",
                "https://avatars.githubusercontent.com/u/206812154?s=200&v=4", ""))

        Discord:SendEmbedEx(embed, mention)
    end
end

return Utils
