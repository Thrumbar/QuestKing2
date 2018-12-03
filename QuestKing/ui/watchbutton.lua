local addonName, QuestKing = ...

-- options
local opt = QuestKing.options

local opt_font = opt.font
local opt_fontChallengeTimer = opt.fontChallengeTimer
local opt_fontSize = opt.fontSize
local opt_fontStyle = opt.fontStyle
local opt_fontLayer = opt.fontLayer

local opt_buttonWidth = opt.buttonWidth
local opt_lineHeight = opt.lineHeight
local opt_titleHeight = opt.titleHeight

local opt_colors = opt.colors

local opt_itemButtonScale = opt.itemButtonScale
local opt_itemAnchorSide = opt.itemAnchorSide

-- import
local tinsert = table.insert
local tremove = table.remove

--

local WatchButtonPrototype = CreateFrame("Frame")
local WatchButton = setmetatable({}, { __index = WatchButtonPrototype })
WatchButton.__index = WatchButton
QuestKing.WatchButton = WatchButton
do
	local buttonCounter = 0

	local usedPool = {}
	local freePool = {}
	local requestOrder = {}
	WatchButton.usedPool = usedPool
	WatchButton.freePool = freePool
	WatchButton.requestOrder = requestOrder

	WatchButton.requestCount = 0

	function WatchButton:StartOrder()
		for i = 1, #usedPool do
			local button = usedPool[i]
			button.wasRequested = false
		end
		WatchButton.requestCount = 0
	end

	function WatchButton:FreeUnused()
		for i = #usedPool, 1, -1 do
			local button = usedPool[i]
			if (button) and (button.wasRequested == false) then
				button:Wipe()
				tremove(usedPool, i)
				tinsert(freePool, button)
			end
		end
	end

	--

	function WatchButton:GetKeyedRaw(type, uniq)
		for i = 1, #usedPool do
			local b = usedPool[i]
			if ((b.type == type) and (b.uniq == uniq)) then
				return b
			end
		end
		return nil
	end

	function WatchButton:GetKeyed(type, uniq)
		local button

		-- type/uniq match found, mark unfresh
		for i = 1, #usedPool do
			local b = usedPool[i]
			if ((b.type == type) and (b.uniq == uniq)) then
				-- D("=REUSING", type, uniq)
				button = b
				button.fresh = false
				break
			end
		end

		-- type/uniq match NOT found, mark fresh
		if not button then
			if (#freePool > 0) then
				-- D("=USING-FREE", type, uniq)
				button = tremove(freePool)
			else
				-- D("=CREATING", type, uniq)
				button = WatchButton:Create()
			end
			tinsert(usedPool, button)

			button.fresh = true
			button.type = type
			button.uniq = uniq

			if (type == "header") then
				button.titleButton:EnableMouse(false)
			end
		end

		WatchButton.requestCount = WatchButton.requestCount + 1
		requestOrder[WatchButton.requestCount] = button
		button.wasRequested = true

		button:Ready()
		return button
	end

	--

	function WatchButton:Wipe()
		self:Hide()

		if (self.itemButton) then
			if InCombatLockdown() then
				QuestKing:StartCombatTimer()
			else
				self:RemoveItemButton()
			end
		end

		self:EnableMouse(false)
		self.titleButton:EnableMouse(true)

		self:SetBackdropColor(0, 0, 0, 0)
		self:SetScript("OnUpdate", nil)

		self.icon.animGroup:Stop()
		self.icon:Hide()
		self.buttonPulser.animGroup:Stop()
		self.buttonPulser:Hide()

		if (self.challengeBar) then
			self.challengeBar:Hide()
			self.challengeBar = nil
			self.challengeBarIcon = nil
			self.challengeBarText = nil
		end

		local lines = self.lines
		for i = 1, #lines do
			lines[i]:Wipe()
		end

		self.noTitle = false
		self.titleButton:Show()

		self.mouseHandler = nil

		-- various
		self.questID = nil
		self.questIndex = nil
		-- quest
		self._questCompleted = nil
		self._lastNumObj = nil
		-- scenario
		self._lastStepIndex = nil
		-- bonusobjective
		self._previousHeader = nil
		-- challengetimer
		self._challengeMedalTimes = nil
		self._challengeTime = nil
		self._challengeCurrentMedalTime = nil
		self._challengeRecheck = nil
		-- popup
		self._popupType = nil
		self._itemID = nil
		-- collapser
		self._headerName = nil

		self.type = "none"
		self.uniq = 0
	end

	function WatchButton:HideTitle()
		self.titleButton:Hide()
		self.noTitle = true
	end

	function WatchButton:Ready()
		self.currentLine = 0
	end

	--

	local function hideOnOnFinished (self)
		self:GetParent():Hide()
	end

	local function buttonPulse (self, r, g, b)
		local pulser = self.buttonPulser

		pulser:SetVertexColor(r, g, b)
		pulser:Show()

		pulser.animGroup:Stop()
		pulser.animGroup:Play()
	end

	local function buttonSetIcon (self, iconType)
		local icon = self.icon

		if (iconType == "QuestIcon-Exclamation") then
			-- icon:SetTexture([[Interface\QuestFrame\AutoQuest-Parts]])
			icon:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000)
		elseif (iconType == "QuestIcon-QuestionMark") then
			-- icon:SetTexture([[Interface\QuestFrame\AutoQuest-Parts]])
			icon:SetTexCoord(0.17578125, 0.21289063, 0.01562500, 0.53125000)
		end

		icon:Show()
		icon.animGroup:Play()
	end

	local function titleSetTextIcon (self, ...)
		self:SetText(...)
		self:Hide()
		self:Show()
		self:SetAlpha(0)
		self:SetAlpha(1)
	end

	local function titleSetFormattedTextIcon (self, ...)
		self:SetFormattedText(...)
		self:Hide()
		self:Show()
		self:SetAlpha(0)
		self:SetAlpha(1)
	end

	function WatchButton:Create()
		buttonCounter = buttonCounter + 1
		local name = "QuestKing_PoolButton" .. buttonCounter
		-- D("CREATE", buttonCounter)

		-- button

		local button = CreateFrame("Button", name, QuestKing.Tracker)
		button.name = name
		button:SetWidth(opt_buttonWidth)
		button:SetHeight(opt_lineHeight)
		button:SetPoint("TOPLEFT", 0, 0)

		button:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		})
		button:SetBackdropColor(0, 0, 0, 0)

		local buttonHighlight = button:CreateTexture()
		buttonHighlight:SetAllPoints(button)
		buttonHighlight:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
		buttonHighlight:SetAlpha(0.5)
		button.buttonHighlightTexture = buttonHighlight

		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:EnableMouse(false)
		button:SetHighlightTexture(buttonHighlight, "ADD")
		button:SetScript("OnClick", WatchButton.ButtonOnClick)
		button:SetScript("OnEnter", WatchButton.ButtonOnEnter)
		button:SetScript("OnLeave", WatchButton.ButtonOnLeave)

		-- pulser

		local buttonPulser = button:CreateTexture()
		buttonPulser:SetAllPoints(button)
		buttonPulser:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
		buttonPulser:SetBlendMode("ADD")
		buttonPulser:SetAlpha(0)

		local animGroup = buttonPulser:CreateAnimationGroup()
		local a1 = animGroup:CreateAnimation("Alpha")
			a1:SetStartDelay(0); a1:SetDuration(0.50); a1:SetFromAlpha(1); a1:SetOrder(1); a1:SetSmoothing("OUT");
		local a2 = animGroup:CreateAnimation("Alpha")
			a2:SetStartDelay(0.2); a2:SetDuration(0.50); a2:SetFromAlpha(-1); a2:SetOrder(2); a2:SetSmoothing("IN");
		animGroup:SetLooping("NONE")
		animGroup:SetScript("OnFinished", hideOnOnFinished)

		button.buttonPulser = buttonPulser
		button.buttonPulser.animGroup = animGroup
		button.Pulse = buttonPulse

		-- icons

		local icon = button:CreateTexture(nil, nil, "QuestIcon-Exclamation")
		icon:ClearAllPoints()
		icon:SetPoint("RIGHT", button, "LEFT")
		icon:SetHeight(opt_lineHeight * 2 - 2)
		icon:SetWidth(opt_lineHeight * 1.4)
		icon:Hide()

		local animGroup = icon:CreateAnimationGroup()
		local a1 = animGroup:CreateAnimation("Alpha")
			a1:SetStartDelay(0.25); a1:SetDuration(0.33); a1:SetFromAlpha(-1); a1:SetOrder(1); a1:SetSmoothing("IN");
		animGroup:SetLooping("BOUNCE")

		button.icon = icon
		button.icon.animGroup = animGroup
		button.SetIcon = buttonSetIcon

		-- title button

		local titleButton = CreateFrame("Button", nil, button)
		titleButton:SetPoint("TOPLEFT", 0, 0)
		titleButton:SetWidth(opt_buttonWidth)
		titleButton:SetHeight(opt_lineHeight)
		titleButton.parent = button

		titleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		titleButton:SetScript("OnClick", WatchButton.TitleButtonOnClick)
		titleButton:SetScript("OnEnter", WatchButton.TitleButtonOnEnter)
		titleButton:SetScript("OnLeave", WatchButton.TitleButtonOnLeave)
		button.titleButton = titleButton

		-- title button hover

		local tex = titleButton:CreateTexture()
		tex:SetAllPoints(titleButton)
		tex:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
		tex:SetAlpha(0.5)
		titleButton.highlightTexture = tex

		titleButton:EnableMouse(true)
		titleButton:SetHighlightTexture(tex, "ADD")

		-- title text

		local title = titleButton:CreateFontString(nil, opt_fontLayer)
		title:SetFont(opt_font, opt_fontSize, opt_fontStyle)
		title:SetJustifyH("LEFT")
		title:SetTextColor(1, 1, 0)
		title:SetShadowOffset(1, -1)
		title:SetShadowColor(0, 0, 0, 1)
		title:SetPoint("TOPLEFT", 0, 0)
		title:SetWidth(opt_buttonWidth)
		title:SetHeight(opt_lineHeight)
		title:SetWordWrap(false)
		title:SetText("<Error>")

		title.SetTextIcon = titleSetTextIcon
		title.SetFormattedTextIcon = titleSetFormattedTextIcon

		button.title = title
		titleButton.text = title

		-- variables

		button.lines = {}
		button.currentLine = 0

		button.challengeBarShown = false

		setmetatable(button, WatchButton)

		button:Wipe()

		return button
	end

	---- ########
	---- Lines
	---- ########

	local function lineWipe (self)
		self:Hide()
		self.right:Hide()

		self.flash.animGroup:Stop()
		self.flash:Hide()
		self.glow.animGroup:Stop()
		self.glow:Hide()

		if (self.timerBar) then
			self.timerBar:Free()
		end

		if (self.progressBar) then
			self.progressBar:Free()
		end

		self._lastQuant = nil
	end

	local function lineFlash (self)
		if ((self.timerBar) or (self.progressBar)) then
			return
		end

		self.flash:Show()
		self.flash.animGroup:Play()
	end

	local function lineGlow (self, r, g, b)
		if ((self.timerBar) or (self.progressBar)) then
			return
		end

		if r then
			self.glow:SetVertexColor(r, g, b)
		end

		self.glow:Show()
		self.glow.animGroup:Play()
	end

	function WatchButton:CreateLines(currentLine)
		local line = self:CreateFontString(nil, opt_fontLayer)
		line:SetFont(opt_font, opt_fontSize, opt_fontStyle)
		line:SetJustifyH("LEFT")
		line:SetTextColor(1, 1, 0)
		line:SetShadowOffset(1, -1)
		line:SetShadowColor(0, 0, 0, 1)
		line:SetPoint("TOPLEFT", 0, 0)
		line:SetJustifyV("TOP")
		line:SetWordWrap(false)
		tinsert(self.lines, line)

		local right = self:CreateFontString(nil, opt_fontLayer)
		right:SetFont(opt_font, opt_fontSize, opt_fontStyle)
		right:SetJustifyH("LEFT")
		right:SetTextColor(1, 1, 0)
		right:SetShadowOffset(1, -1)
		right:SetShadowColor(0, 0, 0, 1)
		right:SetPoint("TOPLEFT", 0, 0)
		right:SetJustifyV("TOP")
		right:SetWordWrap(false)
		line.right = right

		local flash = self:CreateTexture()
		flash:SetPoint("TOPLEFT", line)
		flash:SetPoint("BOTTOMLEFT", line)
		flash:SetWidth(opt_buttonWidth)
		flash:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
		flash:SetBlendMode("ADD")
		flash:SetVertexColor(opt_colors.ObjectiveProgressFlash[1], opt_colors.ObjectiveProgressFlash[2], opt_colors.ObjectiveProgressFlash[3], 0)
		flash:Hide()

		local animGroup = flash:CreateAnimationGroup()
		local a1 = animGroup:CreateAnimation("Alpha")
			a1:SetStartDelay(0); a1:SetDuration(0.15); a1:SetFromAlpha(1); a1:SetOrder(1); a1:SetSmoothing("OUT")
		local a2 = animGroup:CreateAnimation("Alpha")
			a2:SetStartDelay(0.25); a2:SetDuration(0.50); a2:SetFromAlpha(-1); a2:SetOrder(2); a2:SetSmoothing("IN")
		animGroup:SetScript("OnFinished", hideOnOnFinished)

		line.flash = flash
		line.flash.animGroup = animGroup
		line.Flash = lineFlash

		local glow = self:CreateTexture()
		glow:SetPoint("TOPLEFT", line)
		glow:SetPoint("BOTTOMLEFT", line, 0, -2.5)
		glow:SetWidth(opt_buttonWidth)
		glow:SetTexture([[Interface\AddOns\QuestKing\textures\Objective-Lineglow-White]])
		glow:SetBlendMode("ADD")
		glow:SetVertexColor(0.8, 0.6, 0.2, 0)
		glow:Hide()

		local animGroup = glow:CreateAnimationGroup()
		local a0 = animGroup:CreateAnimation("Scale")
			a0:SetStartDelay(0); a0:SetScale(0.2, 1); a0:SetDuration(0); a0:SetOrder(1); a0:SetOrigin("LEFT", 0, 0)
		local a1 = animGroup:CreateAnimation("Scale")
			a1:SetStartDelay(0.067); a1:SetScale(5, 1); a1:SetDuration(0.633); a1:SetOrder(1); a1:SetOrigin("LEFT", 0, 0)
		local a2 = animGroup:CreateAnimation("Alpha")
			a2:SetStartDelay(0.067); a2:SetFromAlpha(1.0); a2:SetDuration(0.1); a2:SetOrder(1);
		local a3 = animGroup:CreateAnimation("Alpha")
			a3:SetStartDelay(0.867); a3:SetFromAlpha(-1.0); a3:SetDuration(0.267); a3:SetOrder(1);
		animGroup:SetScript("OnFinished", hideOnOnFinished)

		line.glow = glow
		line.glow.animGroup = animGroup
		line.Glow = lineGlow

		line.Wipe = lineWipe

		return line, right
	end

	function WatchButton:AddLine (textleft, textright, r, g, b, a)
		local currentLine = self.currentLine + 1
		self.currentLine = currentLine

		local line, right
		if self.lines[currentLine] then
			line = self.lines[currentLine]
			right = line.right
		else
			line, right = self:CreateLines(currentLine)
		end

		line.isTimer = false

		line:SetText(textleft)
		right:SetText(textright)

		if r ~= nil then
			line:SetTextColor(r, g, b, a or 1)
			right:SetTextColor(r, g, b, a or 1)
		end

		return line
	end

	function WatchButton:AddLineIcon (...)
		local line = self:AddLine(...)
		line:Hide()
		line:Show()
		line:SetAlpha(0)
		line:SetAlpha(1)
	end

	---- ########
	---- Render
	---- ########

	function WatchButton:Render()
		local noTitle = self.noTitle

		local height = 0
		local extraHeight = 0
		local lastLine = nil

		-- local title = self.title
		-- title:SetWidth(0)
		-- local titleWidth = title:GetStringWidth()
		-- if (titleWidth > opt_buttonWidth) then
		-- 	title:SetWidth(opt_buttonWidth)
		-- else
		-- 	title:SetWidth(title:GetStringWidth())
		-- end

		for i = 1, #self.lines do
			local line = self.lines[i]
			local right = line.right

			if (i > self.currentLine) then
				line:Wipe()
			else
				line:Show()
				right:Show()

				if lastLine == nil then
					if (noTitle) then
						line:SetPoint("TOPLEFT", self.title, "TOPLEFT", 0, 0)
					else
						line:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
					end
				else
					line:SetPoint("TOPLEFT", lastLine, "BOTTOMLEFT", 0, 0)
				end
				right:SetPoint("TOPLEFT", line, "TOPRIGHT", -1, 0)

				line:SetWidth(0)
				line:SetHeight(0)

				local lenLeft = line:GetStringWidth()
				local lenRight = right:GetStringWidth()

				if (lenLeft + lenRight) > opt_buttonWidth then
					--left:SetHeight(left:GetStringHeight())
					line:SetHeight(opt_lineHeight)
					line:SetWidth(opt_buttonWidth - lenRight)
				else
					line:SetHeight(opt_lineHeight)
				end

				if (line.timerBar) or (line.progressBar) then
					extraHeight = extraHeight + 7
				end

				lastLine = line
				height = (opt_lineHeight * i)
			end
		end

		height = height + extraHeight

		if noTitle then
			height = height - opt_lineHeight
		end

		if (self.challengeBar) then
			height = height + self.challengeBar.bonusHeight
		end

		self:SetHeight(opt_lineHeight + height)
		self:Show()

		-- anchor item buttons
		if (self.itemButton) then
			if InCombatLockdown() then
				QuestKing:StartCombatTimer()
			else
				if opt_itemAnchorSide == "right" then
					self.itemButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
						self:GetRight() / opt_itemButtonScale + 4,
						self:GetTop()   / opt_itemButtonScale - 1)
				else
					self.itemButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT",
						self:GetLeft() / opt_itemButtonScale - 4,
						self:GetTop()  / opt_itemButtonScale - 1)
				end
			end
		end
		-- end anchor item buttons

	end
