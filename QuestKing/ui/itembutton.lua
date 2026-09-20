local addonName, QuestKing = ...

local opt = QuestKing.options or {}

local tinsert = table.insert
local tremove = table.remove
local tonumber = tonumber
local type = type

local itemButtonPool = {}
local RANGE_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2
local ITEM_BUTTON_TEMPLATE = "QuestKingItemButtonTemplate"
local SECURE_MODIFIED_CLICK_PREFIXES = {
    "shift-",
    "ctrl-",
    "alt-",
    "shift-ctrl-",
    "shift-alt-",
    "ctrl-alt-",
    "shift-ctrl-alt-",
    "ctrl-shift-",
    "alt-shift-",
    "alt-ctrl-",
    "ctrl-alt-shift-",
    "alt-ctrl-shift-",
}
local function QueueTrackerRefresh(forceBuild)
    if QuestKing and type(QuestKing.RequestTrackerUpdate) == "function" then
        QuestKing:RequestTrackerUpdate(false, "item", false)
        return
    end

    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(false, false, "item")
        return
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "item")
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

local function SafeGetActiveChatWindow()
    if ChatFrameUtil and type(ChatFrameUtil.GetActiveWindow) == "function" then
        local ok, activeWindow = pcall(ChatFrameUtil.GetActiveWindow)
        if ok and activeWindow then
            return activeWindow
        end
    end

    if type(_G.ChatEdit_GetActiveWindow) == "function" then
        local ok, activeWindow = pcall(_G.ChatEdit_GetActiveWindow)
        if ok and activeWindow then
            return activeWindow
        end
    end

    return nil
end

local function SafeInsertChatLink(link)
    if not link or not SafeGetActiveChatWindow() then
        return false
    end

    if ChatFrameUtil and type(ChatFrameUtil.InsertLink) == "function" then
        local ok, inserted = pcall(ChatFrameUtil.InsertLink, link)
        if ok and inserted ~= false then
            return true
        end
    end

    if type(_G.ChatEdit_InsertLink) == "function" then
        local ok, inserted = pcall(_G.ChatEdit_InsertLink, link)
        if ok and inserted ~= false then
            return true
        end
    end

    return false
end

local function IsChatLinkModifiedClick()
    if type(_G.IsModifiedClick) ~= "function" then
        return false
    end

    local ok, isModified = pcall(_G.IsModifiedClick, "CHATLINK")
    return ok and isModified and true or false
end

local function SafeSetAttribute(frame, name, value)
    if not frame or type(frame.SetAttribute) ~= "function" then
        return false
    end

    if IsInCombatLockdownCompat() then
        return false
    end

    local ok = pcall(frame.SetAttribute, frame, name, value)
    return ok and true or false
end

local function BuildSecureItemToken(itemID)
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        return "item:" .. itemID
    end

    return nil
end

local function ConfigureSecureItemUse(itemButton, questLogIndex, itemLink, itemID)
    if not itemButton or IsInCombatLockdownCompat() then
        return false
    end

    local item = BuildSecureItemToken(itemID or SafeGetItemIDFromLink(itemLink))
    if not item then
        return false
    end

    -- SecureActionButtonTemplate owns the protected use. Use a plain item:id
    -- token instead of a full item link. Full links route through item-name
    -- parsing on current clients and can taint C_Item.UseItemByName().
    SafeSetAttribute(itemButton, "type1", "item")
    SafeSetAttribute(itemButton, "item", item)
    SafeSetAttribute(itemButton, "item1", item)
    SafeSetAttribute(itemButton, "questLogIndex", questLogIndex)

    -- Modified chat-link clicks are handled in PostClick. ATTRIBUTE_NOOP keeps
    -- Shift/Ctrl/Alt left-clicks from also using the item.
    for index = 1, #SECURE_MODIFIED_CLICK_PREFIXES do
        SafeSetAttribute(itemButton, SECURE_MODIFIED_CLICK_PREFIXES[index] .. "type1", ATTRIBUTE_NOOP or "")
    end

    if type(itemButton.SetID) == "function" then
        pcall(itemButton.SetID, itemButton, questLogIndex)
    end

    return true
end

local function ClearSecureItemUse(itemButton)
    if not itemButton or IsInCombatLockdownCompat() then
        return
    end

    SafeSetAttribute(itemButton, "type1", nil)
    SafeSetAttribute(itemButton, "item", nil)
    SafeSetAttribute(itemButton, "item1", nil)
    SafeSetAttribute(itemButton, "questLogIndex", nil)

    for index = 1, #SECURE_MODIFIED_CLICK_PREFIXES do
        SafeSetAttribute(itemButton, SECURE_MODIFIED_CLICK_PREFIXES[index] .. "type1", nil)
    end

    if type(itemButton.SetID) == "function" then
        pcall(itemButton.SetID, itemButton, 0)
    end
end

