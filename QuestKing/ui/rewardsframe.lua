local addonName, QuestKing = ...

local opt = QuestKing.options

local rewardQueue = {}
local animatingData = nil

local tinsert = table.insert
local tremove = table.remove
local type = type
local tonumber = tonumber
local unpack = table.unpack or unpack

local REWARD_SOUND_KIT = 45142

local function SafeUpdateTracker()
    if QuestKing and QuestKing.UpdateTracker then
        QuestKing:UpdateTracker()
    end
end

local function SafeClearDummyTask(questID)
    if QuestKing and QuestKing.ClearDummyTask then
        QuestKing:ClearDummyTask(questID)
    end
end

local function GetPlayerMaxLevelSafe()
    if type(IsPlayerAtEffectiveMaxLevel) == "function" then
        return IsPlayerAtEffectiveMaxLevel()
    end

    if type(MAX_PLAYER_LEVEL) == "number" and MAX_PLAYER_LEVEL > 0 then
        local playerLevel = UnitLevel("player") or 0
        return playerLevel >= MAX_PLAYER_LEVEL
    end

    if C_LevelSquish and type(C_LevelSquish.GetMaxPlayerLevel) == "function" then
        local level = C_LevelSquish.GetMaxPlayerLevel()
        if type(level) == "number" and level > 0 then
            return (UnitLevel("player") or 0) >= level
        end
    end

    if type(GetMaxPlayerLevel) == "function" then
        local level = GetMaxPlayerLevel()
        if type(level) == "number" and level > 0 then
            return (UnitLevel("player") or 0) >= level
        end
    end

    return false
end

local function GetQuestRewardXPCompat(questID)
    if questID and type(GetQuestLogRewardXP) == "function" then
        return GetQuestLogRewardXP(questID) or 0
    end

    return 0
end

local function GetQuestRewardMoneyCompat(questID)
    if questID and type(GetQuestLogRewardMoney) == "function" then
        return GetQuestLogRewardMoney(questID) or 0
    end

    return 0
end

local function GetQuestRewardCurrenciesCompat(questID)
    if not questID then
        return {}
    end

    if C_QuestLog and type(C_QuestLog.GetQuestRewardCurrencies) == "function" then
        local rewards = C_QuestLog.GetQuestRewardCurrencies(questID)
        if type(rewards) == "table" then
            return rewards
        end
    end

    local rewards = {}

    if type(GetNumQuestLogRewardCurrencies) == "function" and type(GetQuestLogRewardCurrencyInfo) == "function" then
        local numCurrencies = GetNumQuestLogRewardCurrencies(questID) or 0
        for index = 1, numCurrencies do
            local name, texture, count = GetQuestLogRewardCurrencyInfo(index, questID)
            rewards[#rewards + 1] = {
                name = name,
                texture = texture,
                totalRewardAmount = count or 0,
            }
        end
    end

    return rewards
end

local function GetQuestRewardItemsCompat(questID)
    local rewards = {}

    if not questID then
        return rewards
    end

    if type(GetNumQuestLogRewards) == "function" and type(GetQuestLogRewardInfo) == "function" then
        local numItems = GetNumQuestLogRewards(questID) or 0
        for index = 1, numItems do
            local name, texture, count = GetQuestLogRewardInfo(index, questID)
            rewards[#rewards + 1] = {
                name = name,
                texture = texture,
                count = count or 0,
            }
        end
    end

    return rewards
end

local function QueueDummyTaskCleanup(questID, delay)
    if not questID then
        return
    end

    local function Cleanup()
        SafeClearDummyTask(questID)
        SafeUpdateTracker()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or 0, Cleanup)
    else
        Cleanup()
    end
end

local function PlayRewardSound()
    if not PlaySound then
        return
    end

    PlaySound(REWARD_SOUND_KIT)
end

local function GetRewardsFrame()
    return QuestKing_RewardsFrame
end

