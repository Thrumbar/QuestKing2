local addonName, QuestKing = ...

local opt = QuestKing.options or {}

local rewardQueue = {}
local animatingData = nil

local tinsert = table.insert
local tremove = table.remove
local type = type
local tonumber = tonumber
local unpack = table.unpack or unpack

local REWARD_SOUND_KIT = 45142

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h, i
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function SafeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    local converted = tonumber(value)
    if type(converted) == "number" then
        return converted
    end

    return fallback
end

local function SafeString(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return fallback
end

local function QueueTrackerRefresh(forceBuild)
    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
        return
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function SafeClearDummyTask(questID)
    if QuestKing and type(QuestKing.ClearDummyTask) == "function" then
        QuestKing:ClearDummyTask(questID)
    end
end

local function GetRewardsFrame()
    return QuestKing_RewardsFrame
end

local function PlayRewardSound()
    if type(PlaySound) ~= "function" then
        return
    end

    if SOUNDKIT and SOUNDKIT.UI_GARRISON_COMMAND_TABLE_SELECT_MISSION then
        pcall(PlaySound, SOUNDKIT.UI_GARRISON_COMMAND_TABLE_SELECT_MISSION)
        return
    end

    pcall(PlaySound, REWARD_SOUND_KIT)
end

local function QueueDummyTaskCleanup(questID, delay)
    if type(questID) ~= "number" or questID <= 0 then
        return
    end

    local function Cleanup()
        SafeClearDummyTask(questID)
        QueueTrackerRefresh(true)
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or 0, Cleanup)
    else
        Cleanup()
    end
end

local function GetPlayerAtEffectiveMaxLevel()
    if type(IsPlayerAtEffectiveMaxLevel) == "function" then
        local ok, atMax = SafeCall(IsPlayerAtEffectiveMaxLevel)
        if ok then
            return atMax and true or false
        end
    end

    local maxLevel = nil

    if C_LevelSquish and type(C_LevelSquish.GetMaxPlayerLevel) == "function" then
        local ok, level = SafeCall(C_LevelSquish.GetMaxPlayerLevel)
        if ok then
            maxLevel = SafeNumber(level, nil)
        end
    end

    if not maxLevel and type(GetMaxPlayerLevel) == "function" then
        local ok, level = SafeCall(GetMaxPlayerLevel)
        if ok then
            maxLevel = SafeNumber(level, nil)
        end
    end

    if not maxLevel and type(MAX_PLAYER_LEVEL) == "number" then
        maxLevel = MAX_PLAYER_LEVEL
    end

    if maxLevel and type(UnitLevel) == "function" then
        local ok, level = SafeCall(UnitLevel, "player")
        if ok and type(level) == "number" then
            return level >= maxLevel
        end
    end

    return false
end

local function GetQuestRewardXPCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return 0
    end

    if C_QuestLog and type(C_QuestLog.GetQuestRewardXP) == "function" then
        local ok, xp = SafeCall(C_QuestLog.GetQuestRewardXP, questID)
        if ok then
            return SafeNumber(xp, 0) or 0
        end
    end

    if type(GetQuestLogRewardXP) == "function" then
        local ok, xp = SafeCall(GetQuestLogRewardXP, questID)
        if ok then
            return SafeNumber(xp, 0) or 0
        end
    end

    return 0
end

local function GetQuestRewardMoneyCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return 0
    end

    if C_QuestLog and type(C_QuestLog.GetQuestLogRewardMoney) == "function" then
        local ok, money = SafeCall(C_QuestLog.GetQuestLogRewardMoney, questID)
        if ok then
            return SafeNumber(money, 0) or 0
        end
    end

    if type(GetQuestLogRewardMoney) == "function" then
        local ok, money = SafeCall(GetQuestLogRewardMoney, questID)
        if ok then
            return SafeNumber(money, 0) or 0
        end
    end

    return 0
end

