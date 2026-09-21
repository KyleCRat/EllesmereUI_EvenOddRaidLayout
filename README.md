# EllesmereUI Even/Odd Raid Layout

Groups EUI raid frames by odd subgroup first, then even subgroup:

`1, 3, 5, 7, 2, 4, 6, 8`

Only groups displayed by EUI take up positions. With groups 1-4 populated and
**Hide Empty Groups** enabled, the order is `1, 3, 2, 4`.

Enable the companion and turn **Merge Groups** off in EUI's raid-frame options.
Use EUI's existing **Unit Growth**, **Group Growth**, spacing, visible-group,
and raid-size settings. The companion has no separate settings or saved data.

With **Unit Growth: Right** and **Group Growth: Down**:

```text
[1.1][1.2][1.3][1.4][1.5]
[3.1][3.2][3.3][3.4][3.5]
[2.1][2.2][2.3][2.4][2.5]
[4.1][4.2][4.3][4.4][4.5]
```

With both growth directions set to **Up**, group 1 starts at the bottom;
groups 3, 2, then 4 appear above it. Members retain EUI's existing order within
each group, growing upward from `.1` to `.5`.

EUI's raid previews and raid-size previews also use the odd/even order. Friendly
Boss Frames and Extra Frames attached to the raid follow its first or last group.
Party frames and merged raid layouts retain EUI's normal behavior.

Layout changes wait until combat ends. Actual raid subgroup assignments are
unchanged. To restore numeric display order, disable the companion and reload.

Targets Retail 12.1.0 and the installed EllesmereUI Raid Frames 9.2.2. It uses
EUI's internal layout hooks, so future EUI updates may require adjustments.
The Lua passes a 5.1 syntax check. In-game validation is still needed for both
example layouts, previews, roster changes, click casting, and combat transitions.
