local _, NPI = ...
local L = NPI.L

local Settings_API = _G.Settings

local M = {}
NPI.Settings = M

local categoryRef

---Registers a setting that reads and writes `db[key]` directly, calling
---`onChange` after every write so the panel updates immediately.
local function registerProxy(category, getDB, onChange, variable, key, name, default)
  return Settings_API.RegisterProxySetting(
    category, variable, type(default), name, default,
    function()
      local db = getDB()
      local value = db and db[key]
      if value == nil then return default end
      return value
    end,
    function(value)
      local db = getDB()
      if not db then return end
      db[key] = value
      onChange()
    end
  )
end

local function dropdownOptions(entries)
  return function()
    local container = Settings_API.CreateControlTextContainer()
    for _, entry in ipairs(entries) do container:Add(entry[1], entry[2]) end
    return container:GetData()
  end
end

-- =====================================================================
-- Credits
-- =====================================================================

local TACTYKS = "|cff7fb2ffTactyks|r"

-- Links can't be opened from the game, so each button shows its URL ready to copy.
local SOCIALS = {
  { "|cffff4e45YouTube|r", "https://www.youtube.com/@Tactyks" },
  { "|cffa970ffTwitch|r", "https://twitch.tv/tactyks" },
  { "|cfff96854Patreon|r", "https://patreon.com/tactyks" },
}

StaticPopupDialogs["MDTNPI_COPY_LINK"] = {
  text = L["Copy this link (Ctrl+C):"],
  button1 = CLOSE,
  hasEditBox = true,
  editBoxWidth = 280,
  OnShow = function(self, data)
    local box = self.EditBox or self.editBox or (self.GetEditBox and self:GetEditBox())
    box.link = data or self.data or ""
    box:SetText(box.link)
    box:HighlightText()
    box:SetFocus()
  end,
  -- Keep the link intact if something gets typed over it.
  EditBoxOnTextChanged = function(box)
    if box.link and box:GetText() ~= box.link then
      box:SetText(box.link)
      box:HighlightText()
    end
  end,
  EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function addCredits(layout)
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Ability data by %s"]:format(TACTYKS),
    L["Ability tags, notes and important picks for Midnight Seasons 1 and 2 come from Tactyks' M+ Ability Tracking Sheets, used with his permission."]))
  if not CreateSettingsButtonInitializer then return end
  for _, social in ipairs(SOCIALS) do
    local label, url = social[1], social[2]
    layout:AddInitializer(CreateSettingsButtonInitializer(label, L["Copy link"],
      function() StaticPopup_Show("MDTNPI_COPY_LINK", nil, nil, url) end, url, true))
  end
end

---@param getDB fun(): table|nil the saved settings table
---@param defaults table default values, keyed like the saved settings
---@param maxRows number upper bound of the enemy count slider
---@param onChange fun() called after any setting changes
---@param addSubcategories fun(category)|nil adds sub-pages before the category is registered
function M:Register(getDB, defaults, maxRows, onChange, addSubcategories)
  if categoryRef or not (Settings_API and Settings_API.RegisterVerticalLayoutCategory) then return end

  local category, layout = Settings_API.RegisterVerticalLayoutCategory(L["MDT Next Pull Info"])
  categoryRef = category
  local function proxy(variable, key, name)
    return registerProxy(category, getDB, onChange, variable, key, name, defaults[key])
  end

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["General"]))

  Settings_API.CreateCheckbox(category, proxy("MDTNPI_ENABLED", "enabled", L["Show panel"]),
    L["Show the notable enemies panel next to the Next Pull Tracker beacon."])

  Settings_API.CreateDropdown(category, proxy("MDTNPI_MODE", "mode", L["Mode"]),
    dropdownOptions({
      { "important", L["Important abilities"] },
      { "all", L["All abilities"] },
    }),
    L["Important: only enemies with abilities marked important (see the Important abilities page), showing just those abilities. All: every enemy and ability. Bosses always show all their abilities."])

  Settings_API.CreateCheckbox(category, proxy("MDTNPI_OVERVIEW", "overview", L["Show trash overview before a key"]),
    L["In a Mythic dungeon, before the key starts, open a window listing the trash with important abilities. It closes when the key starts. /npi overview opens it any time."])

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Layout"]))

  Settings_API.CreateDropdown(category, proxy("MDTNPI_SIDE", "side", L["Side"]),
    dropdownOptions({
      { "RIGHT", L["Right of the beacon"] },
      { "LEFT", L["Left of the beacon"] },
      { "TOP", L["Above the beacon"] },
      { "BOTTOM", L["Below the beacon"] },
    }),
    L["Which side of the beacon the panel attaches to."])

  local rowOptions = Settings_API.CreateSliderOptions(1, maxRows, 1)
  rowOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
    function(value) return tostring(math.floor(value + 0.5)) end)
  Settings_API.CreateSlider(category, proxy("MDTNPI_MAX_ROWS", "maxRows", L["Maximum enemies"]), rowOptions,
    L["How many enemies the panel lists before summarising the rest as \"+N more\"."])

  addCredits(layout)

  if addSubcategories then addSubcategories(category) end
  Settings_API.RegisterAddOnCategory(category)
end

function M:Open()
  if not categoryRef then return end
  Settings_API.OpenToCategory(categoryRef:GetID())
end
