local _, NPI = ...
local L = NPI.L
local Data = NPI.Data
local Panel = NPI.Panel

local ipairs, pairs, type = ipairs, pairs, type
local table_sort = table.sort

-- "Important abilities" options page: pick a dungeon and one of its lists
-- (like MDT routes), tick the abilities important mode should show, and share
-- lists as text strings.
local M = {}
NPI.ImportantOptions = M

local HEADER_H = 28
local SPELL_ROW_H = 24
local ENEMY_GAP = 6
local FALLBACK_ICON = 134400
local PREFIX = "|cFF00FF00MDT-NextPullInfo|r: "

local onChange = function() end
local canvas, scrollChild, dropdown, listDropdown, deleteButton, summary
local selectedDungeon
local headerPool, spellPool = {}, {}

local function mdt() return _G.MDT_NPT.MDT end

local function englishDungeonName(index)
  local info = mdt().mapInfo[index]
  return (info and info.englishName) or ("#"..tostring(index))
end

-- Localized through MDT's public API. That call goes through MDT's UI addon,
-- which NPT loads when tracking starts; fall back to English until it has.
local function dungeonName(index)
  local api = _G.MythicDungeonToolsAPI
  if api and api.GetDungeonName then
    local ok, name = pcall(api.GetDungeonName, api, index)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  return englishDungeonName(index)
end
NPI.DungeonName = dungeonName

