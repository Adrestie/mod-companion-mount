# mod-companion-mount

**WORK IN PROGRESS**

An AzerothCore module (WoW 3.3.5a): your mount becomes a companion that walks beside you, fights, loots, levels up and learns talents of its own.

## Key features

- A guardian that fights at the player's side, for every class, and can live alongside any pet; right-click it to ride it.
- Orders and stances like a pet: attack, follow, stay; passive, defensive, aggressive.
- Loots the corpses around you for you, under the core's rules.
- A level and experience per mount, and 50-slot saddlebags shared by all of a character's mounts.
- Three talent trees (Fury, Bulwark, Benevolence), with a key spell per kind of mount and an ultimate.
- You decide how it fights with your own rules, "target + condition → action" (for instance: an ally below 50% health → heal it), checked from top to bottom; up to 10 rules, saved as presets.
- A companion panel, an order bar and a portrait, with no client patch.

## Dependencies

| Dependency | For |
|---|---|
| [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (WotLK 3.3.5a) | the server |
| [mod-ale](https://github.com/azerothcore/mod-ale) | runs the interface on the server |
| [AIO](https://github.com/Rochet2/AIO) | the interface: `AIO_Server` in `lua_scripts`, and the `AIO_Client` addon on every client |
| [mod-forever-ui](https://github.com/Adrestie/mod-forever-ui) | optional: its theme, and a micro button on its bar |
| [mod-aoe-loot](https://github.com/Adrestie/mod-aoe-loot) | optional: the mount loots every corpse around, as you do |

## How to install

1. Download `installer.exe` from the [WoW-mods-installer releases](https://github.com/Adrestie/WoW-mods-installer/releases).
2. Stop the worldserver.
3. Run `installer.exe`, give it this folder and the folders it asks for, click **Check**, then **Install**.
4. Rebuild the worldserver. On its next start, the core applies the module's SQL.

## How to update

Same steps with the new version's folder, choosing **Update** instead of **Install**. Players' mounts, saddlebags, talents and gambits, and your `mod-companion-mount.conf` settings, are kept. Rebuild the worldserver.

## How to uninstall

Same steps, choosing **Remove**. Everything goes, database included: empty the saddlebags first, the items left in them are lost. Rebuild the worldserver.

## Configuration

`mod-companion-mount.conf` sets:

- the module on or off, and whether the mount may come out in dungeons and battlegrounds;
- instant mounting, revive delay, leash and click distances;
- the mount's health, damage, healing and share of the owner's attack power;
- levels and experience;
- saddlebag slots;
- talent points per level and per tier, one tree or all;
- energy and the cost of each kind of spell;
- gambit slots.

## Commands

| Command | |
|---|---|
| `/companion` | opens the panel (also `/compagnon`); `gambits`, `talents`, `bag` open each part, `bar` hides the order bar |
| `/companion preset <name>` | loads a gambit preset |
| `.companion summon [spell]` | brings the mount out |
| `.companion dismiss` | sends it back |
| `.companion info` | its state |
| `.companion attack \| follow \| stay` | orders |
| `.companion passive \| defensive \| aggressive` | stances |
| `.companion rename <name>` | renames it |
| `.companion bag` | the saddlebags |
| `.companion talent` | the talents |
| `.companion gambit` | the gambits |
| `.companion cast <spell>` | casts one of its spells |
| `.companion setlevel <n>, debug` | game master: tests |
| `.companion reload` | administrator: reloads talents and key spells |
