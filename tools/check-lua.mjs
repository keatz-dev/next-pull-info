// Syntax-checks every addon .lua file with fengari (a Lua VM in JS), since
// the dev machine has no native Lua. fengari is Lua 5.3; WoW is 5.1, so this
// catches syntax errors but not 5.1-vs-5.3 API differences.
//
// Usage (from the tools/ folder):  npm install && npm run check

import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import fengari from "fengari";

const { lua, lauxlib, to_luastring } = fengari;
const addonRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

function luaFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    if (name === "node_modules" || name.startsWith(".")) return [];
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return luaFiles(path);
    return name.endsWith(".lua") ? [path] : [];
  });
}

let failed = 0;
for (const file of luaFiles(addonRoot)) {
  const L = lauxlib.luaL_newstate();
  const status = lauxlib.luaL_loadbuffer(L, readFileSync(file), null, to_luastring("@" + relative(addonRoot, file)));
  if (status !== lua.LUA_OK) {
    failed++;
    console.error(lua.lua_tojsstring(L, -1));
  }
}
console.log(failed ? `${failed} file(s) failed` : "All Lua files parse cleanly");
process.exit(failed ? 1 : 0);