---Dungeons with enemy data, grouped by NPI.Seasons (newest first) and sorted
---by name within each group; anything in no season goes last under "Other".
---@return table sections { title, dungeons = { { index, name }, ... } }
local function dungeonSections()
  local available = {}
  for index, enemies in pairs(mdt().dungeonEnemies) do
    if type(enemies) == "table" and #Data.DungeonEnemies(enemies) > 0 then available[index] = true end
  end

  local sections = {}
  local function addSection(title, indexes)
    local dungeons = {}
    for _, index in ipairs(indexes) do
      if available[index] then
        dungeons[#dungeons + 1] = { index = index, name = dungeonName(index) }
        available[index] = nil
      end
    end
    table_sort(dungeons, function(a, b) return a.name < b.name end)
    if #dungeons > 0 then sections[#sections + 1] = { title = title, dungeons = dungeons } end
  end

  for _, season in ipairs(NPI.Seasons) do addSection(L[season.name], season.dungeons) end
  local others = {}
  for index in pairs(available) do others[#others + 1] = index end
  addSection(L["Other"], others)
  return sections
end

-- The dungeon being tracked, else MDT's selected dungeon, else the newest season's first.
local function initialDungeon(sections)
  local state = _G.MDT_NPT.state
  local mdtDB = mdt():GetDB()
  local current = (state and state.dungeonIndex) or (mdtDB and mdtDB.currentDungeonIdx)
  for _, section in ipairs(sections) do
    for _, dungeon in ipairs(section.dungeons) do
      if dungeon.index == current then return current end
    end
  end
  return sections[1] and sections[1].dungeons[1].index
end

-- =====================================================================
-- List rows
-- =====================================================================

local function createHeader()
  local header = CreateFrame("Frame", nil, scrollChild)
  header:SetHeight(HEADER_H)
  header.portrait = header:CreateTexture(nil, "ARTWORK")
  header.portrait:SetSize(24, 24)
  header.portrait:SetPoint("LEFT", header, "LEFT", 2, 0)
  header.portrait:SetMask("Interface\\Masks\\CircleMaskScalable")
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header.text:SetPoint("LEFT", header.portrait, "RIGHT", 6, 0)
  return header
end

local function updateSummary()
  if not (summary and selectedDungeon) then return end
  local marked = 0
  local dungeonEnemies = mdt().dungeonEnemies[selectedDungeon]
  local common = Data.CommonSpells(dungeonEnemies)
  for _, enemy in ipairs(Data.DungeonEnemies(dungeonEnemies)) do
    for _, group in ipairs(Data.SpellGroups(enemy.spells, false, common, selectedDungeon, enemy)) do
      if Data.IsGroupImportant(group) then marked = marked + 1 end
    end
  end
  local text = L["%d abilities marked important in this dungeon"]:format(marked)
  local source = Data.SourceName(selectedDungeon)
  if source then text = text.."  |cff8f8f8f"..L["Ability data by %s"]:format(source).."|r" end
  summary:SetText(text)
end

local function createSpellRow()
  local row = CreateFrame("Button", nil, scrollChild)
  row:SetHeight(SPELL_ROW_H)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("LEFT", row, "LEFT", 28, 0)
  row.check:SetScript("OnClick", function(self)
    Data.SetGroupImportant(row.group, self:GetChecked() == true)
    updateSummary()
    onChange()
  end)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

  row.tags = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.tags:SetPoint("LEFT", row.name, "RIGHT", 10, 0)

  -- Clicking anywhere on the row toggles it.
  row:SetScript("OnClick", function(self) self.check:Click() end)
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.group.spellId)
    if self.group.note then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(self.group.note, 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

local function acquire(pool, index, factory)
  local widget = pool[index] or factory()
  pool[index] = widget
  return widget
end

local function placeRow(widget, y)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
  widget:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
  widget:Show()
end

local function rebuild()
  if not (scrollChild and selectedDungeon) then return end
  local dungeonEnemies = mdt().dungeonEnemies[selectedDungeon]
  local common = Data.CommonSpells(dungeonEnemies)

  -- Enemies in the data add-on's order (roughly pull order, bosses last), the
  -- ones it doesn't list after them in MDT order.
  local entries = {}
  for i, enemy in ipairs(Data.DungeonEnemies(dungeonEnemies)) do
    -- Alphabetical so rows stay put when ticked (the panel sorts important first).
    local groups, addOf = Data.SpellGroups(enemy.spells, false, common, selectedDungeon, enemy)
    local order = Data.SourceOrder(groups, enemy.isBoss or addOf ~= nil)
    entries[i] = { enemy = enemy, groups = groups, addOf = addOf, order = order, mdtOrder = i }
  end
  table.sort(entries, function(a, b)
    if (a.order ~= nil) ~= (b.order ~= nil) then return a.order ~= nil end
    if a.order and a.order ~= b.order then return a.order < b.order end
    return a.mdtOrder < b.mdtOrder
  end)

  local y, headers, rows = 0, 0, 0
  for _, entry in ipairs(entries) do
    local enemy, groups, addOf = entry.enemy, entry.groups, entry.addOf
    if #groups > 0 then
      headers = headers + 1
      local header = acquire(headerPool, headers, createHeader)
      placeRow(header, y)
      SetPortraitTextureFromCreatureDisplayID(header.portrait, enemy.displayId or 39490)
      local name = Panel.LocalizedName(enemy.name)
      if enemy.isBoss then
        header.text:SetText(name.."  |cffff8000"..L["Boss"].."|r")
      elseif addOf then
        header.text:SetText(name.."  |cffff8000"..L["Add: %s"]:format(addOf).."|r")
      else
        header.text:SetText(name)
      end
      y = y + HEADER_H
    end

    for _, group in ipairs(groups) do
      rows = rows + 1
      local row = acquire(spellPool, rows, createSpellRow)
      placeRow(row, y)
      row.group = group
      row.check:SetChecked(group.important)
      row.icon:SetTexture(C_Spell.GetSpellTexture(group.spellId) or FALLBACK_ICON)
      row.name:SetText(group.name)
      row.tags:SetText(Panel.TagLine(group.tags))
      y = y + SPELL_ROW_H
    end
    if #groups > 0 then y = y + ENEMY_GAP end
  end

  for i = headers + 1, #headerPool do headerPool[i]:Hide() end
  for i = rows + 1, #spellPool do spellPool[i]:Hide() end
  scrollChild:SetHeight(math.max(y, 1))
  updateSummary()
end

-- Rebuilds the list and refreshes everything that shows which list is active.
local function listsChanged()
  if listDropdown then listDropdown:GenerateMenu() end
  if deleteButton and selectedDungeon then
    deleteButton:SetEnabled(#Data.ListNames(selectedDungeon) > 1)
  end
  rebuild()
  onChange()
end

-- =====================================================================
-- List dialogs
-- =====================================================================

local function popupEditBox(popup)
  return popup.EditBox or popup.editBox or (popup.GetEditBox and popup:GetEditBox())
end

local NAME_ERRORS = {
  empty = "Enter a name for the list.",
  exists = "A list with that name already exists in this dungeon.",
}

-- One name dialog for New, Copy and Rename; `data.action` says which.
StaticPopupDialogs["MDTNPI_LIST_NAME"] = {
  text = "%s",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = 40,
  OnShow = function(self, data)
    data = data or self.data
    local box = popupEditBox(self)
    box:SetText(data.initial or "")
    box:HighlightText()
    box:SetFocus()
  end,
  OnAccept = function(self, data)
    data = data or self.data
    local name = popupEditBox(self):GetText()
    local result, err
    if data.action == "rename" then
      result, err = Data.RenameList(selectedDungeon, data.from, name)
    else
      result, err = Data.CreateList(selectedDungeon, name, data.action == "copy" and data.from or nil)
    end
    if not result then
      print(PREFIX..L[NAME_ERRORS[err] or "Could not save the list."])
      return
    end
    listsChanged()
  end,
  EditBoxOnEnterPressed = function(box)
    local popup = box:GetParent()
    StaticPopupDialogs["MDTNPI_LIST_NAME"].OnAccept(popup, popup.data)
    popup:Hide()
  end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MDTNPI_LIST_DELETE"] = {
  text = L["Delete the list \"%s\"?"],
  button1 = YES,
  button2 = NO,
  OnAccept = function(self, data)
    data = data or self.data
    Data.DeleteList(selectedDungeon, data)
    listsChanged()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MDTNPI_LIST_RESET"] = {
  text = L["Reset the list \"%s\" to the defaults?"],
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    Data.ResetActiveList(selectedDungeon)
    listsChanged()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MDTNPI_LIST_EXPORT"] = {
  text = L["Copy this text (Ctrl+C) to share the list:"],
  button1 = CLOSE,
  hasEditBox = true,
  editBoxWidth = 350,
  OnShow = function(self, data)
    local box = popupEditBox(self)
    box:SetText(data or self.data or "")
    box:HighlightText()
    box:SetFocus()
  end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function importText(text)
  local dungeonIndex, name, picks = Data.ParseListString(text)
  local enemies = dungeonIndex and mdt().dungeonEnemies[dungeonIndex]
  if not enemies then
    print(PREFIX..L["That isn't a Next Pull Info list, or its dungeon isn't in MDT."])
    return
  end
  local created = Data.ImportList(dungeonIndex, enemies, name, picks)
  if not created then
    print(PREFIX..L["Could not save the list."])
    return
  end
  selectedDungeon = dungeonIndex
  if dropdown then dropdown:GenerateMenu() end
  listsChanged()
  print(PREFIX..L["Imported \"%s\" into %s."]:format(created, dungeonName(dungeonIndex)))
end

StaticPopupDialogs["MDTNPI_LIST_IMPORT"] = {
  text = L["Paste a shared list (Ctrl+V):"],
  button1 = L["Import"],
  button2 = CANCEL,
  hasEditBox = true,
  editBoxWidth = 350,
  OnShow = function(self)
    local box = popupEditBox(self)
    box:SetText("")
    box:SetFocus()
  end,
  OnAccept = function(self) importText(popupEditBox(self):GetText()) end,
  EditBoxOnEnterPressed = function(box)
    importText(box:GetText())
    box:GetParent():Hide()
  end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- =====================================================================
-- Options page
-- =====================================================================

local function activeList()
  local _, active = Data.ListNames(selectedDungeon)
  return active
end

local function button(parent, text, width, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 22)
  btn:SetText(text)
  btn:SetScript("OnClick", onClick)
  return btn
end

local function createCanvas()
  local frame = CreateFrame("Frame")
  frame:Hide()

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
  title:SetText(L["Important abilities"])

  local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  description:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
  description:SetJustifyH("LEFT")
  description:SetText(L["Tick the abilities that important mode should show. Each dungeon can have several lists, like MDT routes; the selected list is the one used. Enemies with no ticked abilities are hidden in important mode."])

  dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(240)
  dropdown:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
  dropdown:SetupMenu(function(_, root)
    for i, section in ipairs(dungeonSections()) do
      if i > 1 then root:CreateDivider() end
      root:CreateTitle(section.title)
      for _, dungeon in ipairs(section.dungeons) do
        root:CreateRadio(dungeon.name,
          function(index) return index == selectedDungeon end,
          function(index)
            selectedDungeon = index
            listsChanged()
          end,
          dungeon.index)
      end
    end
  end)

  summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  summary:SetPoint("LEFT", dropdown, "RIGHT", 12, 0)

  -- Sharing and reset sit top right; list management on its own row.
  local exportButton = button(frame, L["Export"], 90, function()
    StaticPopup_Show("MDTNPI_LIST_EXPORT", nil, nil, Data.ExportList(selectedDungeon, mdt().dungeonEnemies[selectedDungeon]))
  end)
  exportButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -16)
  local importButton = button(frame, L["Import"], 90, function() StaticPopup_Show("MDTNPI_LIST_IMPORT") end)
  importButton:SetPoint("RIGHT", exportButton, "LEFT", -6, 0)
  local resetButton = button(frame, L["Reset to defaults"], 140, function()
    StaticPopup_Show("MDTNPI_LIST_RESET", activeList())
  end)
  resetButton:SetPoint("RIGHT", importButton, "LEFT", -6, 0)

  local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listLabel:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -14)
  listLabel:SetText(L["List:"])

  listDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  listDropdown:SetWidth(200)
  listDropdown:SetPoint("LEFT", listLabel, "RIGHT", 8, 0)
  listDropdown:SetupMenu(function(_, root)
    if not selectedDungeon then return end
    for _, name in ipairs((Data.ListNames(selectedDungeon))) do
      root:CreateRadio(name,
        function(listName) return listName == activeList() end,
        function(listName)
          Data.SetActiveList(selectedDungeon, listName)
          listsChanged()
        end,
        name)
    end
  end)

  local newButton = button(frame, L["New"], 70, function()
    StaticPopup_Show("MDTNPI_LIST_NAME", L["Name for the new list:"], nil, { action = "new" })
  end)
  newButton:SetPoint("LEFT", listDropdown, "RIGHT", 8, 0)
  local copyButton = button(frame, L["Copy"], 70, function()
    local from = activeList()
    StaticPopup_Show("MDTNPI_LIST_NAME", L["Name for the copy:"], nil, { action = "copy", from = from, initial = from })
  end)
  copyButton:SetPoint("LEFT", newButton, "RIGHT", 4, 0)
  local renameButton = button(frame, L["Rename"], 70, function()
    local from = activeList()
    StaticPopup_Show("MDTNPI_LIST_NAME", L["New name for the list:"], nil, { action = "rename", from = from, initial = from })
  end)
  renameButton:SetPoint("LEFT", copyButton, "RIGHT", 4, 0)
  deleteButton = button(frame, L["Delete"], 70, function()
    local name = activeList()
    StaticPopup_Show("MDTNPI_LIST_DELETE", name, nil, name)
  end)
  deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 4, 0)

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -14)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)

  scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetSize(1, 1)
  scroll:SetScrollChild(scrollChild)
  scroll:SetScript("OnSizeChanged", function(self, width) scrollChild:SetWidth(width) end)

  frame:SetScript("OnShow", function()
    if not selectedDungeon then selectedDungeon = initialDungeon(dungeonSections()) end
    dropdown:GenerateMenu()
    listDropdown:GenerateMenu()
    deleteButton:SetEnabled(#Data.ListNames(selectedDungeon) > 1)
    rebuild()
  end)

  -- Methods the Settings panel calls on canvas pages.
  frame.OnCommit = function() end
  frame.OnDefault = function() end
  frame.OnRefresh = function() if frame:IsShown() then rebuild() end end

  return frame
end

---Adds the page under the addon's options category.
---@param changed fun() called after any important pick changes
function M:Register(parentCategory, changed)
  if canvas or not parentCategory then return end
  onChange = changed
  canvas = createCanvas()
  Settings.RegisterCanvasLayoutSubcategory(parentCategory, canvas, L["Important abilities"])
end
