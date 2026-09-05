-- Unit Frames Code
local PartyFrame = nil
local PetsFrame = nil
local MeFrame = nil
local DamagersFrame = nil
local HealersFrame = nil
local TanksFrame = nil
local FriendsFrame = nil
local GroupFrames = { }
local TargetFrame = nil
local FocusFrame = nil

local PartyFrameWasShown = nil
local PetsFrameWasShown = nil
local MeFrameWasShown = nil
local DamagersFrameWasShown = nil
local HealersFrameWasShown = nil
local TanksFrameWasShown = nil
local FriendsFrameWasShown = nil
local GroupFramesWasShown = { }
local TargetFrameWasShown = nil
local FocusFrameWasShown = nil

local MaxBuffs = 6
local xSpacing = 2
local NamePlateHeight = 28
local LastDebuffSoundTime = GetTime()

local UnitFrames = { } -- table of all unit frames

ClickCastFrames = ClickCastFrames or {} -- used by Clique and any other click cast frames
local DebuffSoundPath

-- locale safe versions of spell names
local RejuvenationGermination = Healium_GetSpellName(155777) -- Rejuvenation (Germination) is a buff when a druid with the Germination talent casts Rejuvenation on a target
local EternalFlame = Healium_GetSpellName(156322) -- Eternal Flame is a buff when a paladin with the Eternal Flame talent casts Word of Glory on a target
local Atonement = Healium_GetSpellName(81749) -- Atonement: Plea, Power Word: Shield, Shadow Mend, and Power Word: Radiance also apply Atonement to your target for 15 sec.\
local GlimmerOfLight = Healium_GetSpellName(325983) -- Glimmer of Light is a buff when a paladin with the Glimmer of Light talent casts Holy Shock
local Tranquility = Healium_GetSpellName(740) -- Tranquility - HOT from Druid casting Tranquility
local TemporalBeaconName = Healium_GetSpellName(400735) -- Temporal Beacon

-- The set of buff names that light up a buff icon.  This used to be re-tested
-- with a loop over every button plus a chain of comparisons for every buff of
-- every unit; it only changes when the button configuration changes.
local ArmedBuffNames = nil

function Healium_InvalidateArmedBuffNames()
	ArmedBuffNames = nil
end

local function GetArmedBuffNames()
	if ArmedBuffNames then return ArmedBuffNames end

	local names = {}
	local Profile = Healium_GetProfile()

	for j = 1, Profile.ButtonCount, 1 do
		local name = Profile.SpellNames[j]
		if name then names[name] = true end
	end

	-- Buffs Healium always shows.  Any of these can be nil on a client where
	-- the spell does not exist.
	local special = { RejuvenationGermination, EternalFlame, Atonement, GlimmerOfLight, Tranquility, TemporalBeaconName }

	for i = 1, 6 do
		if special[i] then names[special[i]] = true end
	end

	ArmedBuffNames = names
	return names
end

-- sounds ids from https://wow.tools/files/#search=&page=1&sort=0&desc=asc
Healium_Sounds = {
	{ ["Alliance Bell"] = { fileid = 566564, path = "Sound\\Doodad\\BellTollAlliance.ogg"}},
	{ ["Bellow"] = { fileid = 566234, path = "Sound\\Doodad\\BellowIn.ogg" }},
	{ ["Dwarf Horn"] = {fileid = 566064, path = "Sound\\Doodad\\DwarfHorn.ogg" }},
	{ ["Gruntling Horn A"] = {retail = 1, fileid = 598076, path = "Sound\\Events\\gruntling_horn_aa.ogg" }},
	{ ["Gruntling Horn B"] = {retail = 1, fileid = 598196, path = "Sound\\Events\\gruntling_horn_bb.ogg" }},
	{ ["Horde Bell"] = { fileid = 565853, path = "Sound\\Doodad\\BellTollHorde.ogg" }},
	{ ["Man Scream"] = { retail = 1, fileid = 598052, path = "Sound\\Events\\EbonHold_ManScream1_02.ogg" }},
	{ ["Night Elf Bell"] = { fileid = 566558, path = "Sound\\Doodad\\BellTollNightElf.ogg" }},
	{ ["Space Death"] = { retail = 1, fileid = 567198, path = "Sound\\Effects\\DeathImpacts\\SpaceDeathUni.ogg" }},
	{ ["Tribal Bell"] = { fileid = 566027, path = "Sound\\Doodad\\BellTollTribal.ogg" }},
	{ ["Wisp"] = { fileid = 567294, path = "Sound\\Event Sounds\\Wisp\\WispPissed2.ogg" }},
	{ ["Woman Scream"] = { retail = 1, fileid = 598223, path = "Sound\\Events\\EbonHold_WomanScream1_02.ogg" }}
}



