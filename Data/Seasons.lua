-- Mythic+ seasons for grouping dungeons in the options, newest first.
--
-- Mirrors MDT's own dungeon selector (MDT.seasonList / MDT.dungeonSelectionToIndex
-- in MythicDungeonTools/Modules/DungeonSelect.lua). MDT keeps that list private
-- and its public API has no getter, so it is copied here: when MDT adds a
-- season, add it at the top. Numbers are MDT dungeon indexes; dungeons MDT has
-- that are in no season are listed under "Other".
local _, NPI = ...

-- Season-wide effects MDT lists as enemy spells (seasonal affixes and the
-- like), always hidden. The addon also hides spells shared by most of a
-- dungeon's enemies, but these can sit under that threshold (Xal'atath's Gift
-- is on 17 of Murder Row's 41 enemies). Update together with the seasons.
NPI.SeasonWideSpells = {
  [1221063] = true, -- Xal'atath's Gift
}

NPI.Seasons = {
  { name = "Midnight Season 2", dungeons = { 160, 161, 162, 163, 164, 42, 20, 17 } },
  { name = "Midnight Season 1", dungeons = { 45, 11, 150, 151, 152, 153, 154, 155 } },
}
