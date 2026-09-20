--[[
QuestKing_ActionButtonLayout_v3.lua

Purpose:
  Keep QuestKing quest item/action buttons from covering tracker progress bars.

Install:
  Replace this file:
    QuestKing\ui\actionbuttonlayout.lua

TOC:
  Keep this file loaded after ui\watchbutton.lua. It may load before
  ui\itembutton.lua and ui\progressbar.lua because the Render hook is applied
  to the WatchButton prototype created by watchbutton.lua.

Compatibility:
  Lua 5.1. Retail/Midnight, Classic Era, Classic Anniversary, Cataclysm/MoP
  Classic. No external libraries required.
--]]

local addonName, QuestKing = ...

local _G = _G
local tonumber = tonumber
local type = type
local max = math.max
local abs = math.abs
local print = print

local BAR_LEFT_INSET = 16
local BAR_RIGHT_INSET = 20
local BAR_TOP_OFFSET = -1
local BAR_MIN_WIDTH = 48
local ITEM_SIDE_PADDING = 10
local DEBUG_PREFIX = "|cff33ff99QuestKing action layout:|r "

local Layout = {}
Layout.debug = false
Layout.lastAdjusted = 0
Layout.installed = false

local function GetOptions()
  return (QuestKing and QuestKing.options) or {}
end

local function ToNumber(value, fallback)
  local numberValue = tonumber(value)
  if type(numberValue) == "number" then
    return numberValue
  end
  return fallback
end

local function GetButtonWidth(baseButton)
  if baseButton and baseButton.GetWidth then
    local width = baseButton:GetWidth()
    if type(width) == "number" and width > 0 then
      return width
    end
  end

  local width = ToNumber(GetOptions().buttonWidth, 230)
  if width < 120 then
    width = 120
  end
  return width
end

local function GetLineHeight()
  local height = ToNumber(GetOptions().lineHeight, 16)
  if height < 10 then
    height = 10
  end
  return height
end

local function GetItemButtonScale(itemButton)
  local scale = 1

  if itemButton and itemButton.GetScale then
    scale = ToNumber(itemButton:GetScale(), scale)
  end

  if not scale or scale <= 0 then
    scale = ToNumber(QuestKing and QuestKing.itemButtonScale, nil)
      or ToNumber(GetOptions().itemButtonScale, 1)
  end

  if not scale or scale <= 0 then
    scale = 1
  end

  return scale
end

local function IsVisible(frame)
  return frame and frame.IsShown and frame:IsShown()
end

local function GetReservedItemWidth(baseButton)
  local itemButton = baseButton and baseButton.itemButton
  if not IsVisible(itemButton) then
    return 0
  end

  local scale = GetItemButtonScale(itemButton)
  local width = 0

  if itemButton.GetWidth then
    width = ToNumber(itemButton:GetWidth(), 0)
  end

  local formulaWidth = (GetLineHeight() * 2 * scale) + ITEM_SIDE_PADDING
  local visualWidth = (width * scale) + ITEM_SIDE_PADDING

  return max(formulaWidth, visualWidth)
end

local function CalculateBarWidth(baseButton)
  local width = GetButtonWidth(baseButton) - GetReservedItemWidth(baseButton) - BAR_LEFT_INSET - BAR_RIGHT_INSET

  if width < BAR_MIN_WIDTH then
    width = BAR_MIN_WIDTH
  end

  return width
end

local function UpdateBarAnimations(bar)
  if not bar then
    return
  end

  if bar.UpdateBurstWidths then
    bar:UpdateBurstWidths()
  end
end
local function SetBarLayout(baseButton, line, bar)
  if not baseButton or not line or not bar then
    return false
  end

  if not bar.SetWidth or not bar.ClearAllPoints or not bar.SetPoint then
    return false
  end

  local newWidth = CalculateBarWidth(baseButton)
  local oldWidth = bar.GetWidth and bar:GetWidth() or 0

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", line, "TOPLEFT", BAR_LEFT_INSET, BAR_TOP_OFFSET)
  bar:SetWidth(newWidth)

  if bar.SetHeight and (not bar.GetHeight or (bar:GetHeight() or 0) <= 0) then
    bar:SetHeight(15)
  end

  UpdateBarAnimations(bar)

  return abs((oldWidth or 0) - newWidth) >= 1