function Healium_GetSoundPath(sound)
	for i,j in ipairs(Healium_Sounds) do
		if sound == next(j, nil) then
			if not Healium_IsRetail then 
				return j[sound].path
			else
				return j[sound].fileid
			end
		end
	end
	
	return nil
end

function Healium_InitDebuffSound()
	DebuffSoundPath = Healium_GetSoundPath(Healium.DebufAudioFile)
	
	if DebuffSoundPath == nil then
		Healium.DebufAudioFile = "Horde Bell"
		DebuffSoundPath = Healium_GetSoundPath(Healium.DebufAudioFile)
	end
end

function Healium_PlayDebuffSound()
	if not DebuffSoundPath then return end

	if Healium_Debug then Healium_DebugPrint("playing sound " .. DebuffSoundPath) end
	PlaySoundFile(DebuffSoundPath)	
end

local function CreateButton(ButtonName,ParentFrame,xoffset)
	local button = CreateFrame("Button", ButtonName, ParentFrame, "HealiumHealButtonTemplate")
	button:SetPoint("LEFT", ParentFrame, "RIGHT", xoffset, 0)
	return button
end

-- please make sure we are not in combat before calling this function
function Healium_CreateButtonsForNameplate(frame)
	local x = xSpacing
	local Profile = Healium_GetProfile()
	
	for i=1, Healium_MaxButtons, 1 do
		local name = frame:GetName()
		local button = CreateButton(name.."_Heal"..i, frame, x)
		x = x + xSpacing + NamePlateHeight

		button.index = i -- .index is used by drag operation
		frame.buttons[i] = button

		-- set spell attribute for button
		Healium_SetButtonAttributes(button)
		
		-- set icon for button
		local texture = Profile.SpellIcons[i]	
		Healium_UpdateButtonIcon(button, texture)
	
		if (i > Profile.ButtonCount) then 
			button:Hide()
			
			if button:IsShown() then
				Healium_Warn("Failed to hide heal button")
			end
		else
			button:Show()
			
			if not button:IsShown() then
				Healium_Warn("Failed to show heal button")			
			end
		end
	end	
end

local function SetHeaderAttributes(frame)
--	frame.initialConfigFunction = initialConfigFunction
	frame:SetAttribute("showPlayer", "true")
	frame:SetAttribute("maxColumns", 1)
	frame:SetAttribute("columnAnchorPoint", "LEFT")
	frame:SetAttribute("point", "TOP")
	frame:SetAttribute("template", "HealiumUnitFrames_ButtonTemplate")
	frame:SetAttribute("templateType", "Button")
	frame:SetAttribute("unitsPerColumn", 5) 
end

local function CreateHeader(TemplateName, FrameName, ParentFrame)
	local f = CreateFrame("Frame", FrameName, ParentFrame, TemplateName)
	ParentFrame.hdr = f
	f:SetPoint("TOPLEFT", ParentFrame, "BOTTOMLEFT")	
	SetHeaderAttributes(f)			
	return f
end

local function UpdateCloseButton(frame)
	-- Hide close button if set to
	if not InCombatLockdown() then
		if Healium.HideCloseButton then
			frame.CaptionBar.CloseButton:Hide()
		else
			frame.CaptionBar.CloseButton:Show()
		end
	end
end

local function UpdateHideCaption(frame)
	if Healium.HideCaptions then
		frame.CaptionBar:SetAlpha(0)
	else
		frame.CaptionBar:SetAlpha(1)
	end
end

local function CreateUnitFrame(FrameName, Caption, IsPet, Group)
	local uf = CreateFrame("Frame", FrameName, UIParent, "HealiumUnitFrameTemplate")
	table.insert(UnitFrames, uf) 	
	uf.CaptionBar.Caption:SetText(Caption)
	UpdateCloseButton(uf)	
	UpdateHideCaption(uf)
	return uf
end

local function CreatePetHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupPetHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("filterOnPet", "true")
	h:SetAttribute("unitsPerColumn", 40) -- allow pets frame to show more than 5	
	h:SetAttribute("showSolo", "true")	
	h:SetAttribute("showRaid", "true")	
	h:SetAttribute("showParty", "true")	
	h:Show()
	return h
end

local function CreateGroupHeader(FrameName, ParentFrame, Group)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("groupFilter", Group)	
	h:SetAttribute("showRaid", "true")	
	h:Show()
	return h
end

