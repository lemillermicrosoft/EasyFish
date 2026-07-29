# Changelog

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
