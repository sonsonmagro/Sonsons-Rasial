--- @module "Sonson's GUI Library"
--- @version 1.0.0
--- A reusable GUI library for building consistent, themeable ImGui interfaces.
--- This library provides a standardized set of UI widgets and theming utilities
--- that can be used across all scripts.
---@diagnostic disable: undefined-global
-- ImGui, ImGuiCol, ImGuiStyleVar, ImGuiCond, ImGuiTableColumnFlags, ImGuiTreeNodeFlags
-- are provided by the runtime environment
---@diagnostic disable: undefined-field
local API = require("api")

--------------------------------------------------------------------------------
-- MODULE DEFINITION
--------------------------------------------------------------------------------

--- @class GUILib
--- @field theme Theme The active theme configuration
--- @field state table<string, any> Shared state storage for widgets
local GUILib = {}
GUILib.__index = GUILib

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------

--- @class Theme
--- @field colors ThemeColors Color definitions for the theme
--- @field padding ThemePadding Padding values for various elements
--- @field window WindowConfig Window configuration defaults
--- @field style StyleConfig Style configuration for ImGui elements

--- @class ThemeColors
--- @field header number[] RGBA color for headers
--- @field label number[] RGBA color for labels
--- @field hint number[] RGBA color for hint/description text
--- @field separator number[] RGBA color for separators
--- @field accent number[] RGBA color for accent elements
--- @field success number[] RGBA color for success states
--- @field warning number[] RGBA color for warning states
--- @field error number[] RGBA color for error states
--- @field disabled number[] RGBA color for disabled elements
--- @field buttonText number[] RGBA color for primary button text

--- @class ThemePadding
--- @field frame number[] Frame padding {x, y}
--- @field window number[] Window padding {x, y}
--- @field item number[] Item spacing {x, y}

--- @class WindowConfig
--- @field width number Default window width
--- @field height number Default window height (0 for auto)
--- @field rounding number Window corner rounding

--- @class StyleConfig
--- @field frameRounding number Frame corner rounding
--- @field tabRounding number Tab corner rounding
--- @field buttonHeight number Default button height

--------------------------------------------------------------------------------
-- DEFAULT THEME
--------------------------------------------------------------------------------

--- Default dark theme with clean grays and gold accents on CTAs
--- @type Theme
local DEFAULT_THEME = {
    colors = {
        -- Text colors
        header = {0.95, 0.95, 0.95, 1.0}, -- Near-white headers
        label = {0.88, 0.88, 0.88, 1.0}, -- Light gray labels
        hint = {0.52, 0.52, 0.52, 1.0}, -- Muted gray hints
        separator = {0.28, 0.28, 0.28, 0.50}, -- Subtle gray separator
        -- Semantic colors
        accent = {0.93, 0.77, 0.40, 1.0}, -- Gold accent
        success = {0.33, 0.75, 0.42, 1.0}, -- Muted green
        warning = {0.88, 0.70, 0.22, 1.0}, -- Muted amber
        error = {0.85, 0.33, 0.33, 1.0}, -- Muted red
        disabled = {0.42, 0.42, 0.42, 0.60}, -- Gray disabled
        -- Window colors
        windowBg = {0.09, 0.09, 0.09, 0.97}, -- Deep dark gray
        frameBg = {0.15, 0.15, 0.15, 0.90}, -- Frame background
        frameBgHover = {0.21, 0.21, 0.21, 1.0}, -- Frame hover
        frameBgActive = {0.27, 0.27, 0.27, 1.0}, -- Frame active
        -- Tab colors
        tab = {0.12, 0.12, 0.12, 1.0}, -- Inactive tab (recessed)
        tabHovered = {0.18, 0.18, 0.18, 1.0}, -- Tab hover
        tabActive = {0.09, 0.09, 0.09, 1.0}, -- Active tab (flush with window)
        -- Button colors (primary CTA — gold)
        button = {0.80, 0.65, 0.30, 0.90}, -- Gold CTA
        buttonHover = {0.88, 0.74, 0.40, 1.0}, -- Gold hover
        buttonActive = {0.70, 0.56, 0.24, 1.0}, -- Gold pressed
        buttonText = {0.15, 0.12, 0.08, 1.0}, -- Dark text on gold
        -- Slider/Check colors (gold — interactive confirmations)
        sliderGrab = {0.93, 0.77, 0.40, 1.0}, -- Gold grab
        checkMark = {0.93, 0.77, 0.40, 1.0} -- Gold check
    },
    padding = {frame = {4, 4}, window = {14, 10}, item = {6, 4}},
    window = {
        width = 600,
        height = 0, -- 0 = auto height
        rounding = 6
    },
    style = {frameRounding = 4, tabRounding = 4, buttonHeight = 28}
}

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--- Creates a new GUILib instance with optional custom theme
--- @param customTheme? Theme Optional custom theme to merge with defaults
--- @return GUILib instance New GUILib instance
function GUILib.new(customTheme)
    local self = setmetatable({}, GUILib)

    -- Deep merge custom theme with defaults
    self.theme = GUILib._mergeThemes(DEFAULT_THEME, customTheme or {})
    self.state = {}

    return self