local function CreateDamagersHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("unitsPerColumn", 40) -- allow  frame to show more than 5
	h:SetAttribute("roleFilter", "DAMAGER")
	h:SetAttribute("showParty", "true")
	h:SetAttribute("showRaid", "true")	
	h:Show()
	return h
end

local function CreateHealersHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("unitsPerColumn", 40) -- allow frame to show more than 5	
	h:SetAttribute("roleFilter", "HEALER")
	h:SetAttribute("showParty", "true")
	h:SetAttribute("showRaid", "true")	
	h:Show()
	return h
end

local function CreateTanksHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("unitsPerColumn", 40) -- allow frame to show more than 5
	h:SetAttribute("roleFilter", "MT,TANK")
	h:SetAttribute("showParty", "true")
	h:SetAttribute("showRaid", "true")	
	h:Show()
	return h
end

local function CreatePartyHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("showSolo", "true")		
	local profile = Healium_GetProfile()
	if Healium_IsClassicMists and profile and profile.PartyFrameOrder == "TANK_HEALER_DPS" then
		h:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
		h:SetAttribute("groupBy", "ASSIGNEDROLE")
	end
	h:Show()
	return h
end

function Healium_UpdatePartyFrameOrder()
	if PartyFrame == nil or PartyFrame.hdr == nil then return true end
	if InCombatLockdown() then return false end

	local profile = Healium_GetProfile()
	local order = profile and profile.PartyFrameOrder or "DEFAULT"
	if Healium_IsClassicMists and order == "TANK_HEALER_DPS" then
		PartyFrame.hdr:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
		PartyFrame.hdr:SetAttribute("groupBy", "ASSIGNEDROLE")
	else
		PartyFrame.hdr:SetAttribute("groupBy", nil)
		PartyFrame.hdr:SetAttribute("groupingOrder", nil)
	end
	return true
end

local function CreateMeHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("showSolo", "true")		
	h:SetAttribute("nameList", UnitName("Player"))
	h:Show()
	return h
end

local function CreateFriendsHeader(FrameName, ParentFrame)
	local h = CreateHeader("SecureGroupHeaderTemplate", FrameName, ParentFrame)
	h:SetAttribute("showSolo", "true")	
	h:SetAttribute("showRaid", "true")	
	h:SetAttribute("showParty", "true")	
	h:SetAttribute("unitsPerColumn", 20) -- allow friends frame to show more than 5
	h:Show()
	return h
end

local function CreateCustomHeader(FrameName, ParentFrame, Unit)
	local h = CreateFrame("Button", FrameName, ParentFrame, "HealiumUnitFrames_ButtonTemplate")
	h.isCustom = true
	ParentFrame.hdr = h
	h:SetAttribute("unit", Unit)		
	h:SetPoint("TOPLEFT", ParentFrame, "BOTTOMLEFT")
	RegisterUnitWatch(h)
	h:Show()
	return h
end

local function CreateGroupUnitFrame(FrameName, Caption, Group)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateGroupHeader(FrameName .. "_Header", uf, Group)
	return uf
end

local function CreateDamagersUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateDamagersHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreateHealersUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateHealersHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreateTanksUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateTanksHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreatePetUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreatePetHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreateMeUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateMeHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreateFriendsUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateFriendsHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreatePartyUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreatePartyHeader(FrameName .. "_Header", uf)
	return uf
end

local function CreateTargetUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateCustomHeader(FrameName .. "_Header", uf, "target")
	return uf
end

local function CreateFocusUnitFrame(FrameName, Caption)
	local uf = CreateUnitFrame(FrameName, Caption)
	local h = CreateCustomHeader(FrameName .. "_Header", uf, "focus")
	return uf
end

function Healium_UpdateCloseButtons()
	for _,j in pairs(UnitFrames) do
		UpdateCloseButton(j)
	end
end

function Healium_UpdateHideCaptions()
	for _,j in pairs(UnitFrames) do
		UpdateHideCaption(j)
	end
end

function HealiumUnitFrames_OnEnter(frame)
	frame:SetAlpha(1)
end

function HealiumUnitFrames_OnLeave(frame)
	if Healium.HideCaptions then
		frame:SetAlpha(0)
	end
end

function HealiumUnitFrames_OnMouseDown(frame, button)
	if button == "LeftButton" and not Healium.LockFrames and not InCombatLockdown() then
		frame:StartMoving()	
	end
	
	if button == "RightButton" then
		Lib_ToggleDropDownMenu(1, nil, HealiumMenu, frame, 0, 0)	
	end
end