local function QueuePostClickTrackerRefresh()
    QueueTrackerRefresh(false)
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
    itemButton._stateRefreshPending = nil

    ClearSecureItemUse(itemButton)

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

    -- Keep secure action buttons under the stable tracker. Reparenting one to
    -- a recyclable watch row makes that row protected and prevents combat-time
    -- mouse-state changes when the pool later reuses it for another row type.
    if itemButton.GetParent and itemButton:GetParent() ~= QuestKing.Tracker then
        itemButton:SetParent(QuestKing.Tracker)
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

    local inCombat = IsInCombatLockdownCompat()
    if inCombat then
        local currentQuestLogIndex = itemButton.questLogIndex
        local currentItemLink = itemButton.itemLink

        if currentQuestLogIndex ~= questLogIndex or currentItemLink ~= link then
            itemButton._pendingQuestLogIndex = questLogIndex
            itemButton._pendingItemLink = link
            if QuestKing.StartCombatTimer then
                QuestKing:StartCombatTimer()
            end
            return itemButton
        end

        itemButton.charges = charges
        itemButton.rangeTimer = itemButton.rangeTimer or 0
        itemButton._stateRefreshPending = nil
        SafeSetItemButtonTexture(itemButton, itemTexture)
        SafeSetItemButtonCount(itemButton, charges)
        QuestKing_QuestObjectiveItem_UpdateCooldown(itemButton)
        UpdateRangeIndicator(itemButton)
        return itemButton
    end

    if itemButton.GetParent and itemButton:GetParent() ~= QuestKing.Tracker then
        itemButton:SetParent(QuestKing.Tracker)
    end
    itemButton:ClearAllPoints()
    ApplyItemButtonZOrder(itemButton, self)

    itemButton._pendingQuestLogIndex = nil
    itemButton._pendingItemLink = nil
    itemButton._stateRefreshPending = nil
    itemButton.questLogIndex = questLogIndex
    itemButton.charges = charges
    itemButton.rangeTimer = 0
    itemButton.itemLink = link
    itemButton.itemID = SafeGetItemIDFromLink(link)

    ConfigureSecureItemUse(itemButton, questLogIndex, itemButton.itemLink, itemButton.itemID)
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
    if itemButton.GetParent and itemButton:GetParent() ~= QuestKing.Tracker then
        itemButton:SetParent(QuestKing.Tracker)
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

    self.rangeTimer = RANGE_UPDATE_TIME

    local link, itemTexture, charges = GetQuestLogSpecialItemInfoCompat(self.questLogIndex)
    if not link or not itemTexture then
        if not self._stateRefreshPending then
            self._stateRefreshPending = true
            QueueTrackerRefresh(false)
        end
        return
    end

    if charges ~= self.charges then
        if not self._stateRefreshPending then
            self._stateRefreshPending = true
            QueueTrackerRefresh(false)
        end
        return
    end

    if self.itemLink ~= link then
        if IsInCombatLockdownCompat() then
            self._pendingQuestLogIndex = self.questLogIndex
            self._pendingItemLink = link
            if QuestKing.StartCombatTimer then
                QuestKing:StartCombatTimer()
            end
        else
            self.itemLink = link
            self.itemID = SafeGetItemIDFromLink(link)
            ConfigureSecureItemUse(self, self.questLogIndex, self.itemLink, self.itemID)
        end
    end

    UpdateRangeIndicator(self)
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

function QuestKing_QuestObjectiveItem_OnClick(self, mouseButton, down, isKeyPress, isSecureAction)
    -- Compatibility wrapper for old cached XML. Current XML does not override
    -- OnClick; SecureActionButtonTemplate supplies the inherited handler.
    if type(SecureActionButton_OnClick) == "function" then
        return SecureActionButton_OnClick(self, mouseButton, down, isKeyPress, isSecureAction)
    end
end

function QuestKing_QuestObjectiveItem_PostClick(self, mouseButton)
    if not self then
        return
    end

    local questLogIndex = self.questLogIndex
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return
    end

    if IsChatLinkModifiedClick() then
        local link = self.itemLink
        if not link then
            link = GetQuestLogSpecialItemInfoCompat(questLogIndex)
        end

        SafeInsertChatLink(link)
        return
    end

    if mouseButton == "LeftButton" then
        QueuePostClickTrackerRefresh()
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
    local questLogIndex = self.questLogIndex

    if QuestKing.IsMainline then
        if questLogIndex
            and type(QuestKing.PopulatePrivateTooltipFromQuestLogSpecialItem) == "function" then
            shown = QuestKing:PopulatePrivateTooltipFromQuestLogSpecialItem(
                tooltip,
                questLogIndex
            )
        end

        if not shown
            and self.itemLink
            and type(QuestKing.PopulatePrivateTooltipFromHyperlink) == "function" then
            shown = QuestKing:PopulatePrivateTooltipFromHyperlink(
                tooltip,
                self.itemLink
            )
        end

        if not shown
            and self.itemID
            and type(QuestKing.PopulatePrivateTooltipFromItemID) == "function" then
            shown = QuestKing:PopulatePrivateTooltipFromItemID(
                tooltip,
                self.itemID
            )
        end
    else
        if questLogIndex and type(tooltip.SetQuestLogSpecialItem) == "function" then
            local ok = pcall(tooltip.SetQuestLogSpecialItem, tooltip, questLogIndex)
            shown = ok and true or false
        end

        if not shown and self.itemLink then
            shown = SafeSetHyperlink(tooltip, self.itemLink)
        end

        if not shown and self.itemID then
            shown = SafeSetItemByID(tooltip, self.itemID)
        end
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
