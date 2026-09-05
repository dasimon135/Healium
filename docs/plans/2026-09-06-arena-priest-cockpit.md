# Arena Priest Cockpit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a retail-only "Arena" Healium frame (arena1-3) whose buttons come from a separate, offensive, per-spec button profile, with Blizzard Aura Containers lighting the Dispel Magic button when an opponent carries a dispellable buff.

**Architecture:** Three watched unit buttons (`RegisterUnitWatch`) under one movable container, flagged `isHostile`. Every place that reads `Healium_GetProfile()` for a button or frame goes through `Healium_GetProfileForFrame(frame)` so hostile frames read `Healium.HostileProfiles[spec]`. The debuff Aura Container of a hostile frame filters `HELPFUL|RAID_PLAYER_DISPELLABLE` with the offensive dispel types instead of `HARMFUL|...`. Design: `docs/plans/2026-09-06-arena-priest-cockpit-design.md`.

**Tech Stack:** WoW Lua 5.1 / Blizzard XML, retail 12.1 (Midnight) API. No test suite: every task ends with a syntax check (`node luacheck.js`, luaparse in the scratchpad) and the last task lists the in-game checks.

**Syntax check command** (from the repo root; `$SCRATCH` is the session scratchpad holding `luacheck.js` and `node_modules/luaparse`):

```
node "$SCRATCH/luacheck.js" retail/*.lua
```

Expected: `OK   ...` for every file, exit code 0.

**Commit convention:** this repo commits as `see changelog.txt`; the changelog entry is written in Task 10, so intermediate commits use descriptive messages and the final one follows the convention.

---

### Task 1: Settings, hostile profiles, profile selection (Healium.lua)

**Files:**
- Modify: `retail/Healium.lua:67-69` (defaults), `:246-254` (`Healium_GetProfile`), `:1281-1305` (`InitVariables`), `:1429-1436` (`PLAYER_ENTERING_WORLD`), `:1508-1531` (`PLAYER_LOGIN`)

**Step 1: Defaults.** After `ShowFocusFrame = false,` add:

```lua
  ShowArenaFrame = false,						-- Whether or not to show the arena frame (new in 3.7.0)
```

After `DebufAudioFile = "Horde Bell",` add:

```lua
  EnableOffensiveDispelAudio = false,			-- Whether or not to play a sound when an arena opponent has a buff you can dispel (new in 3.7.0)
```

**Step 2: Profile selection.** After `Healium_GetProfile` add:

```lua
-- Hostile frames (arena opponents) carry their own, offensive, button set.
function Healium_GetHostileProfile()
	local currentSpec = GetSpecialization()

	if not currentSpec then
		currentSpec = 1
	end

	return Healium.HostileProfiles[currentSpec]
end

-- The profile a unit frame's buttons are built from.
function Healium_GetProfileForFrame(frame)
	if frame and frame.isHostile then
		return Healium_GetHostileProfile()
	end

	return Healium_GetProfile()
end

-- Heal buttons are direct children of their unit frame.
function Healium_GetProfileForButton(button)
	return Healium_GetProfileForFrame(button:GetParent())
end
```

**Step 3: Saved-variable migration.** In `InitVariables`, after the `for i = 1,5 do ... end` loop over `Healium.Profiles`, add:

```lua
	-- Hostile profiles (arena opponents) were added in 3.7.0.  Same shape as
	-- Healium.Profiles; PartyFrameOrder means nothing there and is left unset.
	if Healium.HostileProfiles == nil then
		Healium.HostileProfiles = { }
	end

	for i = 1,5 do
		if Healium.HostileProfiles[i] == nil then
			Healium.HostileProfiles[i] = Healium_DeepCopy(DefaultProfile)
			Healium.HostileProfiles[i].PartyFrameOrder = nil
		end

		if Healium.HostileProfiles[i].SpellTypes == nil then
			Healium.HostileProfiles[i].SpellTypes = {}
		end

		if Healium.HostileProfiles[i].IDs == nil then
			Healium.HostileProfiles[i].IDs = {}
		end

		if Healium.HostileProfiles[i].SpellRanks == nil then
			Healium.HostileProfiles[i].SpellRanks = {}
		end
	end
```

**Step 4: Events.** In the `PLAYER_ENTERING_WORLD` branch, after `Healium_UpdateButtonAttributes()`, add `Healium_UpdateArenaTestMode()`. In `PLAYER_LOGIN`, after `Healium_ShowHideFocusFrame()`, add `Healium_ShowHideArenaFrame()`.

**Step 5:** Syntax check. **Step 6:** Commit `Add hostile profiles and arena settings`.

---

