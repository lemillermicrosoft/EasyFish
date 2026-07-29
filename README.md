# EasyFish

A tiny quality-of-life addon for fishing in **World of Warcraft: TBC Classic (2.5.6)**.

**Concept:** hold `Alt` and double right-click anywhere in the empty game world, and EasyFish walks you through equipping a fishing pole, applying your preferred lure, and starting to fish — one action per double-click.

## Why the double-click and modifier

WoW's protected action APIs (`EquipItemByName`, `UseItemByName`, `CastSpellByName`) only fire when driven by a real hardware click on a secure action button. A plain `WorldFrame` mouse hook doesn't count — that's why the v0.3.0 flow silently failed in-game. EasyFish now uses a `SecureActionButton` bound to `Alt`+right-click. The `Alt` modifier keeps it out of the way of the default right-click camera drag, and the double-click gesture makes it deliberate.

Because a single hardware click can only perform one protected action, the flow spans multiple presses:

1. Alt + double-right-click empty world → equip a fishing pole from bags (if none is equipped).
2. Alt + double-right-click empty world → apply the top-priority available lure (if the pole has no lure buff).
3. Alt + double-right-click empty world → cast Fishing.

If you have no matching lure in bags, step 2 is skipped and step 3 fires directly.

## Install

1. Copy the `EasyFish` folder into `World of Warcraft\_classic_\Interface\AddOns\`.
2. Restart the client or `/reload`.

## Commands

- `/easyfish` or `/ef` — show help.
- `/ef list` — show lure priority and current bag counts.
- `/ef prefer <name>` — move a lure to the top of the priority list.
- `/ef reset` — restore default TBC lure priority.
- `/ef test` — report which action the next click would fire, without arming it.
- `/ef debug` — toggle verbose right-click logging.
- `/ef status` — show the resolved input binding and secure-button state.

## Default lure priority

Bright Baubles → Aquadynamic Fish Attractor → Aquadynamic Fish Lens → Nightcrawlers → Shiny Bauble.

## Requested by

toast06961 via Discord DM to the OpenClaw bot.

## Repo

<https://github.com/lemillermicrosoft/EasyFish>
