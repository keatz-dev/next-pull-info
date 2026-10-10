# Changelog

## v0.1.2

- Changed: bosses now follow your important list like trash does. Untick or tick boss abilities on the Important abilities page.
- New: boss adds (like Lightwarden Ruia's Spirit Bear) are recognised.
- Changed: the Important abilities page trash order is now similar to the pull order.
- Changed: picks on bosses and their adds are saved separately from trash, so a spell both use can be ticked on one and not the other. Shared lists now export as `!NPI2!` strings; `!NPI1!` strings still import.
- Fixed: sharing an ability during a key caused an "action blocked" error, as Blizzard doesn't let add-ons send chat then. The next pull panel's button now opens the message to copy (Ctrl+C) and paste into chat; the trash overview still sends directly before the key.
- Changed: the `MDT_NPI` global now only exposes `MDT_NPI:RegisterAbilityData(...)` for other add-ons, instead of the whole add-on table.

## v0.1.1

- Fixed: searching the game's Options (e.g. "sc") could get the add-on blocked with "only available to the Blizzard UI".

## v0.1.0

Initial release.

- Next pull panel beside the Next Pull Tracker beacon: enemies with portraits and one line per ability, with tags, notes and counters in tooltips
- Trash overview window before a Mythic key starts
- Important and All modes; per-dungeon important lists with import/export
- Ability data for Midnight Seasons 1 and 2 by Tactyks, used with permission