end

--- Deep merges two theme tables
--- @param base Theme Base theme
--- @param override Theme Override theme
--- @return Theme Merged theme
--- @private
function GUILib._mergeThemes(base, override)
    local result = {}
    for k, v in pairs(base) do
        if type(v) == "table" and type(override[k]) == "table" then
            result[k] = GUILib._mergeThemes(v, override[k])
        else
            result[k] = override[k] ~= nil and override[k] or v
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- THEME APPLICATION
--------------------------------------------------------------------------------

--- Pushes all theme colors and styles to ImGui
--- Call this before ImGui.Begin()
--- @return number colorCount Number of colors pushed (for PopStyleColor)
--- @return number styleCount Number of styles pushed (for PopStyleVar)
function GUILib:pushTheme()
    local c = self.theme.colors
    local p = self.theme.padding
    local s = self.theme.style
    local w = self.theme.window

    -- Push colors (17 total)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, c.windowBg[1], c.windowBg[2],
                         c.windowBg[3], c.windowBg[4])
    ImGui.PushStyleColor(ImGuiCol.TitleBg, c.frameBg[1] * 0.6,
                         c.frameBg[2] * 0.6, c.frameBg[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, c.frameBg[1], c.frameBg[2],
                         c.frameBg[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, c.separator[1], c.separator[2],
                         c.separator[3], c.separator[4])
    ImGui.PushStyleColor(ImGuiCol.Tab, c.tab[1], c.tab[2], c.tab[3], c.tab[4])
    ImGui.PushStyleColor(ImGuiCol.TabHovered, c.tabHovered[1], c.tabHovered[2],
                         c.tabHovered[3], c.tabHovered[4])
    ImGui.PushStyleColor(ImGuiCol.TabActive, c.tabActive[1], c.tabActive[2],
                         c.tabActive[3], c.tabActive[4])
    ImGui.PushStyleColor(ImGuiCol.FrameBg, c.frameBg[1], c.frameBg[2],
                         c.frameBg[3], c.frameBg[4])
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, c.frameBgHover[1],
                         c.frameBgHover[2], c.frameBgHover[3], c.frameBgHover[4])
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, c.frameBgActive[1],
                         c.frameBgActive[2], c.frameBgActive[3],
                         c.frameBgActive[4])
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, c.sliderGrab[1], c.sliderGrab[2],
                         c.sliderGrab[3], c.sliderGrab[4])
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, c.accent[1], c.accent[2],
                         c.accent[3], c.accent[4])
    ImGui.PushStyleColor(ImGuiCol.CheckMark, c.checkMark[1], c.checkMark[2],
                         c.checkMark[3], c.checkMark[4])
    ImGui.PushStyleColor(ImGuiCol.Header, c.frameBg[1], c.frameBg[2],
                         c.frameBg[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, c.frameBgHover[1],
                         c.frameBgHover[2], c.frameBgHover[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, c.frameBgActive[1],
                         c.frameBgActive[2], c.frameBgActive[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, c.label[1], c.label[2], c.label[3],
                         c.label[4])

    -- Push styles (5 total)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, p.window[1], p.window[2])
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, p.item[1], p.item[2])
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, s.frameRounding)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, w.rounding)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, s.tabRounding)

    return 17, 5
end

--- Pops all theme colors and styles from ImGui
--- Call this after ImGui.End()
--- @param colorCount? number Number of colors to pop (default: 17)
--- @param styleCount? number Number of styles to pop (default: 5)
function GUILib:popTheme(colorCount, styleCount)
    ImGui.PopStyleVar(styleCount or 5)
    ImGui.PopStyleColor(colorCount or 17)
end

--------------------------------------------------------------------------------
-- SPACING & LAYOUT UTILITIES
--------------------------------------------------------------------------------

