if IsAddOnLoaded("PetTracker") then

	PetTracker.Objectives.Startup = function (self)
		local header = QuestKing.WatchButton:Create()
		self.Header = header
		header:SetParent(self)
		header:SetPoint("TOPLEFT")
		header:Show()

		header.mouseHandler = {}
		header.mouseHandler.TitleButtonOnClick = self.ToggleOptions

		header.title:SetText(PetTracker.Locals.BattlePets)
		header.title:SetVertexColor(0.5, 0.65, 0.85, 1)

		self.Anchor:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, -8)
		self.Anchor:SetWidth(QuestKing.options.buttonWidth)

		self:SetParent(QuestKing.Tracker)
		self:SetPoint("TOPLEFT", QuestKing.Tracker, "BOTTOMLEFT", 0, -5)

		self.maxEntries = 1000

		table.insert(QuestKing.updateHooks, function()
			if (QuestKingDBPerChar.trackerCollapsed > 0) then
				self:Hide()
			elseif (PetTracker.Sets.HideTracker) then
				self:Hide()
			else
				self:Show()
			end
		end)

		-- end
	end

	PetTracker.Objectives.TrackingChanged = function (self)
		self:Update()

		if (QuestKingDBPerChar.trackerCollapsed > 0) then
			self:Hide()
		elseif (PetTracker.Sets.HideTracker) then
			self:Hide()
		else
			self:Show()
		end
	end	

end
