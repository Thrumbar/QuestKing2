local addonName, QuestKing = ...

local opt = QuestKing.options or {}

local tinsert = table.insert
local tremove = table.remove
local tonumber = tonumber
local type = type

local itemButtonPool = {}
local RANGE_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2
local ITEM_BUTTON_TEMPLATE = "QuestKingItemButtonTemplate"

local function QueueTrackerRefresh(forceBuild)
    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
        return
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function GetCurrentLineHeight()
    local lineHeight = tonumber((QuestKing.options or opt).lineHeight) or 18
    if lineHeight < 1 then
        lineHeight = 18
    end
    return lineHeight
end

local function GetCurrentItemButtonScale()
    local scale = tonumber(QuestKing.itemButtonScale) or tonumber((QuestKing.options or opt).itemButtonScale) or 1
    if scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetCurrentItemButtonAlpha()
    local alpha = tonumber(QuestKing.itemButtonAlpha) or 1
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    return alpha
end

local function IsInCombatLockdownCompat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() or false
end

local function GetQuestLogSpecialItemInfoCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil, nil, nil, nil
    end

    if type(GetQuestLogSpecialItemInfo) == "function" then
        local ok, link, texture, charges, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, questLogIndex)
        if ok then
            return link, texture, charges, showWhenComplete
        end
    end

    return nil, nil, nil, nil
end

local function GetQuestLogSpecialItemCooldownCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return 0, 0, 0
    end

    if type(GetQuestLogSpecialItemCooldown) == "function" then
        local ok, start, duration, enable = pcall(GetQuestLogSpecialItemCooldown, questLogIndex)
        if ok then
            return start, duration, enable
        end
    end

    return 0, 0, 0
end

local function IsQuestLogSpecialItemInRangeCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
    end

    if type(IsQuestLogSpecialItemInRange) == "function" then
        local ok, inRange = pcall(IsQuestLogSpecialItemInRange, questLogIndex)
        if ok then
            return inRange
        end
    end

    return nil
end

local function SafeSetItemButtonTexture(itemButton, texture)
    if type(SetItemButtonTexture) == "function" then
        pcall(SetItemButtonTexture, itemButton, texture)
        return
    end

    if itemButton and itemButton.icon then
        itemButton.icon:SetTexture(texture)
    end
end

local function SafeSetItemButtonCount(itemButton, charges)
    if type(SetItemButtonCount) == "function" then
        pcall(SetItemButtonCount, itemButton, charges)
        return
    end

    if not itemButton or not itemButton.Count then
        return
    end

    if charges and charges > 1 then
        itemButton.Count:SetText(charges)
        itemButton.Count:Show()
    else
        itemButton.Count:SetText("")
        itemButton.Count:Hide()
    end
end

local function SafeSetItemButtonTextureVertexColor(itemButton, r, g, b)
    if type(SetItemButtonTextureVertexColor) == "function" then
        pcall(SetItemButtonTextureVertexColor, itemButton, r, g, b)
        return
    end

    if itemButton and itemButton.icon then
        itemButton.icon:SetVertexColor(r, g, b)
    end
end

local function SafeHideTooltip()
    if QuestKing and QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

local function SafeSetHyperlink(tooltip, link)
    if not tooltip or not link then
        return false
    end

    if tooltip.SetHyperlink then
        local ok = pcall(tooltip.SetHyperlink, tooltip, link)
        if ok then
            return true
        end
    end

    return false
end

local function SafeSetItemByID(tooltip, itemID)
    if not tooltip or not itemID then
        return false
    end

    if tooltip.SetItemByID then
        local ok = pcall(tooltip.SetItemByID, tooltip, itemID)
        if ok then
            return true
        end
    end

    return false
end

local function SafeGetItemName(link, itemID)
    if type(GetItemInfo) == "function" then
        local ok, name = pcall(GetItemInfo, link or itemID)
        if ok and name and name ~= "" then
            return name
        end
    end

    if C_Item and type(C_Item.GetItemNameByID) == "function" and itemID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and name and name ~= "" then
            return name
        end
    end

    return nil
end

local function SafeGetItemIDFromLink(link)
    if not link or type(link) ~= "string" then
        return nil
    end

    if C_Item and type(C_Item.GetItemIDForItemInfo) == "function" then
        local ok, itemID = pcall(C_Item.GetItemIDForItemInfo, link)
        if ok and itemID then
            return itemID
        end
    end

    if type(GetItemInfoInstant) == "function" then
        local ok, itemID = pcall(GetItemInfoInstant, link)
        if ok and itemID then
            return itemID
        end
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID and itemID > 0 then
        return itemID
    end

    return nil
end

