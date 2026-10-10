local _, NPI = ...
local L = NPI.L
local Data = NPI.Data

local ipairs, math_min, string_format, table_concat, unpack = ipairs, math.min, string.format, table.concat, unpack

local Panel = {}
NPI.Panel = Panel

local WIDTH = 300
local PADDING = 8
local GAP_TO_BEACON = 4
local HEADER_H = 18
local ROW_GAP = 6
local OVERFLOW_H = 14
local PORTRAIT_SIZE = 40
local TEXT_X = PORTRAIT_SIZE + 8 -- where a row's text column starts

-- Each enemy row: its name, then one line per ability (icon beside the
-- ability's name and its own tags), so tags never mix between abilities.
-- Past DETAIL_LIMIT, the remaining abilities sit in a strip of small icons.
local NAME_H = 20
local DETAIL_H = 32
local DETAIL_ICON = 26
local DETAIL_LIMIT = 3
local TAG_LINE_H = 12 -- each extra line of tags when they don't fit on one
local STRIP_H = 26
local ICON_SIZE = 22
local ICON_GAP = 3
local MAX_STRIP_ICONS = 14 -- created per row; how many show depends on the panel width
Panel.MAX_ROWS = 8

local FALLBACK_DISPLAY_ID = 39490
local FALLBACK_ICON = 134400 -- question mark

local BACKDROP = { 0.058, 0.058, 0.058, 0.9 }
local ACCENT = { 0, 1, 0.5, 1 } -- NPT's header green

-- Keyed by tag, by a "Category: value" tag's value (Debuff: Magic -> Magic),
-- or by its category (Frontal: Locks -> Frontal), in that order.
local TAG_COLORS = {
  Interrupt = "66ccff",
  Magic = "3399ff",
  Curse = "b266ff",
  Poison = "33cc33",
  Disease = "cc9933",
  Bleed = "ff4d4d",
  Enrage = "ff9933",
  -- Categories a data add-on may use.
  Important = "ffd100",
  ["Party Dam"] = "ff6666",
  Avoid = "ffcc66",
  Frontal = "ffd633",
  ["Tank Buster"] = "a0b4c8",
  Stop = "33e6e6",
  Buff = "ff9933",
  Debuff = "cc99ff",
  Special = "bbbbbb",
  ["Add Spawn"] = "cc99ff",
  ["CC Effect"] = "ff66cc",
}

local function tagColor(tag)
  if TAG_COLORS[tag] then return TAG_COLORS[tag] end
  local category, value = tag:match("^(.-): (.+)$")
  return (value and TAG_COLORS[value]) or (category and TAG_COLORS[category]) or "cccccc"
end

-- Tactyks' shorthand spelled out. "Special" tags name what counters the
-- ability, so they read as the counter itself.
local TAG_TEXT = {
  ["Buff: Other"] = "Buff",
  ["Debuff: Non-Phys"] = "Debuff: Non-physical",
  ["Frontal: Locks"] = "Frontal (locked)",
  ["Frontal: Follows"] = "Frontal (follows)",
  ["Special: Dwarf"] = "Stoneform",
  ["Special: Meld"] = "Shadowmeld",
  ["Special: Freedom"] = "Freedom",
  ["Special: LoS"] = "Line of sight",
}

local function localizedTag(tag)
  if TAG_TEXT[tag] then return L[TAG_TEXT[tag]] end
  local category, value = tag:match("^(.-): (.+)$")
  if category then return L[category]..": "..L[value] end
  return L[tag]
end

local function isCounter(tag) return tag:find("^Special: ") ~= nil end

local TAG_SEPARATOR = "|cff606060  ·  |r"

local settings = { side = "RIGHT" }

local function localizedName(name)
  local npt = _G.MDT_NPT
  return (npt and npt.L and npt.L[name]) or name
end
Panel.LocalizedName = localizedName

---Colored, localized tags, one string each.
---@param skip fun(tag: string): boolean|nil tags to leave out
local function tagParts(tags, skip)
  local parts = {}
  for _, tag in ipairs(tags) do
    if not (skip and skip(tag)) then
      parts[#parts + 1] = "|cff"..tagColor(tag)..localizedTag(tag).."|r"
    end
  end
  return parts
end

---Colored, localized tags on one line, e.g. "Interrupt · Magic".
local function tagLine(tags, skip)
  return table_concat(tagParts(tags, skip), TAG_SEPARATOR)
end
Panel.TagLine = tagLine

-- =====================================================================
-- Portrait
-- =====================================================================

local function createPortrait(row)
  local portrait = CreateFrame("Frame", nil, row)
  portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
  portrait:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  portrait:EnableMouse(true)

  portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
  portrait.texture:SetAllPoints()
  portrait.texture:SetMask("Interface\\Masks\\CircleMaskScalable")

  portrait:SetScript("OnEnter", function(self)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(localizedName(entry.name), 1, 1, 1)
    if entry.isBoss then GameTooltip:AddLine(L["Boss"], 1, 0.5, 0) end
    if entry.addOf then GameTooltip:AddLine(L["Add: %s"]:format(entry.addOf), 1, 0.5, 0) end
    local tags = tagLine(entry.tags)
    if tags ~= "" then GameTooltip:AddLine(tags, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  portrait:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return portrait
end

-- =====================================================================
-- Ability icons and lines
-- =====================================================================

---@param owner table frame the tooltip anchors to
---@param group table an ability from Data.SpellGroups
local function showAbilityTooltip(owner, group)
  if not group then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetSpellByID(group.spellId)
  -- "Marked important" follows the player's list, so the data's own
  -- Important tag would only repeat (or contradict) it.
  local tags = tagLine(group.tags, function(tag) return tag == "Important" or isCounter(tag) end)
  local counters = tagLine(group.tags, function(tag) return not isCounter(tag) end)
  if group.important or tags ~= "" or counters ~= "" or group.note then GameTooltip:AddLine(" ") end
  if group.important then GameTooltip:AddLine(L["Marked important"], 1, 0.82, 0) end
  if tags ~= "" then GameTooltip:AddLine(tags, 1, 1, 1, true) end
  if counters ~= "" then GameTooltip:AddLine(L["Countered by: %s"]:format(counters), 0.6, 0.6, 0.6, true) end
  if group.note then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(group.note, 0.9, 0.9, 0.9, true)
  end
  local source = group.external and Data.SourceName(group.dungeonIndex)
  if source then GameTooltip:AddLine("— "..source, 0.45, 0.45, 0.45) end
  GameTooltip:Show()
end

local function hideTooltip() GameTooltip:Hide() end

local function createSpellIcon(parent, size)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  btn.border = btn:CreateTexture(nil, "BACKGROUND")
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetAllPoints()
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  btn:SetScript("OnEnter", function(self) showAbilityTooltip(self, self.group) end)
  btn:SetScript("OnLeave", hideTooltip)
  return btn
end

-- =====================================================================
-- Sharing an ability in chat
-- =====================================================================

local CHAT_PREFIX = "|cff00ff80Next Pull Info|r: "
local MESSAGE_PREFIX = "MDT Next Pull Info: " -- starts each shared ability, so the group knows where it's from
local MAX_MESSAGE = 255 -- bytes the server accepts in one chat message

local function groupChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then return "INSTANCE_CHAT" end
  if IsInGroup() then return "PARTY" end
end

---Cuts a string to `bytes` without splitting a UTF-8 character.
local function trimBytes(text, bytes)
  if #text <= bytes then return text end
  text = text:sub(1, bytes)
  return (text:gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", ""))
end

---One chat line about an ability: link, enemy, tags, counters, note.
---@param plain boolean the ability's name instead of its link (copied link codes don't paste back)
local function chatMessage(group, plain)
  local plainTags, counters = {}, {}
  for _, tag in ipairs(group.tags) do
    if isCounter(tag) then counters[#counters + 1] = localizedTag(tag)
    else plainTags[#plainTags + 1] = localizedTag(tag) end
  end
  local head = not plain and C_Spell.GetSpellLink(group.spellId) or group.name
  if group.enemy then head = head.." ("..localizedName(group.enemy)..")" end
  local parts = {}
  if #plainTags > 0 then parts[#parts + 1] = table_concat(plainTags, ", ") end
  if #counters > 0 then parts[#parts + 1] = L["Countered by: %s"]:format(table_concat(counters, ", ")) end
  local body = MESSAGE_PREFIX..head..(#parts > 0 and ": "..table_concat(parts, ". ") or "")

  local room = MAX_MESSAGE - #body - 2 -- 2 for ". "
  if group.note and room > 10 then
    local note = group.note
    if #note > room then note = trimBytes(note, room - 3).."..." end
    body = body..". "..note
  end
  return trimBytes(body, MAX_MESSAGE)
end

---Shows an ability's chat line ready to copy and paste into chat yourself.
local function copyAbility(group)
  StaticPopup_Show("MDTNPI_COPY", L["Copy (Ctrl+C), then paste it in chat:"], nil, chatMessage(group, true))
end

---Sends an ability to party (or instance) chat. Blizzard blocks add-ons from
---sending chat during keys and encounters (even text they only put in the chat
---box), so then it's offered to copy instead.
local function shareAbility(group)
  local lockdown = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
  if lockdown then return copyAbility(group) end
  local channel = groupChannel()
  local message = chatMessage(group)
  if not channel then
    print(CHAT_PREFIX..L["Not in a group. This is what would be sent:"])
    print(message)
    return
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  send(message, channel)
end

local CHAT_BUTTON = 32

---@param copy boolean copy the ability's chat line (the panel, used during keys) instead of sending it
local function createChatButton(line, copy)
  local btn = CreateFrame("Button", nil, line)
  btn:SetSize(CHAT_BUTTON, CHAT_BUTTON)
  btn:SetPoint("RIGHT", line, "RIGHT", 0, 0)
  if copy then
    btn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    btn:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6)
    -- Drawn at half size; the button keeps its full size so it's easy to click.
    for _, texture in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture() }) do
      texture:ClearAllPoints()
      texture:SetSize(CHAT_BUTTON / 2, CHAT_BUTTON / 2)
      texture:SetPoint("CENTER")
    end
  else
    btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
  end
  btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  if copy then
    local highlight = btn:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetSize(CHAT_BUTTON / 2, CHAT_BUTTON / 2)
    highlight:SetPoint("CENTER")
  end
  btn:GetNormalTexture():SetAlpha(0.6)
  btn:SetScript("OnClick", function()
    local group = line.icon.group
    if not group then return end
    if copy then copyAbility(group) else shareAbility(group) end
  end)
  btn:SetScript("OnEnter", function(self)
    self:GetNormalTexture():SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if copy then
      GameTooltip:SetText(L["Copy for chat"], 1, 1, 1)
      GameTooltip:AddLine(L["This ability's tags and notes, ready to paste into chat. Blizzard doesn't let add-ons send chat during keys."], 0.7, 0.7, 0.7, true)
    else
      GameTooltip:SetText(L["Send to party chat"], 1, 1, 1)
      GameTooltip:AddLine(L["Shares this ability's tags and notes with your group."], 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function(self)
    self:GetNormalTexture():SetAlpha(0.6)
    GameTooltip:Hide()
  end)
  return btn
end

local TAGS_X = 2 + DETAIL_ICON + 7 -- where an ability line's text starts
local TAGS_RIGHT = CHAT_BUTTON + 4 -- room kept clear for the chat button

local function textWidth(fontString, text)
  fontString:SetText(text)
  if fontString.GetUnboundedStringWidth then return fontString:GetUnboundedStringWidth() end
  return fontString:GetStringWidth()
end

---An ability line's tags ("Important" is left to the gold icon frame), packed
---into as many lines as `width` needs so no tag is cut off or split.
local function layoutLineTags(fontString, tags, width)
  -- Measure without a width so nothing wraps or truncates while measuring.
  fontString:SetWidth(0)
  fontString:SetWordWrap(false)
  local lines, current = {}, nil
  for _, part in ipairs(tagParts(tags, function(tag) return tag == "Important" end)) do
    local candidate = current and (current..TAG_SEPARATOR..part) or part
    if current and textWidth(fontString, candidate) > width then
      lines[#lines + 1] = current
      current = part
    else
      current = candidate
    end
  end
  lines[#lines + 1] = current
  -- Fixed width with wrapping on, so a line still breaks if a measurement was off.
  fontString:SetWidth(width)
  fontString:SetWordWrap(true)
  fontString:SetText(table_concat(lines, "\n"))
  local shown = math.ceil((fontString:GetStringHeight() + 1) / TAG_LINE_H)
  return math.max(#lines, shown, 1)
end

---@param copy boolean|nil its chat button copies the ability's chat line instead of sending it
local function createDetailLine(row, copy)
  local line = CreateFrame("Frame", nil, row)
  line:SetHeight(DETAIL_H)
  line:EnableMouse(true)
  line:SetScript("OnEnter", function(self) showAbilityTooltip(self, self.icon.group) end)
  line:SetScript("OnLeave", hideTooltip)

  line.icon = createSpellIcon(line, DETAIL_ICON)
  line.icon:SetPoint("TOPLEFT", line, "TOPLEFT", 2, -3)
  line.chat = createChatButton(line, copy == true)

  line.name = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  line.name:SetPoint("TOPLEFT", line, "TOPLEFT", TAGS_X, -2)
  line.name:SetPoint("RIGHT", line, "RIGHT", -TAGS_RIGHT, 0)
  line.name:SetJustifyH("LEFT")
  line.name:SetWordWrap(false)

  line.tags = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  line.tags:SetPoint("TOPLEFT", line.name, "BOTTOMLEFT", 0, -2)
  line.tags:SetJustifyH("LEFT")
  line.tags:SetJustifyV("TOP")
  line.tags:SetNonSpaceWrap(false)
  return line
end

---@param group table an ability from Data.SpellGroups
local function setSpellIcon(btn, group)
  btn.group = group
  btn.important = group.important
  btn.icon:SetTexture(C_Spell.GetSpellTexture(group.spellId) or FALLBACK_ICON)

  -- Important abilities get a thicker gold frame.
  local inset = btn.important and 2 or 1
  btn.border:ClearAllPoints()
  btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", -inset, inset)
  btn.border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", inset, -inset)
  if btn.important then
    btn.border:SetColorTexture(1, 0.82, 0, 1)
  else
    btn.border:SetColorTexture(0.3, 0.3, 0.3, 1)
  end
  btn:Show()
end

-- Ability lines are shared with the trash overview window.
Panel.CreateDetailLine = createDetailLine

---Shows one ability on a line from Panel.CreateDetailLine and returns the
---line's height, which grows when its tags need more than one line.
---@param width number the line's width
function Panel.FillDetailLine(line, group, width)
  setSpellIcon(line.icon, group)
  line.name:SetText(group.name)
  local tagLines = layoutLineTags(line.tags, group.tags, width - TAGS_X - TAGS_RIGHT)
  local height = DETAIL_H + (tagLines - 1) * TAG_LINE_H
  line:SetHeight(height)
  return height
end

-- =====================================================================
-- Rows
-- =====================================================================

local function createRow(parent)
  local row = CreateFrame("Frame", nil, parent) -- width follows the panel, see Panel:Render
  row.portrait = createPortrait(row)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -2)
  row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  row.details, row.strip = {}, {}
  return row
end

---Lays out one enemy and returns the row's height.
---@param contentWidth number usable width of the panel
local function fillRow(row, entry, contentWidth)
  row.entry = entry

  local name = localizedName(entry.name)
  if entry.count > 1 then name = name.." |cffaaaaaax"..entry.count.."|r" end
  row.name:SetText(name)
  if entry.isBoss or entry.addOf then
    row.name:SetTextColor(1, 0.5, 0)
  elseif entry.hasImportant then
    row.name:SetTextColor(1, 0.82, 0)
  else
    row.name:SetTextColor(1, 1, 1)
  end

  SetPortraitTextureFromCreatureDisplayID(row.portrait.texture, entry.displayId or FALLBACK_DISPLAY_ID)

  -- One line per ability (groups come important first). Bosses get a line for
  -- every ability; others get the first few and an icon strip for the rest.
  local y = NAME_H
  local detailCount = entry.isBoss and #entry.groups or math_min(#entry.groups, DETAIL_LIMIT)
  for i = 1, detailCount do
    local group = entry.groups[i]
    -- The panel is up during keys, when add-ons can't send chat: copy instead.
    local line = row.details[i] or createDetailLine(row, true)
    row.details[i] = line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -y)
    line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    line:Show()
    y = y + Panel.FillDetailLine(line, group, contentWidth - TEXT_X)
  end
  for i = detailCount + 1, #row.details do row.details[i]:Hide() end

  -- The rest as a strip of small icons, as many as fit.
  local slots = math.floor((contentWidth - TEXT_X + ICON_GAP) / (ICON_SIZE + ICON_GAP))
  local stripCount = math_min(#entry.groups - detailCount, slots, MAX_STRIP_ICONS)
  for i = 1, stripCount do
    local btn = row.strip[i] or createSpellIcon(row, ICON_SIZE)
    row.strip[i] = btn
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X + 2 + (i - 1) * (ICON_SIZE + ICON_GAP), -(y + 2))
    setSpellIcon(btn, entry.groups[detailCount + i])
  end
  for i = stripCount + 1, #row.strip do row.strip[i]:Hide() end
  if stripCount > 0 then y = y + STRIP_H end

  local height = math.max(PORTRAIT_SIZE, y)
  row:SetHeight(height)
  return height
end

-- =====================================================================
-- Panel frame
-- =====================================================================

local function createEdge(frame, p1, p2, horizontal)
  local edge = frame:CreateTexture(nil, "BORDER")
  edge:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  edge:SetPoint(p1)
  edge:SetPoint(p2)
  if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
end

-- Dragging the panel moves the beacon, through NPT's own handlers so NPT
-- keeps saving the position and honouring its lock.
local function forwardToBeacon(script)
  return function(self)
    local beacon = self:GetParent()
    local handler = beacon and beacon:GetScript(script)
    if handler then handler(beacon) end
  end
end

local function create(beacon)
  local frame = CreateFrame("Frame", "MDTNextPullInfoFrame", beacon)
  frame:SetWidth(WIDTH)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", forwardToBeacon("OnDragStart"))
  frame:SetScript("OnDragStop", forwardToBeacon("OnDragStop"))

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(BACKDROP[1], BACKDROP[2], BACKDROP[3], BACKDROP[4])
  createEdge(frame, "TOPLEFT", "TOPRIGHT", true)
  createEdge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true)
  createEdge(frame, "TOPLEFT", "BOTTOMLEFT", false)
  createEdge(frame, "TOPRIGHT", "BOTTOMRIGHT", false)

  frame.header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  frame.header:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[4])

  frame.overflow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.overflow:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, PADDING)
  frame.overflow:SetTextColor(0.6, 0.6, 0.6, 1)

  frame.rows = {}
  frame:Hide()
  return frame
end

-- side -> { panel point, beacon point, x, y }. Top/bottom align to the
-- beacon's left edge; the panel grows away from the beacon either way.
local ANCHORS = {
  RIGHT = { "TOPLEFT", "TOPRIGHT", GAP_TO_BEACON, 0 },
  LEFT = { "TOPRIGHT", "TOPLEFT", -GAP_TO_BEACON, 0 },
  TOP = { "BOTTOMLEFT", "TOPLEFT", 0, GAP_TO_BEACON },
  BOTTOM = { "TOPLEFT", "BOTTOMLEFT", 0, -GAP_TO_BEACON },
}
Panel.SIDES = { "RIGHT", "LEFT", "TOP", "BOTTOM" }

local function anchorToBeacon(frame, beacon)
  local side = ANCHORS[settings.side] and settings.side or "RIGHT"
  local point, relativePoint, x, y = unpack(ANCHORS[side])
  frame:ClearAllPoints()
  frame:SetPoint(point, beacon, relativePoint, x, y)

  -- Above/below, match the beacon's width so the two read as one block, but
  -- never go narrower than the rows need (NPT's map-only beacon is ~166px).
  if side == "TOP" or side == "BOTTOM" then
    frame:SetWidth(math.max(WIDTH, beacon:GetWidth()))
  else
    frame:SetWidth(WIDTH)
  end
end

function Panel:Configure(side)
  settings.side = side
end

---Shows the notable enemies of one pull next to the NPT beacon.
---@param mobs table from Data.CollectPullMobs
function Panel:Render(beacon, pullIndex, inCombat, mobs, maxRows)
  if not self.frame or self.frame:GetParent() ~= beacon then
    self.frame = create(beacon)
  end
  local frame = self.frame
  anchorToBeacon(frame, beacon)

  frame.header:SetText(string_format(inCombat and L["Pull %d (in combat)"] or L["Pull %d"], pullIndex))

  local contentWidth = frame:GetWidth() - 2 * PADDING

  -- Rows have different heights (one line per ability), so stack them.
  local y = PADDING + HEADER_H
  local shown = math_min(#mobs, maxRows)
  for i = 1, shown do
    local row = frame.rows[i] or createRow(frame)
    frame.rows[i] = row
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -y)
    y = y + fillRow(row, mobs[i], contentWidth)
    if i < shown then y = y + ROW_GAP end
    row:Show()
  end
  for i = shown + 1, #frame.rows do
    frame.rows[i].entry = nil
    frame.rows[i]:Hide()
  end

  local hidden = #mobs - shown
  frame.overflow:SetText(hidden > 0 and string_format(L["+%d more"], hidden) or "")

  local height = y + PADDING
  if hidden > 0 then height = height + OVERFLOW_H end
  frame:SetHeight(height)
  frame:Show()
end

function Panel:Hide()
  if self.frame then self.frame:Hide() end
end
