-- ui/optionspanel.lua
-- Native Blizzard AddOns settings panel for QuestKing.
-- Lua 5.1 compatible. No Ace3 dependency.

local addonName, QuestKing = ...

if type(QuestKing) ~= "table" then
    return
end

local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

local format = string.format
local pairs = pairs
local pcall = pcall
local select = select
local string_format = string.format
local table_insert = table.insert
local tonumber = tonumber
local tostring = tostring
local type = type

local PANEL_TITLE = "QuestKing"
local PANEL_NAME = "QuestKingOptionsPanel"
local PANEL_WIDTH = 620
local PANEL_HEIGHT = 1560

local optionDefinitions = {}
local controls = {}
local baselineOptions = nil
local panel = nil
local scrollChild = nil
local settingsCategory = nil
local settingsCategoryID = nil
local registered = false

local managedOptionKeys = {
    disableBlizzard = true,
    enableItemPopups = true,
    enablePetTrackerCompatibility = true,
    showCompletedObjectives = true,
    hideSupersedingObjectives = true,
    enableScenarioTracker = true,
    respectScenarioCriteriaVisibility = true,
    preferRaidScenarioLabel = true,
    showScenarioObjectivesInRaids = true,
    allowInstanceScenarioFallback = true,
    showScenarioSpellsInTooltip = true,
    allowDrag = true,
    hideToggleButtonBorder = true,
    hideWatchFrameBorder = true,
    enableAdvancedBackground = true,
    enableBackdrop = true,
    trackerBackgroundAlpha = true,
    buttonWidth = true,
    lineHeight = true,
    titleHeight = true,
    fontSize = true,
    itemButtonScale = true,
    itemAnchorSide = true,
    rewardAnchorSide = true,
    tooltipAnchor = true,
}

local function SafeError(err)
    if type(_G.geterrorhandler) == "function" then
        _G.geterrorhandler()(err)
    end
end

local function SafeCallMethod(target, methodName, ...)
    if type(target) ~= "table" or type(methodName) ~= "string" then
        return false, nil
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(method, target, ...)
    if not ok then
        SafeError(result)
        return true, nil
    end

    return true, result
end

local function Print(message, ...)
    if select("#", ...) > 0 then
        message = format(message, ...)
    end

    local chat = _G.DEFAULT_CHAT_FRAME
    if chat and type(chat.AddMessage) == "function" then
        chat:AddMessage("|cff99ccffQuestKing|r: " .. tostring(message))
    elseif type(_G.print) == "function" then
        _G.print("QuestKing: " .. tostring(message))
    end
end

local function EnsureSavedVariables()
    _G.QuestKingDB = type(_G.QuestKingDB) == "table" and _G.QuestKingDB or {}
    _G.QuestKingDBPerChar = type(_G.QuestKingDBPerChar) == "table" and _G.QuestKingDBPerChar or {}
    _G.QuestKingDB.options = type(_G.QuestKingDB.options) == "table" and _G.QuestKingDB.options or {}
    return _G.QuestKingDB, _G.QuestKingDBPerChar
end

local function GetOptions()
    QuestKing.options = type(QuestKing.options) == "table" and QuestKing.options or {}
    return QuestKing.options
end

local function SnapshotBaselineOptions()
    if baselineOptions then
        return
    end

    baselineOptions = {}

    local options = GetOptions()
    for key in pairs(managedOptionKeys) do
        baselineOptions[key] = options[key]
    end

    baselineOptions.trackerAlpha = tonumber(options.trackerAlpha) or 0.92
    baselineOptions.trackerScale = tonumber(options.trackerScale) or 1.00
end

local function ClampNumber(value, fallback, minimum, maximum)
    value = tonumber(value)
    if value == nil then
        value = fallback
    end

    if minimum and value < minimum then
        value = minimum
    end

    if maximum and value > maximum then
        value = maximum
    end

    return value
end

