local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_buttonWidth = opt.buttonWidth
local opt_lineHeight = opt.lineHeight
local opt_itemButtonScale = opt.itemButtonScale

-- local functions
local freeProgressBar

-- local variables
local progressBarPool = {}
local numProgressBars = 0

local progressBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

--

function freeProgressBar (self)
	self:Hide()
	self:ClearAllPoints()

	self.baseLine.progressBar = nil
	self.baseLine = nil
	self.baseButton = nil

	self._lastPercent = nil

	tinsert(progressBarPool, self)
end

function setPercent (self, percent)
	self:SetValue(percent)
	self.text:SetFormattedText("%.1f%%", percent)

	local lastPercent = self._lastPercent
	if (lastPercent) and (percent ~= lastPercent) then
		
		local delta = percent - lastPercent
		if (delta < 0) then delta = 0 end

		if (delta >= 5) then
			if (self.topLineBurst.animGroup:IsPlaying()) then
				self.topLineBurst.animGroup:Stop()
				self.bottomLineBurst.animGroup:Stop()
			end
			self.topLineBurst.animGroup:Play()
			self.bottomLineBurst.animGroup:Play()
		end

		if (delta >= 1) then
			local width = self:GetWidth()
			local offset = (width * percent / 100)

			local deltaWidth = delta * (width / 100)
			if (deltaWidth < 2) then deltaWidth = 2 end

			self.glow:SetWidth(deltaWidth)
			self.glow:SetPoint("RIGHT", self, "LEFT", offset, 0)

			if (self.glow.animGroup:IsPlaying()) then
				self.glow.animGroup:Stop()
			end
			self.glow.animGroup:Play()
		end

		if (self.pulse.animGroup:IsPlaying()) then
			self.pulse.animGroup:Stop()
		end
		self.pulse.animGroup:Play()		
	end

	self._lastPercent = percent
end