function HealiumUnitFrames_OnMouseUp(frame, button)
	if button == "LeftButton" and not InCombatLockdown() then
		frame:StopMovingOrSizing()	
	end
end

function HealiumUnitFrames_ShowHideFrame(frame, show)
	if frame == PartyFrame then
		Healium.ShowPartyFrame = show
		Healium_ShowPartyCheck:SetChecked(Healium.ShowPartyFrame)
		return
	end
	
	if frame == PetsFrame then
		Healium.ShowPetsFrame = show
		Healium_ShowPetsCheck:SetChecked(Healium.ShowPetsFrame)
		return
	end
	
	if frame == MeFrame then
		Healium.ShowMeFrame = show
		Healium_ShowMeCheck:SetChecked(Healium.ShowMeFrame)
		return
	end
	
	if frame == FriendsFrame then
		Healium.ShowFriendsFrame = show
		Healium_ShowFriendsCheck:SetChecked(Healium.ShowFriendsFrame)
		return
	end
	
	if frame == DamagersFrame then
		Healium.ShowDamagersFrame = show
-- TODO DAMAGERS/HEALERS frame	
		Healium_ShowDamagersCheck:SetChecked(Healium.ShowDamagersFrame)
		return
	end
	
	if frame == HealersFrame then
		Healium.ShowHealersFrame = show
-- TODO DAMAGERS/HEALERS frame	
		Healium_ShowHealersCheck:SetChecked(Healium.ShowHealersFrame)
		return
	end
	
	if frame == TanksFrame then
		Healium.ShowTanksFrame = show
		Healium_ShowTanksCheck:SetChecked(Healium.ShowTanksFrame)
		return
	end
	
	if frame == TargetFrame then
		Healium_DebugPrint("ShowHide Target Frame")	
		Healium.ShowTargetFrame = show		
		Healium_ShowTargetCheck:SetChecked(Healium.ShowTargetFrame)
		Healium_UpdateShowTargetFrame()	
		Healium_UpdateTargetFrame()
		return
	end
	
	if (not Healium_IsClassic) and (frame == FocusFrame) then
		Healium_DebugPrint("ShowHide Focus Frame")
		Healium.ShowFocusFrame = show
		Healium_ShowFocusCheck:SetChecked(Healium.ShowFocusFrame)
		Healium_UpdateShowFocusFrame()		
		Healium_UpdateFocusFrame()
		return
	end
	
	
	for i,j in ipairs(GroupFrames) do
		if frame == j then
			Healium.ShowGroupFrames[i] = show
			Healium_ShowGroup1Check:SetChecked(Healium.ShowGroupFrames[1])		
			Healium_ShowGroup2Check:SetChecked(Healium.ShowGroupFrames[2])				
			Healium_ShowGroup3Check:SetChecked(Healium.ShowGroupFrames[3])				
			Healium_ShowGroup4Check:SetChecked(Healium.ShowGroupFrames[4])				
			Healium_ShowGroup5Check:SetChecked(Healium.ShowGroupFrames[5])				
			Healium_ShowGroup6Check:SetChecked(Healium.ShowGroupFrames[6])				
			Healium_ShowGroup7Check:SetChecked(Healium.ShowGroupFrames[7])				
			Healium_ShowGroup8Check:SetChecked(Healium.ShowGroupFrames[8])				
			return
		end
	end	
end

function HealiumUnitFrames_Button_OnLoad(frame)
	frame.buttons = { }
	frame:RegisterForClicks("AnyUp", "AnyDown")	
	
	table.insert(Healium_Frames, frame)
	
	if Healium.EnableClique then
		ClickCastFrames[frame] = true	
	end

	-- configure buff frames
	frame.buffs = { }	

	local framename = frame:GetName()	
	for i=1, MaxBuffs, 1 do
		local buffframe = _G[framename.."_Buff"..i]
		local name = buffframe:GetName()
		buffframe.icon = _G[name.."Icon"]
		buffframe.cooldown = _G[name.."Cooldown"]
		buffframe.count = _G[name.."Count"]
		buffframe.border = _G[name.."Border"]
		buffframe.id = i
		frame.buffs[i] = buffframe
	end

	if InCombatLockdown() then
		frame.fixCreateButtons = true
		table.insert(Healium_FixNameplates, frame)
		Healium_DebugPrint("Unit frame created during combat. Its buttons will not be available until combat ends.")
	else
		if (not Healium.ShowPercentage) then frame.HealthBar.HPText:Hide() end	
		Healium_CreateButtonsForNameplate(frame)			
	end

	frame:RegisterForDrag("RightButton")
end

