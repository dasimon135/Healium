# Arena priest cockpit — design

Date: 2026-09-06. Scope: `retail/` only (Midnight 12.1). `classic/` is untouched.

## Goal

Give a Shadow / Discipline priest playing arena (Solo Shuffle, 2v2, 3v3) a
Healium frame per arena opponent carrying a row of *offensive* secure buttons
(Dispel Magic, Silence, Mind Control, dots…), with the Dispel Magic button lit
by Blizzard when the opponent carries a buff the priest can dispel. Party
frames keep the existing defensive buttons. The profile switches with the
spec, as today.

## Why this shape

Midnight's secret-value system (verified against Blizzard's "Combat Philosophy
and Addon Disarmament" article, the 12.0 / 12.1 API-change pages and Icy Veins'
summary of the relaxed restrictions) means an addon can *display* combat
state but never *know* it: auras, health, power, cooldowns and casts are
secret, and the combat log is gone. Anything that decides for the player
(rotation, "dispel now", enemy interrupt tracking) is impossible on retail.
What remains is ergonomics: secure buttons bound to arena1-3 and party units,
Aura Containers where Blizzard picks what to show, and everything outside
combat. Nothing does this for priests today.

Chosen over: a standalone addon (would rewrite what Healium already has), a
plugin depending on Healium (frame creation is file-local, would need an API
first), and a priest module in sArena Reloaded (that repo tracks Bodify's
upstream; a priest feature would diverge it for good).

## 1. Arena frames

- New frame type **Arena**, created in `Healium_CreateUnitFrames` next to
  Target and Focus: one `HealiumUnitFrameTemplate` container
  (`HealiumArenaFrame`, caption "Arena") with three children built by the
  existing `CreateCustomHeader` for units `arena1`, `arena2`, `arena3`.
  `RegisterUnitWatch` shows/hides them as the units appear at the gates and
  vanish afterwards. No arena pets, no prep-phase frame: nothing is actionable
  before the gates.
- Each header carries `isHostile = true`. That flag, not the unit token,
  drives profile selection and aura filters below.
- Inherited for free: name and health bar (already secret-safe), class colour,
  global scale (`Healium_SetScale`), Blizzard layout cache for position,
  inclusion in Frame Layouts, registration in `Healium_Frames` /
  `Healium_Units`.
- Settings: `Healium.ShowArenaFrame` (default false), a "Show Arena frame"
  checkbox in the config panel next to Target / Focus, and
  `Healium_UpdateShowArenaFrame` / `Healium_ShowHideArenaFrame` following the
  Target pattern (shown when the setting is on; the unit watch does the rest).
- Test mode: `/hlm arena test` swaps the three unit attributes to `target`,
  `focus`, `player` out of combat, so layout and buttons can be checked
  without an arena; `/hlm arena test` again, or entering an arena, restores
  the arena tokens. Refuses to run in combat.

## 2. Buttons and the hostile profile

- `Healium.HostileProfiles[1..5]`, same shape as `Healium.Profiles`
  (`SpellNames`, `SpellIcons`, `SpellTypes`, `SpellRanks`, `IDs`,
  `ButtonCount`), seeded and migrated in `InitVariables` exactly like the
  friendly set. `PartyFrameOrder` is irrelevant there and left unset.
- `Healium_GetProfileForFrame(frame)` returns the hostile profile when
  `frame.isHostile`, else `Healium_GetProfile()`. `Healium_SetButtonAttributes`
  and the slot-ID refresh in `Healium_UpdateButtonAttributes` go through it.
  Button visibility / count for a hostile frame reads the hostile
  `ButtonCount`. The secure-button mechanism itself is unchanged.
- `HealiumSpells.lua`: the PRIEST list gains the targeted hostile spells
  (Dispel Magic, Silence, Psychic Horror, Mind Control, Shadow Word: Pain,
  Shadow Word: Death, Vampiric Touch, Mind Blast, Smite, Penance, plus any
  12.1-current Discipline offensive spell confirmed by ID). Non-targeted
  spells (Psychic Scream, Mass Dispel, Dispersion) stay out. IDs are verified
  against an external source before being written, and `GetSpellSlotID`
  already ignores spells missing from the spellbook. The mechanism is class
  agnostic; only the priest list ships in this version.
- Config panel: on the Button Profiles sub-panel a "Friendly / Arena" selector
  chooses which set the existing editor edits. Named class profiles
  (`HealiumGlobal.ClassProfiles`) save and load both sets.
- Out of scope: hostile profile on Target / Focus, `[harm]/[help]` dual
  buttons.

## 3. Auras: lighting the Dispel Magic button

- Today a per-frame Aura Container declares slots filtered
  `HARMFUL|RAID_PLAYER_DISPELLABLE`, restricted to the dispel types each cure
  button handles; Blizzard drops the debuff icon on the matching button. The
  addon never reads the aura; it only learns of it through the aura button's
  `OnShow`, which fires the 3.6.0 audio warning.
- Mirror for hostile frames: `Healium_OffensiveCures` in `HealiumSpells.lua`
  maps Dispel Magic → `{ Magic }`. A hostile frame's container declares its
  slots with `HELPFUL|RAID_PLAYER_DISPELLABLE` (12.1 extended that filter to
  helpful auras on enemies dispellable / stealable by a raid member),
  restricted to the offensive-cure types. Result: the enemy buff icon lands on
  the Dispel Magic button and on the health-bar slot. Only what is already
  attached on friendly frames is attached here (the `OnShow` hook and the
  tinted border), through the same `pcall` wrappers, since aura buttons are
  forbidden objects while auras are secret.
- `Healium.EnableOffensiveDispelAudio` (default false), a checkbox under
  Debuff Warnings reusing the existing sound picker.
- No player-buff container on hostile frames. Enemy defensive cooldowns are
  left to sArena.

## 4. Combat lockdown, verification, risks

- All new protected work (header creation, button attributes, unit swap in
  test mode, container creation) sits behind `InCombatLockdown()` and defers
  through `Healium_FixNameplates`, as the rest of the addon does.
- There is no test suite. Verification is: Lua syntax check where a runtime is
  available, spell IDs checked against Wowhead, then in game:
  `/hlm arena test` out of combat (frames, buttons, tooltips, profile editor),
  a skirmish (frames appear at the gates, buttons cast, dispellable buff icon
  lands on Dispel Magic, audio plays if enabled), both in and out of combat.
- Risks: the `HELPFUL` + `RAID_PLAYER_DISPELLABLE` combination on hostile
  units is documented for 12.1 but not yet exercised by Healium; if it yields
  nothing, only the highlight is lost, buttons still work. Priest spell IDs may
  have moved in 12.1; unknown spells are skipped, not fatal.
