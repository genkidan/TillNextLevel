# Changelog

## 0.1.8

- Use the current character's class color for the XP fill, with a blue fallback if the client does not provide class color data. Quest forecasts retain gold and bronze.

## 0.1.7

- Display ongoing quest XP on an additional line below completed quest XP.
- Redesigned the interface as a compact 520 × 94 panel: blue/gold bar, level and XP inside, percentage at the right, time/session above, and completed quest XP and XP/hour below.
- Retained localized labels, quest forecasts, tooltip details, dragging, and saved preferences. Completed quests use gold; ongoing quests use bronze.

## 0.1.6

- Added a gray track across the full width of the bar to show the remaining space after current XP and quest forecasts.

## 0.1.5

- Added automatic localization based on the game client: French, English, German, Spanish (Europe and Latin America), Italian, Brazilian Portuguese, Russian, Korean, and Simplified/Traditional Chinese.
- Translated labels, tooltips, and help text; number separators match the selected language.
- `/tnl scale` also accepts a decimal comma.

## 0.1.4

- Added remaining XP to the next level, as a value and percentage, beside current progress above the bar.

## 0.1.3

- Positioned the tooltip below the bar with a 14-pixel gap to keep information visible.

## 0.1.2

- Made the background transparent by removing the panel background, dark track, and top accent; no frame or border.
- Increased the bar width to 1000, with XP/hour, time to the next level, completed quests, and quests in progress on one line.

## 0.1.1

- Increased the frame size to 640 × 132, with a thicker XP bar and larger text.
- Added direct dragging without holding Shift; position locking remains available through `/tnl lock`.

## 0.1.0

- Initial release for WoW Forever: XP bar, average XP per hour, time to the next level, and quest forecasts.
- Added dragging, scaling, position locking, and per-character preferences.
