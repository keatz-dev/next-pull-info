local _, NPI = ...

local pairs, ipairs, tonumber, type, tostring = pairs, ipairs, tonumber, type, tostring
local table_sort, table_concat = table.sort, table.concat

local Data = {}
NPI.Data = Data

-- MDT spell flags -> display tags, in display order.
local FLAG_TAGS = {
  { "interruptible", "Interrupt" },
  { "magic", "Magic" },
  { "curse", "Curse" },
  { "poison", "Poison" },
  { "disease", "Disease" },
  { "enrage", "Enrage" },
  { "bleed", "Bleed" },
}

-- =====================================================================
-- Curated ability data (Data/Tactyks.lua, or another data add-on)
-- =====================================================================

-- A source describes abilities per dungeon: its own tags, a note, and whether
-- it considers them important. Where a dungeon has such data, its tags replace
-- MDT's and its important picks are the defaults instead of Data/Important.lua.
local external = {} -- dungeonIndex -> { source, byId, byName, pending }

---@param source table { name = "...", dungeons = { [MDT dungeon index] = { { spellId, tags, note, important }, ... } } }
function Data.RegisterAbilityData(source)
  for dungeonIndex, entries in pairs(source.dungeons) do
    local dungeon = { source = source.name, byId = {}, byName = {}, pending = {} }
    for _, entry in ipairs(entries) do
      dungeon.byId[entry.spellId] = dungeon.byId[entry.spellId] or entry
      dungeon.pending[#dungeon.pending + 1] = entry
    end
    external[dungeonIndex] = dungeon
  end
end

function NPI:RegisterAbilityData(source) Data.RegisterAbilityData(source) end

---@return string|nil the name of the source providing this dungeon's ability data
function Data.SourceName(dungeonIndex)
  local dungeon = dungeonIndex and external[dungeonIndex]
  return dungeon and dungeon.source
end

-- Names come from the client (localized, and only once it has the spell
-- loaded), so they are indexed lazily and retried until all have arrived.
local function indexNames(dungeon)
  local stillPending = {}
  for _, entry in ipairs(dungeon.pending) do
    local name = C_Spell.GetSpellName(entry.spellId)
    if name then
      dungeon.byName[name] = dungeon.byName[name] or entry
    else
      stillPending[#stillPending + 1] = entry
    end
  end
  dungeon.pending = stillPending
end

-- Matched by spell ID, else by name within the dungeon: sources often link a
-- different ID of the same ability (the debuff instead of the cast).
local function externalEntry(dungeonIndex, group)
  local dungeon = dungeonIndex and external[dungeonIndex]
  if not dungeon then return nil end
  for _, spellId in ipairs(group.ids) do
    if dungeon.byId[spellId] then return dungeon.byId[spellId] end
  end
  if #dungeon.pending > 0 then indexNames(dungeon) end
  return dungeon.byName[group.name]
end

-- =====================================================================
-- Important abilities: per-dungeon lists, like MDT's routes
-- =====================================================================

-- Each dungeon has named lists; the active one decides what important mode
-- shows there. A list stores only where the player differs from the defaults
-- (data add-on picks, else Data/Important.lua): spellId -> true/false.
--   store[dungeonIndex] = { active = "Default", lists = { [name] = { [spellId] = bool } } }
local DEFAULT_LIST = "Default"
local MAX_NAME_LENGTH = 40
local store = {}
local legacyOverrides -- picks saved before lists existed; seed each dungeon's "Default"

---@param saved table saved-variables table for the lists
---@param legacy table|nil pre-lists overrides (spellId -> bool), copied into new "Default" lists
function Data.SetListStore(saved, legacy)
  store = saved
  legacyOverrides = legacy
end

local function dungeonLists(dungeonIndex)
  local dungeon = store[dungeonIndex]
  if not dungeon then
    local default = {}
    for spellId, value in pairs(legacyOverrides or {}) do default[spellId] = value end
    dungeon = { active = DEFAULT_LIST, lists = { [DEFAULT_LIST] = default } }
    store[dungeonIndex] = dungeon
  end
  if not dungeon.lists[dungeon.active] then
    dungeon.active = next(dungeon.lists) or DEFAULT_LIST
    dungeon.lists[dungeon.active] = dungeon.lists[dungeon.active] or {}
  end
  return dungeon
end

local noOverrides = {}

local function activeOverrides(dungeonIndex)
  if not dungeonIndex then return noOverrides end
  local dungeon = dungeonLists(dungeonIndex)
  return dungeon.lists[dungeon.active]
end

-- The data add-on's pick where it covers the dungeon, else the shipped list.
local function groupDefault(group)
  if group.hasExternalData then
    return group.external ~= nil and group.external.important == true
  end
  for _, spellId in ipairs(group.ids) do
    if NPI.DefaultImportant[spellId] then return true end
  end
  return false
end

---Names of a dungeon's lists, sorted, and the active one.
function Data.ListNames(dungeonIndex)
  local dungeon = dungeonLists(dungeonIndex)
  local names = {}
  for name in pairs(dungeon.lists) do names[#names + 1] = name end
  table_sort(names)
  return names, dungeon.active
end

function Data.SetActiveList(dungeonIndex, name)
  local dungeon = dungeonLists(dungeonIndex)
  if dungeon.lists[name] then dungeon.active = name end
end

---@return string|nil cleanName, string|nil error
local function validName(dungeonIndex, name)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, MAX_NAME_LENGTH)
  if name == "" then return nil, "empty" end
  if dungeonLists(dungeonIndex).lists[name] then return nil, "exists" end
  return name
end

---Creates a list (a copy of `copyFrom`, else starting from the defaults) and makes it active.
---@return string|nil name, string|nil error "empty" | "exists"
function Data.CreateList(dungeonIndex, name, copyFrom)
  local cleanName, err = validName(dungeonIndex, name)
  if not cleanName then return nil, err end
  local dungeon = dungeonLists(dungeonIndex)
  local list = {}
  for spellId, value in pairs(copyFrom and dungeon.lists[copyFrom] or {}) do list[spellId] = value end
  dungeon.lists[cleanName] = list
  dungeon.active = cleanName
  return cleanName
end

---@return string|nil name, string|nil error "empty" | "exists"
function Data.RenameList(dungeonIndex, oldName, newName)
  local dungeon = dungeonLists(dungeonIndex)
  if not dungeon.lists[oldName] then return nil, "missing" end
  if newName == oldName then return oldName end
  local cleanName, err = validName(dungeonIndex, newName)
  if not cleanName then return nil, err end
  dungeon.lists[cleanName], dungeon.lists[oldName] = dungeon.lists[oldName], nil
  if dungeon.active == oldName then dungeon.active = cleanName end
  return cleanName
end

---Deletes a list; a dungeon always keeps at least one.
function Data.DeleteList(dungeonIndex, name)
  local dungeon = dungeonLists(dungeonIndex)
  local names = Data.ListNames(dungeonIndex)
  if #names <= 1 or not dungeon.lists[name] then return false end
  dungeon.lists[name] = nil
  if dungeon.active == name then dungeon.active = Data.ListNames(dungeonIndex)[1] end
  return true
end

---Clears the active list's changes, back to the defaults.
function Data.ResetActiveList(dungeonIndex)
  local overrides = activeOverrides(dungeonIndex)
  for spellId in pairs(overrides) do overrides[spellId] = nil end
end

-- =====================================================================
-- MDT enemy data
-- =====================================================================

local function tagsFromFlags(flagged)
  local tags = {}
  for _, flag in ipairs(FLAG_TAGS) do
    if flagged[flag[2]] then tags[#tags + 1] = flag[2] end
  end
  return tags
end

-- An ability can span several spell IDs (cast, debuff, damage tick). Ticking it
-- writes the same choice to all of them, so the first override found decides.
function Data.IsGroupImportant(group)
  local overrides = activeOverrides(group.dungeonIndex)
  for _, spellId in ipairs(group.ids) do
    local override = overrides[spellId]
    if override ~= nil then return override end
  end
  return groupDefault(group)
end

function Data.SetGroupImportant(group, important)
  local overrides = activeOverrides(group.dungeonIndex)
  local default = groupDefault(group)
  for _, spellId in ipairs(group.ids) do
    if important == default then
      overrides[spellId] = nil
    else
      overrides[spellId] = important
    end
  end
  group.important = important
end

-- Spells on at least this share of a dungeon's enemies are season-wide effects
-- (e.g. Xal'atath's Gift), not something to watch for, so they are hidden.
local COMMON_SHARE = 0.5
local COMMON_MIN_ENEMIES = 4
local commonCache = setmetatable({}, { __mode = "k" })

---Spell IDs shared by most of a dungeon's enemies.
---@param enemies table MDT dungeonEnemies for one dungeon
---@return table set spellId -> true
function Data.CommonSpells(enemies)
  if type(enemies) ~= "table" then return {} end
  local cached = commonCache[enemies]
  if cached then return cached end

  local counts, total = {}, 0
  for _, enemy in ipairs(Data.DungeonEnemies(enemies)) do
    total = total + 1
    for spellId in pairs(enemy.spells) do counts[spellId] = (counts[spellId] or 0) + 1 end
  end
  local common = {}
  for spellId in pairs(NPI.SeasonWideSpells or {}) do common[spellId] = true end
  for spellId, count in pairs(counts) do
    if count >= COMMON_MIN_ENEMIES and count >= total * COMMON_SHARE then common[spellId] = true end
  end
  commonCache[enemies] = common
  return common
end

---Abilities in an MDT spells table, one per spell name: MDT often lists several
---IDs that the game names the same (cast, debuff, damage tick), which read as
---duplicates. The shown icon/tooltip is the first flagged ID, else the lowest.
---@param spells table MDT spells: spellId -> flags
---@param importantFirst boolean sort important abilities first (else by name only)
---@param hidden table|nil spellId -> true for spells to leave out (Data.CommonSpells)
---@param dungeonIndex number|nil MDT dungeon index, to look up data add-on entries
---@return table groups { name, spellId, ids, tags, note, important }
function Data.SpellGroups(spells, importantFirst, hidden, dungeonIndex)
  local groups = {}
  if type(spells) ~= "table" then return groups end

  local ids = {}
  for spellId in pairs(spells) do
    local id = tonumber(spellId)
    if id and not (hidden and hidden[id]) then ids[#ids + 1] = id end
  end
  table_sort(ids)

  local byName, flagsByGroup = {}, {}
  for _, spellId in ipairs(ids) do
    local name = C_Spell.GetSpellName(spellId) or ("#"..spellId)
    local group = byName[name]
    if not group then
      group = { name = name, spellId = spellId, ids = {} }
      byName[name] = group
      flagsByGroup[group] = {}
      groups[#groups + 1] = group
    end
    group.ids[#group.ids + 1] = spellId

    local data = spells[spellId] or spells[tostring(spellId)]
    local hasFlags = false
    for _, flag in ipairs(FLAG_TAGS) do
      if type(data) == "table" and data[flag[1]] then
        flagsByGroup[group][flag[2]] = true
        hasFlags = true
      end
    end
    if hasFlags and not group.flaggedId then group.flaggedId = spellId end
  end

  local hasExternalData = dungeonIndex ~= nil and external[dungeonIndex] ~= nil
  for _, group in ipairs(groups) do
    group.spellId = group.flaggedId or group.spellId
    group.flaggedId = nil
    group.dungeonIndex = dungeonIndex
    group.hasExternalData = hasExternalData
    group.external = externalEntry(dungeonIndex, group)
    if group.external then
      group.tags = group.external.tags
      group.note = group.external.note
    else
      group.tags = tagsFromFlags(flagsByGroup[group])
    end
    group.important = Data.IsGroupImportant(group)
  end

  table_sort(groups, function(a, b)
    if importantFirst and a.important ~= b.important then return a.important end
    if a.name ~= b.name then return a.name < b.name end
    return a.spellId < b.spellId
  end)
  return groups
end

---Enemies of one MDT pull, merged by enemy type, with the abilities to show.
---Important-only keeps just the abilities marked important and drops trash
---that has none; bosses always show every ability. Sorted bosses first, then
---enemies with important abilities, then by how many are in the pull.
---@param pull table MDT pull: enemyIndex -> list of clone indexes
---@param enemies table MDT dungeonEnemies for the dungeon
---@param dungeonIndex number MDT dungeon index
---@return table list { name, displayId, count, isBoss, hasImportant, groups, tags }
function Data.CollectPullMobs(pull, enemies, importantOnly, dungeonIndex)
  local list, byName = {}, {}
  if type(pull) ~= "table" or type(enemies) ~= "table" then return list end
  local common = Data.CommonSpells(enemies)

  for enemyIndex, clones in pairs(pull) do
    local enemy = tonumber(enemyIndex) and enemies[enemyIndex]
    if enemy and enemy.name then
      local entry = byName[enemy.name]
      if not entry then
        local groups, tags, seenTag, hasImportant = {}, {}, {}, false
        for _, group in ipairs(Data.SpellGroups(enemy.spells, true, common, dungeonIndex)) do
          if enemy.isBoss or not importantOnly or group.important then
            group.enemy = enemy.name
            groups[#groups + 1] = group
            hasImportant = hasImportant or group.important
            for _, tag in ipairs(group.tags) do
              if not seenTag[tag] then
                seenTag[tag] = true
                tags[#tags + 1] = tag
              end
            end
          end
        end
        entry = {
          name = enemy.name,
          displayId = enemy.displayId,
          count = 0,
          isBoss = enemy.isBoss == true,
          hasImportant = hasImportant,
          groups = groups,
          tags = tags,
        }
        byName[enemy.name] = entry
        if #groups > 0 then list[#list + 1] = entry end
      end
      entry.count = entry.count + (type(clones) == "table" and #clones or 0)
    end
  end

  table_sort(list, function(a, b)
    if a.isBoss ~= b.isBoss then return a.isBoss end
    if a.hasImportant ~= b.hasImportant then return a.hasImportant end
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  return list
end

---A dungeon's trash (no bosses) with abilities marked important in its active
---list, in MDT order, each with just those abilities.
---@param enemies table MDT dungeonEnemies for the dungeon
---@return table list { name, displayId, groups }
function Data.ImportantTrash(dungeonIndex, enemies)
  local list = {}
  if type(enemies) ~= "table" then return list end
  local common = Data.CommonSpells(enemies)
  for _, enemy in ipairs(Data.DungeonEnemies(enemies)) do
    if not enemy.isBoss then
      local groups = {}
      for _, group in ipairs(Data.SpellGroups(enemy.spells, true, common, dungeonIndex)) do
        if group.important then
          group.enemy = enemy.name
          groups[#groups + 1] = group
        end
      end
      if #groups > 0 then
        list[#list + 1] = { name = enemy.name, displayId = enemy.displayId, groups = groups }
      end
    end
  end
  return list
end

---Enemies of a dungeon that have abilities, in MDT order. MDT can list one
---enemy name several times; those are merged into one entry with all spells.
---@return table list { name, displayId, isBoss, spells = { [spellId] = MDT spell data } }
function Data.DungeonEnemies(enemies)
  local list, byName = {}, {}
  for _, enemy in ipairs(enemies or {}) do
    if enemy.name and type(enemy.spells) == "table" and next(enemy.spells) then
      local entry = byName[enemy.name]
      if not entry then
        entry = { name = enemy.name, displayId = enemy.displayId, isBoss = enemy.isBoss == true, spells = {} }
        byName[enemy.name] = entry
        list[#list + 1] = entry
      end
      for spellId, data in pairs(enemy.spells) do
        if tonumber(spellId) then entry.spells[tonumber(spellId)] = data end
      end
    end
  end
  return list
end

-- =====================================================================
-- Sharing lists as text: "!NPI1!<dungeonIndex>!<name>!<spellId>,<spellId>,..."
-- =====================================================================

-- The string holds the list's actual picks, not its differences from the
-- defaults, so it reads the same for players with other data add-ons.
local SHARE_PREFIX = "!NPI1!"

local function escapeName(name)
  return (name:gsub("[%%!,]", function(char) return ("%%%02X"):format(char:byte()) end))
end

local function unescapeName(text)
  return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function dungeonGroups(dungeonIndex, enemies)
  local groups = {}
  local common = Data.CommonSpells(enemies)
  for _, enemy in ipairs(Data.DungeonEnemies(enemies)) do
    for _, group in ipairs(Data.SpellGroups(enemy.spells, false, common, dungeonIndex)) do
      groups[#groups + 1] = group
    end
  end
  return groups
end

---The active list of a dungeon as a share string.
---@param enemies table MDT dungeonEnemies for the dungeon
function Data.ExportList(dungeonIndex, enemies)
  local _, active = Data.ListNames(dungeonIndex)
  local ids, seen = {}, {}
  for _, group in ipairs(dungeonGroups(dungeonIndex, enemies)) do
    if group.important then
      for _, spellId in ipairs(group.ids) do
        if not seen[spellId] then
          seen[spellId] = true
          ids[#ids + 1] = spellId
        end
      end
    end
  end
  table_sort(ids)
  return SHARE_PREFIX..dungeonIndex.."!"..escapeName(active).."!"..table_concat(ids, ",")
end

---@return number|nil dungeonIndex, string|nil name, table|nil picks spellId -> true
function Data.ParseListString(text)
  local dungeonIndex, name, ids = (text or ""):match("^%s*!NPI1!(%d+)!([^!]*)!([%d,]*)%s*$")
  if not dungeonIndex then return nil end
  local picks = {}
  for spellId in ids:gmatch("%d+") do picks[tonumber(spellId)] = true end
  return tonumber(dungeonIndex), unescapeName(name), picks
end

---Adds a shared list to its dungeon as a new, active list (renamed if the name is taken).
---@param enemies table MDT dungeonEnemies for the dungeon
---@return string|nil name
function Data.ImportList(dungeonIndex, enemies, name, picks)
  local base = name:sub(1, MAX_NAME_LENGTH - 5)
  if base:match("^%s*$") then base = "Imported" end
  local unique, n = base, 2
  while dungeonLists(dungeonIndex).lists[unique] do
    unique = base.." ("..n..")"
    n = n + 1
  end
  local created = Data.CreateList(dungeonIndex, unique)
  if not created then return nil end

  -- Groups are read after creating the list, so "important" here is the default.
  for _, group in ipairs(dungeonGroups(dungeonIndex, enemies)) do
    local wanted = false
    for _, spellId in ipairs(group.ids) do
      if picks[spellId] then
        wanted = true
        break
      end
    end
    if wanted ~= group.important then Data.SetGroupImportant(group, wanted) end
  end
  return created
end