function HealiumUnitFrames_Button_OnShow(frame)
	-- Keyed by frame so OnHide can actually remove it again.
	Healium_ShownFrames[frame] = true
end	

function HealiumUnitFrames_Button_OnHide(frame)
	Healium_ShownFrames[frame] = nil
	
	local parent = frame:GetParent()
	
	if not frame.isCustom then 
		parent = parent:GetParent()
	end
	
	if parent.childismoving then
		parent:StopMovingOrSizing()		
		parent.childismoving = nil
	end

end	

function HealiumUnitFrames_Button_OnAttributeChanged(frame, name, value)
	if name == "unit" or name == "unitsuffix" then
		local newUnit = SecureButton_GetUnit(frame)
		local oldUnit = frame.TargetUnit
		
		Healium_DebugPrint(newUnit)
		
--		if newUnit == oldUnit then
--			return
--		end
		
		if newUnit then
			-- update cooldowns
			Healium_UpdateButtonCooldownByUnitFrame(frame)

			if not Healium_Units[newUnit] then
				Healium_Units[newUnit] = { }
			end
			
			table.insert(Healium_Units[newUnit], frame)

			for i =1, MaxBuffs, 1 do
				frame.buffs[i].unit = newUnit
			end
			
			Healium_UpdateManaBarVisibility(frame) -- This is important to do here.
			Healium_UpdateUnitName(newUnit, frame)
			Healium_UpdateUnitHealth(newUnit, frame)
			Healium_UpdateUnitMana(newUnit, frame)
			Healium_UpdateUnitBuffs(newUnit, frame)		
			Healium_UpdateUnitThreat(newUnit, frame)
			Healium_UpdateUnitRole(newUnit, frame)
			Healium_UpdateSpecialBuffs(newUnit)
			Healium_UpdateRaidTargetIcon(frame)

			if not Healium.ShowIncomingHeals then
				frame.PredictBar:Hide()
			end

		end
		
		if oldUnit then
			if Healium_Units[oldUnit] then
				for i,v in ipairs(Healium_Units[oldUnit]) do
					if v == frame then
						table.remove(Healium_Units[oldUnit], i)
						break
					end
				end
			end
		end
	
		frame.TargetUnit = newUnit
	end
end

function HealiumUnitFrames_Button_OnMouseDown(frame, button)
	if button == "RightButton" and not Healium.LockFrames then
		local parent = frame:GetParent()
		
		if not frame.isCustom then 
			parent = parent:GetParent()
		end

		parent.childismoving = true
		parent:StartMoving()	
	end
end

function HealiumUnitFrames_Button_OnMouseUp(frame, button)
	if button == "RightButton" then
		local parent = frame:GetParent()
		
		if not frame.isCustom then 
			parent = parent:GetParent()
		end

		parent:StopMovingOrSizing()		
		parent.childismoving = nil
	end	
end

local function IsAnyUnitFrameVisible()
	local visible
	
	for _,j in pairs(UnitFrames) do
		if j:IsShown() then 
			return true
		end
	end

	return nil
end