--- Adds vertical spacing
--- @param count? number Number of spacing lines (default: 1)
function GUILib:spacing(count)
    count = count or 1
    for _ = 1, count do ImGui.Spacing() end
end

--- Renders a horizontal separator with optional spacing
--- @param spaceBefore? number Spacing lines before separator (default: 1)
--- @param spaceAfter? number Spacing lines after separator (default: 3)
function GUILib:separator(spaceBefore, spaceAfter)
    self:spacing(spaceBefore or 1)
    ImGui.Separator()
    self:spacing(spaceAfter or 3)
end

--- Begins a multi-column table layout.
--- Pass a single number for a two-column split (left width ratio), or a table
--- of stretch weights for N equal or weighted columns.
--- @param id string Unique table identifier
--- @param widths number|number[] Column width ratio or table of stretch weights (default: 0.5)
--- @return boolean success Whether the table was created
function GUILib:beginColumns(id, widths)
    if type(widths) == "number" then
        widths = {widths, 1 - widths}
    else
        widths = widths or {0.5, 0.5}
    end
    if ImGui.BeginTable(id, #widths) then
        for i, w in ipairs(widths) do
            ImGui.TableSetupColumn("##col" .. i,
                                   ImGuiTableColumnFlags.WidthStretch, w)
        end
        return true
    end
    return false
end

--- Ends a column table layout
function GUILib:endColumns() ImGui.EndTable() end

--- Begins a 2-column key/value info table.
--- Pairs with tableRow() for rows and endColumns() to close.
--- @param id string Unique table identifier
--- @param labelWidth? number Label column width ratio (default: 0.35)
--- @return boolean success Whether the table was created
function GUILib:beginInfoTable(id, labelWidth)
    labelWidth = labelWidth or 0.35
    if ImGui.BeginTable(id, 2) then
        ImGui.TableSetupColumn("##lbl", ImGuiTableColumnFlags.WidthStretch,
                               labelWidth)
        ImGui.TableSetupColumn("##val", ImGuiTableColumnFlags.WidthStretch,
                               1 - labelWidth)
        return true
    end
    return false
end

--- Advances to the next row and first column in a table
function GUILib:nextRow()
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
end

--- Advances to the next column in a table
function GUILib:nextColumn() ImGui.TableNextColumn() end

--- Places the next widget on the same line as the previous one
--- @param offsetX? number Horizontal offset from default position (default: 0)
function GUILib:sameLine(offsetX) ImGui.SameLine(offsetX or 0) end

--- Returns the available content area width in pixels
--- @return number width Available width
function GUILib:getContentWidth() return ImGui.GetContentRegionAvail() end

--- Calculates the rendered pixel width of a text string
--- @param text string The text to measure
--- @return number width Pixel width of the text
function GUILib:calcTextSize(text) return ImGui.CalcTextSize(text) end

--------------------------------------------------------------------------------
-- TEXT RENDERING
--------------------------------------------------------------------------------

--- Renders styled text with word wrapping
--- @param text string The text to display
--- @param textType? "header"|"label"|"hint"|"success"|"warning"|"error" Style type (default: "label")
function GUILib:text(text, textType)
    textType = textType or "label"
    local color = self.theme.colors[textType] or self.theme.colors.label
    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], color[4])
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

--- Renders styled text without word wrapping (for use after sameLine)
--- @param text string The text to display
--- @param textType? "header"|"label"|"hint"|"success"|"warning"|"error" Style type (default: "label")
function GUILib:textInline(text, textType)
    textType = textType or "label"
    local color = self.theme.colors[textType] or self.theme.colors.label
    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], color[4])
    ImGui.Text(text)
    ImGui.PopStyleColor(1)
end

--- Renders text in an arbitrary RGBA color
--- @param text string The text to display
--- @param color number[] RGBA color array
function GUILib:textColored(text, color)
    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3],
                         color[4] or 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

--- Renders status text with semantic coloring and optional icon prefix
--- @param text string The status message to display
--- @param status "success"|"warning"|"error"|"info" The status type
--- @param showIcon? boolean Whether to show an icon prefix (default: true)
function GUILib:statusText(text, status, showIcon)
    local c = self.theme.colors

    -- Map status to theme colors
    local statusColors = {
        success = c.success,
        warning = c.warning,
        error = c.error,
        info = c.accent
    }

    -- Map status to icon prefixes
    local statusIcons = {
        success = "[OK] ",
        warning = "[!] ",
        error = "[X] ",
        info = "[i] "
    }

    local color = statusColors[status] or c.label
    local icon = (showIcon ~= false) and (statusIcons[status] or "") or ""

    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3],
                         color[4] or 1.0)
    ImGui.TextWrapped(icon .. text)
    ImGui.PopStyleColor(1)