local function GetQuestRewardCurrenciesCompat(questID)
    local rewards = {}

    if type(questID) ~= "number" or questID <= 0 then
        return rewards
    end

    if C_QuestLog and type(C_QuestLog.GetQuestRewardCurrencies) == "function" then
        local ok, data = SafeCall(C_QuestLog.GetQuestRewardCurrencies, questID)
        if ok and type(data) == "table" then
            for index = 1, #data do
                local reward = data[index]
                if type(reward) == "table" then
                    rewards[#rewards + 1] = {
                        label = SafeString(reward.name, nil),
                        texture = reward.texture,
                        count = SafeNumber(reward.totalRewardAmount, nil)
                            or SafeNumber(reward.baseRewardAmount, nil)
                            or SafeNumber(reward.bonusRewardAmount, 0)
                            or 0,
                        fontObject = "GameFontHighlightSmall",
                        quality = SafeNumber(reward.quality, nil),
                    }
                end
            end

            return rewards
        end
    end

    if type(GetNumQuestLogRewardCurrencies) == "function" and type(GetQuestLogRewardCurrencyInfo) == "function" then
        local okCount, count = SafeCall(GetNumQuestLogRewardCurrencies, questID)
        count = okCount and (SafeNumber(count, 0) or 0) or 0

        for index = 1, count do
            local okInfo, name, texture, numItems, _, quality = SafeCall(GetQuestLogRewardCurrencyInfo, index, questID)
            if okInfo then
                rewards[#rewards + 1] = {
                    label = SafeString(name, nil),
                    texture = texture,
                    count = SafeNumber(numItems, 0) or 0,
                    fontObject = "GameFontHighlightSmall",
                    quality = SafeNumber(quality, nil),
                }
            end
        end
    end

    return rewards
end

local function GetQuestRewardItemsCompat(questID)
    local rewards = {}

    if type(questID) ~= "number" or questID <= 0 then
        return rewards
    end

    if type(GetNumQuestLogRewards) == "function" and type(GetQuestLogRewardInfo) == "function" then
        local okCount, count = SafeCall(GetNumQuestLogRewards, questID)
        count = okCount and (SafeNumber(count, 0) or 0) or 0

        for index = 1, count do
            local okInfo, name, texture, numItems, quality = SafeCall(GetQuestLogRewardInfo, index, questID)
            if okInfo then
                rewards[#rewards + 1] = {
                    label = SafeString(name, nil),
                    texture = texture,
                    count = SafeNumber(numItems, 0) or 0,
                    fontObject = "GameFontHighlightSmall",
                    quality = SafeNumber(quality, nil),
                }
            end
        end
    end

    return rewards
end

local function ResolveFontObject(fontObjectName)
    if type(fontObjectName) == "table" then
        return fontObjectName
    end

    if type(fontObjectName) == "string" then
        return _G[fontObjectName]
    end

    return nil
end

local function EnsureRewardFramePool(rewardsFrame)
    if type(rewardsFrame.rewardFrames) == "table" then
        return rewardsFrame.rewardFrames
    end

    rewardsFrame.rewardFrames = {}

    if rewardsFrame.Rewards and rewardsFrame.Rewards[1] then
        rewardsFrame.rewardFrames[1] = rewardsFrame.Rewards[1]
    end

    return rewardsFrame.rewardFrames
end

local function ResetRewardItemFrame(rewardItem)
    if not rewardItem then
        return
    end

    if rewardItem.Anim and rewardItem.Anim.IsPlaying and rewardItem.Anim:IsPlaying() then
        rewardItem.Anim:Stop()
    end

    if rewardItem.Count then
        rewardItem.Count:SetText("")
        rewardItem.Count:Hide()
        rewardItem.Count:SetAlpha(0)
    end

    if rewardItem.Label then
        rewardItem.Label:SetText("")
        rewardItem.Label:SetAlpha(0)
    end

    if rewardItem.ItemIcon then
        rewardItem.ItemIcon:SetTexture(nil)
        rewardItem.ItemIcon:SetAlpha(0)
    end

    if rewardItem.ItemBorder then
        rewardItem.ItemBorder:SetAlpha(0)
        if rewardItem.ItemBorder.SetVertexColor then
            rewardItem.ItemBorder:SetVertexColor(1, 1, 1, 1)
        end
    end
