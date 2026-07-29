# EasyFish

A tiny quality-of-life addon for fishing in **World of Warcraft: TBC Classic (2.5.6)**.

**Concept:** point at the empty game world and double-press your configured binding. EasyFish walks you through equipping a fishing pole, applying your preferred lure, and starting to fish — one action per double-press.

## Why the double-click and modifier

WoW's protected action APIs (`EquipItemByName`, `UseItemByName`, `CastSpellByName`) only fire when driven by a real hardware event on a secure action button. A plain `WorldFrame` mouse hook doesn't count, and this Classic client consumes `BUTTON2` over empty 3D terrain before an addon can receive it. EasyFish therefore declares `Alt+F` through WoW's static Key Bindings system and routes it to a `SecureActionButton`.

After installing or updating, run `/ef bind` once to assign the default `Alt+right-click` binding. It preserves normal bobber looting and works with click-to-move. You can select another input with `/ef binding alt-f` or `/ef binding right`. Plain right-click replaces WoW's normal camera, interaction, and bobber-looting binding while enabled; switching to another mode restores it. You can also assign **EasyFish → Advance fishing setup** in WoW's Key Bindings UI.

Because a single hardware click can only perform one protected action, the flow spans multiple presses:

1. Double-press the configured binding over empty world → equip a fishing pole from bags (if none is equipped).
2. Double-press it again → apply the top-priority available lure (if the pole has no lure buff).
3. Double-press it again → cast Fishing.

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
- `/ef bind` — bind the default `Alt` + right-click input.
- `/ef binding alt-right` — use `Alt` + right-click.
- `/ef binding alt-f` — use `Alt+F` as a fallback.
- `/ef binding right` — use right-click and temporarily replace normal right-click behavior.
- `/ef binding off` — disable EasyFish's input and restore displaced bindings.
- `/ef debug` — toggle verbose input logging.
- `/ef status` — show the resolved input binding and secure-button state.

## Default lure priority

Bright Baubles → Aquadynamic Fish Attractor → Aquadynamic Fish Lens → Nightcrawlers → Shiny Bauble.

## Requested by

toast06961 via Discord DM to the OpenClaw bot.

## Repo

<https://github.com/lemillermicrosoft/EasyFish>