-- if forceHide is not specified it is a true toggle
-- if forceHide is true then frames will be hidden, not toggled
function Healium_ToggleAllFrames(forceHide, silent)
	if InCombatLockdown() then
		Healium_Warn("Can't toggle frames while in combat.")
		return
	end
	
	local hide = false
	
	if forceHide ~= nil then
		hide = forceHide
	else
		if PartyFrame:IsShown() then hide = true end
		if PetsFrame:IsShown() then hide = true end
		if MeFrame:IsShown() then hide = true end
		if FriendsFrame:IsShown() then hide = true end
		if DamagersFrame:IsShown() then hide = true end
		if HealersFrame:IsShown() then hide = true end
		if TanksFrame:IsShown() then hide = true end
		if TargetFrame:IsShown() then hide = true end
		
		if not Healium_IsClassic then 
			if FocusFrame:IsShown() then hide = true end
		end

		for i,j in ipairs(GroupFrames) do
			if j:IsShown() then
				hide = true
				break
			end
		end
	end
	
	if hide then
		PartyFrameWasShown = PartyFrame:IsShown()
		PetsFrameWasShown = PetsFrame:IsShown()	
		MeFrameWasShown = MeFrame:IsShown()
		FriendsFrameWasShown = FriendsFrame:IsShown()
		DamagersFrameWasShown = DamagersFrame:IsShown()		
		HealersFrameWasShown = HealersFrame:IsShown() 
		TanksFrameWasShown = TanksFrame:IsShown()
		TargetFrameWasShown = TargetFrame:IsShown()
		
		if not Healium_IsClassic then 
			FocusFrameWasShown = FocusFrame:IsShown()
		end
	
		PartyFrame:Hide()
		PetsFrame:Hide()
		MeFrame:Hide()
		FriendsFrame:Hide()
		DamagersFrame:Hide()
		HealersFrame:Hide()
		TanksFrame:Hide()
		TargetFrame:Hide()
		
		if not Healium_IsClassic then 
			FocusFrame:Hide()
		end
		
		for i,j in ipairs(GroupFrames) do
			GroupFramesWasShown[i] = j:IsShown()
			j:Hide()
		end
		
		if not silent then 
			Healium_Print("Current frames are now hidden.")
		end

		return
	end
	
	-- after this point, we know we are showing frames
	
	if PartyFrameWasShown then PartyFrame:Show() end
	if PetsFrameWasShown then PetsFrame:Show() end
	if MeFrameWasShown then MeFrame:Show() end
	if FriendsFrameWasShown then FriendsFrame:Show() end
	if DamagersFrameWasShown then DamagersFrame:Show() end
	if HealersFrameWasShown then HealersFrame:Show() end
	if TanksFrameWasShown then TanksFrame:Show() end
	if TargetFrameWasShown then TargetFrame:Show() end
	
	if not Healium_IsClassic then 
		if FocusFrameWasShown then FocusFrame:Show() end
	end
	
	for i,j in ipairs(GroupFramesWasShown) do
		if j then
			GroupFrames[i]:Show()
		end
	end
	
	if IsAnyUnitFrameVisible() == nil then
		PartyFrame:Show()
		PetsFrame:Show()
	end
	
	if not silent then 
		Healium_Print("Current frames are now shown.")	
	end
end

function Healium_ShowHidePartyFrame(show)
	if PartyFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowPartyFrame = show end
	
	if Healium.ShowPartyFrame then
		PartyFrame:Show()
	else
		PartyFrame:Hide()
	end
end

function Healium_ShowHidePetsFrame(show)
	if PetsFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowPetsFrame = show end
	
	if Healium.ShowPetsFrame then
		PetsFrame:Show()
	else
		PetsFrame:Hide()
	end
end

function Healium_ShowHideMeFrame(show)
	if MeFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowMeFrame = show end
	
	if Healium.ShowMeFrame then
		MeFrame:Show()
	else
		MeFrame:Hide()
	end
end

function Healium_ShowHideFriendsFrame(show)
	if FriendsFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowFriendsFrame = show end
	
	if Healium.ShowFriendsFrame then
		FriendsFrame:Show()
	else
		FriendsFrame:Hide()
	end
end

function Healium_ShowHideDamagersFrame(show)
	if DamagersFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowDamagersFrame = show end
	
	if Healium.ShowDamagersFrame then
		DamagersFrame:Show()
	else
		DamagersFrame:Hide()
	end
end

function Healium_ShowHideHealersFrame(show)
	if HealersFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowHealersFrame = show end
	
	if Healium.ShowHealersFrame then
		HealersFrame:Show()
	else
		HealersFrame:Hide()
	end
end

function Healium_ShowHideTanksFrame(show)
	if TanksFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowTanksFrame = show end
	
	if Healium.ShowTanksFrame then
		TanksFrame:Show()
	else
		TanksFrame:Hide()
	end
end

function Healium_ShowHideTargetFrame(show)
	if TargetFrame == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowTargetFrame = show end
	
	if Healium.ShowTargetFrame then
		TargetFrame:Show()
	else
		TargetFrame:Hide()
	end

	Healium_UpdateShowTargetFrame()
end

function Healium_ShowHideFocusFrame(show)
	if FocusFrame == nil then return end
	if Healium_IsClassic then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowFocusFrame = show end
	
	if Healium.ShowFocusFrame then
		FocusFrame:Show()
	else
		FocusFrame:Hide()
	end
	
	Healium_UpdateShowFocusFrame()	
end

function Healium_ShowHideGroupFrame(group, show)
	if GroupFrames == nil then return end 
	if GroupFrames[group] == nil then return end
	if InCombatLockdown() then return end
	if (show ~= nil) then Healium.ShowGroupFrames[group] = show end
	
	if Healium.ShowGroupFrames[group] then
		GroupFrames[group]:Show()
	else
		GroupFrames[group]:Hide()
	end
end

function Healium_HideAllRaidFrames()
	if InCombatLockdown() then return end
--	TanksFrame:Hide()
	for i,j in ipairs(GroupFrames) do
		if j ~= nil then 
			j:Hide()
		end
	end
