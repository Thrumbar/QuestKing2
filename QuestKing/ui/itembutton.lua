local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_lineHeight = opt.lineHeight
local opt_itemButtonScale = opt.itemButtonScale

-- local variables
local itemButtonPool = {}
local numItemButtons = 0

--

function QuestKing.WatchButton:SetItemButton (questIndex, link, item, charges, displayedObj)
	local itemButton = self.itemButton

	if (not itemButton) then
		if (#itemButtonPool > 0) then
			itemButton = tremove(itemButtonPool)
		else
			numItemButtons = numItemButtons + 1
			itemButton = CreateFrame("Button", "QuestKing_ItemButton"..numItemButtons, UIParent, "QuestKingItemButtonTemplate")
		end

		self.itemButton = itemButton
		itemButton.baseButton = self

		itemButton:ClearAllPoints()
		itemButton:Show()
	end

	-- set values
	itemButton:SetAttribute("type", "item")
	itemButton:SetAttribute("item", link)

	itemButton.questLogIndex = questIndex
	itemButton.charges = charges
	itemButton.rangeTimer = -1

	SetItemButtonTexture(itemButton, item)
	SetItemButtonCount(itemButton, charges)
	QuestObjectiveItem_UpdateCooldown(itemButton);

	-- resize
	if displayedObj > 0 then
		itemButton:SetHeight(opt_lineHeight * 2)
		itemButton.icon:SetTexCoord(0, 1, 0, 1)
		itemButton.NormalTexture:SetHeight(42)
	else
		itemButton:SetHeight(opt_lineHeight)
		itemButton.icon:SetTexCoord(0, 1, 0.25, 0.75)
		itemButton.NormalTexture:SetHeight(21)
	end
	itemButton:SetWidth(opt_lineHeight * 2)
	itemButton:SetScale(QuestKing.itemButtonScale)
	itemButton:SetAlpha(QuestKing.itemButtonAlpha)

	return itemButton
end

function QuestObjectiveItem_OnEvent(self, event, ...)
	if ( event == "PLAYER_TARGET_CHANGED" ) then
		self.rangeTimer = -1;
	elseif ( event == "BAG_UPDATE_COOLDOWN" ) then
		QuestObjectiveItem_UpdateCooldown(self);
	end
end

function QuestKing.WatchButton:RemoveItemButton ()
	local itemButton = self.itemButton

	if (not itemButton) then return end

	itemButton:Hide()
	itemButton:ClearAllPoints()

	itemButton.questLogIndex = nil
	itemButton.charges = nil
	itemButton.rangeTimer = nil

	itemButton.baseButton = nil
	self.itemButton = nil

	tinsert(itemButtonPool, itemButton)
end

function QuestKing_QuestObjectiveItem_OnUpdate (self, elapsed)
	-- Handle range indicator
	local rangeTimer = self.rangeTimer;
	if ( rangeTimer ) then
		rangeTimer = rangeTimer - elapsed;
		if ( rangeTimer <= 0 ) then
			local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(self:GetID());
			if ( not charges or charges ~= self.charges ) then
				ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_QUEST);
				return;
			end
			local count = self.HotKey;
			local valid = IsQuestLogSpecialItemInRange(self:GetID());
			if ( valid == 0 ) then
				count:Show();
				count:SetVertexColor(1.0, 0.1, 0.1);
			elseif ( valid == 1 ) then
				count:Show();
				count:SetVertexColor(0.6, 0.6, 0.6);
			else
				count:Hide();
			end
			rangeTimer = TOOLTIP_UPDATE_TIME;
		end

		self.rangeTimer = rangeTimer;
	end
end

function QuestObjectiveItem_UpdateCooldown(itemButton)
	local start, duration, enable = GetQuestLogSpecialItemCooldown(itemButton:GetID());
	if ( start ) then
		CooldownFrame_Set(itemButton.Cooldown, start, duration, enable);
		if ( duration > 0 and enable == 0 ) then
			SetItemButtonTextureVertexColor(itemButton, 0.4, 0.4, 0.4);
		else
			SetItemButtonTextureVertexColor(itemButton, 1, 1, 1);
		end
	end
end