function QuestKing.WatchButton:AddProgressBar (duration, startTime)
	local line = self:AddLine()
	local progressBar = line.progressBar

	if (not progressBar) then
		if (#progressBarPool > 0) then
			progressBar = tremove(progressBarPool)
		else
			numProgressBars = numProgressBars + 1

			progressBar = CreateFrame("StatusBar", "QuestKing_ProgressBar"..numProgressBars, QuestKing.Tracker)
			progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
			progressBar:GetStatusBarTexture():SetHorizTile(false)
			progressBar:SetStatusBarColor(0.2, 0.4, 0.9)
			progressBar:SetMinMaxValues(0, 100)
			progressBar:SetValue(100)
			progressBar:SetWidth(opt_buttonWidth - 36)
			progressBar:SetHeight(15)

			progressBar:SetBackdrop(progressBackdrop)
			progressBar:SetBackdropColor(0, 0, 0, 0.4)

			local border = progressBar:CreateTexture(nil, "OVERLAY")
			border:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-Skills-BarBorder]])
			border:SetPoint("TOPLEFT", progressBar, "TOPLEFT", -3, 8)
			border:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 3, -8)
			progressBar.border = border

			local text = progressBar:CreateFontString(nil, "OVERLAY")
			text:SetFont(opt.font, opt.fontSize - 1, opt.fontStyle)
			text:SetJustifyH("CENTER")
			text:SetJustifyV("CENTER")
			
			text:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
			text:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 0, 2)
			
			text:SetTextColor(1, 1, 1)
			text:SetShadowOffset(1, -1)
			text:SetShadowColor(0, 0, 0, 1)
			text:SetWordWrap(false)
			text:SetVertexColor(0.8, 0.8, 0.8)
			text:SetText("0%")
			progressBar.text = text

			local glow = progressBar:CreateTexture(nil, "OVERLAY")
			glow:SetPoint("RIGHT", progressBar, "LEFT", 0, 0)
			glow:SetWidth(5)
			glow:SetHeight(progressBar:GetHeight() - 4)
			glow:SetTexture([[Interface\AddOns\QuestKing\textures\Full-Line-Glow-White]])
			glow:SetVertexColor(0.6, 0.8, 1, 0)
			glow:SetBlendMode("ADD")		
			progressBar.glow = glow

			local animGroup = glow:CreateAnimationGroup()
			local a0 = animGroup:CreateAnimation("Alpha")
				a0:SetStartDelay(0); a0:SetChange(1); a0:SetDuration(0.25); a0:SetOrder(1);
			local a1 = animGroup:CreateAnimation("Alpha")
				a1:SetStartDelay(0.3); a1:SetChange(-1); a1:SetDuration(0.2); a1:SetOrder(1);
			glow.animGroup = animGroup

			local topLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
			topLineBurst:SetPoint("CENTER", glow, "TOP", -3, 0)
			topLineBurst:SetWidth(progressBar:GetWidth() * 0.6)
			topLineBurst:SetHeight(8)
			topLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
			topLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
			topLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
			topLineBurst:SetBlendMode("ADD")		
			progressBar.topLineBurst = topLineBurst

			local animGroup = topLineBurst:CreateAnimationGroup()
			local a0 = animGroup:CreateAnimation("Alpha")
				a0:SetStartDelay(0); a0:SetChange(1); a0:SetDuration(0.25); a0:SetOrder(1);
			local a1 = animGroup:CreateAnimation("Alpha")
				a1:SetStartDelay(0.3); a1:SetChange(-1); a1:SetDuration(0.2); a1:SetOrder(1);
			local a2 = animGroup:CreateAnimation("Translation")
				a2:SetStartDelay(0); a2:SetOffset(5, 0); a2:SetDuration(0.25); a2:SetOrder(1);
			topLineBurst.animGroup = animGroup

			local bottomLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
			bottomLineBurst:SetPoint("CENTER", glow, "BOTTOM", -3, 0)
			bottomLineBurst:SetWidth(progressBar:GetWidth() * 0.6)
			bottomLineBurst:SetHeight(8)
			bottomLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
			bottomLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
			bottomLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
			bottomLineBurst:SetBlendMode("ADD")		
			progressBar.bottomLineBurst = bottomLineBurst

			local animGroup = bottomLineBurst:CreateAnimationGroup()
			local a0 = animGroup:CreateAnimation("Alpha")
				a0:SetStartDelay(0); a0:SetChange(1); a0:SetDuration(0.25); a0:SetOrder(1);
			local a1 = animGroup:CreateAnimation("Alpha")
				a1:SetStartDelay(0.3); a1:SetChange(-1); a1:SetDuration(0.2); a1:SetOrder(1);
			local a2 = animGroup:CreateAnimation("Translation")
				a2:SetStartDelay(0); a2:SetOffset(5, 0); a2:SetDuration(0.25); a2:SetOrder(1);
			bottomLineBurst.animGroup = animGroup

			local pulse = progressBar:CreateTexture(nil, "OVERLAY")
			pulse:SetAllPoints(progressBar)
			pulse:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
			pulse:SetVertexColor(0.6, 0.8, 1, 0)
			pulse:SetBlendMode("ADD")		
			progressBar.pulse = pulse

			local animGroup = pulse:CreateAnimationGroup()
			local a1 = animGroup:CreateAnimation("Alpha")
				a1:SetStartDelay(0); a1:SetDuration(0.25); a1:SetChange(1); a1:SetOrder(1);
			local a2 = animGroup:CreateAnimation("Alpha")
				a2:SetStartDelay(0.3); a2:SetDuration(0.2); a2:SetChange(-1); a2:SetOrder(1);
			pulse.animGroup = animGroup

			progressBar.Free = freeProgressBar
			progressBar.SetPercent = setPercent
		end

		line.progressBar = progressBar
		line.progressBarText = progressBarText

		progressBar.baseButton = self
		progressBar.baseLine = line

		progressBar._lastPercent = nil

		progressBar:SetPoint("TOPLEFT", line, "TOPLEFT", 16, -3)
		progressBar:Show()
	end

	return progressBar
end
