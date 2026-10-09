# Till Next Level

**Version: 0.1.8**

Standalone addon for **WoW Forever 1.60.1 (Interface 16001)**, inspired by Luxthos XP bars. No WeakAuras dependency.

The language is selected automatically based on your game client: French, English (US/GB), German, Spanish (ES/MX), Italian, Brazilian Portuguese, Russian, Korean, and Simplified/Traditional Chinese. Quest names and fonts come from the game. `/tnl` commands are the same in every language; numbers and durations are localized. Unsupported languages fall back to English.

- Current XP, required XP, and level progress percentage.
- XP per hour and estimated time to the next level.
- Session duration above the bar, with completed and ongoing quest XP totals below.
- Bar forecast: character class color = current XP, gold = completed quests ready to turn in, bronze = quests in progress, dark gray = remaining space after these forecasts.
- Hover for reward details, rested XP, and estimated time after turning in completed quests.
- Position, scale, and visibility saved per character.

## Usage

Install the `TillNextLevel` folder in `Interface/AddOns`, then restart the game or use `/reload` if the addon was already detected.

**Click and drag with the left mouse button** to move the bar, without holding any additional key. If the position is locked, use `/tnl unlock`. The compact frame measures 520 × 94, with a 28-pixel-high XP bar. Time to the next level and session duration appear above; level, current/required XP, and progress percentage appear inside the bar. Completed quest XP and XP/hour appear below, with ongoing quest XP on an additional line. The panel background is transparent, with class-colored XP and gold/bronze quest forecasts and a dark track. Hover for ongoing quest totals, remaining/rested XP, and quest details. Use `/tnl scale` to adjust the size.

| Command | Action |
| --- | --- |
| `/tnl` | Show available commands |
| `/tnl show` / `/tnl hide` | Show / hide |
| `/tnl lock` / `/tnl unlock` | Lock / unlock the position |
| `/tnl center` | Move the bar below the center of the screen |
| `/tnl scale 1.2` | Set the scale between 0.5 and 2 |
| `/tnl reset` | Restart session tracking |

## Calculations and limitations

XP per hour is the average since login, the last `/reload`, or `/tnl reset`, including breaks. Level transitions are taken into account. Skipping multiple levels resets tracking because the XP requirements for the intermediate levels are unknown.

Rewards are read using `GetQuestLogRewardXP(questID)` when the client provides this function. Unavailable rewards are shown as `?`, and the total is marked as partial. No reward amounts are invented. Failed quests and hidden entries are excluded. The forecast does not include XP from killing enemies to complete a quest or any bonuses absent from the reward provided by the client. Visual forecasts stop at the end of the level; reward totals remain complete.

The addon does not change the selected quest in the quest log. Other Classic variants are outside the scope of this initial release.

## Verification

`tests/model.lua`, `tests/localization.lua`, and `tests/runtime.lua` check calculations, translations, and events using simulated APIs. The runtime test can be run for each language, for example `tests/runtime.lua deDE`. In-game validation is still needed to confirm the appearance and availability of quest rewards on the Forever beta.

## License

Copyright (C) 2026 G3nkidan.

Till Next Level is licensed under the GNU General Public License, version 3 only (GPL-3.0-only). You may redistribute and modify it under the terms of this license. It is distributed without any warranty. See [LICENSE](LICENSE) for the full license text.