### Task 2: Frame-aware button code (Healium.lua)

**Files:**
- Modify: `retail/Healium.lua` — `Healium_UpdateButtonCooldownByUnitFrame` (:979), `Healium_UpdateButtonCooldownsByColumn` (:993), `Healium_UpdateButtonIcon` (:1021), `Healium_UpdateButtonIcons` (:1048), `Healium_SetButtonAttributes` (:1066), `Healium_UpdateButtonAttributes` (:1103), `UpdateButtonVisibility` (:1132), `Healium_RangeCheckButton` (:1192)

**Step 1:** In `Healium_UpdateButtonCooldownByUnitFrame` replace `local Profile = Healium_GetProfile()` with `local Profile = Healium_GetProfileForFrame(frame)`.

**Step 2:** Rewrite `Healium_UpdateButtonCooldownsByColumn`:

```lua
function Healium_UpdateButtonCooldownsByColumn(column)
	-- Common call site: numeric column index
	if type(column) == "number" then
		for _, frame in ipairs(Healium_Frames) do
			local button = frame.buttons and frame.buttons[column]
			if button and button.cooldown then
				local durObj = Healium_GetCooldownDurationObject(Healium_GetProfileForFrame(frame), column)
				Healium_ApplyDurationObject(button.cooldown, durObj)
			end
		end
		return
	end

	-- Alternate call site: pass the unit frame itself
	if type(column) == "table" and column.buttons then
		Healium_UpdateButtonCooldownByUnitFrame(column)
	end
end
```

**Step 3:** In `Healium_UpdateButtonIcon` replace `local Profile = Healium_GetProfile()` with `local Profile = Healium_GetProfileForButton(button)`.

**Step 4:** Rewrite `Healium_UpdateButtonIcons`:

```lua
function Healium_UpdateButtonIcons()
	if InCombatLockdown() then
		return
	end

	for _, k in ipairs(Healium_Frames) do
		local Profile = Healium_GetProfileForFrame(k)
		for i=1, Healium_MaxButtons, 1 do
			local button = k.buttons[i]
			if button then 
				Healium_UpdateButtonIcon(button, Profile.SpellIcons[i])
			end
		end
	end
end
```

**Step 5:** In `Healium_SetButtonAttributes` replace `local Profile = Healium_GetProfile()	` with `local Profile = Healium_GetProfileForButton(button)`.

**Step 6:** Rewrite `Healium_UpdateButtonAttributes` (slot IDs for both sets, then every button through its own profile):

```lua
local function UpdateProfileSpellSlots(Profile)
	for i=1, Healium_MaxButtons, 1 do
		if (Profile.SpellTypes[i] == nil) or (Profile.SpellTypes[i] == Healium_Type_Spell) then 
			local name = Profile.SpellNames[i]
			local subtext = Profile.SpellRanks[i]
			if name then 
				Profile.IDs[i] = GetSpellSlotID(name, subtext)
			end
		end
	end
end

function Healium_UpdateButtonAttributes()
	UpdateProfileSpellSlots(Healium_GetProfile())
	UpdateProfileSpellSlots(Healium_GetHostileProfile())

	for _,k in ipairs(Healium_Frames) do
		for i=1, Healium_MaxButtons, 1 do
			local button = k.buttons[i]
			if button then 
				Healium_SetButtonAttributes(button)
			end
		end
	end
	
	Healium_InvalidateRangeCheckCache()
	Healium_UpdateCures()
	if Healium_RefreshAuraContainers then
		Healium_RefreshAuraContainers()
	end
end
```

**Step 7:** In `UpdateButtonVisibility(frame)` replace `local count = Healium_GetProfile().ButtonCount` with `local count = Healium_GetProfileForFrame(frame).ButtonCount`.

**Step 8:** In `Healium_RangeCheckButton`, the per-column caches must not mix the two sets. Replace the first two lines of the body with:

```lua
	local Profile = Healium_GetProfileForButton(button)
	local index = button.index
	-- The column caches are shared by every frame, so a hostile column must
	-- not reuse the friendly column's answers.
	local key = button:GetParent().isHostile and ("H" .. index) or index
```

and replace every `ColumnUsableTime[index]`, `ColumnNoMana[index]`, `ColumnHasRange[index]` in that function with `[key]` (the `Profile.SpellTypes[index]` / `Profile.SpellNames[index]` reads keep `index`).

**Step 9:** Syntax check. **Step 10:** Commit `Read button profiles per frame`.

---

### Task 3: Heal button tooltip and drag & drop (HealiumHealButton.lua)

**Files:**
- Modify: `retail/HealiumHealButton.lua:39`, `:64`, `:147`, `:218`

