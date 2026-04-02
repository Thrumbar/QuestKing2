local addonName, QuestKing = ...

local opt = QuestKing.options

local tinsert = table.insert
local tremove = table.remove

local itemButtonPool = {}
local numItemButtons = 0

local RANGE_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2
local ITEM_BUTTON_TEMPLATE = "QuestKingItemButtonTemplate"

local function GetCurrentLineHeight()
    local lineHeight = opt and opt.lineHeight or 18
    if lineHeight < 1 then
        lineHeight = 18
    end
    return lineHeight
end

local function GetCurrentItemButtonScale()
    local scale = QuestKing.itemButtonScale or (opt and opt.itemButtonScale) or 1
    if scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetCurrentItemButtonAlpha()
    local alpha = QuestKing.itemButtonAlpha or 1
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    return alpha
end

local function IsInCombatLockdown()
    return InCombatLockdown and InCombatLockdown()
end

local function GetQuestLogSpecialItemInfoCompat(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil, nil, nil, nil
    end

    if GetQuestLogSpecialItemInfo then
        return GetQuestLogSpecialItemInfo(questLogIndex)
    end

    return nil, nil, nil, nil
end

local function GetQuestLogSpecialItemCooldownCompat(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return 0, 0, 0
    end

    if GetQuestLogSpecialItemCooldown then
        return GetQuestLogSpecialItemCooldown(questLogIndex)
    end

    return 0, 0, 0
end

local function IsQuestLogSpecialItemInRangeCompat(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if IsQuestLogSpecialItemInRange then
        return IsQuestLogSpecialItemInRange(questLogIndex)
    end

    return nil
end

local function SafeSetItemButtonTexture(itemButton, texture)
    if SetItemButtonTexture then
        SetItemButtonTexture(itemButton, texture)
        return
    end

    if itemButton and itemButton.icon then
        itemButton.icon:SetTexture(texture)
    end
end

local function SafeSetItemButtonCount(itemButton, charges)
    if SetItemButtonCount then
        SetItemButtonCount(itemButton, charges)
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
    if SetItemButtonTextureVertexColor then
        SetItemButtonTextureVertexColor(itemButton, r, g, b)
        return
    end

    if itemButton and itemButton.icon then
        itemButton.icon:SetVertexColor(r, g, b)
    end
end

local function AcquireItemButton(baseButton)
    local itemButton = baseButton.itemButton
    if itemButton then
        itemButton.baseButton = baseButton
        return itemButton
    end

    if IsInCombatLockdown() then
        if QuestKing.StartCombatTimer then
            QuestKing:StartCombatTimer()
        end
        return nil
    end

    if #itemButtonPool > 0 then
        itemButton = tremove(itemButtonPool)
    else
        numItemButtons = numItemButtons + 1
        itemButton = CreateFrame("Button", "QuestKing_ItemButton" .. numItemButtons, QuestKing.Tracker, ITEM_BUTTON_TEMPLATE)
    end

    baseButton.itemButton = itemButton
    itemButton.baseButton = baseButton
    itemButton:ClearAllPoints()
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
    if not questLogIndex or not link or not itemTexture then
        return nil
    end

    local itemButton = AcquireItemButton(self)
    if not itemButton then
        return nil
    end

    if IsInCombatLockdown() then
        local currentQuestLogIndex = itemButton.questLogIndex
        local currentItemLink = itemButton:GetAttribute("item")

        if currentQuestLogIndex ~= questLogIndex or currentItemLink ~= link then
            if QuestKing.StartCombatTimer then
                QuestKing:StartCombatTimer()
            end
            return itemButton
        end
    else
        itemButton:SetAttribute("type", "item")
        itemButton:SetAttribute("item", link)
    end

    itemButton.questLogIndex = questLogIndex
    itemButton.charges = charges
    itemButton.rangeTimer = 0

    SafeSetItemButtonTexture(itemButton, itemTexture)
    SafeSetItemButtonCount(itemButton, charges)
    QuestKing_QuestObjectiveItem_UpdateCooldown(itemButton)
    ResetRangeIndicator(itemButton)
    UpdateRangeIndicator(itemButton)
    ResizeItemButton(itemButton, displayedObj)

    return itemButton
end

function QuestKing.WatchButton:RemoveItemButton()
    local itemButton = self.itemButton
    if not itemButton then
        return
    end

    if IsInCombatLockdown() then
        if QuestKing.StartCombatTimer then
            QuestKing:StartCombatTimer()
        end
        return
    end

    itemButton:Hide()
    itemButton:ClearAllPoints()
    itemButton:SetScript("OnUpdate", QuestKing_QuestObjectiveItem_OnUpdate)

    itemButton.questLogIndex = nil
    itemButton.charges = nil
    itemButton.rangeTimer = nil

    itemButton:SetAttribute("item", nil)
    itemButton.baseButton = nil
    self.itemButton = nil

    if GameTooltip and GameTooltip:IsOwned(itemButton) then
        GameTooltip:Hide()
    end

    ResetRangeIndicator(itemButton)
    SafeSetItemButtonCount(itemButton, 0)
    SafeSetItemButtonTextureVertexColor(itemButton, 1, 1, 1)

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
        QuestKing:UpdateTracker()
        return
    end

    if charges ~= self.charges then
        QuestKing:UpdateTracker()
        return
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

    if CooldownFrame_SetTimer then
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
    if not self or not self.questLogIndex or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(self, (opt and opt.tooltipAnchor) or "ANCHOR_RIGHT")

    if GameTooltip.SetQuestLogSpecialItem then
        GameTooltip:SetQuestLogSpecialItem(self.questLogIndex)
    end
end

function QuestKing_QuestObjectiveItem_OnLeave(self)
    if GameTooltip then
        GameTooltip:Hide()
    end
end