local function RoundToStep(value, step)
    value = tonumber(value) or 0
    step = tonumber(step) or 1

    if step <= 0 then
        return value
    end

    return math.floor((value / step) + 0.5) * step
end

local function NormalizeChoice(value, choices, fallback)
    if type(choices) ~= "table" then
        return fallback
    end

    for index = 1, #choices do
        if choices[index].value == value then
            return value
        end
    end

    return fallback
end

local function GetSavedOption(key)
    local db = EnsureSavedVariables()
    return db.options[key]
end

local function SaveManagedOption(key, value)
    local db = EnsureSavedVariables()
    db.options[key] = value
end

local function ClearManagedOptions()
    local db = EnsureSavedVariables()
    db.options = {}
    db.dbTrackerAlpha = nil
    db.dbTrackerScale = nil
end

local function GetEffectiveOption(key)
    local options = GetOptions()
    local db = EnsureSavedVariables()

    if key == "trackerAlpha" then
        return ClampNumber(db.dbTrackerAlpha, tonumber(options.trackerAlpha) or baselineOptions.trackerAlpha or 0.92, 0, 1)
    end

    if key == "trackerScale" then
        return ClampNumber(db.dbTrackerScale, tonumber(options.trackerScale) or baselineOptions.trackerScale or 1, 0.25, 3)
    end

    local saved = GetSavedOption(key)
    if saved ~= nil then
        return saved
    end

    return options[key]
end

local function ApplyTrackerPresentation()
    local tracker = QuestKing.Tracker

    if type(tracker) == "table" then
        SafeCallMethod(tracker, "SetCustomAlpha")
        SafeCallMethod(tracker, "SetCustomScale")
        SafeCallMethod(tracker, "CheckDrag")
        SafeCallMethod(tracker, "RefreshLayoutMetrics")
        SafeCallMethod(tracker, "ApplyTrackerBackground")
    end
end

local function QueueTrackerRefresh(forceBuild)
    if not SafeCallMethod(QuestKing, "QueueTrackerUpdate", forceBuild and true or false, false) then
        SafeCallMethod(QuestKing, "UpdateTracker", forceBuild and true or false, false)
    end
end

local function SyncDragLockWithAllowDrag()
    local db = EnsureSavedVariables()
    db.dragLocked = GetOptions().allowDrag ~= true
end

local function ApplyBlizzardTrackerSetting()
    if type(QuestKing.RefreshBlizzardTrackerSuppression) == "function" then
        SafeCallMethod(QuestKing, "RefreshBlizzardTrackerSuppression")
        return
    end

    if GetOptions().disableBlizzard and type(QuestKing.DisableBlizzard) == "function" then
        SafeCallMethod(QuestKing, "DisableBlizzard")
    end
end

local function ApplySetting(key, value, forceBuild)
    local options = GetOptions()
    local db = EnsureSavedVariables()

    if key == "trackerAlpha" then
        db.dbTrackerAlpha = ClampNumber(value, baselineOptions.trackerAlpha or 0.92, 0, 1)
    elseif key == "trackerScale" then
        db.dbTrackerScale = ClampNumber(value, baselineOptions.trackerScale or 1, 0.25, 3)
    else
        options[key] = value
        SaveManagedOption(key, value)
    end

    if key == "disableBlizzard" then
        ApplyBlizzardTrackerSetting()
    elseif key == "allowDrag" and type(QuestKing.Tracker) == "table" then
        db.dragLocked = value ~= true

        if type(QuestKing.Tracker.CaptureCurrentPosition) == "function" then
            QuestKing.Tracker:CaptureCurrentPosition()
        end

        if type(QuestKing.Tracker.CheckDrag) == "function" then
            QuestKing.Tracker:CheckDrag()
        end
    end

    ApplyTrackerPresentation()
    QueueTrackerRefresh(forceBuild ~= false)
end

