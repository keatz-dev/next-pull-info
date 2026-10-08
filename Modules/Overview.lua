local _, NPI = ...
local L = NPI.L
local Data = NPI.Data
local Panel = NPI.Panel

local ipairs, math_max = ipairs, math.max

-- Trash overview: a closable window listing a dungeon's trash that has
-- important abilities (from its active list). It opens by itself inside a
-- dungeon on Mythic difficulty while no key is running, i.e. while waiting to
-- start a key, and closes when the key starts. Closed by the player, it stays
-- closed until they leave the dungeon. /npi overview opens it any time.
local Overview = {}
NPI.Overview = Overview

local MYTHIC_DIFFICULTY = 23 -- Mythic dungeon; a running key is difficulty 8
local WIDTH, HEIGHT = 380, 460
local PADDING = 10
local CONTENT_W = WIDTH - PADDING - 28 -- the scroll area, left of its scroll bar
local PORTRAIT_SIZE = 32
local TEXT_X = PORTRAIT_SIZE + 8
local NAME_H = 20
local ENEMY_GAP = 8
local FALLBACK_DISPLAY_ID = 39490
local BACKDROP = { 0.058, 0.058, 0.058, 0.95 }
local ACCENT = { 0, 1, 0.5, 1 } -- NPT's header green

local getDB
local frame, scrollChild
local enemyPool, linePool = {}, {}
local dismissedIn -- dungeon the player closed the window in; cleared on leaving it

local function mdt() return _G.MDT_NPT.MDT end

-- The MDT dungeon the player is in, looked up the way NPT does it.
local function currentDungeon()
  local zoneId = C_Map.GetBestMapForUnit("player")
  if not zoneId then return nil end
  local m = mdt()
  if m.GetDungeonIdxForZone then return m:GetDungeonIdxForZone(zoneId, GetSubZoneText()) end
  return m.zoneIdToDungeonIdx and m.zoneIdToDungeonIdx[zoneId]
end

-- =====================================================================
-- Window
-- =====================================================================

local function createEdge(parent, p1, p2, horizontal)
  local edge = parent:CreateTexture(nil, "BORDER")
  edge:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  edge:SetPoint(p1)
  edge:SetPoint(p2)
  if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
end

local function savePosition(self)
  local point, _, relativePoint, x, y = self:GetPoint()
  getDB().overviewPosition = { point, relativePoint, x, y }
end

local function create()
  local f = CreateFrame("Frame", "MDTNextPullInfoOverview", UIParent)
  f:SetSize(WIDTH, HEIGHT)
  local position = getDB().overviewPosition
  if position then
    f:SetPoint(position[1], UIParent, position[2], position[3], position[4])
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  end
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self)
  end)
  tinsert(UISpecialFrames, f:GetName()) -- Escape closes it

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(BACKDROP[1], BACKDROP[2], BACKDROP[3], BACKDROP[4])
  createEdge(f, "TOPLEFT", "TOPRIGHT", true)
  createEdge(f, "BOTTOMLEFT", "BOTTOMRIGHT", true)
  createEdge(f, "TOPLEFT", "BOTTOMLEFT", false)
  createEdge(f, "TOPRIGHT", "BOTTOMRIGHT", false)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
  f.title:SetPoint("RIGHT", close, "LEFT", -4, 0)
  f.title:SetJustifyH("LEFT")
  f.title:SetWordWrap(false)
  f.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[4])

  f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.subtitle:SetTextColor(0.6, 0.6, 0.6, 1)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -52)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, PADDING)
  scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetSize(1, 1)
  scroll:SetScrollChild(scrollChild)
  scroll:SetScript("OnSizeChanged", function(_, width) scrollChild:SetWidth(width) end)

  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -8)
  f.empty:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
  f.empty:SetJustifyH("LEFT")
  f.empty:SetText(L["No trash abilities are marked important in this dungeon yet. Tick some on the Important abilities options page."])

  -- Closed by the player (X or Escape): stay closed while in this dungeon.
  f:SetScript("OnHide", function(self)
    if not self.closingForKey then dismissedIn = self.dungeonIndex end
    self.closingForKey = nil
  end)

  f:Hide()
  return f
end

