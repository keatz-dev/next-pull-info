// Writes a starting Data/Important.lua from MDT's own spell flags: every spell
// MDT marks as interruptible or dispellable (magic, curse, poison, disease,
// enrage). It is a mechanical draft to finalise by hand. Spells shared by most
// of a dungeon's enemies (season-wide effects) are skipped, same as in the addon.
//
// Usage (from the tools/ folder):  npm install && npm run seed

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import fengari from "fengari";

const { lua, lauxlib, lualib, to_luastring } = fengari;
const addonRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const mdtRoot = join(addonRoot, "..", "MythicDungeonTools");
const outFile = join(addonRoot, "Data", "Important.lua");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(chunk, name, ...globals) {
  if (lauxlib.luaL_loadbuffer(L, chunk, null, to_luastring(name)) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
  lua.lua_pushstring(L, to_luastring("addon"));
  for (const g of globals) lua.lua_getglobal(L, to_luastring(g));
  if (lua.lua_pcall(L, 1 + globals.length, 1, 0) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
  const result = lua.lua_isstring(L, -1) ? lua.lua_tojsstring(L, -1) : null;
  lua.lua_pop(L, 1);
  return result;
}

// Minimal stand-ins for what MDT's dungeon files and our Data.lua touch.
run(to_luastring(`
  NPI = { DefaultImportant = {} }
  C_Spell = { GetSpellName = function() return nil end }
  MDT = setmetatable({ AddonName = "MythicDungeonTools", L = setmetatable({}, { __index = function(_, k) return k end }) },
    { __index = function(t, k) local v = {}; rawset(t, k, v); return v end })
  function MDT:RegisterDungeonLocation() end
`), "=setup");

// The same dungeon files NPT loads (MDT's Midnight list).
const xml = readFileSync(join(mdtRoot, "Midnight", "load_midnight.xml"), "utf8");
for (const [, file] of xml.matchAll(/file='([^']+\.lua)'/g)) {
  run(readFileSync(join(mdtRoot, "Midnight", file)), "@" + file, "MDT");
}
run(readFileSync(join(addonRoot, "Modules", "Data.lua")), "@Data.lua", "NPI");

const text = run(to_luastring(`
  local Data = NPI.Data
  local FLAGS = {
    { "interruptible", "Interrupt" }, { "magic", "Magic" }, { "curse", "Curse" },
    { "poison", "Poison" }, { "disease", "Disease" }, { "enrage", "Enrage" },
  }

  local dungeons = {}
  for index in pairs(MDT.dungeonEnemies) do dungeons[#dungeons + 1] = index end
  table.sort(dungeons, function(a, b)
    return (MDT.mapInfo[a].englishName or "") < (MDT.mapInfo[b].englishName or "")
  end)

  local lines = {
    "-- Abilities that important mode shows by default, keyed by spell ID.",
    "-- Only used for dungeons Data/Tactyks.lua doesn't cover; where it does, its",
    "-- important picks are the defaults instead.",
    "--",
    "-- Players keep their own per-dungeon lists on the addon's \\"Important",
    "-- abilities\\" options page; each list stores only where it differs from this.",
    "--",
    "-- Seeded by tools/seed-important.mjs from MDT's spell flags (interruptible",
    "-- or dispellable).",
    "local _, NPI = ...",
    "",
    "NPI.DefaultImportant = {",
  }
  local seen, total = {}, 0
  for _, index in ipairs(dungeons) do
    local enemies = MDT.dungeonEnemies[index]
    local common = Data.CommonSpells(enemies)
    local block = {}
    for _, enemy in ipairs(Data.DungeonEnemies(enemies)) do
      local ids = {}
      for id in pairs(enemy.spells) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do
        local data, why = enemy.spells[id], {}
        for _, flag in ipairs(FLAGS) do
          if type(data) == "table" and data[flag[1]] then why[#why + 1] = flag[2] end
        end
        if #why > 0 and not common[id] and not seen[id] then
          seen[id] = true
          total = total + 1
          block[#block + 1] = string.format("  [%d] = true, -- %s: %s", id, enemy.name, table.concat(why, ", "))
        end
      end
    end
    if #block > 0 then
      lines[#lines + 1] = "  -- " .. MDT.mapInfo[index].englishName
      for _, line in ipairs(block) do lines[#lines + 1] = line end
    end
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\\n") .. "\\n", total
`), "=seed");

writeFileSync(outFile, text, "utf8");
const count = (text.match(/= true,/g) || []).length;
console.log(`Wrote ${outFile} with ${count} abilities`);