end

--- Renders a section header with optional description
--- @param title string Section title
--- @param description? string Optional help text shown below title
function GUILib:sectionHeader(title, description)
    self:text(title, "header")
    self:spacing(1)
    if description then
        self:text(description, "hint")
        self:spacing(3)
    end
end

--- Renders a labeled row in a table (label on left, value on right).
--- For 2-column tables: pass label and value as strings
--- For N-column tables: pass a table of values as the first argument
--- @param labelOrValues string|string[] The label text OR table of column values
--- @param value? string The value text (only for 2-column mode)
--- @param valueColor? number[] Optional RGBA color for value (or array of colors for N-column mode)
function GUILib:tableRow(labelOrValues, value, valueColor)
    local c = self.theme.colors
    ImGui.TableNextRow()

    -- Multi-column mode: first argument is a table of values
    if type(labelOrValues) == "table" then
        local values = labelOrValues
        local colors = value -- In multi-column mode, second arg is colors array

        for i, cellValue in ipairs(values) do
            ImGui.TableNextColumn()
            local cellColor = colors and colors[i] or nil

            if cellColor then
                ImGui.PushStyleColor(ImGuiCol.Text, cellColor[1], cellColor[2],
                                     cellColor[3], cellColor[4] or 1.0)
                ImGui.TextWrapped(tostring(cellValue))
                ImGui.PopStyleColor(1)
            elseif i == 1 then
                -- First column uses label color
                ImGui.PushStyleColor(ImGuiCol.Text, c.label[1], c.label[2],
                                     c.label[3], c.label[4])
                ImGui.TextWrapped(tostring(cellValue))
                ImGui.PopStyleColor(1)
            else
                ImGui.TextWrapped(tostring(cellValue))
            end
        end
    else
        -- 2-column mode (backward compatible)
        ImGui.TableNextColumn()
        ImGui.PushStyleColor(ImGuiCol.Text, c.label[1], c.label[2], c.label[3],
                             c.label[4])
        ImGui.TextWrapped(labelOrValues)
        ImGui.PopStyleColor(1)
        ImGui.TableNextColumn()
        if valueColor then
            ImGui.PushStyleColor(ImGuiCol.Text, valueColor[1], valueColor[2],
                                 valueColor[3], valueColor[4] or 1.0)
            ImGui.TextWrapped(value)
            ImGui.PopStyleColor(1)
        else
            ImGui.TextWrapped(value)
        end
    end
end

--------------------------------------------------------------------------------
-- INPUT WIDGETS
--------------------------------------------------------------------------------