end

local function AcquireRewardItemFrame(rewardsFrame, index)
    local frames = EnsureRewardFramePool(rewardsFrame)
    local rewardItem = frames[index]

    if rewardItem then
        ResetRewardItemFrame(rewardItem)
        return rewardItem
    end

    rewardItem = CreateFrame("Frame", nil, rewardsFrame, "QuestKing_RewardTemplate")
    frames[index] = rewardItem

    if index == 1 then
        rewardItem:SetPoint("TOPLEFT", rewardsFrame.RewardsTop, "BOTTOMLEFT", 25, 0)
    else
        rewardItem:SetPoint("TOPLEFT", frames[index - 1], "BOTTOMLEFT", 0, -4)
    end

    ResetRewardItemFrame(rewardItem)
    return rewardItem
end

local function HideUnusedRewardFrames(rewardsFrame, firstUnusedIndex)
    local frames = EnsureRewardFramePool(rewardsFrame)
    for index = firstUnusedIndex, #frames do
        local frame = frames[index]
        if frame then
            ResetRewardItemFrame(frame)
            frame:Hide()
        end
    end
end

local function SetAnimationShadowScale(rewardsFrame, contentsHeight)
    if not (rewardsFrame and rewardsFrame.Anim and rewardsFrame.Anim.RewardsShadowAnim) then
        return
    end

    local scaleY = contentsHeight / 16
    local anim = rewardsFrame.Anim.RewardsShadowAnim

    if anim.SetScaleTo then
        anim:SetScaleTo(0.8, scaleY)
    elseif anim.SetToScale then
        anim:SetToScale(0.8, scaleY)
    end
end

local function ResolveAnchorButton(button)
    if button and button.IsVisible and button:IsVisible() then
        return button
    end

    if QuestKing and QuestKing.Tracker then
        return QuestKing.Tracker
    end

    return UIParent
end

