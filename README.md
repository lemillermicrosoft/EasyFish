# EasyFish Forever

A separate, conservative port of EasyFish for **World of Warcraft: Forever (Interface 16001)**.

EasyFish Forever prepares one fishing step at a time:

1. Equip a fishing pole from bags.
2. Apply the highest-priority available lure.
3. Cast Fishing.

Every step requires its own physical click. Bobber interaction and loot remain completely native.

> Initial public alpha for Interface 16001. The secure equip, lure, cast, visible-button, and key-binding paths have been smoke-tested on the WoW Forever beta client; see [API_FINDINGS.md](API_FINDINGS.md).

## Install

Extract the package so this exact folder exists:

`World of Warcraft\_classic_beta_\Interface\AddOns\EasyFish_Forever\`

The folder name may change when WoW Forever leaves beta; the required final portion remains `Interface\AddOns\EasyFish_Forever\`.

At character login, open **Esc > Options > AddOns > EasyFish Forever**. Choose a quick modifier binding, or use **Esc > Options > Key Bindings > EasyFish Forever**.

The default quick binding is `NONE`. Recommended: `ALT-BUTTON2`. Plain double-right-click is intentionally not available because its old late-binding technique has not been proven safe on the restricted Interface 16001 client.

## Appearance

The on-screen action button shows the currently prepared step. Options include:

- `native` — Blizzard quick-slot appearance (default)
- `original` — EasyFish blue styling
- `custom` — purple custom styling

The button can be hidden after assigning a binding.

## Commands

- `/eff` or `/eff options` — open settings
- `/eff status` — report prepared action, binding, combat state, and version
- `/eff refresh` — refresh the prepared action out of combat
- `/eff bind alt-f|alt-right|shift-right|off` — set a safe quick override
- `/eff import` — opt-in copy of the original addon's lure order
- `/eff debug` — toggle secure-click diagnostics
- `/eff help` — command summary

Forever uses `EasyFishForeverDB` and does not modify `EasyFishDB`. Its slash commands are distinct from `/ef` and `/easyfish`.

## Safety boundary

EasyFish Forever does not:

- auto-click or auto-loot a bobber;
- detect bites from sound;
- inspect mouseover/cursor targets to choose protected actions;
- call protected cast/equip/use APIs without a hardware event;
- change secure attributes or bindings in combat;
- use unmodified right-click.

See [API_FINDINGS.md](API_FINDINGS.md) for the full feasibility audit and exact smoke tests.

## Build and test

Requires Node.js:

```text
npm install
npm test
npm run package
```

The deterministic candidate is written to `dist/EasyFish_Forever-v0.1.1-alpha.zip`; the ZIP root is `EasyFish_Forever/`.

## Separate Forever product

EasyFish Forever is published separately from EasyFish TBC because it has a different addon folder, TOC, SavedVariables, slash commands, security model, supported client, and release validation gate. The original repository and history remain the provenance and optional settings-import source.

The source is publicly available, but no open-source license is currently granted. All rights are reserved unless the owner later publishes explicit license terms.