--- Renders a dropdown/combo box
--- @param id string Unique widget ID (e.g., "##myCombo")
--- @param currentIndex number Currently selected index (1-based for Lua)
--- @param items string[] List of options
--- @param maxVisible? number Max items shown in dropdown (default: 10)
--- @return number newIndex The selected index (1-based)
--- @return boolean changed Whether the selection changed
function GUILib:combo(id, currentIndex, items, maxVisible)
    maxVisible = maxVisible or 10
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, self.theme.padding.frame[1],
                       self.theme.padding.frame[2])
    ImGui.PushItemWidth(-1)

    -- ImGui.Combo returns: changed (boolean), newIndex (0-based)
    local changed, newIndex = ImGui.Combo(id, currentIndex - 1, items,
                                          maxVisible)

    ImGui.PopItemWidth()
    ImGui.PopStyleVar()

    -- Only update if changed, convert to 1-based index
    if changed then
        local luaIndex = (newIndex or 0) + 1
        luaIndex = math.max(1, math.min(luaIndex, #items))
        return luaIndex, true
    end

    return currentIndex, false
end

--- Renders a labeled dropdown/combo box
--- @param label string Label text shown above dropdown
--- @param id string Unique widget ID
--- @param currentIndex number Currently selected index (1-based)
--- @param items string[] List of options
--- @return number newIndex The selected index (1-based)
--- @return boolean changed Whether the selection changed
function GUILib:labeledCombo(label, id, currentIndex, items)
    self:text(label, "label")
    self:spacing(1)
    local newIndex, changed = self:combo(id, currentIndex, items)
    self:spacing(1)
    return newIndex, changed
end

--- Renders a text input field
--- @param id string Unique widget ID
--- @param currentValue string Current text value
--- @param flags? number ImGui input text flags
--- @return string newValue The updated text value
--- @return boolean changed Whether the value changed
function GUILib:inputText(id, currentValue, flags)
    flags = flags or 0
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, self.theme.padding.frame[1],
                       self.theme.padding.frame[2])
    ImGui.PushItemWidth(-1)

    local changed, newValue = ImGui.InputText(id, currentValue, flags)

    ImGui.PopItemWidth()
    ImGui.PopStyleVar()

    return newValue or currentValue, changed
end

--- Renders a labeled text input field
--- @param label string Label text shown above input
--- @param id string Unique widget ID
--- @param currentValue string Current text value
--- @return string newValue The updated text value
--- @return boolean changed Whether the value changed
function GUILib:labeledInput(label, id, currentValue)
    self:text(label, "label")
    self:spacing(1)
    local newValue, changed = self:inputText(id, currentValue)
    self:spacing(1)
    return newValue, changed
end

--- Renders a numeric input field
--- @param id string Unique widget ID
--- @param currentValue number Current numeric value
--- @param step? number Step increment (default: 1)
--- @param stepFast? number Fast step increment (default: 10)
--- @return number newValue The updated numeric value
--- @return boolean changed Whether the value changed
function GUILib:inputInt(id, currentValue, step, stepFast)
    step = step or 1
    stepFast = stepFast or 10
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, self.theme.padding.frame[1],
                       self.theme.padding.frame[2])
    ImGui.PushItemWidth(-1)

    local changed, newValue = ImGui.InputInt(id, currentValue, step, stepFast)

    ImGui.PopItemWidth()
    ImGui.PopStyleVar()

    return newValue or currentValue, changed
end

--- Renders a labeled numeric input field
--- @param label string Label text shown above input
--- @param id string Unique widget ID
--- @param currentValue number Current numeric value
--- @param step? number Step increment (default: 1)
--- @return number newValue The updated numeric value
--- @return boolean changed Whether the value changed
function GUILib:labeledInputInt(label, id, currentValue, step)
    self:text(label, "label")
    self:spacing(1)
    local newValue, changed = self:inputInt(id, currentValue, step)
    self:spacing(1)
    return newValue, changed
end

--- Renders a checkbox and returns its state
--- @param label string Checkbox label
--- @param currentValue boolean Current checked state
--- @return boolean newValue The updated state
--- @return boolean changed Whether the state changed
function GUILib:checkbox(label, currentValue)
    local clicked = ImGui.Checkbox(label, currentValue)
    local newValue = currentValue
    if clicked then newValue = not currentValue end
    self:spacing(1)
    return newValue, clicked
end

--- Renders an integer slider
--- @param id string Unique widget ID
--- @param currentValue number Current value
--- @param min number Minimum value
--- @param max number Maximum value
--- @param format? string Display format (default: "%d")
--- @return number newValue The updated value
--- @return boolean changed Whether the value changed
function GUILib:sliderInt(id, currentValue, min, max, format)
    format = format or "%d"
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, self.theme.padding.frame[1],
                       self.theme.padding.frame[2])
    ImGui.PushItemWidth(-1)

    local changed, newValue =
        ImGui.SliderInt(id, currentValue, min, max, format)

    ImGui.PopItemWidth()
    ImGui.PopStyleVar()

    return newValue or currentValue, changed
end

--- Renders a labeled integer slider
--- @param label string Label text shown above slider
--- @param id string Unique widget ID
--- @param currentValue number Current value
--- @param min number Minimum value
--- @param max number Maximum value
--- @param format? string Display format (default: "%d")
--- @return number newValue The updated value
--- @return boolean changed Whether the value changed
function GUILib:labeledSliderInt(label, id, currentValue, min, max, format)
    self:text(label, "label")
    self:spacing(1)
    local newValue, changed = self:sliderInt(id, currentValue, min, max, format)
    self:spacing(1)
    return newValue, changed
end

--- Renders a labeled float slider
--- @param label string Label text shown above slider
--- @param id string Unique widget ID
--- @param currentValue number Current value
--- @param min number Minimum value
--- @param max number Maximum value
--- @param format? string Display format (default: "%.2f")
--- @return number newValue The updated value
--- @return boolean changed Whether the value changed
function GUILib:labeledSliderFloat(label, id, currentValue, min, max, format)
    self:text(label, "label")
    self:spacing(1)
    local newValue, changed = self:sliderFloat(id, currentValue, min, max,
                                               format)
    self:spacing(1)
    return newValue, changed