end

local function ApplyLayoutToWatchButton(baseButton)
  if not baseButton or not baseButton.lines then
    return 0
  end

  local adjusted = 0

  for i = 1, #baseButton.lines do
    local line = baseButton.lines[i]
    if line and IsVisible(line) then
      if line.progressBar and SetBarLayout(baseButton, line, line.progressBar) then
        adjusted = adjusted + 1
      end

    end
  end

  return adjusted
end

local function ApplyLayoutToUsedButtons()
  local watchButton = QuestKing and QuestKing.WatchButton
  local usedPool = watchButton and watchButton.usedPool
  local adjusted = 0

  if type(usedPool) ~= "table" then
    return 0
  end

  for i = 1, #usedPool do
    local baseButton = usedPool[i]
    if IsVisible(baseButton) then
      adjusted = adjusted + ApplyLayoutToWatchButton(baseButton)
    end
  end

  Layout.lastAdjusted = adjusted
  return adjusted
end

local function DebugPrint(message)
  if Layout.debug then
    print(DEBUG_PREFIX .. message)
  end
end

local function HookWatchButtonRender()
  local watchButton = QuestKing and QuestKing.WatchButton
  if not watchButton or type(watchButton.Render) ~= "function" then
    return false
  end

  if watchButton._qkActionButtonLayoutV3 then
    return true
  end

  local originalRender = watchButton.Render

  watchButton.Render = function(self, ...)
    originalRender(self, ...)

    local adjusted = ApplyLayoutToWatchButton(self)
    Layout.lastAdjusted = adjusted
    if adjusted > 0 then
      DebugPrint("adjusted " .. adjusted .. " bar(s) after Render")
    end
  end

  watchButton._qkActionButtonLayoutV3 = true
  return true
end

local function HookProgressBarCreation()
  local watchButton = QuestKing and QuestKing.WatchButton
  if not watchButton or type(watchButton.AddProgressBar) ~= "function" then
    return false
  end

  if watchButton._qkActionButtonLayoutProgressHookV3 then
    return true
  end

  local originalAddProgressBar = watchButton.AddProgressBar

  watchButton.AddProgressBar = function(self, ...)
    local progressBar = originalAddProgressBar(self, ...)
    if progressBar and progressBar.baseLine then
      SetBarLayout(self, progressBar.baseLine, progressBar)
    end
    return progressBar
  end

  watchButton._qkActionButtonLayoutProgressHookV3 = true
  return true
end

local function InstallHooks()
  if not QuestKing or not QuestKing.WatchButton then
    return false
  end

  local renderHooked = HookWatchButtonRender()
  HookProgressBarCreation()

  Layout.installed = renderHooked and true or false
  return Layout.installed
end

local function RequestLayoutPass()
  if not InstallHooks() then
    return
  end

  ApplyLayoutToUsedButtons()
end

_G.SLASH_QUESTKINGACTIONLAYOUT1 = "/qkactionlayout"
local slashCmdList = _G.SlashCmdList
if type(slashCmdList) == "table" then
slashCmdList.QUESTKINGACTIONLAYOUT = function(message)
  message = type(message) == "string" and message:lower() or ""

  if message == "debug" then
    Layout.debug = not Layout.debug
    print(DEBUG_PREFIX .. "debug " .. (Layout.debug and "on" or "off"))
    return
  end

  local installed = InstallHooks()
  local adjusted = ApplyLayoutToUsedButtons()

  print(DEBUG_PREFIX .. "installed=" .. tostring(installed) .. ", adjusted=" .. tostring(adjusted) .. ", last=" .. tostring(Layout.lastAdjusted))
end
end

InstallHooks()
