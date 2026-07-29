# Changelog

## Unreleased

- **fix:** Rebuild the Alt + double-right-click flow on a `SecureActionButton` with an override binding. v0.3.0's `WorldFrame:HookScript("OnMouseDown")` approach did not count as a hardware event, so the protected `UseItemByName` / `CastSpellByName` calls silently failed in-game. (#4)
- **feat:** State-machine progression per click: equip fishing pole from bags → apply top-priority lure → cast Fishing. One protected action per click, gated by an empty-world / no-mouseover / no-UI-focus check in `PreClick`.
- `/ef test` now reports the next protected action instead of just bait selection.
- `/ef debug` and `/ef status` help diagnose binding issues live.

## v0.2.0 - 2026-07-28

- **feat:** Double right-click in empty world with fishing pole equipped applies your top preferred bait automatically. (#2)
- `/ef list` shows preferred bait order + current bag counts.
- `/ef prefer <name>` moves a bait to the top of the priority list.
- `/ef reset` restores default TBC bait order.
- `/ef test` dry-runs bait selection without applying.
- Silent no-op when pole isn't equipped, lure is already active, or no bait in bags (with a friendly "no bait" message).

## v0.1.0 - 2026-07-28

- Initial scaffold. Loads in-game, registers `/easyfish` (`/ef`) slash command.
- Core "double right-click to apply bait" feature not yet implemented.
