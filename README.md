# Mythic Dungeon Tools - Next Pull Info

A companion for **[Next Pull Tracker](https://www.curseforge.com/wow/addons/mythicdungeontools-nextpulltracker)**: a panel beside its beacon showing the enemies of your next MDT pull and the abilities that matter.

## Features

- **Next pull panel**: the enemies in your next pull and the abilities to watch for. Hover an ability for its tooltip, notes and counters, or share it with your party.
- **Trash overview**: before a Mythic key starts, a window lists the dungeon's trash with important abilities. Closes when the key starts.
- **Important lists**: tick which abilities matter, keep several lists per dungeon (like MDT routes), and share them as import/export strings.
- **Follows the beacon**: shows, hides, moves and scales with Next Pull Tracker. Attach it right, left, above or below.

## Requirements

- [Mythic Dungeon Tools](https://www.curseforge.com/wow/addons/mythic-dungeon-tools)
- [Mythic Dungeon Tools - Next Pull Tracker](https://www.curseforge.com/wow/addons/mythicdungeontools-nextpulltracker)

## Usage

Options: Esc → Options → AddOns → **MDT Next Pull Info**, or `/npi`.

| Command | Does |
|---|---|
| `/npi` | Open the options |
| `/npi overview` | Show or hide the trash overview |
| `/npi toggle` | Turn the panel on or off |
| `/npi mode important\|all` | Important abilities only (default), or everything |
| `/npi side right\|left\|top\|bottom` | Where the panel attaches |
| `/npi rows 1-8` | Maximum enemies shown (default 4) |
| `/npi help` | List commands |

To try it without a key: open MDT on a route, then `/npt start` and `/npt skip <N>`.

## Data

- **Enemies and abilities** come from MDT at runtime, so every dungeon MDT supports works.
- **Tags, notes and default important picks** for Midnight Seasons 1 and 2 come from Tactyks' sheets (`Data/Tactyks.lua`). Other dungeons use MDT's spell flags and the draft list in `Data/Important.lua`.
- **Season grouping** on the options page comes from `Data/Seasons.lua`; add new seasons at the top.
- Spells shared by most of a dungeon's enemies (like Xal'atath's Gift) are hidden.
- Other add-ons can supply their own data with `MDT_NPI:RegisterAbilityData({ name, dungeons = { [mdtDungeonIndex] = { { spellId, tags, note, important, boss }, ... } } })`. `boss` is the name of the boss whose encounter the ability belongs to.

## Development

Requires Node.js 18+:

```bash
cd tools
npm install
npm run check    # syntax-check all Lua files
npm run tactyks  # refresh Data/Tactyks.lua from Tactyks' sheets (tabs are mapped in SHEETS)
npm run seed     # regenerate the Data/Important.lua draft from MDT's flags
```

## Credits

- Ability data by **Tactyks**, from his M+ Ability Tracking Sheets ([Season 2](https://docs.google.com/spreadsheets/d/1gI8-pZVc5LluzupXtsuNOT6Q7LMTu-rD3v2IJhewakY), [Season 1](https://docs.google.com/spreadsheets/d/11pOj8w823fjBJqnOWTCA9vwL8_TVJF-kWFCK6WGJ7Jk)), used with permission. [YouTube](https://www.youtube.com/@Tactyks) · [Twitch](https://twitch.tv/tactyks) · [Patreon](https://patreon.com/tactyks)
- Built on [Mythic Dungeon Tools](https://github.com/Nnoggie/MythicDungeonTools) and [Next Pull Tracker](https://www.curseforge.com/wow/addons/mythicdungeontools-nextpulltracker).

## License

Code: MIT, see [LICENSE](LICENSE). `Data/Tactyks.lua` is Tactyks' data, included with permission and not covered by the MIT license.