local function ClearButtonState(itemButton)
    if not itemButton then
        return
    end

    itemButton.questLogIndex = nil
    itemButton.charges = nil
    itemButton.rangeTimer = nil
    itemButton.itemLink = nil
    itemButton.itemID = nil
    itemButton.baseButton = nil
    itemButton._pendingQuestLogIndex = nil
    itemButton._pendingItemLink = nil

    SafeSetItemButtonCount(itemButton, 0)
    SafeSetItemButtonTexture(itemButton, nil)
    SafeSetItemButtonTextureVertexColor(itemButton, 1, 1, 1)

    if itemButton.Cooldown and itemButton.Cooldown.Clear then
        itemButton.Cooldown:Clear()
    elseif itemButton.Cooldown and itemButton.Cooldown.SetCooldown then
        itemButton.Cooldown:SetCooldown(0, 0)
    end

    if itemButton.icon then
        itemButton.icon:SetTexCoord(0, 1, 0, 1)
    end

    if itemButton.NormalTexture then
        itemButton.NormalTexture:SetHeight(42)
    end
end

local function ApplyItemButtonZOrder(itemButton, baseButton)
    if not itemButton or not baseButton or IsInCombatLockdownCompat() then
        return
    end

    local frameStrata = "MEDIUM"
    local frameLevel = 1

    if baseButton.GetFrameStrata then
        local strata = baseButton:GetFrameStrata()
        if strata and strata ~= "" then
            frameStrata = strata
        end
    elseif QuestKing.Tracker and QuestKing.Tracker.GetFrameStrata then
        local strata = QuestKing.Tracker:GetFrameStrata()
        if strata and strata ~= "" then
            frameStrata = strata
        end
    end

    if baseButton.GetFrameLevel then
        frameLevel = baseButton:GetFrameLevel() or 1
    elseif QuestKing.Tracker and QuestKing.Tracker.GetFrameLevel then
        frameLevel = QuestKing.Tracker:GetFrameLevel() or 1
    end

    itemButton:SetFrameStrata(frameStrata)
    itemButton:SetFrameLevel(frameLevel + 25)

    if itemButton.SetToplevel then
        itemButton:SetToplevel(true)
    end
end

local function AcquireItemButton(baseButton)
    local itemButton = baseButton.itemButton
    if itemButton then
        itemButton.baseButton = baseButton
        ApplyItemButtonZOrder(itemButton, baseButton)
        return itemButton
    end

    if IsInCombatLockdownCompat() then
        if QuestKing.StartCombatTimer then
            QuestKing:StartCombatTimer()
        end
        return nil
    end

    if #itemButtonPool > 0 then
        itemButton = tremove(itemButtonPool)
    else
        itemButton = CreateFrame("Button", nil, QuestKing.Tracker, ITEM_BUTTON_TEMPLATE)
    end

    baseButton.itemButton = itemButton
    itemButton.baseButton = baseButton
    itemButton:ClearAllPoints()
    ApplyItemButtonZOrder(itemButton, baseButton)
    itemButton:Show()

    return itemButton
end

local function ResetRangeIndicator(itemButton)
    if not itemButton or not itemButton.HotKey then
        return
    end

    itemButton.HotKey:SetText(RANGE_INDICATOR)
    itemButton.HotKey:Hide()
    itemButton.HotKey:SetVertexColor(0.6, 0.6, 0.6)
end

local function UpdateRangeIndicator(itemButton)
    if not itemButton or not itemButton.questLogIndex or not itemButton.HotKey then
        return
    end

    local valid = IsQuestLogSpecialItemInRangeCompat(itemButton.questLogIndex)
    if valid == 0 then
        itemButton.HotKey:Show()
        itemButton.HotKey:SetVertexColor(1.0, 0.1, 0.1)
    elseif valid == 1 then
        itemButton.HotKey:Show()
        itemButton.HotKey:SetVertexColor(0.6, 0.6, 0.6)
    else
        itemButton.HotKey:Hide()
    end
end

local function ResizeItemButton(itemButton, displayedObj)
    local lineHeight = GetCurrentLineHeight()

    if displayedObj and displayedObj > 0 then
        itemButton:SetHeight(lineHeight * 2)
        if itemButton.icon then
            itemButton.icon:SetTexCoord(0, 1, 0, 1)
        end
        if itemButton.NormalTexture then
            itemButton.NormalTexture:SetHeight(42)
        end
    else
        itemButton:SetHeight(lineHeight)
        if itemButton.icon then
            itemButton.icon:SetTexCoord(0, 1, 0.25, 0.75)
        end
        if itemButton.NormalTexture then
            itemButton.NormalTexture:SetHeight(21)
        end
    end

    itemButton:SetWidth(lineHeight * 2)
    itemButton:SetScale(GetCurrentItemButtonScale())
    itemButton:SetAlpha(GetCurrentItemButtonAlpha())
end