end

--- Renders a float slider
--- @param id string Unique widget ID
--- @param currentValue number Current value
--- @param min number Minimum value
--- @param max number Maximum value
--- @param format? string Display format (default: "%.2f")
--- @return number newValue The updated value
--- @return boolean changed Whether the value changed
function GUILib:sliderFloat(id, currentValue, min, max, format)
    format = format or "%.2f"
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, self.theme.padding.frame[1],
                       self.theme.padding.frame[2])
    ImGui.PushItemWidth(-1)

    local changed, newValue = ImGui.SliderFloat(id, currentValue, min, max,
                                                format)

    ImGui.PopItemWidth()
    ImGui.PopStyleVar()

    return newValue or currentValue, changed
end

--- Renders a visually disabled integer input (dimmed, signals read-only)
--- @param id string Unique widget ID
--- @param value number The value to display
function GUILib:inputIntDisabled(id, value)
    local d = self.theme.colors.disabled
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.15, 0.15, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Text, d[1], d[2], d[3], d[4])
    ImGui.PushItemWidth(-1)
    ImGui.InputInt(id, value, 1, 5)
    ImGui.PopItemWidth()
    ImGui.PopStyleColor(2)
end

--------------------------------------------------------------------------------
-- SELECTABLE & LIST WIDGETS
--------------------------------------------------------------------------------

--- Renders a selectable item (clickable list item)
--- @param label string Item text
--- @param selected boolean Whether this item is currently selected
--- @param flags? number ImGui SelectableFlags (optional)
--- @param width? number Item width (default: 0, auto-width)
--- @param height? number Item height (default: 0, auto-height)
--- @return boolean clicked True if the item was clicked
function GUILib:selectable(label, selected, flags, width, height)
    flags = flags or 0
    width = width or 0
    height = height or 0

    -- Apply selection highlight color
    if selected then
        local accent = self.theme.colors.accent
        ImGui.PushStyleColor(ImGuiCol.Header, accent[1], accent[2], accent[3], 0.3)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, accent[1], accent[2], accent[3], 0.4)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, accent[1], accent[2], accent[3], 0.5)
    else
        -- Subtle hover for unselected items
        ImGui.PushStyleColor(ImGuiCol.Header, 0.2, 0.2, 0.2, 0.3)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.3, 0.3, 0.3, 0.4)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.4, 0.4, 0.4, 0.5)
    end

    local clicked = ImGui.Selectable(label, selected, flags, width, height)

    ImGui.PopStyleColor(3)

    return clicked
end