**Step 1:** Replace all four `local Profile = Healium_GetProfile()` with `local Profile = Healium_GetProfileForButton(frame)`.

**Step 2:** Syntax check. **Step 3:** Commit `Heal buttons edit the profile of their own frame`.

---

### Task 4: Priest hostile spells and offensive cures (HealiumSpells.lua, Healium.lua, HealiumConfigPanel.lua)

**Files:**
- Modify: `retail/HealiumSpells.lua:6-7` (locals), `:34` (reset), `:96-114` (priest block), end of file
- Modify: `retail/Healium.lua:34` (`Healium_MaxClassSpells`)
- Modify: `retail/HealiumConfigPanel.lua:934-942` (`DropDownMenuItem_OnClick` loop)

**Step 1:** In `HealiumSpells.lua` after `local Cures = { }` add `local OffensiveCures = { }`; in `Healium_InitSpells` after `Cures = {}` add `OffensiveCures = {}`.

**Step 2:** In the PRIEST block, after `AddSpell(47536)     -- Rapture`, add:

```lua

		-- Targeted hostile spells for the Arena frame (new in 3.7.0).  IDs
		-- checked against Wowhead on 2026-09-06.  Psychic Scream, Mass Dispel
		-- and Dispersion take no unit and stay out.  Anything not in the
		-- spellbook is simply not offered.
		AddSpell(528)		-- Dispel Magic
		AddSpell(15487)		-- Silence
		AddSpell(64044)		-- Psychic Horror
		AddSpell(605)		-- Mind Control
		AddSpell(589)		-- Shadow Word: Pain
		AddSpell(32379)		-- Shadow Word: Death
		AddSpell(34914)		-- Vampiric Touch
		AddSpell(8092)		-- Mind Blast
		AddSpell(585)		-- Smite
		AddSpell(335467)	-- Shadow Word: Madness (was Devouring Plague)
		AddSpell(15407)		-- Mind Flay
		AddSpell(263165)	-- Void Torrent
		AddSpell(73510)		-- Shadeburst (was Mind Spike)
		AddSpell(204197)	-- Purge the Wicked
		AddSpell(375901)	-- Mindgames
```

After the `Purify Disease` cure block (before `end` of the PRIEST block) add:

```lua

		-- Priest Dispel Magic: removes one Magic buff from an enemy
		CureName = Healium_GetSpellName(528)
		if CureName then
			OffensiveCures[CureName] = { Magic = true }
		end
```

**Step 3:** At the end of the file add:

```lua

-- Returns the dispel types an offensive dispel removes from an enemy, for the
-- Arena frame's Aura Containers.  Mirrors Healium_GetCureDispelTypes.
function Healium_GetOffensiveDispelTypes(spellName)
	local cure = spellName and OffensiveCures[spellName]
	if not cure then return nil end

	local dispelTypes = {}
	for dispelType in pairs(cure) do dispelTypes[dispelType] = true end
	return dispelTypes
end
```

**Step 4:** The priest list now has 36 entries but `Healium_MaxClassSpells = 20` and the config dropdown only matches values below it (`HealiumConfigPanel.lua:936`), so the 21st entry onward could never be selected. In `Healium.lua:34` set `Healium_MaxClassSpells = 40` and update the comment: `-- Upper bound on class specific spells in Healium_Spell.Name (priest is the largest, 36 in 3.7.0)`. In `DropDownMenuItem_OnClick` change the inner loop to `for j=0, #Healium_Spell.Name - 1, 1 do`.

**Step 5:** Syntax check. **Step 6:** Commit `Add priest arena spells and offensive dispel table`.

---

### Task 5: Arena frame, visibility, layouts, test mode (HealiumUnitFrames.lua)

**Files:**
- Modify: `retail/HealiumUnitFrames.lua:10-22` (locals), `:546-548` (`Healium_CreateButtonsForNameplate`), after `CreateFocusUnitFrame` (:792), `HealiumUnitFrames_ShowHideFrame` (:886-893), `Healium_ToggleAllFrames` (:1066-1157), after `Healium_ShowHideFocusFrame` (:1277), `Healium_CreateUnitFrames` (:1341), `Healium_SetScale` (:1362), `Healium_CaptureFrameLayout` (:1402), `Healium_ApplyFrameLayout` (:1436)

**Step 1: Locals.** After `local FocusFrame = nil` add `local ArenaFrame = nil`; after `local FocusFrameWasShown = nil` add:

