# EasyFish

A tiny quality-of-life addon for fishing in **World of Warcraft: TBC Classic (2.5.6)**.

**Concept:** point at the empty game world and double-press your configured binding. EasyFish walks you through equipping a fishing pole, applying your preferred lure, and starting to fish — one action per double-press.

## Why the double-click and modifier

WoW's protected action APIs (`EquipItemByName`, `UseItemByName`, `CastSpellByName`) only fire when driven by a real hardware event on a secure action button. A plain `WorldFrame` mouse hook doesn't count, and this Classic client consumes `BUTTON2` over empty 3D terrain before an addon can receive it. EasyFish therefore declares `Alt+F` through WoW's static Key Bindings system and routes it to a `SecureActionButton`.

After installing or updating, run `/ef bind` once to assign the default `Alt+right-click` binding, or use the new plain `double-right` mode which does not require a modifier. `double-right` uses a *late-bound override*: a `GLOBAL_MOUSE_DOWN` handler only registers `BUTTON2` on the secure button for the single synthetic click that fires after a valid double-tap on empty world; it is cleared immediately after via a restricted `SecureHandlerWrapScript` snippet. That means normal right-click (camera turn, bobber looting, left+right run-forward) is untouched at all other times. `double-right` is the default for new installs; existing users keep whatever mode they had.

Switch modes with `/ef binding <mode>`:

- `double-right` — plain double-right-click, late-bound override (default for new installs).
- `alt-right` / `alt-double-right` — `Alt` + right-click, single or double press.
- `alt-f` / `alt-double-f` — `Alt+F` keyboard fallback.
- `shift-right` / `shift-double-right` — `Shift` + right-click.
- `off` — disable EasyFish's input and restore displaced bindings.

You can also assign **EasyFish → Advance fishing setup** in WoW's Key Bindings UI.

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
- `/ef binding double-right` — plain double-right-click via a late-bound override (default).
- `/ef binding alt-right` — use `Alt` + right-click.
- `/ef binding alt-f` — use `Alt+F` as a fallback.
- `/ef binding shift-right` — use `Shift` + right-click.
- `/ef binding off` — disable EasyFish's input and restore displaced bindings.
- `/ef debug` — toggle verbose input logging.
- `/ef status` — show the resolved input binding and secure-button state.

## Default lure priority

Bright Baubles → Aquadynamic Fish Attractor → Aquadynamic Fish Lens → Nightcrawlers → Shiny Bauble.

## Requested by

toast06961 via Discord DM to the OpenClaw bot.

## Repo

<https://github.com/lemillermicrosoft/EasyFish>