end

function Healium_ShowAllRaidFramesWithMembers()
end
		
function Healium_Show10ManRaidFrames()
	if (GroupFrames == nil) or (GroupFrames[1]) == nil or (GroupFrames[2]) == nil then return end
	if InCombatLockdown() then return end
	GroupFrames[1]:Show()
	GroupFrames[2]:Show()
end

function Healium_Show25ManRaidFrames()
	if GroupFrames == nil then return end
	if InCombatLockdown() then return end
	for i=1, 5, 1 do
		if GroupFrames[i] ~= nil then 
			GroupFrames[i]:Show()
		end
	end
end

function Healium_Show40ManRaidFrames()
	if GroupFrames == nil then return end
	if InCombatLockdown() then return end
	for i=1, 8, 1 do
		if GroupFrames[i] ~= nil then 	
			GroupFrames[i]:Show()
		end
	end
end

function Healium_CreateUnitFrames()
	PartyFrame = CreatePartyUnitFrame("HealiumPartyFrame", "Party")
	PetsFrame = CreatePetUnitFrame("HealiumPetFrame", "Pets")
	MeFrame = CreateMeUnitFrame("HealiumMeFrame", "Me")
	FriendsFrame = CreateFriendsUnitFrame("HealiumFriendsFrame", "Friends")
	DamagersFrame = CreateDamagersUnitFrame("HealiumDamagersFrame", "Damagers")
	HealersFrame = CreateHealersUnitFrame("HealiumHealersFrame", "Healers")
	TanksFrame = CreateTanksUnitFrame("HealiumTanksFrame", "Tanks")
	TargetFrame = CreateTargetUnitFrame("HealiumTargetFrame", "Target")
	
	if not Healium_IsClassic then 
		FocusFrame = CreateFocusUnitFrame("HealiumFocusFrame", "Focus")
	end
	
	for i=1, 8, 1 do
		GroupFrames[i] = CreateGroupUnitFrame("HealiumGroup" .. i .. "Frame", "Group " .. i, tostring(i))
		GroupFramesWasShown[i]  = false
	end	
	
end


function Healium_SetScale()
	local Scale = Healium.Scale
	
	PartyFrame:SetScale(Scale)
	PetsFrame:SetScale(Scale)	
	MeFrame:SetScale(Scale)
	FriendsFrame:SetScale(Scale)
	DamagersFrame:SetScale(Scale)
	HealersFrame:SetScale(Scale)
	TanksFrame:SetScale(Scale)
	TargetFrame:SetScale(Scale)
	
	if not Healium_IsClassic then 
		FocusFrame:SetScale(Scale)
	end
	
	for i,j in ipairs(GroupFrames) do
		j:SetScale(Scale)
	end	
end

function Healium_MakeRankedSpellName(spellName, spellSubtext)
	local rankedSpellName
	
	if spellSubtext == "" then
		spellSubtext = nil
	end
		
	if spellSubtext then
		rankedSpellName = spellName .. "(" .. spellSubtext .. ")"
	else
		rankedSpellName = spellName
	end
	
	return rankedSpellName
end

local function FindAuraInstanceID(auras, spellId)
	for i,j in pairs(auras) do
		if (spellId == j.spellId) and (j.sourceUnit == "player")  then 
			return j.auraInstanceID
		end
	end	
	
	return nil
end
		