```lua
local ArenaFrameWasShown = nil

-- Solo Shuffle, 2v2 and 3v3 never field more than three opponents.
local ArenaUnits = { "arena1", "arena2", "arena3" }
-- /hlm arena test points the same three buttons at units that exist anywhere.
local ArenaTestUnits = { "target", "focus", "player" }
local ArenaTestMode = false
```

**Step 2:** In `Healium_CreateButtonsForNameplate` replace `local Profile = Healium_GetProfile()` with `local Profile = Healium_GetProfileForFrame(frame)`.

**Step 3: Creation.** After `CreateFocusUnitFrame` add:

```lua
-- Arena opponents: three watched unit buttons stacked under one movable
-- container, like Target and Focus.  isHostile switches them to the offensive
-- button profile and to the enemy buff filters.  OnLoad runs before the flag
-- can be set, so the buttons it builds are refreshed by Healium_UpdateButtons
-- at the end of ADDON_LOADED.
local function CreateArenaUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	uf.hdrs = { }

	local anchor = uf
	for i, unit in ipairs(ArenaUnits) do
		local h = CreateFrame("Button", FrameName .. "_Header" .. i, uf, "HealiumUnitFrames_ButtonTemplate")
		h.isCustom = true
		h.isHostile = true
		h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
		h:SetAttribute("unit", unit)
		RegisterUnitWatch(h)
		h:Show()
		uf.hdrs[i] = h
		anchor = h
	end

	uf.hdr = uf.hdrs[1]
	return uf
end
```

**Step 4:** In `HealiumUnitFrames_ShowHideFrame`, after the `FocusFrame` block add:

```lua
	if frame == ArenaFrame then
		Healium_DebugPrint("ShowHide Arena Frame")
		Healium.ShowArenaFrame = show
		Healium_ShowArenaCheck:SetChecked(Healium.ShowArenaFrame)
		return
	end
```

**Step 5:** In `Healium_ToggleAllFrames`: after `if FocusFrame:IsShown() then hide = true end` add `if ArenaFrame:IsShown() then hide = true end`; after `FocusFrameWasShown = FocusFrame:IsShown()` add `ArenaFrameWasShown = ArenaFrame:IsShown()`; after `FocusFrame:Hide()` add `ArenaFrame:Hide()`; after `if FocusFrameWasShown then FocusFrame:Show() end` add `if ArenaFrameWasShown then ArenaFrame:Show() end`.

**Step 6:** After `Healium_ShowHideFocusFrame` add:

```lua
function Healium_ShowHideArenaFrame(show)
	if ArenaFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowArenaFrame = show end

	-- Test mode keeps the frame up whatever the setting says.
	if Healium.ShowArenaFrame or ArenaTestMode then
		ArenaFrame:Show()
	else
		ArenaFrame:Hide()
	end
end

-- /hlm arena test: point the three arena buttons at target, focus and the
-- player, so layout and buttons can be checked without queueing.
function Healium_SetArenaTestMode(enabled)
	if ArenaFrame == nil then return end
	if InCombatLockdown() then
		Healium_Warn("Arena test mode cannot be changed during combat.")
		return
	end

	ArenaTestMode = enabled and true or false

	for i, h in ipairs(ArenaFrame.hdrs) do
		h:SetAttribute("unit", ArenaTestMode and ArenaTestUnits[i] or ArenaUnits[i])
	end

	Healium_ShowHideArenaFrame()

	if ArenaTestMode then
		Healium_Print("Arena test mode ON: the Arena frame shows your target, focus and yourself.  Type " .. Healium_Slash .. " arena test again to turn it off.")
	else
		Healium_Print("Arena test mode OFF.")
	end
end

function Healium_ToggleArenaTestMode()
	Healium_SetArenaTestMode(not ArenaTestMode)
end

-- Walking into an arena with test mode still on would show the wrong units.
function Healium_UpdateArenaTestMode()
	if not ArenaTestMode then return end

	local _, instanceType = IsInInstance()
	if instanceType == "arena" then
		Healium_SetArenaTestMode(false)
	end
end
```

**Step 7:** In `Healium_CreateUnitFrames` after the Focus line add `ArenaFrame = CreateArenaUnitFrame("HealiumArenaFrame", "Arena")`. In `Healium_SetScale` after `FocusFrame:SetScale(Scale)` add `ArenaFrame:SetScale(Scale)`. In `Healium_CaptureFrameLayout` after `Focus = ...,` add `Arena = Healium.ShowArenaFrame and true or false,`. In `Healium_ApplyFrameLayout` after the Focus line add `Healium_ShowHideArenaFrame(visibility.Arena and true or false)`.

**Step 8:** Syntax check. **Step 9:** Commit `Add the Arena unit frame with a test mode`.

---