local function createEnemy()
  local enemy = CreateFrame("Frame", nil, scrollChild)
  enemy:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
  enemy.portrait = enemy:CreateTexture(nil, "ARTWORK")
  enemy.portrait:SetAllPoints()
  enemy.portrait:SetMask("Interface\\Masks\\CircleMaskScalable")
  enemy.name = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  enemy.name:SetJustifyH("LEFT")
  enemy.name:SetWordWrap(false)
  return enemy
end

local function render(dungeonIndex)
  local list = Data.ImportantTrash(dungeonIndex, mdt().dungeonEnemies[dungeonIndex])
  local _, listName = Data.ListNames(dungeonIndex)
  frame.title:SetText(L["Trash to watch: %s"]:format(NPI.DungeonName(dungeonIndex)))
  frame.subtitle:SetText(L["List: %s"]:format(listName).."   "..L["%d enemies"]:format(#list))

  local y, lines = 0, 0
  for i, entry in ipairs(list) do
    local enemy = enemyPool[i] or createEnemy()
    enemyPool[i] = enemy
    local top = y
    enemy:ClearAllPoints()
    enemy:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -top)
    SetPortraitTextureFromCreatureDisplayID(enemy.portrait, entry.displayId or FALLBACK_DISPLAY_ID)
    enemy.name:ClearAllPoints()
    enemy.name:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", TEXT_X, -(top + 2))
    enemy.name:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    enemy.name:SetText(Panel.LocalizedName(entry.name))
    enemy:Show()
    enemy.name:Show()
    y = y + NAME_H

    for _, group in ipairs(entry.groups) do
      lines = lines + 1
      local line = linePool[lines] or Panel.CreateDetailLine(scrollChild)
      linePool[lines] = line
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", TEXT_X, -y)
      line:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
      line:Show()
      y = y + Panel.FillDetailLine(line, group, CONTENT_W - TEXT_X)
    end
    y = math_max(y, top + PORTRAIT_SIZE) + ENEMY_GAP
  end

  for i = #list + 1, #enemyPool do
    enemyPool[i]:Hide()
    enemyPool[i].name:Hide()
  end
  for i = lines + 1, #linePool do linePool[i]:Hide() end
  scrollChild:SetHeight(math_max(y, 1))
  frame.empty:SetShown(#list == 0)
  return #list
end

-- =====================================================================
-- Showing and hiding
-- =====================================================================

function Overview:Show(dungeonIndex)
  if not dungeonIndex then return end
  frame = frame or create()
  frame.dungeonIndex = dungeonIndex
  render(dungeonIndex)
  frame:Show()
end

---/npi overview: the dungeon the player is in, else MDT's selected dungeon.
function Overview:Toggle()
  if frame and frame:IsShown() then return frame:Hide() end
  local mdtDB = mdt():GetDB()
  self:Show(currentDungeon() or (mdtDB and mdtDB.currentDungeonIdx))
end

---Re-renders after the player changes settings or lists.
function Overview:Refresh()
  if frame and frame:IsShown() then render(frame.dungeonIndex) end
end

local function closeForKey()
  if frame and frame:IsShown() then
    frame.closingForKey = true
    frame:Hide()
  end
end

local function evaluate()
  local _, instanceType, difficultyID = GetInstanceInfo()
  local dungeonIndex = instanceType == "party" and currentDungeon() or nil
  if not dungeonIndex then
    dismissedIn = nil
    return
  end
  if C_ChallengeMode.IsChallengeModeActive() then return closeForKey() end
  if not getDB().overview or difficultyID ~= MYTHIC_DIFFICULTY or dismissedIn == dungeonIndex then return end
  if frame and frame:IsShown() and frame.dungeonIndex == dungeonIndex then return end
  -- Only open by itself when there is something to show.
  if #Data.ImportantTrash(dungeonIndex, mdt().dungeonEnemies[dungeonIndex]) > 0 then
    Overview:Show(dungeonIndex)
  end
end

---@param db fun(): table the addon's saved variables
function Overview:Init(db)
  getDB = db
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:RegisterEvent("CHALLENGE_MODE_START")
  events:SetScript("OnEvent", function(_, event)
    if event == "CHALLENGE_MODE_START" then return closeForKey() end
    -- Zone and difficulty can lag a moment behind the loading screen.
    C_Timer.After(1, evaluate)
  end)
end