--- Renders a reorderable list with up/down buttons
--- @param id string Unique widget ID
--- @param items table[] Array of {key: string, label: string, disabled: boolean}
--- @param selectedIndex number Currently selected item index (1-based)
--- @return number newSelectedIndex Updated selected index
--- @return table|nil action Action: {type: "move_up"|"move_down"|"select", index: number}
function GUILib:reorderableList(id, items, selectedIndex)
    local action = nil

    if not items or #items == 0 then
        self:text("No tasks configured", "hint")
        return selectedIndex, action
    end

    -- Normalize selected index
    selectedIndex = math.max(1, math.min(selectedIndex, #items))

    if self:beginColumns(id .. "_list", {0.65, 0.15, 0.15}) then
        for i, item in ipairs(items) do
            self:nextRow()

            -- Column 1: Selectable item label
            local displayLabel = item.label
            if item.disabled then
                displayLabel = displayLabel .. " (disabled)"
            end

            if item.disabled then
                -- Grayed out text for disabled items
                self:text(displayLabel, "hint")
            else
                if self:selectable(displayLabel .. "##item" .. i, i == selectedIndex) then
                    selectedIndex = i
                    action = {type = "select", index = i}
                end
            end

            self:nextColumn()

            -- Column 2: Move Up button
            if item.disabled or i == 1 then
                self:text("", "hint")  -- Empty space
            else
                if self:buttonSecondary("↑##up" .. i, 22) then
                    action = {type = "move_up", index = i}
                end
            end

            self:nextColumn()

            -- Column 3: Move Down button
            if item.disabled or i == #items then
                self:text("", "hint")  -- Empty space
            else
                if self:buttonSecondary("↓##dn" .. i, 22) then
                    action = {type = "move_down", index = i}
                end
            end
        end
        self:endColumns()
    end

    return selectedIndex, action
end

--------------------------------------------------------------------------------
-- BUTTON WIDGETS
--------------------------------------------------------------------------------

--- Renders a button with the primary theme color (gold CTA)
--- @param label string Button text
--- @param height? number Button height in pixels (default: theme buttonHeight)
--- @param width? number Button width in pixels (default: -1, full available width)
--- @return boolean clicked True if button was clicked
function GUILib:button(label, height, width)
    height = height or self.theme.style.buttonHeight
    width = width or -1
    local colors = self.theme.colors

    ImGui.PushStyleColor(ImGuiCol.Button, colors.button[1], colors.button[2],
                         colors.button[3], colors.button[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, colors.buttonHover[1],
                         colors.buttonHover[2], colors.buttonHover[3],
                         colors.buttonHover[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, colors.buttonActive[1],
                         colors.buttonActive[2], colors.buttonActive[3],
                         colors.buttonActive[4])
    ImGui.PushStyleColor(ImGuiCol.Text, colors.buttonText[1],
                         colors.buttonText[2], colors.buttonText[3],
                         colors.buttonText[4])

    local clicked = ImGui.Button(label, width, height)

    ImGui.PopStyleColor(4)
    return clicked
end

--- Renders a secondary (subtle) button
--- @param label string Button text
--- @param height? number Button height in pixels
--- @return boolean clicked True if button was clicked
function GUILib:buttonSecondary(label, height)
    height = height or self.theme.style.buttonHeight

    ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)

    local clicked = ImGui.Button(label, -1, height)

    ImGui.PopStyleColor(3)
    return clicked
end

--- Renders a success-colored button (green)
--- @param label string Button text
--- @param height? number Button height in pixels
--- @return boolean clicked True if button was clicked
function GUILib:buttonSuccess(label, height)
    height = height or self.theme.style.buttonHeight

    ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.5, 0.2, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.65, 0.25, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.75, 0.15, 1.0)

    local clicked = ImGui.Button(label, -1, height)

    ImGui.PopStyleColor(3)
    return clicked
end

--- Renders a danger-colored button (red)
--- @param label string Button text
--- @param height? number Button height in pixels
--- @return boolean clicked True if button was clicked
function GUILib:buttonDanger(label, height)
    height = height or self.theme.style.buttonHeight

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)

    local clicked = ImGui.Button(label, -1, height)

    ImGui.PopStyleColor(3)
    return clicked
end

--- Renders a warning-colored button (amber)
--- @param label string Button text
--- @param height? number Button height in pixels
--- @return boolean clicked True if button was clicked
function GUILib:buttonWarning(label, height)
    height = height or self.theme.style.buttonHeight

    ImGui.PushStyleColor(ImGuiCol.Button, 0.50, 0.45, 0.10, 0.80)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.55, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.80, 0.70, 0.10, 1.0)

    local clicked = ImGui.Button(label, -1, height)

    ImGui.PopStyleColor(3)
    return clicked
end

--------------------------------------------------------------------------------
-- PROGRESS & STATUS WIDGETS
--------------------------------------------------------------------------------

--- Returns black or white based on perceived luminance of an RGB color.
--- Uses the BT.601 luma coefficients to match human brightness perception.
--- @param rgb number[] RGB values in 0–1 range
--- @return number[] RGBA {r, g, b, 1.0} — black if bright, white if dark
--- @private
function GUILib._contrastColor(rgb)
    local l = 0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]
    return l > 0.5 and {0.0, 0.0, 0.0, 1.0} or {1.0, 1.0, 1.0, 1.0}
end

--- Renders a themed progress bar
--- @param progress number Progress value between 0 and 1
--- @param height? number Bar height in pixels (default: 28)
--- @param text? string Optional text overlay (automatically high-contrast)
--- @param color? number[] Optional RGB color (default: accent color)
function GUILib:progressBar(progress, height, text, color)
    height = height or 28
    text = text or ""
    color = color or self.theme.colors.accent

    local barRGB = {color[1] * 0.7, color[2] * 0.7, color[3] * 0.7}
    local textColor = GUILib._contrastColor(barRGB)

    ImGui.PushStyleColor(ImGuiCol.Text, textColor[1], textColor[2],
                         textColor[3], textColor[4])
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, barRGB[1], barRGB[2],
                         barRGB[3], 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, color[1] * 0.2, color[2] * 0.2,
                         color[3] * 0.2, 0.8)

    ImGui.ProgressBar(progress, -1, height, text)

    ImGui.PopStyleColor(3)