### Task 6: Enemy buff filters and offensive dispel audio (HealiumUnitFrames.lua)

**Files:**
- Modify: `retail/HealiumUnitFrames.lua` — `AddDispelTintTexture` (:125), `CreateTintedBorder` (:139), `InvalidateAuraFilterCache` (:199), `OnCurableDebuffShown` (:317), `InitializeHealthDebuffButton` (:337), `InitializeCureDebuffButton` (:358), `GetCureTypeFilters` (:386-403), `CreateDebuffAuraContainer` (:405), `GetConfiguredCureTypes` (:441), `RefreshFrameAuraContainers` (:448), `Healium_RefreshAuraContainers` (:524)

**Step 1:** `AddDispelTintTexture(auraButton, texture, helpful)`: build options as

```lua
	local options = {
		showWhenHarmful = not helpful,
		showWhenHelpful = helpful and true or false,
		customDispelColorMap = DispelColorMap,
	}
```

`CreateTintedBorder(auraButton, storage, helpful)` passes `helpful` to `AddDispelTintTexture(auraButton, texture, helpful)`.

**Step 2:** Caches. Next to `CachedAllCureTypes` add `local CachedHostileCureTypes = nil` and `local CachedAllHostileCureTypes = nil`; `InvalidateAuraFilterCache` also sets both to nil.

**Step 3:** `OnCurableDebuffShown`:

```lua
-- Called when Blizzard shows the health bar debuff button, meaning the unit has
-- a debuff one of the configured buttons can remove, or, on a hostile frame, a
-- buff the offensive dispel can strip.
local function OnCurableDebuffShown(frame)
	if not Healium.EnableDebufs then return end

	local hostile = frame and frame.isHostile
	if hostile and not Healium.EnableOffensiveDispelAudio then return end
	if not hostile and not Healium.EnableDebufAudio then return end

	local now = GetTime()
	if now < (LastDebuffSoundTime + DebuffSoundInterval) then return end

	local unit = frame and frame.TargetUnit
	if not unit or not UnitExists(unit) then return end

	-- Do not shout about someone we cannot reach.  UnitInRange returns false for
	-- the player, and may be secret, in which case warn rather than stay silent.
	-- It only knows party and raid members, so opponents skip the check.
	if unit ~= "player" and not hostile then
		local inRange = UnitInRange(unit)
		if not Healium_IsSecret(inRange) and not inRange then return end
	end

	LastDebuffSoundTime = now
	Healium_PlayDebuffSound()
end
```

**Step 4:** `InitializeHealthDebuffButton`: `CreateTintedBorder(auraButton, frame.DebuffHealthBorderTextures, frame.isHostile)` and `AddDispelTintTexture(auraButton, overlay, frame.isHostile)`. `InitializeCureDebuffButton`: `CreateTintedBorder(auraButton, frame.DebuffButtonBorderTextures[index], frame.isHostile)`.

**Step 5:** Replace the `local GetConfiguredCureTypes` declaration and `GetCureTypeFilters` with:

```lua
local GetConfiguredCureTypes
local GetConfiguredOffensiveCureTypes

local function BuildCureTypeFilters(profile, getTypes)
	local perButton, all = {}, {}

	for i = 1, Healium_MaxButtons do
		perButton[i] = getTypes(profile, i)
		for dispelType in pairs(perButton[i]) do all[dispelType] = true end
	end

	return perButton, all
end

-- Cure types per button plus their union, cached alongside the buff filter.
-- Hostile frames read the offensive set.
local function GetCureTypeFilters(frame)
	if frame and frame.isHostile then
		if not CachedHostileCureTypes then
			CachedHostileCureTypes, CachedAllHostileCureTypes =
				BuildCureTypeFilters(Healium_GetHostileProfile(), GetConfiguredOffensiveCureTypes)
		end
		return CachedHostileCureTypes, CachedAllHostileCureTypes
	end

	if not CachedCureTypes then
		CachedCureTypes, CachedAllCureTypes = BuildCureTypeFilters(Healium_GetProfile(), GetConfiguredCureTypes)
	end

	return CachedCureTypes, CachedAllCureTypes
end

-- Debuffs on friends, buffs on enemies.  12.1 extended RAID_PLAYER_DISPELLABLE
-- to helpful auras on enemies that a raid member can dispel or steal.
local function GetDebuffSlotFilter(frame)
	if frame and frame.isHostile then
		return "HELPFUL|RAID_PLAYER_DISPELLABLE"
	end
	return "HARMFUL|RAID_PLAYER_DISPELLABLE"
end
```

