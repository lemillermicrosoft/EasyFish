# EasyFish Forever port plan

## Completed in 0.1.1-alpha

- [x] Preserve original EasyFish git history on a dedicated port branch/worktree.
- [x] Audit original interaction model, repository license state, GitHub release behavior, and CurseForge metadata.
- [x] Create distinct `EasyFish_Forever` product metadata, SavedVariables, slash commands, binding header, and package root.
- [x] Port the equip → lure → cast state machine with one hardware click per protected action.
- [x] Remove unproven `GLOBAL_MOUSE_DOWN`, tooltip/mouseover, plain-BUTTON2 late binding, and insecure `PreClick` attribute mutation.
- [x] Add secret-value guards and out-of-combat attribute/binding preparation.
- [x] Leave bobber clicking/loot and bite recognition native/manual.
- [x] Add Esc > Options settings, startup guidance, three appearances, and opt-in legacy import.
- [x] Add Lua 5.1 parsing/static policy checks and deterministic package validation.
- [x] Build local installable candidate.

## Client validation gate

- [ ] Run every probe in `API_FINDINGS.md` on Interface 16001.
- [ ] Verify no blocked-action popup and no addon entry in `Logs/taint.log`.
- [ ] Verify localized Fishing spell lookup and fishing-pole subclass.
- [ ] Verify each lure on the actual Forever content set; replace names with verified item IDs if needed.
- [ ] Confirm exact Forever install client folder and CurseForge game-version ID.

## Publication gate

- [ ] Lee chooses a license/distribution statement (original repository has none).
- [ ] Lee approves a separate GitHub repository.
- [ ] Lee creates/approves a separate CurseForge project and supplies its project ID.
- [ ] Replace beta candidate metadata only after in-game validation.

## Explicit non-goals

- No gameplay without a physical user event.
- No automatic bite detection, bobber targeting, clicking, or looting.
- No bypass of protected calls, combat lockdown, secret values, or taint controls.
- No reuse of original EasyFish CurseForge project 1629924 for the Forever product.
