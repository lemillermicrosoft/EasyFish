# Interface 16001 API and taint feasibility audit

Status: **code-complete candidate; exact Forever client behavior still requires the probes below.** The repository had no Interface 16001 client dump or executable test client, so uncertain behavior is disabled rather than guessed.

## Baseline inspected

The TBC EasyFish 0.5.0 implementation uses an invisible `SecureActionButtonTemplate`, insecure `PreClick` mutation of `type`/`item`/`macrotext`/`spell`, `GLOBAL_MOUSE_DOWN`, tooltip text to identify a bobber, and a one-click `SetOverrideBindingClick` late-bind for plain double-right-click. It scans bags, equips a pole, applies a lure with `/use <lure>\n/use 16`, then casts Fishing. Its releases are manually tagged GitHub releases containing `EasyFish-vX.zip`; `.curseforge.json` points to CurseForge project 1629924. The repository declares **no license** (`licenseInfo: null`, no LICENSE/COPYING in history), so redistribution/relicensing terms must be chosen by the owner before a public separate-project release.

## Decision matrix

| Area | Forever decision | Reason |
|---|---|---|
| Plain double-right late binding | **Not ported** | Dynamic `GLOBAL_MOUSE_DOWN` → `SetOverrideBindingClick` on the same mouse event depends on timing and restricted execution behavior that is not proven for Interface 16001. It also risks consuming native camera/bobber input. |
| Modifier/key binding | **Supported** | A static secure click binding (`ALT-F`, `ALT-BUTTON2`, or `SHIFT-BUTTON2`) is explicit and each action is initiated by a hardware event. Native WoW Key Bindings can bind the same secure button. |
| Fishing cast | **Supported, one click** | Secure button `type="spell"`; spell name/ID is prepared out of combat. No direct `CastSpellByName` call. |
| Pole equip | **Supported, one click** | Secure button `type="item"`; bag inventory is scanned outside combat and the item attribute is prepared before the click. |
| Lure application | **Supported, one click** | Secure macro `/use <lure>` then `/use 16`; this targets the player's own main hand and requires a hardware click. It is never chained with equip/cast. |
| Bobber interaction / loot | **Native only** | The player right-clicks the bobber. The addon does not click, target, loot, or bind over unmodified BUTTON2. |
| Mouseover / cursor APIs | **Not used** | No `UnitExists("mouseover")`, `GetMouseFocus`, tooltip scraping, cursor position, or world-frame hook. Cursor-derived restricted/secret values do not drive protected actions. |
| Sound/bite detection | **Not used** | There is no reliable permitted API that identifies a specific player's bite and authorizes interaction. Sound events are not treated as permission to loot. |
| Secure button | **Supported conservatively** | Protected attributes are updated only outside combat in event handlers. `PreClick` is not used to mutate attributes. `PostClick` only schedules state refreshes. |
| Secret values | **Fail closed** | API results are called with `pcall`; values reported by `issecretvalue` are discarded. A secret/unknown inventory result cannot become a macro, item, or spell attribute. |
| Combat | **No changes in combat** | Attribute and override-binding refresh is deferred until `PLAYER_REGEN_ENABLED`. The current prepared action is labelled locked; no protected API is called directly. |
| Equipment events/caches | **Event refreshed** | `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, and player `UNIT_INVENTORY_CHANGED` prepare the next action. Item cache misses fail closed until another refresh. |

## Why behavior changed

The old state machine was retained, but its decision point moved from `PreClick` to ordinary out-of-combat event refreshes. This avoids relying on whether insecure `PreClick` code may mutate protected attributes on this branch. A click can therefore only execute the action already shown under the button. Inventory changes trigger a refresh, and two delayed refreshes follow a click.

The original plain double-right gesture cannot be claimed reliable without client evidence. Forever defaults to no quick override; the user may select a modifier or use WoW's Key Bindings panel. This is less magical, but keeps native right-click, camera movement, and bobber looting intact.

## Exact client probes

Enable Lua errors (`/console scriptErrors 1`), reload, and run these in a fresh character session:

1. `/eff status` — must report Interface 16001 and a prepared action without Lua errors.
2. Esc > Options > AddOns > EasyFish Forever — panel must open; cycle all three appearances.
3. Esc > Options > Key Bindings > EasyFish Forever — bind **Advance prepared fishing action** to a spare key; verify one press performs exactly one shown step.
4. Put a fishing pole in a bag, leave main hand non-pole, press once — only the pole equips. Wait for the label to change.
5. With a supported lure in bags and an unlured pole equipped, press once — only the lure targeting/application occurs. Confirm a second protected action does not fire.
6. After lure application completes, press once — Fishing casts.
7. Right-click the bobber after a bite — native loot works; camera turn and left+right run remain native.
8. Enter combat, change bags/equipment if possible, and click — no blocked-action/taint popup; label may say `Locked in combat`. Leave combat and confirm it refreshes.
9. `/eff bind alt-right`, reload, and test Alt+right. Then `/eff bind off`; verify native right-click behavior remains and the override is gone.
10. Enable original EasyFish too, `/reload`, then `/eff import` — only `EasyFishForeverDB` changes; original settings/slash commands remain intact.
11. Non-English client probe: ensure the pole is recognized by numeric class/subclass and Fishing resolves from spell ID. Lure defaults are English names; import or a future item-ID table may be needed if name lookup is not locale-neutral on Forever.
12. Taint log probe: `/console taintLog 2`, `/reload`, execute steps 3–9, log out, and inspect `Logs/taint.log` for `EasyFish_Forever`. Any secure-variable taint blocks release.

## Release blockers

- Complete the probes on an actual Interface 16001 build.
- Confirm CurseForge's exact game-version selector/ID for Forever; `1.16.1` is only candidate metadata.
- Choose a license or explicit distribution terms.
- Approve creation of a separate GitHub repository and CurseForge project before publishing.