**Step 6:** In `CreateDebuffAuraContainer`: `local configuredTypes, allCureTypes = GetCureTypeFilters(frame)`, `local slotFilter = GetDebuffSlotFilter(frame)`, and both `AddAuraSlot` calls use `slotFilter` instead of the literal.

**Step 7:** After `GetConfiguredCureTypes = function ... end` add:

```lua
GetConfiguredOffensiveCureTypes = function(profile, index)
	if not profile or not profile.SpellNames then return {} end
	local spellType = profile.SpellTypes and profile.SpellTypes[index]
	if spellType ~= nil and spellType ~= Healium_Type_Spell then return {} end
	return Healium_GetOffensiveDispelTypes(profile.SpellNames[index]) or {}
end
```

**Step 8:** `RefreshFrameAuraContainers`: wrap the buff container creation and its failure report in `if not frame.isHostile then ... end` (no player-buff container on enemies); replace the `buffOK` line with

```lua
	local buffOK = true
	if frame.BuffAuraContainer then
		buffOK = SafeAuraContainerCall(frame.BuffAuraContainer, frame.BuffAuraContainer.SetUnit, unit)
	end
```

wrap the two `frame.BuffAuraContainer:...` calls in the non-restricted branch in `if frame.BuffAuraContainer then ... end`, and change `GetCureTypeFilters()` there to `GetCureTypeFilters(frame)`.

**Step 9:** In `Healium_RefreshAuraContainers` change the initialized test to `if (frame.isHostile or frame.BuffAuraContainer) and frame.DebuffAuraContainer then initialized = true end`.

**Step 10:** Syntax check. **Step 11:** Commit `Light the offensive dispel button from enemy buffs`.

---

### Task 7: Config panel (HealiumConfigPanel.lua)

**Files:**
- Modify: `retail/HealiumConfigPanel.lua` — top locals (:3-7), `CopyProfile` (:36-46), save sites (:349, :356, :367), `LoadProfile` (:386-387), `DropDownMenuItem_OnClick` (:928), `Healium_SetButtonCount` (:989), audio handlers (:1115-1121), `Healium_Update_ConfigPanel` (:1190-1216), dropdown creation (:1392-1401), slider init (:1414), Focus check (:1512-1521), audio controls (:1682-1699), init block (:1828-1850)

**Step 1: Edited set.** After `PartyFrameOrderOptions` add:

```lua
-- Which button set the Button Configuration dropdowns and the button count
-- slider edit.  Party Frame Order always belongs to the friendly set.
local EditingHostileProfile = false
local ButtonSetDropDown
local ButtonSetOptions = {
	{ text = "Friendly frames", value = "FRIENDLY" },
	{ text = "Arena opponents", value = "HOSTILE" },
}

local function GetEditedProfile()
	if EditingHostileProfile then
		return Healium_GetHostileProfile()
	end
	return Healium_GetProfile()
end

local function GetButtonSetText()
	return EditingHostileProfile and ButtonSetOptions[2].text or ButtonSetOptions[1].text
end
```

Replace `Healium_GetProfile()` with `GetEditedProfile()` in `DropDownMenuItem_OnClick`, `Healium_SetButtonCount`, both reads in `Healium_Update_ConfigPanel`, and the slider `SetValue` at :1414.

**Step 2: Class profiles carry both sets.** Rename the existing `CopyProfile` to `CopyProfileSet` and add:

```lua
-- A saved class profile is the friendly set plus, since 3.7.0, the arena set.
local function CopyProfile(profile, hostileProfile)
	local copy = CopyProfileSet(profile)
	if hostileProfile then
		copy.Hostile = CopyProfileSet(hostileProfile)
		copy.Hostile.PartyFrameOrder = nil
	end
	return copy
end
```

The three save sites become `CopyProfile(Healium_GetProfile(), Healium_GetHostileProfile())`. In `LoadProfile` replace `Healium.Profiles[specialization] = CopyProfile(savedProfile)` with:

```lua
		Healium.Profiles[specialization] = CopyProfileSet(savedProfile)
		if savedProfile.Hostile then
			Healium.HostileProfiles[specialization] = CopyProfileSet(savedProfile.Hostile)
			Healium.HostileProfiles[specialization].PartyFrameOrder = nil
		end
```

(Text export/import keeps the friendly set only; the string format is unchanged.)

**Step 3: Dropdown handlers.** After `PartyFrameOrderDropDown_Init` add:

