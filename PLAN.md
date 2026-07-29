# EasyFish Plan

## Vision

A tiny quality-of-life addon for fishing in TBC Classic (2.5.6). When holding a fishing pole, double right-clicking anywhere in the empty game world (not on a fishing bobber, not on an NPC) automatically applies your currently-preferred bait/lure to the pole via `UseItemByName` or the equivalent Enchant Item Temporary spell.

## Scope (MVP)

1. Detect when the player has a fishing pole equipped.
2. Intercept double right-click in the empty world (not on anything targetable).
3. Determine "preferred bait" — priority list from SavedVariables, with defaults for common TBC lures (Bright Baubles, Aquadynamic Fish Attractor, Nightcrawlers, etc.).
4. Apply the top available bait from the player's bags to the equipped pole.
5. Print concise feedback: what was applied, or why nothing was applied.

## Technical Tasks

- [ ] Hook `WorldFrame` mouse events or use `SetBinding`/secure action button for right-click.
- [ ] Detect double-click timing (≈300ms window).
- [ ] Filter: only fire when target is nil / mouseover is nil (empty world).
- [ ] Check equipped item in slot 16 (main hand) for fishing pole via `GetInventoryItemLink` + item subclass.
- [ ] Scan bags for bait items; maintain preference order in `EasyFishDB.preferredBait`.
- [ ] Call `UseItemByName(baitName)` then briefly show `UseContainerItem`-style feedback.
- [ ] Handle already-buffed pole (skip if lure buff already active on weapon).

## QA and validation

- Test on a warrior with fishing pole and no bait: expect "no bait in bags" message.
- Test with Bright Baubles: expect application + confirmation print.
- Test when already lured: expect skip message.
- Test with pole unequipped: expect silent no-op (don't spam).
- Test double-click threshold: single right-clicks must not trigger.

## Post-MVP ideas

- Slash command to reorder bait preferences: `/ef prefer <itemName>`.
- Auto-equip pole toggle before applying bait.
- Fishing hotspot detection (weather + zone).
- Bobber auto-loot integration.

## Deliverables

- `EasyFish.toc`
- `EasyFish.lua` (core + slash command)
- `Media/icon.png`
- `README.md`, `CHANGELOG.md`

## Requested by

toast06961 via Discord DM to the OpenClaw bot, 2026-07-28.
