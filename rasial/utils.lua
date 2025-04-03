local API = require("api")
local Utils = {}

Utils.debug = false

---places t2 in t1
---@param t1 table
---@param t2 table
function Utils.tableConcat(t1, t2)
    for i = 1, #t2 do t1[#t1 + 1] = t2[i] end
end

---quick fix for something
---@param t1 table
---@param t2 table
---@return table
function Utils.virtualTableConcat(t1, t2)
    local temp = {}
    table.move(t1, 1, #t1, 1, temp)
    table.move(t2, 1, #t2, #t1 + 1, temp)
    return temp
end

---formats os.time() to string
---@param time number
---@return string [hh:mm:ss]
function Utils.formatElapsedTime(time)
    local elapsedTime = time - os.time()
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

---when debugging is turned on, will show debug specific messages
---@param message string
function Utils.debugLog(message) if Utils.debug then print("[RASIAL]: "..message) end end

---terminates the script
function Utils.terminate(...)
    local args = {...}
    if #args > 0 then
        for _, message in ipairs(args) do
            print("[RASIAL]: ".. tostring(message))
        end
    end
    print("[RASIAL]: Terminating your session.")
    API.Write_LoopyLoop(false)
end

---uses ability from ability bar
---@param abilityName string
---@return boolean
function Utils.useAbility(abilityName)
    if #API.GetABs_names({abilityName}) > 0 and API.GetABs_names({abilityName})[1].enabled then
        return API.DoAction_Ability(abilityName, 1, API.OFF_ACT_GeneralInterface_route, true)
    else return false end
end

---returns first AllObject
---@param objID number
---@param distance number
---@param objType number
---@return AllObject | boolean
function Utils.find(objID, objType, distance)
    local allObjects = API.GetAllObjArray1({ objID }, distance or 25, { objType })
    return allObjects[1] or false
end

---returns first AllObject
---@param objID number
---@param distance number
---@param objType number
---@return AllObject
function Utils.findAll(objID, objType, distance)
    local allObjects = API.GetAllObjArray1({ objID }, distance or 25, { objType })
    return allObjects or false
end

---checks if the player is within range of a specific tile
---@param x number
---@param y number
---@param z number?
---@param range number
function Utils.atLocation(x, y, range, z)
    return API.PInArea(x, range, y, range, 0 or z)
end

---checks if the player is not moving and has anim == 0
---@param self PlayerManager
---@return boolean
function Utils.playerIsIdle(self)
    return not self.state.moving and self.state.animation == 0
end

---checks the palyer's inventory to see if they have all items listed in loadout
---courtesy of Aria
---@return boolean
function Utils.hasAllItems(invent)
    for i = 1, #invent do
        if invent[i].id == nil then
            Utils.terminate("[RASIAL]: Undefined item ID in loadout.")
            return false
        end
        if API.InvItemcount_1(invent[i].id) < invent[i].amount and API.InvStackSize(invent[i].id) < invent[i].amount then
            return false
        end
    end
    return true
end

---@deprecated
---gets current spellbook
---@return string 
function Utils.getSpellbook()
    local spellbooks = {
        [1] = "Normal",
        [2] = "Ancients",
        [3] = "Lunar",
    }
    local spellbookVarbitValue = API.VB_FindPSettinOrder(4).state
    return spellbooks[spellbookVarbitValue] or "UNKNOWN"
end

---used for things like kills per hour and rares per hour
---@param value number the thing you want per hr
---@param startTime number os.time() snapshot of when the script was started
---@return string
function Utils.valuePerHour(value, startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = elapsedTime/3600
    return string.format("%.2f", value/hours)
end

---sends a discord custom discord embed with images and more
---70% deepseek :^) 
---@param content any
---@param params any
function Utils.sendDiscordWebhook(content, discordWebhookUrl, params)
    -- default parameters
    params = params or {}
    local tts = params.tts or false
    local embeds = params.embeds
    local components = params.components or {}
    local actions = params.actions or {}

    -- escape JSON special characters
    local function escapeJson(str)
        if not str then return nil end
        return str:gsub("\\", "\\\\")
                 :gsub('"', '\\"')
                 :gsub("\n", "\\n")
                 :gsub("\r", "\\r")
                 :gsub("\t", "\\t")
    end

    -- build an embed field object
    local function buildEmbedField(field)
        if not field or not field.name or not field.value then return nil end
        return {
            name = escapeJson(field.name),
            value = escapeJson(field.value),
            inline = field.inline or false
        }
    end

    -- build an author object
    local function buildAuthor(author)
        if not author or not author.name then return nil end
        return {
            name = escapeJson(author.name),
            icon_url = author.icon_url,
            url = author.url
        }
    end

    -- build a footer object
    local function buildFooter(footer)
        if not footer or not footer.text then return nil end
        return {
            text = escapeJson(footer.text),
            icon_url = footer.icon_url
        }
    end

    -- build a thumbnail object
    local function buildThumbnail(thumbnail)
        if not thumbnail or not thumbnail.url then return nil end
        return {
            url = thumbnail.url
        }
    end

    -- build an embed object
    local function buildEmbed(embed)
        if not embed then return nil end

        local builtEmbed = {}

        if embed.title then builtEmbed.title = escapeJson(embed.title) end
        if embed.description then builtEmbed.description = escapeJson(embed.description) end
        if embed.color then builtEmbed.color = embed.color end
        if embed.url then builtEmbed.url = embed.url end

        if embed.author then builtEmbed.author = buildAuthor(embed.author) end
        if embed.footer then builtEmbed.footer = buildFooter(embed.footer) end
        if embed.thumbnail then builtEmbed.thumbnail = buildThumbnail(embed.thumbnail) end

        if embed.fields then
            builtEmbed.fields = {}
            for _, field in ipairs(embed.fields) do
                local builtField = buildEmbedField(field)
                if builtField then table.insert(builtEmbed.fields, builtField) end
            end
            if #builtEmbed.fields == 0 then builtEmbed.fields = nil end
        end

        return builtEmbed
    end

    -- prepare the payload data
    local payload = {
        content = escapeJson(content),
        tts = tts,
        components = components,
        actions = actions
    }

    -- process embeds if provided
    if embeds then
        payload.embeds = {}
        for _, embed in ipairs(embeds) do
            local builtEmbed = buildEmbed(embed)
            if builtEmbed then table.insert(payload.embeds, builtEmbed) end
        end
        if #payload.embeds == 0 then payload.embeds = nil end
    end

    -- convert to JSON string
    local jsonPayload = API.JsonEncode(payload)

    -- escape for command line
    local commandPayload = jsonPayload:gsub('"', '\\"')

    -- build and execute the curl command
    local command = 'curl.exe -X POST -H "Content-Type: application/json" ' ..
                    '-d "' .. commandPayload .. '" ' ..
                    '"' .. discordWebhookUrl .. '"'

    print("[DEBUG] Final command:\n" .. command)
    return os.execute(command)
end


---parses kill duration into from string to number
---@param time string
---@return integer
function Utils.parseCompletionTime(time)
    local minutes, seconds, hundredths = time:match("(%d+):(%d+)%.(%d)")
    if not minutes then return 0 end

    return (tonumber(minutes) * 60 * 1000) + (tonumber(seconds) * 1000) + (tonumber(hundredths) * 100)
end

---formats number back to kill time duration [00:00.0]
---@param ms integer
---@return string
function Utils.formatKillDuration(ms)
    local minutes = math.floor(ms / 60000)
    ms = ms % 60000
    local seconds = math.floor(ms / 1000)
    local hundredths = math.floor((ms % 1000) / 10 + 0.5) -- Rounds to nearest .01 seconds

    -- Handle overflow (e.g., 100ms becomes 1.00s)
    if hundredths >= 100 then
        seconds = seconds + 1
        hundredths = hundredths - 100
    end
    if seconds >= 60 then
        minutes = minutes + 1
        seconds = seconds - 60
    end

    return string.format("%02d:%02d.%1d", minutes, seconds, hundredths or 0)
end


function Utils.getKillStats(log)
    if #log == 0 then
        -- handle empty data
        return {
            fastestKillDuration = "N/A",
            slowestKillDuration = "N/A",
            averageKillDuration = "N/A"
        }
    end

    local durations = {}
    local total = 0

    -- Parse all durations
    for _, kill in ipairs(log) do
        local ms = Utils.parseCompletionTime(kill.fightDuration)
        table.insert(durations, ms)
        total = total + ms
    end

    -- Calculate stats
    local fastestMs = math.min(table.unpack(durations))
    local slowestMs = math.max(table.unpack(durations))
    local averageMs = total / #durations

    -- Format results
    return {
        fastestKillDuration = Utils.formatKillDuration(fastestMs),
        slowestKillDuration = Utils.formatKillDuration(slowestMs),
        averageKillDuration = Utils.formatKillDuration(averageMs)
    }
end

return Utils