end

--- Renders a themed progress bar with the label displayed above it
--- @param progress number Progress value between 0 and 1
--- @param height? number Bar height in pixels (default: 28)
--- @param text? string Optional label text shown above the bar
--- @param color? number[] Optional RGB color (default: accent color)
function GUILib:labeledProgressBar(progress, height, text, color)
    height = height or 28
    color = color or self.theme.colors.accent

    if text and text ~= "" then ImGui.Text(text) end

    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, color[1] * 0.7, color[2] * 0.7,
                         color[3] * 0.7, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, color[1] * 0.2, color[2] * 0.2,
                         color[3] * 0.2, 0.8)

    ImGui.ProgressBar(progress, -1, height, "")

    ImGui.PopStyleColor(2)
end

--------------------------------------------------------------------------------
-- COLLAPSIBLE / TREE WIDGETS
--------------------------------------------------------------------------------

--- Renders a collapsible header
--- @param label string Header label
--- @param defaultOpen? boolean Whether to start open (default: false)
--- @return boolean isOpen Whether the section is currently open
function GUILib:collapsingHeader(label, defaultOpen)
    local flags = defaultOpen and ImGuiTreeNodeFlags.DefaultOpen or 0
    return ImGui.CollapsingHeader(label, flags)
end

--------------------------------------------------------------------------------
-- TAB WIDGETS
--------------------------------------------------------------------------------

--- Begins a tab bar
--- Pushes zero vertical ItemSpacing to prevent non-active tab items from
--- accumulating vertical space in the content region.
--- @param id string Unique tab bar identifier
--- @return boolean success Whether the tab bar was created
function GUILib:beginTabBar(id)
    local p = self.theme.padding.item
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, p[1], 0)
    local result = ImGui.BeginTabBar(id, 0)
    if not result then
        ImGui.PopStyleVar()
    end
    return result
end

--- Ends the current tab bar
function GUILib:endTabBar()
    ImGui.EndTabBar()
    ImGui.PopStyleVar()
end

--- Begins a tab item
--- If the tab is active, restores normal vertical ItemSpacing for content.
--- @param label string Tab label (use ### suffix for stable ID)
--- @param flags? number ImGui tab item flags (e.g. ImGuiTabItemFlags.SetSelected)
--- @return boolean isActive Whether this tab is currently active
function GUILib:beginTab(label, flags)
    flags = flags or 0
    local result = ImGui.BeginTabItem(label, nil, flags)
    if result then
        local p = self.theme.padding.item
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, p[1], p[2])
        self:spacing(1)
    end
    return result
end

--- Ends the current tab item
function GUILib:endTab()
    ImGui.PopStyleVar()
    ImGui.EndTabItem()
end

--------------------------------------------------------------------------------
-- WINDOW MANAGEMENT
--------------------------------------------------------------------------------

--- Sets up the next window with theme defaults
--- @param title? string Window title for position saving
--- @param width? number Override window width
--- @param height? number Override window height
function GUILib:setupWindow(title, width, height)
    width = width or self.theme.window.width
    height = height or self.theme.window.height

    ImGui.SetNextWindowSize(width, height, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
end

--- Begins a themed window. Call endWindow() when done.
--- @param title string Window title (use ### suffix for stable ID)
--- @param flags? number ImGui window flags (default: 0)
--- @return boolean visible Whether the window content area is visible
function GUILib:beginWindow(title, flags)
    return ImGui.Begin(title, 0, flags or 0)
end

--- Ends the current window
function GUILib:endWindow() ImGui.End() end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Formats a large number with K/M suffixes
--- @param n number The number to format
--- @return string Formatted string
function GUILib.formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return string.format("%d", n)
end

--- Formats seconds into MM:SS or HH:MM:SS
--- @param seconds number Total seconds
--- @return string Formatted time string
function GUILib.formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then return string.format("%d:%02d:%02d", hours, mins, secs) end
    return string.format("%d:%02d", mins, secs)
end

--- Returns a color based on a percentage value (green -> yellow -> red)
--- @param percent number Value between 0 and 100
--- @return number[] RGB color array
function GUILib.getHealthColor(percent)
    if percent > 60 then
        return {0.3, 0.85, 0.45} -- Green
    elseif percent > 30 then
        return {1.0, 0.75, 0.2} -- Yellow
    end
    return {1.0, 0.3, 0.3} -- Red
end

--------------------------------------------------------------------------------
-- EXPORT
--------------------------------------------------------------------------------

return GUILib