local function ApplySavedOptions()
    SnapshotBaselineOptions()

    local options = GetOptions()
    local db = EnsureSavedVariables()

    for key, value in pairs(db.options) do
        if managedOptionKeys[key] then
            options[key] = value
        end
    end

    if db.dbTrackerAlpha ~= nil then
        db.dbTrackerAlpha = ClampNumber(db.dbTrackerAlpha, baselineOptions.trackerAlpha or 0.92, 0, 1)
    end

    if db.dbTrackerScale ~= nil then
        db.dbTrackerScale = ClampNumber(db.dbTrackerScale, baselineOptions.trackerScale or 1, 0.25, 3)
    end

    SyncDragLockWithAllowDrag()
end

local function RestoreBaselineOptions()
    SnapshotBaselineOptions()
    ClearManagedOptions()

    local options = GetOptions()
    local db = EnsureSavedVariables()
    for key, value in pairs(baselineOptions) do
        options[key] = value
    end

    SyncDragLockWithAllowDrag()

    ApplyBlizzardTrackerSetting()
    ApplyTrackerPresentation()
    QueueTrackerRefresh(true)
end

local function CreateText(parent, text, template, x, y)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    fontString:SetJustifyH("LEFT")
    fontString:SetText(text or "")
    return fontString
end

local function CreateWrappedText(parent, text, template, x, y, width)
    local fontString = CreateText(parent, text, template, x, y)
    fontString:SetWidth(width or 560)
    fontString:SetWordWrap(true)
    return fontString
end