```lua
local function ButtonSetDropDown_OnClick(dropdownbutton)
	EditingHostileProfile = dropdownbutton.value == "HOSTILE"
	Lib_UIDropDownMenu_SetSelectedValue(dropdownbutton.owner, dropdownbutton.value)
	Lib_UIDropDownMenu_SetText(dropdownbutton.owner, dropdownbutton:GetText())
	Healium_Update_ConfigPanel()
end

local function ButtonSetDropDown_Init(frame, level)
	level = level or 1
	local selected = EditingHostileProfile and "HOSTILE" or "FRIENDLY"
	for _, option in ipairs(ButtonSetOptions) do
		local info = Lib_UIDropDownMenu_CreateInfo()
		info.text = option.text
		info.value = option.value
		info.func = ButtonSetDropDown_OnClick
		info.owner = frame
		info.checked = option.value == selected
		Lib_UIDropDownMenu_AddButton(info, level)
	end
end
```

In `Healium_Update_ConfigPanel`, before the slider line add:

```lua
	if ButtonSetDropDown then
		Lib_UIDropDownMenu_SetText(ButtonSetDropDown, GetButtonSetText())
	end
```

**Step 4: Dropdown creation.** Replace the `for i=1, Healium_MaxButtons` dropdown loop's anchoring so a Button Set dropdown sits first:

```lua
	ButtonSetDropDown = CreateDropDownMenu("$parentButtonSetDropDown", scrollchild)
	ButtonSetDropDown:SetPoint("TOPLEFT", ButtonConfigTitleSubText, "BOTTOMLEFT", 50, -5)
	ButtonSetDropDown.Text:SetText("Button Set")
	ButtonSetDropDown.tooltipText = "Friendly frames share one button set per specialization; the Arena frame has its own."
	Lib_UIDropDownMenu_Initialize(ButtonSetDropDown, ButtonSetDropDown_Init)

	local y_inc = 20
	
	for i=1, Healium_MaxButtons, 1 do
		HealiumDropDown[i] = CreateDropDownMenu("HealiumDropDown[" .. i .. "]",scrollchild)
		if i == 1 then
			HealiumDropDown[i]:SetPoint("TOPLEFT", ButtonSetDropDown, "TOPLEFT", 0, -y_inc - 6)
		else
			HealiumDropDown[i]:SetPoint("TOPLEFT", HealiumDropDown[i - 1], "TOPLEFT", 0, -y_inc)
		end
		HealiumDropDown[i].Text:SetText("Button " .. i)
	end
```

**Step 5: Show Arena check.** After the Focus check block add:

```lua
	-- Show Arena Check
	Healium_ShowArenaCheck = CreateCheck("$parentShowArenaCheckButton",scrollchild,Healium_ShowFocusCheck, "Shows the Arena " .. Healium_AddonColoredName .. " frame: one row per arena opponent, using the Arena button set.", "Arena")

	Healium_ShowArenaCheck:SetScript("OnClick",function()
		Healium.ShowArenaFrame = Healium_ShowArenaCheck:GetChecked() or false
		Healium_ShowHideArenaFrame()
	end)
```

and change `local Group1Parent = Healium_ShowFocusCheck` to `local Group1Parent = Healium_ShowArenaCheck`.

**Step 6: Offensive audio.** After `EnableDebuffAudioCheck_OnClick` add:

```lua
local function EnableOffensiveDispelAudioCheck_OnClick(frame)
	Healium.EnableOffensiveDispelAudio = frame:GetChecked() or false
end
```

Between the `EnableDebuffAudioCheck` block and `SoundDropDown` add:

```lua
	-- Offensive dispel audio check button
	local EnableOffensiveDispelAudioCheck = CreateFrame("CheckButton","$parentEnableOffensiveDispelAudioCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
	EnableOffensiveDispelAudioCheck:SetPoint("TOPLEFT", EnableDebuffAudioCheck, "BOTTOMLEFT", 0, 0)
	EnableOffensiveDispelAudioCheck.Text = EnableOffensiveDispelAudioCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableOffensiveDispelAudioCheck.Text:SetPoint("LEFT", EnableOffensiveDispelAudioCheck, "RIGHT", 0)
	EnableOffensiveDispelAudioCheck.Text:SetText("Arena Dispel Audio Warning")
	table.insert(EnableDebuffsCheck.children, EnableOffensiveDispelAudioCheck.Text)
	EnableOffensiveDispelAudioCheck:SetScript("OnClick", EnableOffensiveDispelAudioCheck_OnClick)
	EnableOffensiveDispelAudioCheck.tooltipText = "Plays the same sound when an arena opponent has a buff one of your Arena buttons can dispel."
```

and re-anchor `SoundDropDown:SetPoint("TOPLEFT", EnableOffensiveDispelAudioCheck, "BOTTOMLEFT", 65, 0)`.

