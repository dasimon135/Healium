# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Healium is a World of Warcraft healing UI addon (Lua + Blizzard XML). It draws its own party/raid unit frames and puts up to 15 configurable spell/item/macro buttons next to each unit. Based on FB Healbox. Upstream: https://github.com/engy99k/Healium

There is **no build system, no test suite, no linter, and no package manager**. The repo *is* the addon: it is packaged by the CurseForge packager (`.pkgmeta`, `package-as: Healium`, `manual-changelog: changelog.txt`) and installed by copying to `World of Warcraft/<flavor>/Interface/AddOns/Healium`.

### Verifying a change

Reload the game (`/reload`) and exercise the UI. In-game diagnostics:

- `/hlm` – command list; `/hlm config`, `/hlm show <frame>`, `/hlm toggle`, `/hlm reset frames`, `/hlm friends …`
- `/hlm debug` – toggles `Healium_Debug`, enabling all `Healium_DebugPrint()` output (undocumented in `printUsage()`)
- `/hlm dump` – `DevTools_Dump` of the saved `Healium` table
- `/run print((select(4, GetBuildInfo())))` – the interface number to put in a `.toc`

Changes touching secure frames or button attributes must be tested **both in and out of combat** — see "Combat lockdown" below.

## Two parallel source trees

[retail/](retail/) and [classic/](classic/) contain the same 12 filenames and the same public function names, but they are **separate, diverged codebases**. Never assume a fix in one applies to the other; port deliberately and check the actual file.

| TOC | Interface | Sources | Flavor |
|---|---|---|---|
| [Healium.toc](Healium.toc) | 120100 | `retail/` | Mainline (also `## Dependencies: Blizzard_AuraContainer`) |
| [Healium_Vanilla.toc](Healium_Vanilla.toc) | 11509 | `classic/` | Classic Era |
| [Healium_TBC.toc](Healium_TBC.toc) | 20506 | `classic/` | TBC Classic |
| [Healium_Cata.toc](Healium_Cata.toc) | 40402 | `classic/` | Cata Classic |
| [Healium_Mists.toc](Healium_Mists.toc) | 50504 | `classic/` | Mists Classic |

