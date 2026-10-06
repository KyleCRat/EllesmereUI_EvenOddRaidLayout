# Changelog

## [12.1.5-2] - 2026-10-06

- Updated for WoW 12.1.5.

## [12.1.0-1] - 2026-09-21

- Initial release for Retail 12.1.0 and EllesmereUI Raid Frames 9.2.2.
- Display odd raid groups together, followed by even groups. If the highest
  displayed group is odd, place it last: groups 1-5 display as `1, 3, 2, 4, 5`.
- Use EUI's growth, spacing, visible-group, and raid-size settings. Requires
  Merge Groups off.
- Apply the same group order to raid previews and keep attached Friendly Boss
  Frames and Extra Frames aligned with the first or last displayed group.
- Defer protected layout changes until combat ends. Enable or disable the
  companion through WoW's addon list; no additional settings or saved data.
