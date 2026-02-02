--- @module 'rasial.gui'
--- @version 1.1.0
--- ImGui-based GUI for Rasial script
--- Inspired by m-qq/rocks mining GUI patterns

local API = require("api")
local Rotations = require("rasial.rotations")

local RasialGUI = {}

------------------------------------------
--# STATE MANAGEMENT
------------------------------------------

RasialGUI.open = true
RasialGUI.started = false
RasialGUI.paused = false
RasialGUI.stopped = false
RasialGUI.cancelled = false
RasialGUI.warnings = {}
RasialGUI.selectConfigTab = true
RasialGUI.selectInfoTab = false
RasialGUI.selectWarningsTab = false

------------------------------------------
--# CONFIGURATION STATE
------------------------------------------

RasialGUI.config = {
    rotationIndex = 0,
    bankPin = "",
    waitForFullHp = true,
    useDiscord = true,
    -- Health thresholds (percent)
    healthSolid = 0,
    healthJellyfish = 40,
    healthPotion = 40,
    healthSpecial = 60,
    -- Prayer thresholds
    prayerNormal = 200,
    prayerCritical = 10,
    prayerSpecial = 600,
    -- War's Retreat options
    summonConjures = true,
    useAdrenCrystal = true,
    surgeDiveChance = 100,
    -- Debug options
    debugMain = true,
    debugTimer = false,
    debugRotation = false,
    debugPlayer = false,
    debugPrayer = false,
}

------------------------------------------
--# ROTATION PRESETS
------------------------------------------

local function buildRotationList()
    local keys, names = {}, {}
    for key in pairs(Rotations) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for i, key in ipairs(keys) do
        names[i] = key
    end
    return keys, names
end

local rotationKeys, rotationNames = buildRotationList()

------------------------------------------
--# NECROMANCY PURPLE THEME COLORS
------------------------------------------

-- Primary purple shades
local PURPLE = {
    dark   = { 0.09, 0.09, 0.09 }, -- Window background (dark gray)
    medium = { 0.18, 0.08, 0.25 }, -- Frames, tabs
    light  = { 0.35, 0.18, 0.45 }, -- Hover states
    bright = { 0.55, 0.28, 0.65 }, -- Active/accent
    glow   = { 0.75, 0.45, 0.85 }, -- Highlights
}

local STATE_COLORS = {
    ["War's Retreat"]  = { 0.3, 0.8, 0.4 },
    ["Rasial Lobby"]   = { 0.6, 0.4, 0.8 },
    ["Phase 1"]        = { 1.0, 0.8, 0.2 },
    ["Phase 2"]        = { 1.0, 0.5, 0.3 },
    ["Looting"]        = { 0.8, 0.5, 1.0 },
    ["Teleporting"]    = { 0.6, 0.9, 1.0 },
    ["Dead"]           = { 0.5, 0.5, 0.5 },
    ["Idle"]           = { 0.7, 0.7, 0.7 },
    ["Paused"]         = { 1.0, 0.8, 0.2 },
    ["Entering Fight"] = { 0.5, 0.3, 0.7 },
}

local HEALTH_COLORS = {
    high   = { 0.3, 0.85, 0.45 },
    medium = { 1.0, 0.75, 0.2 },
    low    = { 1.0, 0.3, 0.3 },
}

------------------------------------------
--# CONFIG FILE MANAGEMENT
------------------------------------------