end

---- ###########################################
---- button-related handlers
---- ###########################################

function WatchButton:TitleButtonOnEnter (motion)
	local button = self.parent

	if ((button.mouseHandler) and (button.mouseHandler.TitleButtonOnEnter)) then
		button.mouseHandler.TitleButtonOnEnter(self, motion)
		return
	end
end

function WatchButton:TitleButtonOnLeave (motion)
	if (opt.tooltipScale) then
		local oldScale = GameTooltip.__QuestKingPreviousScale or 1
		GameTooltip.__QuestKingPreviousScale = nil
		GameTooltip:SetScale(oldScale)
	end
	GameTooltip:Hide()
end

function WatchButton:TitleButtonOnClick (mouse, down)
	local button = self.parent

	if ((button.mouseHandler) and (button.mouseHandler.TitleButtonOnClick)) then
		button.mouseHandler.TitleButtonOnClick(self, mouse, down)
		return
	end

	if (button.type == "collapser") then
		local headerName = button._headerName

		if QuestKingDBPerChar.collapsedHeaders[headerName] then
			QuestKingDBPerChar.collapsedHeaders[headerName] = nil
			wipe(QuestKing.newlyAddedQuests)
		else
			QuestKingDBPerChar.collapsedHeaders[headerName] = true
		end
		QuestKing:UpdateTracker()
	end
end

function WatchButton:ButtonOnEnter (motion)
	local button = self

	if ((button.mouseHandler) and (button.mouseHandler.TitleButtonOnEnter)) then
		button.mouseHandler.TitleButtonOnEnter(self, motion)
		return
	end
end

function WatchButton:ButtonOnLeave (motion)
	if (opt.tooltipScale) then
		local oldScale = GameTooltip.__QuestKingPreviousScale or 1
		GameTooltip.__QuestKingPreviousScale = nil
		GameTooltip:SetScale(oldScale)
	end
	GameTooltip:Hide()
end

function WatchButton:ButtonOnClick (mouse, down)
	local button = self

	if ((button.mouseHandler) and (button.mouseHandler.ButtonOnClick)) then
		button.mouseHandler.ButtonOnClick(self, mouse, down)
		return
	end
end