function Healium_UpdateUnitBuffs(unit, frame)

	local buffIndex = 1
	local Profile = Healium_GetProfile()

	local Auras = {}
	
	if Healium_IsRetail then
		local function HandleAura(aura)
			Auras[aura.auraInstanceID] = aura
		end

		local batchCount = nil
		local usePackedAura = true
		AuraUtil.ForEachAura(unit, "HELPFUL", batchCount, HandleAura, usePackedAura)
	end


	if Healium.ShowBuffs then
		for i=1, 100, 1 do
			local aura = C_UnitAuras.GetBuffDataByIndex(unit, i, "HELPFUL")
			--local name, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId = UnitBuff(unit, i)
			if aura then 
				local name = aura.name
				if (aura.sourceUnit == "player") then
					
					if GetArmedBuffNames()[name] then
						local buffFrame = frame.buffs[buffIndex]

						buffFrame:SetID(i)
						
						if Healium_IsRetail then
							local auraInstanceID = FindAuraInstanceID(Auras, aura.spellId)
							--print("auraInstanceID = ", auraInstanceID)
							if auraInstanceID then
								buffFrame.auraInstanceID = auraInstanceID
							else 
								buffFrame.auraInstanceID = 0
							end						
						end

						
						buffFrame.icon:SetTexture(aura.icon)

						if aura.applications and aura.applications > 1 then
							buffFrame.count:SetText(aura.applications)
							buffFrame.count:Show()
						else
							buffFrame.count:Hide()
						end
						
						if aura.duration and aura.duration > 0 then
							local startTime = aura.expirationTime - aura.duration
							buffFrame.cooldown:SetCooldown(startTime, aura.duration)
							buffFrame.cooldown:Show()
						else
							buffFrame.cooldown:Hide()
						end
						
						buffFrame:Show()
						buffIndex = buffIndex + 1					
						if buffIndex > MaxBuffs then
							break
						end			
						
					end
				end
			else
				break
			end
		end
	end

	-- hide remainder frames
	for i = buffIndex, MaxBuffs, 1 do
		frame.buffs[i]:Hide()
	end
	
	-- Handle affliction notification
	if Healium.EnableDebufs then
	
		local foundDebuff = false
		local debuffTypes = { } 
		
		for i = 1, 40, 1 do
			--local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff(unit, i)
			local aura = C_UnitAuras.GetDebuffDataByIndex(unit, i, "HARMFUL")
			
			if aura == nil then 
				break
			end
			
			local name = aura.name
			
			if name == nil then
				break
			end
			
			local debuffType = aura.dispelName
			
						
			if debuffType ~= nil then
				Healium_DebugPrint(name .. " debuf is " .. debuffType)
				if Healium_CanCureDebuff(debuffType) then
					foundDebuff = true
					debuffTypes[debuffType] = true
					local debuffColor = Healium_DebuffTypeColor[debuffType] or Healium_DebuffTypeColor["None"];
					frame.hasDebuf = true
					frame.debuffColor = debuffColor
					
					if Healium.EnableDebufHealthbarHighlighting then
						frame.CurseBar:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
						frame.CurseBar:SetAlpha(1)
					end	
					
					if Healium.EnableDebufAudio then 
						local now = GetTime()
						if unit == "player" or UnitInRange(unit) then -- UnitInRange will return false for "player"
							if now > (LastDebuffSoundTime + 7) then
								Healium_PlayDebuffSound()
								LastDebuffSoundTime = now
							end
						end
					end
				end
			end
		end
		
		if (not foundDebuff) and frame.hasDebuf then
			frame.CurseBar:SetAlpha(0)
			frame.hasDebuf = nil
		end
		
		if Healium.EnableDebufButtonHighlighting then 
			Healium_ShowDebuffButtons(Profile, frame, debuffTypes)		
		end
		
		Healium_UpdateUnitHealth(unit, frame)
	end
end

function Healium_UpdateEnableDebuffs()
	for _,j in pairs(UnitFrames) do
		if j.hasDebuf then
			frame.CurseBar:SetAlpha(0)
			frame.hasDebuf = nil
			
			for i=1, Healium_MaxButtons, 1 do
				local button = frame.button[i]
				if button then
					button.curseBar:SetAlpha(0)
					button.curseBar.hasDebuf = nil
				end
			end
		end	
	end
end

function Healium_ManaStatusBar_OnLoad(frame)
	frame:SetRotatesTexture(true)
	frame:SetOrientation("VERTICAL")
end

function Healium_UpdateEnableClique()
	for _,k in ipairs(Healium_Frames) do
		if Healium.EnableClique then
			ClickCastFrames[k] = true	
		else
			ClickCastFrames[k] = nil
			k:SetAttribute("type1", "target")
		end
	end
end

function Healium_ResetAllFramePositions()
	for _,k in ipairs(UnitFrames) do
		k:SetUserPlaced(false)
		k:ClearAllPoints()
		k:SetPoint("Center", UIParent, 0,0)
	end
	Healium_Print("Reset frame positions complete.")
end

function Healium_UpdateFriends()
	local names = ""
	for k, v in pairs(HealiumGlobal.Friends) do
		if names:len() > 0 then
			names = names .. "," .. v
		else
			names = v
		end
	end
	Healium_DebugPrint("namesList: " ..names)
	FriendsFrame.hdr:SetAttribute("nameList", names)
--	Healium_DebugPrint("Friends header is shown: " .. FriendsFrame.hdr:IsShown())	
end

function Healium_UpdateTargetFrame()
	HealiumUnitFrames_Button_OnAttributeChanged(TargetFrame.hdr, "unit")
end

function Healium_UpdateFocusFrame()
	if Healium_IsClassic then return end
	HealiumUnitFrames_Button_OnAttributeChanged(FocusFrame.hdr, "unit")
end