local function EnsureRewardFramePool(rewardsFrame)
    if rewardsFrame.rewardFrames then
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

    if rewardItem.Anim and rewardItem.Anim:IsPlaying() then
        rewardItem.Anim:Stop()
    end

    if rewardItem.Count then
        rewardItem.Count:SetText("")
        rewardItem.Count:Hide()
    end

    if rewardItem.Label then
        rewardItem.Label:SetText("")
    end

    if rewardItem.ItemIcon then
        rewardItem.ItemIcon:SetTexture(nil)
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
    local scaleY = contentsHeight / 16
    if rewardsFrame.Anim and rewardsFrame.Anim.RewardsShadowAnim then
        local anim = rewardsFrame.Anim.RewardsShadowAnim
        if anim.SetScaleTo then
            anim:SetScaleTo(0.8, scaleY)
        elseif anim.SetToScale then
            anim:SetToScale(0.8, scaleY)
        end
    end
end

local function ResolveAnchorButton(button)
    if button and button.IsVisible and button:IsVisible() then
        return button
    end

    return QuestKing.Tracker
end

local function PositionRewardsFrame(rewardsFrame, button)
    local anchorButton = ResolveAnchorButton(button)
    local tracker = QuestKing.Tracker
    local scale = (tracker and tracker.GetScale and tracker:GetScale()) or 1

    rewardsFrame:ClearAllPoints()

    local right = anchorButton and anchorButton.GetRight and anchorButton:GetRight()
    local left = anchorButton and anchorButton.GetLeft and anchorButton:GetLeft()
    local top = anchorButton and anchorButton.GetTop and anchorButton:GetTop()

    if not top then
        rewardsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    if opt.rewardAnchorSide == "right" and right then
        rewardsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right * scale - 10, top * scale)
    elseif left then
        rewardsFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left * scale + 10, top * scale)
    else
        rewardsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function QuestKing:AddReward(button, questID, xp, money)
    local data = {
        button = button,
        questID = questID,
        rewards = {},
    }

    if xp == nil and questID then
        xp = GetQuestRewardXPCompat(questID)
    end

    if type(xp) == "number" and xp > 0 and not GetPlayerMaxLevelSafe() then
        data.rewards[#data.rewards + 1] = {
            label = xp,
            texture = "Interface\\Icons\\XP_Icon",
            count = 0,
            font = "NumberFontNormal",
        }
    end

    if questID then
        local currencies = GetQuestRewardCurrenciesCompat(questID)
        for index = 1, #currencies do
            local reward = currencies[index]
            if reward and reward.texture and reward.name then
                data.rewards[#data.rewards + 1] = {
                    label = reward.name,
                    texture = reward.texture,
                    count = reward.totalRewardAmount or reward.baseRewardAmount or reward.bonusRewardAmount or 0,
                    font = "GameFontHighlightSmall",
                }
            end
        end

        local items = GetQuestRewardItemsCompat(questID)
        for index = 1, #items do
            local reward = items[index]
            if reward and reward.texture and reward.name then
                data.rewards[#data.rewards + 1] = {
                    label = reward.name,
                    texture = reward.texture,
                    count = reward.count or 0,
                    font = "GameFontHighlightSmall",
                }
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
            font = "GameFontHighlight",
        }
    end

    if #data.rewards > 0 then
        tinsert(rewardQueue, data)
        QuestKing:AnimateReward()
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

    if rewardsFrame.Anim and rewardsFrame.Anim:IsPlaying() then
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

    if rewardsFrame.Anim and rewardsFrame.Anim.RewardsBottomAnim then
        rewardsFrame.Anim.RewardsBottomAnim:SetOffset(0, -contentsHeight)
    end
    SetAnimationShadowScale(rewardsFrame, contentsHeight)

    for index = 1, numRewards do
        local rewardItem = AcquireRewardItemFrame(rewardsFrame, index)
        local rewardData = data.rewards[index]
        local count = tonumber(rewardData.count) or 0

        if count > 1 then
            rewardItem.Count:Show()
            rewardItem.Count:SetText(count)
        else
            rewardItem.Count:Hide()
            rewardItem.Count:SetText("")
        end

        if rewardItem.Label and rewardData.font and rewardItem.Label.SetFontObject then
            rewardItem.Label:SetFontObject(rewardData.font)
        end
        rewardItem.Label:SetText(rewardData.label or "")
        rewardItem.ItemIcon:SetTexture(rewardData.texture)
        rewardItem:Show()

        if rewardItem.Anim and rewardItem.Anim:IsPlaying() then
            rewardItem.Anim:Stop()
        end
        if rewardItem.Anim then
            rewardItem.Anim:Play()
        end
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