local function PositionRewardsFrame(rewardsFrame, button)
    local anchorButton = ResolveAnchorButton(button)
    local tracker = QuestKing and QuestKing.Tracker
    local trackerScale = (tracker and tracker.GetScale and tracker:GetScale()) or 1

    rewardsFrame:ClearAllPoints()

    local right = anchorButton and anchorButton.GetRight and anchorButton:GetRight()
    local left = anchorButton and anchorButton.GetLeft and anchorButton:GetLeft()
    local top = anchorButton and anchorButton.GetTop and anchorButton:GetTop()

    if not top then
        rewardsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    if opt.rewardAnchorSide == "right" and right then
        rewardsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right * trackerScale - 10, top * trackerScale)
    elseif left then
        rewardsFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left * trackerScale + 10, top * trackerScale)
    else
        rewardsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function BuildRewardData(button, questID, xp, money)
    local data = {
        button = button,
        questID = questID,
        rewards = {},
    }

    if xp == nil and questID then
        xp = GetQuestRewardXPCompat(questID)
    end

    if type(xp) == "number" and xp > 0 and not GetPlayerAtEffectiveMaxLevel() then
        data.rewards[#data.rewards + 1] = {
            label = xp,
            texture = "Interface\\Icons\\XP_Icon",
            count = 0,
            fontObject = "NumberFontNormal",
        }
    end

    if questID then
        local currencies = GetQuestRewardCurrenciesCompat(questID)
        for index = 1, #currencies do
            local reward = currencies[index]
            if reward and reward.texture and reward.label then
                data.rewards[#data.rewards + 1] = reward
            end
        end

        local items = GetQuestRewardItemsCompat(questID)
        for index = 1, #items do
            local reward = items[index]
            if reward and reward.texture and reward.label then
                data.rewards[#data.rewards + 1] = reward
            end
        end
    end

    if money == nil and questID then
        money = GetQuestRewardMoneyCompat(questID)
    end

    if type(money) == "number" and money > 0 and type(GetMoneyString) == "function" then
        data.rewards[#data.rewards + 1] = {
            label = GetMoneyString(money),
            texture = "Interface\\Icons\\inv_misc_coin_01",
            count = 0,
            fontObject = "GameFontHighlight",
        }
    end

    return data
end

local function ApplyRewardQualityBorder(rewardItem, quality)
    if not rewardItem or not rewardItem.ItemBorder then
        return
    end

    rewardItem.ItemBorder:SetAlpha(1)

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1] or nil
    if color and rewardItem.ItemBorder.SetVertexColor then
        rewardItem.ItemBorder:SetVertexColor(color.r, color.g, color.b, 1)
    end
end

local function PopulateRewardItemFrame(rewardItem, rewardData)
    local count = SafeNumber(rewardData.count, 0) or 0

    if rewardItem.Count then
        if count > 1 then
            rewardItem.Count:SetShown(true)
            rewardItem.Count:SetText(count)
        else
            rewardItem.Count:SetShown(false)
            rewardItem.Count:SetText("")
        end
    end

    if rewardItem.Label then
        local fontObject = ResolveFontObject(rewardData.fontObject)
        if fontObject and rewardItem.Label.SetFontObject then
            rewardItem.Label:SetFontObject(fontObject)
        end
        rewardItem.Label:SetText(rewardData.label or "")
    end

    if rewardItem.ItemIcon then
        rewardItem.ItemIcon:SetTexture(rewardData.texture)
    end

    ApplyRewardQualityBorder(rewardItem, rewardData.quality)
    rewardItem:Show()

    if rewardItem.Anim and rewardItem.Anim.IsPlaying and rewardItem.Anim:IsPlaying() then
        rewardItem.Anim:Stop()
    end

    if rewardItem.Anim then
        rewardItem.Anim:Play()
    end
end

function QuestKing:AddReward(button, questID, xp, money)
    local data = BuildRewardData(button, questID, xp, money)

    if #data.rewards > 0 then
        tinsert(rewardQueue, data)
        self:AnimateReward()
    elseif questID then
        QueueDummyTaskCleanup(questID, 10)
    end
end

function QuestKing:AnimateReward()
    local rewardsFrame = GetRewardsFrame()
    if not rewardsFrame then
        animatingData = nil
        return
    end

    if rewardsFrame.Anim and rewardsFrame.Anim.IsPlaying and rewardsFrame.Anim:IsPlaying() then
        return
    end

    if #rewardQueue == 0 then
        animatingData = nil
        rewardsFrame:Hide()
        return
    end

    local data = tremove(rewardQueue, 1)
    animatingData = data

    PositionRewardsFrame(rewardsFrame, data.button)
    rewardsFrame:Show()

    local numRewards = #data.rewards
    local contentsHeight = 12 + numRewards * 36

    if rewardsFrame.Anim and rewardsFrame.Anim.RewardsBottomAnim and rewardsFrame.Anim.RewardsBottomAnim.SetOffset then
        rewardsFrame.Anim.RewardsBottomAnim:SetOffset(0, -contentsHeight)
    end
    SetAnimationShadowScale(rewardsFrame, contentsHeight)

    for index = 1, numRewards do
        local rewardItem = AcquireRewardItemFrame(rewardsFrame, index)
        PopulateRewardItemFrame(rewardItem, data.rewards[index])
    end

    HideUnusedRewardFrames(rewardsFrame, numRewards + 1)

    if rewardsFrame.Anim then
        rewardsFrame.Anim:Play()
    end

    PlayRewardSound()
end

function QuestKing_OnAnimateRewardDone()
    local completedData = animatingData
    if completedData and completedData.questID then
        QueueDummyTaskCleanup(completedData.questID, 3)
    end

    animatingData = nil
    QuestKing:AnimateReward()
end