**Step 7: Init.** In the init block add `EnableOffensiveDispelAudioCheck:SetChecked(Healium.EnableOffensiveDispelAudio)` after the audio line and `Healium_ShowArenaCheck:SetChecked(Healium.ShowArenaFrame)` after the Target line.

**Step 8:** Syntax check. **Step 9:** Commit `Config panel: Arena frame, button set selector, arena dispel audio`.

---

### Task 8: Slash commands and menu

**Files:**
- Modify: `retail/HealiumSlashCommands.lua:21`, `:29`, `:93-95`, `:250-260`
- Modify: `retail/HealiumMenu.lua:33-35`, `:288-292`

**Step 1:** Usage: add `arena` to the `show [...]` list and add after the dump line:

```lua
	Healium_Print(Healium_Slash .. " arena test - Toggles a test mode that points the Arena frame at your target, focus and yourself.")
```

Add `arena = function() Healium_ShowHideArenaFrame(true) end,` to `showHandlers`. Add before `local handlers`:

```lua
-- handles /hlm arena
local function doArena(args)
	args = args and strtrim(string.lower(args)) or ""
	if args == "test" then
		Healium_ToggleArenaTestMode()
		return
	end
	printUsage()
end
```

and `arena = doArena,` to `handlers`.

**Step 2:** Menu: after `ShowFocusFrame` add

```lua
local function ShowArenaFrame()
	Healium_ShowHideArenaFrame(true)
end
```

and after the Focus entry:

```lua
				{	-- Arena Frame
					text = "Show Arena",
					notCheckable = 1,					
					func = ShowArenaFrame,
				},
```

**Step 3:** Syntax check. **Step 4:** Commit `Slash command and menu entries for the Arena frame`.

---

### Task 9: Documentation

**Files:**
- Modify: `CLAUDE.md` (Frames and Profiles sections)

Add to Frames: `- Arena (retail): three plain \`RegisterUnitWatch\` buttons for arena1-3 under one container, flagged \`isHostile\`; \`/hlm arena test\` retargets them to target/focus/player.` Add to Profiles: `\`Healium.HostileProfiles[specIndex]\` (retail, 3.7.0) is the same shape and feeds frames flagged \`isHostile\`; always resolve a button's profile with \`Healium_GetProfileForFrame\` / \`Healium_GetProfileForButton\`, never \`Healium_GetProfile()\` directly.`

Commit `Document the Arena frame and hostile profiles`.

---

### Task 10: Release notes and final verification

**Files:**
- Modify: `HealiumVersion.lua`, `changelog.txt`

**Step 1:** Version `3.7.0`. Prepend to `changelog.txt`:

```
3.7.0
* Retail: New Arena frame, one row per arena opponent (arena1 to arena3), with its own button set per specialization, edited from the Button Set dropdown on the options panel.  Meant for the offensive spells a priest throws at enemies: Dispel Magic, Silence, Psychic Horror, Mind Control, dots.  Enable it under Show Frames or with /hlm show arena; /hlm arena test points it at your target, focus and yourself outside an arena.
* Retail: On the Arena frame the Blizzard Aura Container shows an opponent's dispellable buff on the Dispel Magic button and on the health bar, the same way curable debuffs show on friendly frames.  An optional Arena Dispel Audio Warning plays the debuff sound when that happens.
* Retail: Saved class button profiles now carry both button sets.  Text export and import still carry the friendly set only.
* Retail: The priest spell list gains the targeted hostile spells.  Spells past the twentieth entry could not be picked from the options dropdowns; they can now.
```

**Step 2:** Syntax check all files. **Step 3:** Commit `see changelog.txt`.

**Step 4: In-game checks** (the user runs these; report them as pending):

1. `/reload`, no Lua error, chat shows `3.7.0`.
2. `/hlm config`: Arena check under Show Frames; Button Set dropdown above Button 1; Arena Dispel Audio Warning under Debuff Warnings. Switching Button Set swaps the dropdown texts and the slider; Party Frame Order unaffected.
3. `/hlm arena test` out of combat: Arena frame shows target, focus, self; buttons carry the Arena set; hovering shows tooltips; drag a spell from the spellbook onto an arena button and check it lands in the Arena set (dropdowns under Button Set = Arena opponents), not in the friendly one.
4. Enter combat (target dummy) with test mode on: no error, buttons still cast; `/hlm arena test` refuses; leave combat, toggle works.
5. Skirmish: frames appear at the gates, hide after; with Dispel Magic on an Arena button, a buffed opponent shows the buff icon on that button and a tinted health bar; audio plays if enabled.
6. Button Profiles: Add, Load, both sets restored on another character of the same class.