local CONFIG_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
local CONFIG_PATH = CONFIG_DIR .. "rasial.config.json"

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveConfigToFile(cfg)
    local data = {
        RotationPreset = rotationKeys[cfg.rotationIndex + 1],
        BankPin = cfg.bankPin,
        WaitForFullHp = cfg.waitForFullHp,
        UseDiscord = cfg.useDiscord,
        HealthSolid = cfg.healthSolid,
        HealthJellyfish = cfg.healthJellyfish,
        HealthPotion = cfg.healthPotion,
        HealthSpecial = cfg.healthSpecial,
        PrayerNormal = cfg.prayerNormal,
        PrayerCritical = cfg.prayerCritical,
        PrayerSpecial = cfg.prayerSpecial,
        SummonConjures = cfg.summonConjures,
        UseAdrenCrystal = cfg.useAdrenCrystal,
        SurgeDiveChance = cfg.surgeDiveChance,
        DebugMain = cfg.debugMain,
        DebugTimer = cfg.debugTimer,
        DebugRotation = cfg.debugRotation,
        DebugPlayer = cfg.debugPlayer,
        DebugPrayer = cfg.debugPrayer,
    }
    local ok, json = pcall(API.JsonEncode, data)
    if not ok or not json then
        API.printlua("Failed to encode config JSON", 4, false)
        return
    end
    os.execute('mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" 2>nul')
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        API.printlua("Failed to open config file for writing", 4, false)
        return
    end
    file:write(json)
    file:close()
    API.printlua("Config saved", 0, false)
end

local function findRotationIndex(key)
    if not key then return 0 end
    for i, k in ipairs(rotationKeys) do
        if k == key then return i - 1 end
    end
    return 0
end

------------------------------------------
--# PUBLIC FUNCTIONS
------------------------------------------

function RasialGUI.reset()
    RasialGUI.open = true
    RasialGUI.started = false
    RasialGUI.paused = false
    RasialGUI.stopped = false
    RasialGUI.cancelled = false
    RasialGUI.warnings = {}
    RasialGUI.selectConfigTab = true
    RasialGUI.selectInfoTab = false
    RasialGUI.selectWarningsTab = false
end

function RasialGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end

    local c = RasialGUI.config
    c.rotationIndex = findRotationIndex(saved.RotationPreset)
    if type(saved.BankPin) == "string" then c.bankPin = saved.BankPin end
    if type(saved.WaitForFullHp) == "boolean" then c.waitForFullHp = saved.WaitForFullHp end
    if type(saved.UseDiscord) == "boolean" then c.useDiscord = saved.UseDiscord end
    if type(saved.HealthSolid) == "number" then c.healthSolid = saved.HealthSolid end
    if type(saved.HealthJellyfish) == "number" then c.healthJellyfish = saved.HealthJellyfish end
    if type(saved.HealthPotion) == "number" then c.healthPotion = saved.HealthPotion end
    if type(saved.HealthSpecial) == "number" then c.healthSpecial = saved.HealthSpecial end
    if type(saved.PrayerNormal) == "number" then c.prayerNormal = saved.PrayerNormal end
    if type(saved.PrayerCritical) == "number" then c.prayerCritical = saved.PrayerCritical end
    if type(saved.PrayerSpecial) == "number" then c.prayerSpecial = saved.PrayerSpecial end
    if type(saved.SummonConjures) == "boolean" then c.summonConjures = saved.SummonConjures end
    if type(saved.UseAdrenCrystal) == "boolean" then c.useAdrenCrystal = saved.UseAdrenCrystal end
    if type(saved.SurgeDiveChance) == "number" then c.surgeDiveChance = saved.SurgeDiveChance end
    if type(saved.DebugMain) == "boolean" then c.debugMain = saved.DebugMain end
    if type(saved.DebugTimer) == "boolean" then c.debugTimer = saved.DebugTimer end
    if type(saved.DebugRotation) == "boolean" then c.debugRotation = saved.DebugRotation end
    if type(saved.DebugPlayer) == "boolean" then c.debugPlayer = saved.DebugPlayer end
    if type(saved.DebugPrayer) == "boolean" then c.debugPrayer = saved.DebugPrayer end
end

function RasialGUI.getConfig()
    local c = RasialGUI.config
    return {
        rotationPreset = rotationKeys[c.rotationIndex + 1],
        bankPin = c.bankPin,
        waitForFullHp = c.waitForFullHp,
        useDiscord = c.useDiscord,
        healthSolid = c.healthSolid,
        healthJellyfish = c.healthJellyfish,
        healthPotion = c.healthPotion,
        healthSpecial = c.healthSpecial,
        prayerNormal = c.prayerNormal,
        prayerCritical = c.prayerCritical,
        prayerSpecial = c.prayerSpecial,
        summonConjures = c.summonConjures,
        useAdrenCrystal = c.useAdrenCrystal,
        surgeDiveChance = c.surgeDiveChance,
        debugMain = c.debugMain,
        debugTimer = c.debugTimer,
        debugRotation = c.debugRotation,
        debugPlayer = c.debugPlayer,
        debugPrayer = c.debugPrayer,
    }