One `classic/` build serves four flavors; it branches at runtime on `Healium_IsClassic` / `Healium_IsClassicBCC` / `Healium_IsClassicLK` / `Healium_IsClassicCata` / `Healium_IsClassicMists` (derived from `WOW_PROJECT_ID` at the top of [classic/Healium.lua](classic/Healium.lua#L32-L37)). `classic/` also still carries `Healium_IsRetail` branches left over from when the trees were shared — they are dead on classic builds.

Feature sets differ. `retail/` has class Button Profiles, Frame Layouts, opaque healthbar backgrounds, and debuff icons; `classic/` has debuff audio (`EnableDebufAudio`) and `ShowPercentage`, which retail dropped. Adding a file to a tree means adding it to every `.toc` that loads that tree.

### Releasing

`HealiumVersion.lua` holds the single version string (`Healium_Version`), shown in chat on load and on the config panel. A release bumps that string and prepends an entry to [changelog.txt](changelog.txt) (newest first, `* Retail:` / `* Mists Classic:` prefixes). Commit messages in this repo are literally `see changelog.txt`.

## Architecture

### Entry point and event dispatch

`Healium.xml` creates a single hidden frame named `Healium` whose `OnLoad`/`OnEvent` are `Healium_OnLoad` / `Healium_OnEvent` in `Healium.lua`. `Healium_OnEvent` is one long if-chain and is the **only** central event handler; per-frame and per-button handlers live in the XML templates.

Startup order matters and is fixed:

1. `ADDON_LOADED` → `InitVariables()` (saved-variable migration: fills in `Profiles[1..5]`, and fields added in later versions such as `SpellTypes`, `IDs`, `SpellRanks`, `PartyFrameOrder`), then `Healium_InitSpells` → minimap button → config panel → slash commands → menu → `Healium_CreateUnitFrames` → the `Healium_Update*` pass.
2. `PLAYER_LOGIN` → `Healium_ShowHide*Frame()` for every frame (deliberately later than `ADDON_LOADED`, to avoid units missing right after login).
3. `PLAYER_ENTERING_WORLD` / `SPELLS_CHANGED` / `PLAYER_TALENT_UPDATE` → re-resolve spells and rebuild button attributes.

### Saved variables

- `Healium` — per character (`## SavedVariablesPerCharacter`). Seeded from the `HealiumDefaults` table at the top of `Healium.lua`; holds every option plus `Healium.Profiles`.
- `HealiumGlobal` — per account. `Friends`, and on retail `ClassProfiles[class]` (named button setups) and `FrameLayouts` (named position/visibility/scale sets).

Frame **positions** are not stored in saved variables — frames use Blizzard's layout cache via `SetUserPlaced(true)`; `Healium_ResetAllFramePositions` clears it.

### Profiles and buttons

`Healium.Profiles[specIndex]` (5 slots) is a set of **parallel arrays** indexed by button number: `SpellNames`, `SpellIcons`, `SpellTypes` (`Healium_Type_Spell` = 0 / `_Macro` = 1 / `_Item` = 2 — note `nil` also means Spell, the table was added in 2.0), `SpellRanks` (spell subtext), `IDs`, plus `ButtonCount` and `PartyFrameOrder`. `Healium_GetProfile()` selects the spec: `GetSpecialization()` on retail, `GetActiveTalentGroup()` on Mists Classic, `1` everywhere else. There is a standing TODO in `Healium.lua` to collapse these arrays into one `Spells` table.

`Profile.IDs` and `Healium_Spell.ID` are **spellbook slot indices, not global spell IDs** (`GetSpellSlotID()` scans the spellbook by localized name and rejects `FutureSpell` entries). Slots shift when spells are renamed or talents change, so `Healium_SetButtonAttributes` refreshes `button.id` even *during* combat while skipping the protected `SetAttribute` calls.

Secure action buttons are driven by name, not ID: `type` = `spell`/`macro`/`item` and `spell`/`macro`/`item` = the localized name (retail) or `name(rank)` via `Healium_MakeRankedSpellName` (classic).

### Frames

`HealiumUnitFrames.lua` builds, per frame type, a movable `HealiumUnitFrameTemplate` container plus a secure header child:

- `SecureGroupHeaderTemplate` for party / me / friends / raid groups 1-8 / role frames (`roleFilter` = `DAMAGER`, `HEALER`, `MT,TANK`), `SecureGroupPetHeaderTemplate` for pets, and a plain `RegisterUnitWatch` frame for target/focus.
- Every header gets `template = "HealiumUnitFrames_ButtonTemplate"` from `SetHeaderAttributes`; Blizzard instantiates one unit button per member.
- When the header assigns a unit, `HealiumUnitFrames_Button_OnAttributeChanged` fires and registers the frame in `Healium_Units[unit]`. That map is how `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE`, `UNIT_NAME_UPDATE` are routed to only the affected frames. `Healium_Frames` (all) and `Healium_ShownFrames` are the other global registries.
- Heal buttons hang off the unit button (`frame.buttons[1..15]`, `button.index`), created by `Healium_CreateButtonsForNameplate`.

Range checking is an `OnUpdate` on each heal button throttled to `Healium.RangeCheckPeriod` (0.2-2s).

### Combat lockdown — the main invariant

Anything protected (creating secure frames, `SetAttribute`, showing/hiding secure buttons, header attribute changes, even `SetTexture` on button icons here) is guarded by `if InCombatLockdown() then return end`. Work that could not be done is deferred by setting a flag on the frame (`fixCreateButtons`, `fixShowMana`, `AuraContainerRefreshPending`) and pushing it onto `Healium_FixNameplates`; the `PLAYER_REGEN_ENABLED` branch of `Healium_OnEvent` drains that queue and clears it. **Any new protected call must follow this pattern.**

### Auras: retail vs classic

Retail 12.1 can make aura data "secret" (`C_Secrets.ShouldAurasBeSecret()`, and `issecretvalue()` guards around names/classes throughout `retail/Healium.lua`), so indexed aura reads are unavailable — not only in combat. `retail/HealiumUnitFrames.lua` therefore delegates to Blizzard **Aura Containers** (`CustomAuraContainerTemplate`, gated by `Healium_UsesAuraContainers()` on interface ≥ 120100), declaring which spell IDs and dispel types to show and letting Blizzard pick, position and tint them. `SpecialPlayerBuffSpellIDs` and `PlayerBuffAuraAliases` exist because several spells' cast ID differs from their applied-aura ID; calls into container APIs go through `pcall` wrappers (`SafeAuraContainerCall`, `AddDispelTintTexture`).

`classic/` still reads auras directly (`C_UnitAuras.GetBuffDataByIndex` / `GetDebuffDataByIndex`, `AuraUtil.ForEachAura`) in `Healium_UpdateUnitBuffs`.

### Dispels

`HealiumSpells.lua` hardcodes, per class and race, the spell IDs offered in the button dropdown (`Healium_InitSpells`) and a `Cures` table mapping cure spell name → which debuff types it removes (some entries use a `CanCureMagicFunc` for talent-dependent cases). `Healium_UpdateCures` recomputes the four `CanCure*` flags from the *currently assigned* buttons, which drives healthbar highlighting/coloring and cure-button highlighting. Colors come from `Healium_DebuffTypeColor` in `Healium.lua`.

### Config UI

`HealiumConfigPanel.lua` builds a canvas panel via `Settings.RegisterCanvasLayoutCategory`, with `Settings.RegisterCanvasLayoutSubcategory` for the retail-only "Button Profiles" and "Frame Layouts" panels. Each control's `OnClick` writes the `Healium.*` setting and immediately calls the matching `Healium_Update*` function — settings are applied live, never on a save/apply step.

`UIDropDownMenu.lua` / `UIDropDownMenuTemplates.xml` are a **vendored copy of LibUIDropDownMenu** (globals prefixed `LIB_`/`Lib_`), byte-identical between the two trees. Treat them as third-party; don't hand-edit them.

## Conventions

- Public functions are globals prefixed `Healium_` (or `HealiumUnitFrames_` for XML script handlers); helpers are file-local. There are no modules or namespacing beyond that.
- Indentation is tabs in most files; `HealiumDefaults` uses two spaces.
- Output goes through `Healium_Print` / `Healium_Warn` / `Healium_DebugPrint` (the latter is a no-op unless `Healium_Debug`), never raw `print`.
- Reminder carried at the top of `Healium.lua`: in Lua `0` is truthy, so `not 0` is false.
- Clique support works by inserting unit frames into the global `ClickCastFrames` table (`Healium_UpdateEnableClique`).