function QuestKing.WatchButton:SetItemButton(questLogIndex, link, itemTexture, charges, displayedObj)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 or not link or not itemTexture then
        return nil
    end

    local itemButton = AcquireItemButton(self)
    if not itemButton then
        return nil
    end

    itemButton:SetParent(self)
    itemButton:ClearAllPoints()
    ApplyItemButtonZOrder(itemButton, self)

    if IsInCombatLockdownCompat() then
        local currentQuestLogIndex = itemButton.questLogIndex
        local currentItemLink = itemButton.GetAttribute and itemButton:GetAttribute("item") or nil

        if currentQuestLogIndex ~= questLogIndex or currentItemLink ~= link then
            itemButton._pendingQuestLogIndex = questLogIndex
            itemButton._pendingItemLink = link
            if QuestKing.StartCombatTimer then
                QuestKing:StartCombatTimer()
            end
            return itemButton
        end
    else
        itemButton:SetAttribute("type", "item")
        itemButton:SetAttribute("item", link)
        itemButton._pendingQuestLogIndex = nil
        itemButton._pendingItemLink = nil
    end

    itemButton.questLogIndex = questLogIndex
    itemButton.charges = charges
    itemButton.rangeTimer = 0
    itemButton.itemLink = link
    itemButton.itemID = SafeGetItemIDFromLink(link)

    SafeSetItemButtonTexture(itemButton, itemTexture)
    SafeSetItemButtonCount(itemButton, charges)
    QuestKing_QuestObjectiveItem_UpdateCooldown(itemButton)
    ResetRangeIndicator(itemButton)
    UpdateRangeIndicator(itemButton)
    ResizeItemButton(itemButton, displayedObj)
    ApplyItemButtonZOrder(itemButton, self)
    itemButton:Show()

    return itemButton
end

function QuestKing.WatchButton:RemoveItemButton()
    local itemButton = self.itemButton
    if not itemButton then
        return
    end

    if IsInCombatLockdownCompat() then
        if QuestKing.StartCombatTimer then
            QuestKing:StartCombatTimer()
        end
        return
    end

    SafeHideTooltip()

    itemButton:Hide()
    itemButton:ClearAllPoints()

    if itemButton.SetAttribute then
        itemButton:SetAttribute("item", nil)
    end

    ClearButtonState(itemButton)
    self.itemButton = nil

    ResetRangeIndicator(itemButton)
    tinsert(itemButtonPool, itemButton)
end

function QuestKing_QuestObjectiveItem_OnUpdate(self, elapsed)
    local rangeTimer = self.rangeTimer
    if not rangeTimer then
        return
    end

    rangeTimer = rangeTimer - elapsed
    if rangeTimer > 0 then
        self.rangeTimer = rangeTimer
        return
    end

    local link, itemTexture, charges = GetQuestLogSpecialItemInfoCompat(self.questLogIndex)
    if not link or not itemTexture then
        QueueTrackerRefresh(true)
        return
    end

    if charges ~= self.charges then
        QueueTrackerRefresh(true)
        return
    end

    if self.itemLink ~= link then
        self.itemLink = link
        self.itemID = SafeGetItemIDFromLink(link)
        if not IsInCombatLockdownCompat() and self.SetAttribute then
            self:SetAttribute("item", link)
        end
    end

    UpdateRangeIndicator(self)
    self.rangeTimer = RANGE_UPDATE_TIME
end

function QuestKing_QuestObjectiveItem_UpdateCooldown(itemButton)
    if not itemButton or not itemButton.questLogIndex or not itemButton.Cooldown then
        return
    end

    local start, duration, enable = GetQuestLogSpecialItemCooldownCompat(itemButton.questLogIndex)
    if not start then
        return
    end

    if type(CooldownFrame_SetTimer) == "function" then
        CooldownFrame_SetTimer(itemButton.Cooldown, start, duration or 0, enable)
    elseif itemButton.Cooldown.SetCooldown then
        itemButton.Cooldown:SetCooldown(start, duration or 0)
    end

    if (duration or 0) > 0 and enable == 0 then
        SafeSetItemButtonTextureVertexColor(itemButton, 0.4, 0.4, 0.4)
    else
        SafeSetItemButtonTextureVertexColor(itemButton, 1, 1, 1)
    end
end

function QuestKing_QuestObjectiveItem_OnEnter(self)
    if not self then
        return
    end

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, ((QuestKing.options or opt) and (QuestKing.options or opt).tooltipAnchor) or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    local shown = false

    if self.itemLink then
        shown = SafeSetHyperlink(tooltip, self.itemLink)
    end

    if not shown and self.itemID then
        shown = SafeSetItemByID(tooltip, self.itemID)
    end

    if not shown then
        local itemName = SafeGetItemName(self.itemLink, self.itemID)
        if itemName and itemName ~= "" then
            tooltip:SetText(itemName, 1, 1, 1)
            shown = true
        end
    end

    if shown then
        tooltip:Show()
    else
        SafeHideTooltip()
    end
end

function QuestKing_QuestObjectiveItem_OnLeave(self)
    SafeHideTooltip()
end
