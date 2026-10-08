local AddonName, NPI = ...
local L = NPI.L
local Data = NPI.Data
local Panel = NPI.Panel
local Options = NPI.Settings
local ImportantOptions = NPI.ImportantOptions

local NPT = _G.MDT_NPT
local PREFIX = "|cFF00FF00MDT-NextPullInfo|r: "

local MODE_IMPORTANT, MODE_ALL = "important", "all"

local DEFAULTS = {
  enabled = true,
  -- "important": only enemies with abilities marked important, and only those
  -- abilities. "all": every enemy and ability MDT knows. Bosses always show all.
  mode = MODE_IMPORTANT,
  side = "RIGHT",
  maxRows = 4,
  -- Open the trash overview window in a Mythic dungeon before the key starts.
  overview = true,
}

local db
local hooked = false
local lastRenderKey

-- =====================================================================
-- Refresh: mirror NPT's beacon. NPT owns tracking, we only read its state.
-- =====================================================================

local function hidePanel()
  lastRenderKey = nil
  Panel:Hide()
end

function NPI:Refresh(force)
  local beacon = NPT.Beacon and NPT.Beacon.frame
  local state = NPT.state
  if not (db and db.enabled and beacon and beacon:IsShown()) then return hidePanel() end
  if not (state and state.active and state.currentNextPull) then return hidePanel() end

  local dungeonIndex, pullIndex = state.dungeonIndex, state.currentNextPull
  local enemies = NPT.MDT.dungeonEnemies[dungeonIndex]
  if not enemies then return hidePanel() end

  local pullState = state.pullStates[pullIndex]
  local inCombat = pullState and pullState.state == NPT.PullState.ACTIVE or false

  -- NPT refreshes its beacon on every forces update; only rebuild when the
  -- pull or the beacon's width (NPT's map-only mode) actually changes.
  local renderKey = table.concat({
    dungeonIndex, pullIndex, tostring(inCombat), tostring(state.presetUID), math.floor(beacon:GetWidth()),
  }, ":")
  if renderKey == lastRenderKey and not force then return end

  local preset = NPT.MDT:GetCurrentPreset(dungeonIndex)
  local pull = preset and preset.value and preset.value.pulls and preset.value.pulls[pullIndex]
  local mobs = Data.CollectPullMobs(pull, enemies, db.mode == MODE_IMPORTANT, dungeonIndex)
  if #mobs == 0 then return hidePanel() end

  Panel:Render(beacon, pullIndex, inCombat, mobs, math.floor(db.maxRows + 0.5))
  lastRenderKey = renderKey
end

local function applySettings()
  Panel:Configure(db.side)
  NPI:Refresh(true)
  NPI.Overview:Refresh()
end

-- =====================================================================
-- Slash command
-- =====================================================================

local function printHelp()
  print(PREFIX..L["Commands:"])
  print("  /npi - "..L["open the options"])
  print("  /npi overview - "..L["show or hide the trash overview for this dungeon"])
  print("  /npi toggle - "..L["enable or disable the panel"])
  print("  /npi mode important|all - "..L["important abilities only, or every ability"])
  print("  /npi side right|left|top|bottom - "..L["which side of the beacon to attach to"])
  print("  /npi rows 1-"..Panel.MAX_ROWS.." - "..L["maximum enemies shown"])
end

local function onSlash(input)
  local command, arg = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if command == "" then
    return Options:Open()
  elseif command == "overview" then
    return NPI.Overview:Toggle()
  elseif command == "toggle" then
    db.enabled = not db.enabled
    print(PREFIX..(db.enabled and L["Panel enabled."] or L["Panel disabled."]))
  elseif command == "mode" and (arg == MODE_IMPORTANT or arg == MODE_ALL or arg == "") then
    if arg == "" then
      arg = db.mode == MODE_IMPORTANT and MODE_ALL or MODE_IMPORTANT
    end
    db.mode = arg
    print(PREFIX..L["Mode: %s."]:format(L[arg]))
  elseif command == "side" and tContains(Panel.SIDES, arg:upper()) then
    db.side = arg:upper()
    print(PREFIX..L["Panel side: %s."]:format(arg))
  elseif command == "rows" and tonumber(arg) then
    db.maxRows = math.max(1, math.min(Panel.MAX_ROWS, math.floor(tonumber(arg))))
    print(PREFIX..L["Showing up to %d enemies."]:format(db.maxRows))
  else
    return printHelp()
  end
  applySettings()
end

-- =====================================================================
-- Startup
-- =====================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, addon)
  if event == "PLAYER_LOGIN" then
    -- Same timing as NPT's options page: the Settings UI is ready by login.
    self:UnregisterEvent("PLAYER_LOGIN")
    if hooked then
      Options:Register(function() return db end, DEFAULTS, Panel.MAX_ROWS, applySettings, function(category)
        ImportantOptions:Register(category, applySettings)
      end)
    end
    return
  end
  if addon ~= AddonName then return end
  self:UnregisterEvent("ADDON_LOADED")

  MythicDungeonToolsNextPullInfoDB = MythicDungeonToolsNextPullInfoDB or {}
  db = MythicDungeonToolsNextPullInfoDB
  for key, value in pairs(DEFAULTS) do
    if db[key] == nil then db[key] = value end
  end
  -- Per-dungeon important-ability lists. db.important holds picks saved before
  -- lists existed; each dungeon's "Default" list starts as a copy of them.
  db.lists = db.lists or {}
  Data.SetListStore(db.lists, db.important)

  if not (NPT and NPT.Beacon and NPT.Beacon.Update and NPT.MDT) then
    print(PREFIX.."MythicDungeonTools_NextPullTracker is missing or incompatible; the panel is disabled.")
    return
  end

  Panel:Configure(db.side)
  -- Every NPT state change ends in Beacon:Update, so follow it.
  hooksecurefunc(NPT.Beacon, "Update", function() NPI:Refresh() end)
  hooked = true
  NPI.Overview:Init(function() return db end)

  SLASH_MDTNEXTPULLINFO1 = "/npi"
  SlashCmdList.MDTNEXTPULLINFO = onSlash
end)