end

function RasialGUI.addWarning(msg)
    RasialGUI.warnings[#RasialGUI.warnings + 1] = msg
    if #RasialGUI.warnings > 50 then
        table.remove(RasialGUI.warnings, 1)
    end
end

function RasialGUI.clearWarnings()
    RasialGUI.warnings = {}
end

function RasialGUI.isPaused()
    return RasialGUI.paused
end

function RasialGUI.isStopped()
    return RasialGUI.stopped
end

function RasialGUI.isCancelled()
    return RasialGUI.cancelled
end

------------------------------------------
--# HELPER FUNCTIONS
------------------------------------------

local function row(label, value, lr, lg, lb, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, lr or 1.0, lg or 1.0, lb or 1.0, 1.0)
    ImGui.TextWrapped(label)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function progressBar(progress, height, text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, r * 0.7, g * 0.7, b * 0.7, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, r * 0.2, g * 0.2, b * 0.2, 0.8)
    ImGui.ProgressBar(progress, -1, height, text)
    ImGui.PopStyleColor(2)
end

local function label(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.9, 0.9, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, PURPLE.glow[1], PURPLE.glow[2], PURPLE.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.55, 0.65, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return string.format("%d", n)
end

local function getHealthColor(pct)
    --[[
    if pct > 0.6 then return HEALTH_COLORS.high end
    if pct > 0.3 then return HEALTH_COLORS.medium end
    return HEALTH_COLORS.low
    ]]
    return PURPLE.glow
end

------------------------------------------
--# TAB DRAWING FUNCTIONS
------------------------------------------

local function drawConfigTab(cfg, gui)
    if gui.started then
        -- Show summary and control buttons when running
        local statusText = gui.paused and "PAUSED" or "Running"
        local statusColor = gui.paused and { 1.0, 0.8, 0.2 } or { 0.4, 0.8, 0.4 }
        local tw = ImGui.CalcTextSize(statusText)
        local rw = ImGui.GetContentRegionAvail()
        --ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (rw - tw) * 0.5)
        ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
        ImGui.TextWrapped(statusText)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        ImGui.Separator()

        if ImGui.BeginTable("##cfgsummary", 2) then
            ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
            ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)
            row("Rotation", rotationNames[cfg.rotationIndex + 1])
            row("Discord", cfg.useDiscord and "Enabled" or "Disabled")
            row("Wait Full HP", cfg.waitForFullHp and "Yes" or "No")
            ImGui.EndTable()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Pause/Resume button (Secondary - subtle with border effect)
        if gui.paused then
            -- Resume as secondary button - subtle green
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.5, 0.2, 0.2) -- Very low opacity
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.65, 0.25, 0.35)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.75, 0.15, 0.5)
            if ImGui.Button("Resume Script##resume", -1, 28) then
                gui.paused = false
            end
            ImGui.PopStyleColor(3)
        else
            -- Pause as secondary button
            ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)
            if ImGui.Button("Pause Script##pause", -1, 28) then
                gui.paused = true
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Spacing()

        -- Stop button (Primary - matches the purple theme)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9) -- Deep red, high opacity
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)
        if ImGui.Button("Stop Script##stop", -1, 28) then
            gui.stopped = true
        end
        ImGui.PopStyleColor(3)
        return
    end

    -- Pre-start configuration
    ImGui.PushItemWidth(-1)

    -- === ROTATION SECTION ===
    sectionHeader("Combat Rotation")
    flavorText("Select your ability rotation preset for the fight.")
    ImGui.Spacing()
    label("Rotation Preset")
    local rotChanged, newRotIdx = ImGui.Combo("##rotation", cfg.rotationIndex, rotationNames, 10)
    if rotChanged then cfg.rotationIndex = newRotIdx end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === GENERAL SETTINGS ===
    sectionHeader("General Settings")
    flavorText("Banking and notification preferences.")
    ImGui.Spacing()

    label("Bank PIN")
    local pinChanged, newPin = ImGui.InputText("##bankpin", cfg.bankPin, 0)
    if pinChanged then cfg.bankPin = newPin end

    ImGui.Spacing()

    local waitChanged, waitVal = ImGui.Checkbox("Wait for Full HP##waitfullhp", cfg.waitForFullHp)
    if waitChanged then cfg.waitForFullHp = waitVal end

    local discordChanged, discordVal = ImGui.Checkbox("Discord Notifications##discord", cfg.useDiscord)
    if discordChanged then cfg.useDiscord = discordVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === WAR'S RETREAT OPTIONS ===
    sectionHeader("War's Retreat")
    flavorText("Pre-fight preparation at War's Retreat.")
    ImGui.Spacing()

    local conjuresChanged, conjuresVal = ImGui.Checkbox("Summon Conjures##summonconjures", cfg.summonConjures)
    if conjuresChanged then cfg.summonConjures = conjuresVal end

    local adrenChanged, adrenVal = ImGui.Checkbox("Use Adrenaline Crystal##useadren", cfg.useAdrenCrystal)
    if adrenChanged then cfg.useAdrenCrystal = adrenVal end

    label("Surge + Dive Chance (%)")
    local surgeChanged, surgeVal = ImGui.SliderInt("##surgedive", cfg.surgeDiveChance, 0, 100, "%d%%")
    if surgeChanged then cfg.surgeDiveChance = surgeVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === HEALTH THRESHOLDS ===
    sectionHeader("Health Thresholds")
    flavorText("When to eat food and use healing items.")
    ImGui.Spacing()

    label("Solid Food (%)")
    local solidChanged, solidVal = ImGui.SliderInt("##healthsolid", cfg.healthSolid, 0, 100, "%d%%")
    if solidChanged then cfg.healthSolid = solidVal end

    label("Jellyfish (%)")
    local jellyChanged, jellyVal = ImGui.SliderInt("##healthjelly", cfg.healthJellyfish, 0, 100, "%d%%")
    if jellyChanged then cfg.healthJellyfish = jellyVal end

    label("Healing Potion (%)")
    local potionChanged, potionVal = ImGui.SliderInt("##healthpotion", cfg.healthPotion, 0, 100, "%d%%")
    if potionChanged then cfg.healthPotion = potionVal end

    label("Enhanced Excalibur (%)")
    local specialChanged, specialVal = ImGui.SliderInt("##healthspecial", cfg.healthSpecial, 0, 100, "%d%%")
    if specialChanged then cfg.healthSpecial = specialVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === PRAYER THRESHOLDS ===
    sectionHeader("Prayer Thresholds")
    flavorText("When to restore prayer points.")
    ImGui.Spacing()

    label("Normal Restore (points)")
    local prayNormChanged, prayNormVal = ImGui.SliderInt("##prayernormal", cfg.prayerNormal, 0, 999, "%d")
    if prayNormChanged then cfg.prayerNormal = prayNormVal end

    label("Critical (%)")
    local prayCritChanged, prayCritVal = ImGui.SliderInt("##prayercritical", cfg.prayerCritical, 0, 100, "%d%%")
    if prayCritChanged then cfg.prayerCritical = prayCritVal end

    label("Elven Shard (points)")
    local praySpecChanged, praySpecVal = ImGui.SliderInt("##prayerspecial", cfg.prayerSpecial, 0, 999, "%d")
    if praySpecChanged then cfg.prayerSpecial = praySpecVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === DEBUG OPTIONS ===
    sectionHeader("Debug Options")
    flavorText("Enable logging for troubleshooting.")
    ImGui.Spacing()

    local dbgMainChanged, dbgMainVal = ImGui.Checkbox("Main Script##debugmain", cfg.debugMain)
    if dbgMainChanged then cfg.debugMain = dbgMainVal end

    local dbgTimerChanged, dbgTimerVal = ImGui.Checkbox("Timer System##debugtimer", cfg.debugTimer)
    if dbgTimerChanged then cfg.debugTimer = dbgTimerVal end

    local dbgRotChanged, dbgRotVal = ImGui.Checkbox("Rotation Manager##debugrotation", cfg.debugRotation)
    if dbgRotChanged then cfg.debugRotation = dbgRotVal end

    local dbgPlayerChanged, dbgPlayerVal = ImGui.Checkbox("Player Manager##debugplayer", cfg.debugPlayer)
    if dbgPlayerChanged then cfg.debugPlayer = dbgPlayerVal end

    local dbgPrayerChanged, dbgPrayerVal = ImGui.Checkbox("Prayer Flicker##debugprayer", cfg.debugPrayer)
    if dbgPrayerChanged then cfg.debugPrayer = dbgPrayerVal end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Start button (purple themed)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.2, 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.3, 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.6, 0.35, 0.7, 1.0)
    if ImGui.Button("Start Rasial##start", -1, 32) then
        saveConfigToFile(gui.config)
        gui.started = true
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()

    -- Cancel button
    ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)
    if ImGui.Button("Cancel##cancel", -1, 28) then
        gui.cancelled = true
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab(data)
    -- State display
    local stateText = data.state or "Idle"
    if RasialGUI.paused then stateText = "Paused" end
    local sc = STATE_COLORS[stateText] or { 0.7, 0.7, 0.7 }
    local textWidth = ImGui.CalcTextSize(stateText)
    local regionWidth = ImGui.GetContentRegionAvail()
    --ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (regionWidth - textWidth) * 0.5)
    --ImGui.SetCursorPosX(0)
    ImGui.PushStyleColor(ImGuiCol.Text, sc[1], sc[2], sc[3], 1.0)
    ImGui.TextWrapped(stateText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Boss health bar
    if data.bossHealth and data.bossMaxHealth and data.bossHealth > 0 then
        local pct = math.max(0, math.min(1, data.bossHealth / data.bossMaxHealth))
        local hc = getHealthColor(pct)
        local healthPercent = (data.bossHealth / data.bossMaxHealth) * 100
        local healthText = string.format("Rasial: %s / %s  (%.2f%%)",
            formatNumber(data.bossHealth),
            formatNumber(data.bossMaxHealth),
            healthPercent)
        progressBar(pct, 28, healthText, hc[1], hc[2], hc[3])

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Info table
    if ImGui.BeginTable("##info", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Location", data.location or "Unknown")
        row("Status", data.status or "Idle")
        if data.killTimer then
            row("Kill Timer", data.killTimer)
        end

        ImGui.EndTable()
    end

    -- Active buffs
    if data.activeBuffs and #data.activeBuffs > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        sectionHeader("Active Buffs")

        for _, buff in ipairs(data.activeBuffs) do
            ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.75, 0.75, 1.0)
            ImGui.TextWrapped("[+] " .. buff)
            ImGui.PopStyleColor(1)
        end
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Metrics section
    if ImGui.BeginTable("##metrics", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Kills", string.format("%d (%s/hr)", data.killCount or 0, data.killsPerHour or "0"))
        row("GP", string.format("%s (%s/hr)", formatNumber(data.gp or 0), formatNumber(data.gpPerHour or 0)))

        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Kill times
    if ImGui.BeginTable("##killtimes", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Fastest Kill", data.fastestKill or "--", 1.0, 1.0, 1.0, 0.3, 0.85, 0.45)
        row("Slowest Kill", data.slowestKill or "--", 1.0, 1.0, 1.0, 1.0, 0.5, 0.3)
        row("Average Kill", data.averageKill or "--")

        ImGui.EndTable()
    end

    if data.killData and #data.killData > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.BeginTable("##recentkills", 2) then
            ImGui.TableSetupColumn("kc", ImGuiTableColumnFlags.WidthStretch, 0.3)
            ImGui.TableSetupColumn("killtime", ImGuiTableColumnFlags.WidthStretch, 0.7)

            label("Recent Kills")

            row("Kill Count", "Kill Duration", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

            for i = math.max(1, #data.killData - 4), #data.killData do
                local kill = data.killData[i]
                row(string.format("[%s]", i), kill.fightDuration, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end

            ImGui.EndTable()
        end
    end

    -- Unique drops
    if data.uniquesLooted and #data.uniquesLooted > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, PURPLE.glow[1], PURPLE.glow[2], PURPLE.glow[3], 1.0)
        ImGui.TextWrapped("Unique Drops")
        ImGui.PopStyleColor(1)

        for _, drop in ipairs(data.uniquesLooted) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
            ImGui.TextWrapped(drop[1])
            ImGui.PopStyleColor(1)
        end
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.65, 1.0)
        ImGui.TextWrapped("No warnings.")
        ImGui.PopStyleColor(1)
        return
    end

    for _, warning in ipairs(gui.warnings) do
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
        ImGui.TextWrapped("! " .. warning)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.45, 0.1, 0.8)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.55, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.8, 0.7, 0.1, 1.0)
    if ImGui.Button("Dismiss Warnings##clear", -1, 25) then
        gui.warnings = {}
    end
    ImGui.PopStyleColor(3)
end

local function drawContent(data, gui)
    if ImGui.BeginTabBar("##maintabs", 0) then
        local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectConfigTab = false
        if ImGui.BeginTabItem("Config###config", nil, configFlags) then
            ImGui.Spacing()
            drawConfigTab(gui.config, gui)
            ImGui.EndTabItem()
        end

        if gui.started then
            local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectInfoTab = false
            if ImGui.BeginTabItem("Info###info", nil, infoFlags) then
                ImGui.Spacing()
                drawInfoTab(data)
                ImGui.EndTabItem()
            end
        end

        if #gui.warnings > 0 then
            local warningLabel = "Warnings (" .. #gui.warnings .. ")###warnings"
            local warnFlags = gui.selectWarningsTab and ImGuiTabItemFlags.SetSelected or 0
            if ImGui.BeginTabItem(warningLabel, nil, warnFlags) then
                gui.selectWarningsTab = false
                ImGui.Spacing()
                drawWarningsTab(gui)
                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end
end

------------------------------------------
--# MAIN DRAW FUNCTION
------------------------------------------

function RasialGUI.draw(data)
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    -- Necromancy Purple Theme
    ImGui.PushStyleColor(ImGuiCol.WindowBg, PURPLE.dark[1], PURPLE.dark[2], PURPLE.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, PURPLE.medium[1] * 0.6, PURPLE.medium[2] * 0.6, PURPLE.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, PURPLE.medium[1], PURPLE.medium[2], PURPLE.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, PURPLE.light[1], PURPLE.light[2], PURPLE.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, PURPLE.medium[1] * 0.7, PURPLE.medium[2] * 0.7, PURPLE.medium[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, PURPLE.light[1], PURPLE.light[2], PURPLE.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, PURPLE.bright[1] * 0.7, PURPLE.bright[2] * 0.7, PURPLE.bright[3] * 0.7, 1.0)
    -- Frame/Input styling for white text
    ImGui.PushStyleColor(ImGuiCol.FrameBg, PURPLE.medium[1] * 0.5, PURPLE.medium[2] * 0.5, PURPLE.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, PURPLE.light[1] * 0.7, PURPLE.light[2] * 0.7, PURPLE.light[3] * 0.7,
        1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, PURPLE.bright[1] * 0.5, PURPLE.bright[2] * 0.5, PURPLE.bright[3] * 0.5,
        1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, PURPLE.bright[1], PURPLE.bright[2], PURPLE.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, PURPLE.glow[1], PURPLE.glow[2], PURPLE.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, PURPLE.glow[1], PURPLE.glow[2], PURPLE.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, PURPLE.medium[1], PURPLE.medium[2], PURPLE.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, PURPLE.light[1], PURPLE.light[2], PURPLE.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, PURPLE.bright[1], PURPLE.bright[2], PURPLE.bright[3], 1.0)
    -- Text color white
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local titleText = "Rasial - " .. API.ScriptRuntimeString() .. "###Rasial"
    local visible = ImGui.Begin(titleText, 0)

    if visible then
        local ok, err = pcall(drawContent, data, RasialGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(17)
    ImGui.End()

    return RasialGUI.open
end

return RasialGUI