local function MakeControlName(suffix)
    return PANEL_NAME .. tostring(suffix or (#controls + 1))
end

local function SetLabelText(control, label)
    if control.Text then
        control.Text:SetText(label)
        return
    end

    local name = control.GetName and control:GetName()
    local text = name and _G[name .. "Text"]
    if text and text.SetText then
        text:SetText(label)
    end
end

local function CreateCheck(parent, definition, x, y)
    local check = CreateFrame("CheckButton", MakeControlName(definition.key .. "Check"), parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check.key = definition.key
    check.definition = definition
    check.tooltipText = definition.tooltip or definition.label
    SetLabelText(check, definition.label)

    check:SetScript("OnClick", function(self)
        ApplySetting(self.key, self:GetChecked() and true or false, true)
    end)

    table_insert(controls, check)
    return check
end

local function SetTextureColor(texture, r, g, b, a)
    if not texture then
        return
    end

    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

local function FormatSliderLimit(value, decimals)
    value = tonumber(value) or 0
    decimals = tonumber(decimals) or 0

    if decimals > 0 then
        return string_format("%." .. tostring(decimals) .. "f", value)
    end

    return tostring(math.floor(value + 0.5))
end

local function FormatSliderValue(definition, value)
    local valueFormat = definition.valueFormat or "%s"
    return format(valueFormat, value)
end

local function CreateSliderArtwork(slider, name)
    local trackBackground = slider:CreateTexture(name .. "TrackBackground", "BACKGROUND")
    trackBackground:SetPoint("LEFT", slider, "LEFT", 0, 0)
    trackBackground:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    trackBackground:SetHeight(8)
    SetTextureColor(trackBackground, 0.05, 0.05, 0.05, 0.85)

    local trackTop = slider:CreateTexture(name .. "TrackTop", "BORDER")
    trackTop:SetPoint("TOPLEFT", trackBackground, "TOPLEFT", 0, 0)
    trackTop:SetPoint("TOPRIGHT", trackBackground, "TOPRIGHT", 0, 0)
    trackTop:SetHeight(1)
    SetTextureColor(trackTop, 0.45, 0.45, 0.45, 0.75)

    local trackBottom = slider:CreateTexture(name .. "TrackBottom", "BORDER")
    trackBottom:SetPoint("BOTTOMLEFT", trackBackground, "BOTTOMLEFT", 0, 0)
    trackBottom:SetPoint("BOTTOMRIGHT", trackBackground, "BOTTOMRIGHT", 0, 0)
    trackBottom:SetHeight(1)
    SetTextureColor(trackBottom, 0.00, 0.00, 0.00, 0.90)

    local trackLeft = slider:CreateTexture(name .. "TrackLeft", "BORDER")
    trackLeft:SetPoint("TOPLEFT", trackBackground, "TOPLEFT", 0, 0)
    trackLeft:SetPoint("BOTTOMLEFT", trackBackground, "BOTTOMLEFT", 0, 0)
    trackLeft:SetWidth(1)
    SetTextureColor(trackLeft, 0.35, 0.35, 0.35, 0.75)

    local trackRight = slider:CreateTexture(name .. "TrackRight", "BORDER")
    trackRight:SetPoint("TOPRIGHT", trackBackground, "TOPRIGHT", 0, 0)
    trackRight:SetPoint("BOTTOMRIGHT", trackBackground, "BOTTOMRIGHT", 0, 0)
    trackRight:SetWidth(1)
    SetTextureColor(trackRight, 0.00, 0.00, 0.00, 0.90)

    if type(slider.SetThumbTexture) == "function" then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end

    local thumb = type(slider.GetThumbTexture) == "function" and slider:GetThumbTexture() or nil
    if thumb then
        thumb:SetSize(32, 32)
    end
end

local function NormalizeSliderValue(definition, value)
    local normalized = ClampNumber(value, definition.fallback, definition.min, definition.max)
    normalized = RoundToStep(normalized, definition.step or 1)

    if definition.decimals then
        normalized = tonumber(string_format("%." .. tostring(definition.decimals) .. "f", normalized))
    else
        normalized = math.floor(normalized + 0.5)
    end

    return normalized
end

local function CreateSlider(parent, definition, x, y)
    local name = MakeControlName(definition.key .. "Slider")
    local width = definition.width or 260

    local label = CreateText(parent, definition.label, "GameFontNormal", x, y)
    label:SetWidth(width + 60)

    local slider = CreateFrame("Slider", name, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 24)
    slider:SetSize(width, 18)
    slider:SetMinMaxValues(definition.min, definition.max)

    if type(slider.SetOrientation) == "function" then
        slider:SetOrientation("HORIZONTAL")
    end

    if type(slider.SetValueStep) == "function" then
        slider:SetValueStep(definition.step or 1)
    end

    if type(slider.SetObeyStepOnDrag) == "function" then
        slider:SetObeyStepOnDrag(true)
    end

    if type(slider.EnableMouseWheel) == "function" then
        slider:EnableMouseWheel(true)
    end

    slider.key = definition.key
    slider.definition = definition
    slider.tooltipText = definition.tooltip or definition.label
    slider.label = label

    CreateSliderArtwork(slider, name)

    slider.lowText = CreateText(parent, FormatSliderLimit(definition.min, definition.decimals), "GameFontDisableSmall", x, y - 42)
    slider.highText = CreateText(parent, FormatSliderLimit(definition.max, definition.decimals), "GameFontDisableSmall", x + width - 22, y - 42)
    slider.highText:SetJustifyH("RIGHT")
    slider.highText:SetWidth(48)
    slider.valueText = CreateText(parent, "", "GameFontHighlightSmall", x + width + 36, y - 25)
    slider.valueText:SetWidth(70)

    slider:SetScript("OnValueChanged", function(self, value)
        local def = self.definition
        local normalized = NormalizeSliderValue(def, value)

        if self.valueText then
            self.valueText:SetText(FormatSliderValue(def, normalized))
        end

        if self._questKingRefreshing then
            return
        end

        if math.abs((tonumber(value) or 0) - normalized) > 0.0001 then
            self._questKingRefreshing = true
            self:SetValue(normalized)
            self._questKingRefreshing = false
        end

        ApplySetting(self.key, normalized, true)
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local def = self.definition
        local step = tonumber(def.step) or 1
        local current = tonumber(self:GetValue()) or tonumber(def.fallback) or tonumber(def.min) or 0

        if delta and delta < 0 then
            step = -step
        end

        self:SetValue(NormalizeSliderValue(def, current + step))
    end)

    table_insert(controls, slider)
    return slider
end

local function GetChoiceLabel(definition, value)
    if type(definition.choices) ~= "table" then
        return tostring(value)
    end

    for index = 1, #definition.choices do
        if definition.choices[index].value == value then
            return definition.choices[index].label
        end
    end

    return tostring(value)
end

local function GetNextChoice(definition, value)
    local choices = definition.choices
    if type(choices) ~= "table" or #choices == 0 then
        return value
    end

    for index = 1, #choices do
        if choices[index].value == value then
            local nextIndex = (index % #choices) + 1
            return choices[nextIndex].value
        end
    end

    return choices[1].value
end

local function CreateChoice(parent, definition, x, y)
    local label = CreateText(parent, definition.label, "GameFontNormal", x, y + 3)
    label:SetWidth(230)

    local button = CreateFrame("Button", MakeControlName(definition.key .. "Choice"), parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 240, y)
    button:SetSize(150, 24)
    button.key = definition.key
    button.definition = definition
    button.tooltipText = definition.tooltip or definition.label

    button:SetScript("OnClick", function(self)
        local def = self.definition
        local current = GetEffectiveOption(self.key)
        local nextValue = GetNextChoice(def, current)
        ApplySetting(self.key, nextValue, true)
        self:SetText(GetChoiceLabel(def, nextValue))
    end)

    button.label = label
    table_insert(controls, button)
    return button
end

local function RefreshControls()
    SnapshotBaselineOptions()

    for index = 1, #controls do
        local control = controls[index]
        local definition = control.definition

        if definition and control.key then
            local value = GetEffectiveOption(control.key)

            if definition.kind == "check" then
                control:SetChecked(value and true or false)
            elseif definition.kind == "slider" then
                local normalized = ClampNumber(value, definition.fallback, definition.min, definition.max)
                normalized = RoundToStep(normalized, definition.step or 1)

                control._questKingRefreshing = true
                control:SetValue(normalized)
                control._questKingRefreshing = false

                if control.valueText then
                    local valueFormat = definition.valueFormat or "%s"
                    control.valueText:SetText(format(valueFormat, normalized))
                end
            elseif definition.kind == "choice" then
                value = NormalizeChoice(value, definition.choices, definition.fallback)
                control:SetText(GetChoiceLabel(definition, value))
            end
        end
    end
end

local CONTENT_LEFT = 18
local CONTROL_LEFT = 34
local SLIDER_LEFT = 42
local CONTENT_WIDTH = 560

local function CreateDivider(parent, y)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_LEFT, y)
    texture:SetSize(CONTENT_WIDTH, 1)

    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(0.28, 0.28, 0.32, 0.55)
    else
        texture:SetTexture(0.28, 0.28, 0.32, 0.55)
    end

    return texture
end

local function AddSection(title, description, y)
    CreateText(scrollChild, title, "GameFontNormalLarge", CONTENT_LEFT, y)
    CreateDivider(scrollChild, y - 22)
    y = y - 34

    if description and description ~= "" then
        CreateWrappedText(scrollChild, description, "GameFontHighlightSmall", CONTENT_LEFT, y, CONTENT_WIDTH)
        y = y - 46
    end

    return y
end

local function AddDescription(text, y)
    CreateWrappedText(scrollChild, text, "GameFontHighlightSmall", CONTENT_LEFT, y, CONTENT_WIDTH)
    return y - 54
end

local function AddCheck(key, label, tooltip, y)
    optionDefinitions[#optionDefinitions + 1] = {
        kind = "check",
        key = key,
        label = label,
        tooltip = tooltip,
    }

    CreateCheck(scrollChild, optionDefinitions[#optionDefinitions], CONTROL_LEFT, y)
    return y - 30
end

local function AddSlider(key, label, tooltip, minValue, maxValue, step, decimals, valueFormat, y)
    optionDefinitions[#optionDefinitions + 1] = {
        kind = "slider",
        key = key,
        label = label,
        tooltip = tooltip,
        min = minValue,
        max = maxValue,
        step = step,
        decimals = decimals,
        valueFormat = valueFormat,
        fallback = tonumber(GetOptions()[key]) or tonumber(baselineOptions and baselineOptions[key]) or minValue,
    }

    CreateSlider(scrollChild, optionDefinitions[#optionDefinitions], SLIDER_LEFT, y)
    return y - 58
end

local function AddChoice(key, label, tooltip, choices, fallback, y)
    optionDefinitions[#optionDefinitions + 1] = {
        kind = "choice",
        key = key,
        label = label,
        tooltip = tooltip,
        choices = choices,
        fallback = fallback,
    }

    CreateChoice(scrollChild, optionDefinitions[#optionDefinitions], CONTROL_LEFT, y)
    return y - 34
end

local function BuildPanel()
    if panel then
        return panel
    end

    SnapshotBaselineOptions()

    panel = CreateFrame("Frame", PANEL_NAME, UIParent)
    panel.name = PANEL_TITLE
    panel:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", PANEL_NAME .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    scrollChild = CreateFrame("Frame", PANEL_NAME .. "ScrollChild", scrollFrame)
    scrollChild:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    local y = -18
    CreateText(scrollChild, "QuestKing Settings", "GameFontNormalLarge", CONTENT_LEFT, y)
    y = y - 32
    y = AddDescription("Settings are grouped by what they affect: tracker visibility, frame appearance, row layout, quest behavior, scenario content, and compatibility. Changes are saved in QuestKingDB and apply without Ace3 or other helper libraries.", y)

    y = AddSection("Main Tracker", "Controls whether QuestKing replaces the default tracker and how the main tracker frame behaves on screen.", y)
    y = AddCheck("disableBlizzard", "Hide Blizzard Objective Tracker", "Uses QuestKing's conservative Blizzard tracker suppression path.", y)
    y = AddCheck("allowDrag", "Allow QuestKing tracker dragging", "When enabled, the tracker keeps its current position and can be moved by dragging the titlebar.", y)
    y = AddCheck("hideToggleButtonBorder", "Hide tracker toggle button border", "Keeps the tracker titlebar cleaner by hiding the toggle button border.", y)
    y = AddSlider("trackerScale", "Tracker Scale", "Changes the overall QuestKing tracker scale.", 0.70, 1.50, 0.05, 2, "%.2f", y - 6)
    y = AddSlider("trackerAlpha", "Tracker Alpha", "Changes the opacity of the whole QuestKing tracker, including text and buttons.", 0.35, 1.00, 0.05, 2, "%.2f", y)

    y = AddSection("Frame Appearance", "Controls the watch frame background, border, and fill opacity without changing quest row text visibility.", y - 8)
    y = AddCheck("enableAdvancedBackground", "Enable advanced background", "Uses QuestKing's framed background panel behind the tracker.", y)
    y = AddCheck("enableBackdrop", "Enable simple backdrop", "Uses QuestKing's simple tracker backdrop path.", y)
    y = AddCheck("hideWatchFrameBorder", "Hide watch frame border", "Hides only the outer QuestKing watch frame border. Background fill, tracker text, and buttons stay visible.", y)
    y = AddSlider("trackerBackgroundAlpha", "Quest Frame Background Alpha", "Controls only the QuestKing quest frame background opacity. Tracker text and buttons keep the Tracker Alpha setting.", 0.00, 1.00, 0.05, 2, "%.2f", y)

    y = AddSection("Quest Text & Rows", "Adjusts the size and spacing of quest titles, objective lines, and tracker row width.", y - 8)
    y = AddSlider("buttonWidth", "Button Width", "Width of each QuestKing tracker row.", 180, 360, 5, 0, "%d", y)
    y = AddSlider("lineHeight", "Line Height", "Height of each objective line.", 12, 28, 1, 0, "%d", y)
    y = AddSlider("titleHeight", "Title Height", "Height of the quest title line.", 12, 30, 1, 0, "%d", y)
    y = AddSlider("fontSize", "Font Size", "Base tracker font size.", 8, 20, 1, 0, "%d", y)

    y = AddSection("Item Buttons, Rewards & Tooltips", "Controls the side and scale of tracker extras that attach to quest rows.", y - 8)
    y = AddSlider("itemButtonScale", "Quest Item Button Scale", "Scale multiplier for quest item buttons relative to the tracker.", 0.50, 1.75, 0.05, 2, "%.2f", y)
    y = AddChoice("itemAnchorSide", "Quest Item Anchor", "Controls which side quest item buttons anchor to.", {
        { label = "Right", value = "right" },
        { label = "Left", value = "left" },
    }, "right", y)
    y = AddChoice("rewardAnchorSide", "Reward Anchor", "Controls which side reward frames anchor to.", {
        { label = "Right", value = "right" },
        { label = "Left", value = "left" },
    }, "right", y)
    y = AddChoice("tooltipAnchor", "Tooltip Anchor", "Controls where tracker tooltips are anchored.", {
        { label = "Right", value = "ANCHOR_RIGHT" },
        { label = "Left", value = "ANCHOR_LEFT" },
        { label = "Cursor", value = "ANCHOR_CURSOR" },
        { label = "Top", value = "ANCHOR_TOP" },
        { label = "Bottom", value = "ANCHOR_BOTTOM" },
    }, "ANCHOR_RIGHT", y)

    y = AddSection("Quest Behavior", "Controls what quest information is shown inside normal quest rows.", y - 8)
    y = AddCheck("enableItemPopups", "Enable item-start quest popups", "Shows a QuestKing popup when looting an item that starts a quest.", y)
    y = AddChoice("showCompletedObjectives", "Completed Objectives", "Controls how completed objective lines are shown.", {
        { label = "Hidden", value = false },
        { label = "Visible", value = true },
        { label = "Always", value = "always" },
    }, true, y)
    y = AddCheck("hideSupersedingObjectives", "Hide superseded objectives", "Hides old objective tiers when newer objective steps supersede them.", y)

    y = AddSection("Scenario, Dungeon & Raid Content", "Controls objective blocks supplied through Blizzard's scenario APIs for instanced content.", y - 8)
    y = AddCheck("enableScenarioTracker", "Enable scenario tracker blocks", "Allows scenario, delve, dungeon, and raid-style objective blocks when Blizzard exposes scenario data.", y)
    y = AddCheck("respectScenarioCriteriaVisibility", "Respect Blizzard criteria visibility", "Hides criteria rows when Blizzard reports they should not be displayed.", y)
    y = AddCheck("preferRaidScenarioLabel", "Prefer raid label for raid scenario data", "Labels scenario-backed raid content as Raid when applicable.", y)
    y = AddCheck("showScenarioObjectivesInRaids", "Show scenario objectives in raids", "Allows Blizzard scenario-backed raid objectives to appear in QuestKing.", y)
    y = AddCheck("allowInstanceScenarioFallback", "Allow instance scenario fallback", "Allows scenario-backed blocks in party and dungeon content even when the simple scenario gate is unavailable.", y)
    y = AddCheck("showScenarioSpellsInTooltip", "Show scenario spells in tooltip", "Shows spell names from scenario steps in the tooltip when available.", y)

    y = AddSection("Compatibility", "Extra integration settings that are safer kept separate from normal display controls.", y - 8)
    y = AddCheck("enablePetTrackerCompatibility", "Enable PetTracker compatibility helpers", "Disabled by default because third-party frame reparenting can increase taint risk on modern clients.", y)

    local resetButton = CreateFrame("Button", PANEL_NAME .. "ResetButton", scrollChild, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 18, y - 12)
    resetButton:SetSize(150, 24)
    resetButton:SetText("Reset Defaults")
    resetButton:SetScript("OnClick", function()
        RestoreBaselineOptions()
        RefreshControls()
        Print("Settings reset to file defaults.")
    end)

    local refreshButton = CreateFrame("Button", PANEL_NAME .. "RefreshButton", scrollChild, "UIPanelButtonTemplate")
    refreshButton:SetPoint("LEFT", resetButton, "RIGHT", 12, 0)
    refreshButton:SetSize(150, 24)
    refreshButton:SetText("Refresh Tracker")
    refreshButton:SetScript("OnClick", function()
        ApplyTrackerPresentation()
        QueueTrackerRefresh(true)
        Print("Tracker refreshed.")
    end)

    scrollChild:SetHeight(math.max(PANEL_HEIGHT, math.abs(y) + 110))

    panel.OnRefresh = RefreshControls
    panel.OnCommit = function() end
    panel.OnDefault = function()
        RestoreBaselineOptions()
        RefreshControls()
    end
    panel.default = panel.OnDefault
    panel.refresh = RefreshControls

    panel:SetScript("OnShow", RefreshControls)

    return panel
end

local function RegisterSettingsApi()
    local settings = _G.Settings
    if type(settings) ~= "table" or type(settings.RegisterCanvasLayoutCategory) ~= "function" then
        return false
    end

    local optionsPanel = BuildPanel()
    local category = settings.RegisterCanvasLayoutCategory(optionsPanel, PANEL_TITLE)
    if not category then
        return false
    end

    settingsCategory = category

    if type(category.GetID) == "function" then
        settingsCategoryID = category:GetID()
    end

    if type(settings.RegisterAddOnCategory) == "function" then
        settings.RegisterAddOnCategory(category)
    end

    return true
end

local function RegisterLegacyInterfaceOptions()
    if type(_G.InterfaceOptions_AddCategory) ~= "function" then
        return false
    end

    _G.InterfaceOptions_AddCategory(BuildPanel())
    return true
end

local function OpenOptions()
    if not registered then
        ApplySavedOptions()
        if not RegisterSettingsApi() then
            RegisterLegacyInterfaceOptions()
        end
        registered = true
    end

    RefreshControls()

    local settings = _G.Settings
    if settingsCategoryID and type(settings) == "table" and type(settings.OpenToCategory) == "function" then
        settings.OpenToCategory(settingsCategoryID)
        return
    end

    if settingsCategory and type(settings) == "table" and type(settings.OpenToCategory) == "function" then
        settings.OpenToCategory(settingsCategory)
        return
    end

    if panel and type(_G.InterfaceOptionsFrame_OpenToCategory) == "function" then
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
        return
    end

    if _G.SettingsPanel and type(_G.SettingsPanel.Open) == "function" then
        _G.SettingsPanel:Open()
    end
end

local function RegisterSlashCommand()
    _G.SLASH_QUESTKINGOPTIONS1 = "/qkoptions"
    _G.SLASH_QUESTKINGOPTIONS2 = "/questkingoptions"

    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.QUESTKINGOPTIONS = function()
        OpenOptions()
    end
end

local function RegisterPanelOnce()
    if registered then
        return
    end

    ApplySavedOptions()

    if not RegisterSettingsApi() then
        RegisterLegacyInterfaceOptions()
    end

    RegisterSlashCommand()
    registered = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    RegisterPanelOnce()
end)

QuestKing.ApplySavedOptions = ApplySavedOptions
QuestKing.OpenOptions = OpenOptions
QuestKing.RefreshOptionsPanel = RefreshControls
_G.QuestKing_OpenOptions = OpenOptions
