# Changelog

## Unreleased

- **change:** Make `Alt+right-click` the default because it preserves bobber looting and works with click-to-move.
- **change:** Drop plain `right` / `double-right` binding modes. Binding `BUTTON2` hijacked WoW's native right-click, which broke bobber looting, camera turn, and left+right run-forward. Use `alt-double-right` (default), `alt-double-f`, or `shift-double-right` instead. Existing saves are migrated to `alt-double-right`.
- **fix:** Apply lures with a secure `/use <lure>` + `/use 16` macro, because TBC leaves `target-item` actions on the targeting cursor.
- **fix:** Remove `GetMouseFocus()`, which is unavailable in this Classic client and aborted input handling whenever the cursor was not over a unit.
- **fix:** Replace runtime override bindings with a static `Bindings.xml` secure click command and add `/ef bind` for existing character profiles.
- **fix:** Add `Alt+F` as the reliable input because Classic consumes `BUTTON2` over empty 3D terrain before the addon override receives it.
- **fix:** Register secure clicks for both input phases and explicitly execute bindings on key-up, independent of the client's action-button setting.
- **fix:** Rebuild the Alt + double-right-click flow on a `SecureActionButton` with an override binding. v0.3.0's `WorldFrame:HookScript("OnMouseDown")` approach did not count as a hardware event, so the protected `UseItemByName` / `CastSpellByName` calls silently failed in-game. (#4)
- **feat:** State-machine progression per click: equip fishing pole from bags → apply top-priority lure → cast Fishing. One protected action per click, gated by no-mouseover and no-spell-targeting checks in `PreClick`.
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
