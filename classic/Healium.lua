-- Healium - Maintained by Engee of Durotan.  Based on FB Healbox by Dourd of Argent Dawn EU
--
-- Programming notes
-- WARNING In LUA all logical operators consider false and nil as false and anything else as true.  This means not 0 is false!!!!!!!!
-- Color control characters |CAARRGGBB  then |r resets to normal, where AA == Alpha, RR = Red, GG = Green, BB = blue
-- To get the wow interface number use /run print((select(4, GetBuildInfo())))
-- Interface folders:
-- _classic_era_ = Classic
-- _classic_ = Cata Classic, used to be LK Classic
-- _retail_ = mainline 

Healium_Debug = false

HealiumDropDown = {} -- the dropdown menus on the config panel

-- Constants
local LowHP = 0.6
local VeryLowHP = 0.3
local NamePlateWidth = 120
local _, HealiumClass = UnitClass("player")
local _, HealiumRace = UnitRace("player")
local MaxParty = 5 -- Max number of people in party
local MinRangeCheckPeriod = .2 -- .2 = 5Hz
local MaxRangeCheckPeriod = 2  -- 2 = .5Hz
local DefaultRangeCheckPeriod = .5
local DefaultButtonCount = 5

local LoadedTime = 0
local stable

-- Global Constants
Healium_IsClassic = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC
Healium_IsClassicBCC = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
Healium_IsClassicLK = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC
Healium_IsClassicCata = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CATACLYSM_CLASSIC
Healium_IsClassicMists = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MISTS_CLASSIC
Healium_IsRetail = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE
Healium_MaxButtons = 15		-- Max Possible buttons 
Healium_AddonName = "Healium"
Healium_AddonColor = "|cFF55AAFF"
Healium_AddonColoredName = Healium_AddonColor .. Healium_AddonName .. "|r"
Healium_MaxClassSpells = 20 -- For now this is manually set to the max number of class specific spells in Healium_Spell.Name which currently is priest

Healium_Type_Spell = 0  -- note that nil also means Spell!  This is because we don't init the Spelltypes table.
Healium_Type_Macro = 1
Healium_Type_Item = 2

Healium_DebuffTypeColor = {
    Magic   = { r = 0.2, g = 0.6, b = 1.0 },  -- blue
    Curse   = { r = 0.6, g = 0.0, b = 1.0 },  -- purple
    Disease = { r = 0.6, g = 0.4, b = 0.0 },  -- brown
    Poison  = { r = 0.0, g = 0.6, b = 0.0 },  -- green
	None    = { r = 1.0, g = 1.0, b = 0.0 },  -- default/yellow	
	Secret  = { r = 0.6, g = 0.0, b = 1.0 },  -- purple
}
	
local HealiumDefaults = {
  Scale = 1.0,									-- Scale of frames
  DoRangeChecks = true,							-- Whether or not to do range checks on buttons 
  RangeCheckPeriod = .5,						-- Time period between range checks  
  EnableCooldowns = true,						-- Whether or not to do cooldown animations on buttons
  ShowToolTips = true,							-- Whether or not to display a tooltip for the spell when hovering over buttons
  ShowPercentage = true,						-- Whether or not to display the health percentage
  UseClassColors = false,						-- Whether or not to color the healthbar the color of the class instead of green/yellow/red
  ShowDefaultPartyFrames = false,				-- Whether or not to show the default party frames
  ShowPartyFrame = true,						-- Whether or not to show the party frame
  ShowPetsFrame = true,							-- Whether or not to show the pets frame
  ShowMeFrame = false,  						-- Whether or not to show the me frame
  ShowFriendsFrame = false,						-- Whether or not to show the friends frame
  ShowGroupFrames = { },  						-- Whether or not to show individual group frame
  ShowDamagersFrame = false,			     	-- Whether or not to show the Damagers frame
  ShowHealersFrame = false,						-- Whether or not to show the Heals frame
  ShowTanksFrame = false,						-- Whether or not to show the Tanks frame
  ShowTargetFrame = false,						-- Whether or not to show the target frame
  ShowFocusFrame = false,						-- Whether or not to show the focus frame
  ShowBuffs = true,								-- Whether or not to show your own buffs, that are configured in Healium to the left of the healthbar
  HideCloseButton = false,						-- Whether or not to hide the close (X) button, to prevent accidental closing of the Healium Frame
  HideCaptions = false,							-- Whether or not to hide the caption when the mouse leaves the caption area
  LockFrames = false,							-- Whether or not to prevent dragging of the frame
  EnableClique = false,							-- Whether or not to enable Clique support on the health bars
  EnableDebufs = true,							-- Whether or not to enable the debuf warning system
  EnableDebufAudio = true,						-- Whether or not to enable playing an audio file when a person has a debuf which the player can cure
  DebufAudioFile = nil,							-- The debuf audio file to play
  EnableDebufHealthbarHighlighting = true,		-- Whether or not to highlight the healthbar of a player when they have a debuf which you can cure
  EnableDebufButtonHighlighting = true,			-- Whether or not to highlight buttons which are assigned a spell that can cure a debuff on a player
  EnableDebufHealthbarColoring = false,			-- Whether or not to color the heatlhbar of a player when they have a debuf which you can cure
  ShowMana = true,								-- Whether or not to show mana
  ShowThreat = true,							-- Whether or not to show the threat warnings
  ShowRole = not Healium_IsClassic,				-- Whether or not to show the role icon
  ShowIncomingHeals = true,						-- Whether or not to show incoming heals
  ShowRaidIcons = true,							-- Whether or not to show raid icons
  UppercaseNames = true,						-- Whether or not to show names in UPPERCASE
  ShowMinimapButton = true						-- Whether or not to show the minimap button
}

function Healium_DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- Healium holds per character settings
Healium = Healium_DeepCopy(HealiumDefaults)

-- HealiumGlobal is the variable that holds all Healium settings that are not character specific
HealiumGlobal = {
  Friends = { },								-- List of healium friends
}

--[[
Healium.Profiles is a table of tables with this signature
{
	ButtonCount -- Current button count (as set by slider)
	PartyFrameOrder -- Party frame ordering: "DEFAULT" or "TANK_HEALER_DPS"
	SpellNames -- Table of current spell names
	SpellIcons -- Table of current spell icons
	SpellTypes -- One of the Healium_Type_ (new in Healium 2.0)
	SpellRank -- Spell subtext if it has subtext, or nil (new in Healium 2.7.0)
	IDs -- item ID when SpelType is Healium_Type_Item
}
TODO refactor Healium.Profiles to instead contain a single table named Spells which contain a variable for each of the above tables 
]]


-- NEW FRAMES VARIABLES
Healium_Units = { { } } -- table of tables that maps unit names to their frame, used for efficient handling of UNIT_HEALTH so each button doesn't get a UNIT_HEALTH event for every unit.
Healium_Frames = { } -- table of all created "unit" frames.  Can access buttons from each of these.
Healium_ShownFrames = { } -- table of all shown "unit" frames.
Healium_FixNameplates = { } -- nameplates that need various updates when out of combat

--[[
List of spells, icons for the spells, and SlotIDs. 
These only contain specifically selected spells in HealiumSpells.lua
The Name gets filled in in Healium_InitSpells(). Healium_UpdateSpells() will fill in the ID and Icon if
the player actually has the spell.
--]]
Healium_Spell = {		
  Name = {},
  Icon = {},
  ID = {} -- This is the spell SlotID (spellbook index), not the global SpellID
}

function Healium_GetSpellName(spellID)
	local name
	
	if Healium_IsRetail then 
		name = C_Spell.GetSpellName(spellID)
	else
		name = GetSpellInfo(spellID)
	end
	
	return name	
end



-- locale safe versions of spell names
local ActivatePrimarySpecSpellName = Healium_GetSpellName(63645)
local ActivateSecondarySpecSpellName = Healium_GetSpellName(63644) 
local PWSName = Healium_GetSpellName(17) -- Power Word: Shield
local WeakendSoulName = Healium_GetSpellName(6788) -- Weakened Soul
local SwiftMendName = Healium_GetSpellName(18562) -- Swift Mend
local RejuvinationName = Healium_GetSpellName(774) -- Rejuvenation
local RegrowthName = Healium_GetSpellName(8936) -- Regrowth
local WildGrowthName = Healium_GetSpellName(48438) -- Wild Growth

local HealiumFrame = nil

function Healium_Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(Healium_AddonColor .. Healium_AddonName .. "|r " .. tostring(msg))		
end

function Healium_TableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function Healium_DebugPrint(...)
	if (Healium_Debug) then
		local result = "Debug: "
		
		for i = 1, select("#", ...) do 
			result = result .. " " .. tostring(select(i, ...))
		end
	
		Healium_Print(result)		
	end
end

function Healium_Warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000Warning|r: " .. tostring(msg))		
end

function Healium_GetProfile()
	local currentSpec

	if Healium_IsClassicMists then 
		currentSpec = GetActiveTalentGroup(false, false)
	elseif Healium_IsRetail then 
		currentSpec = GetSpecialization()
	end
	
	if not currentSpec then
		currentSpec = 1
	end
	
	return Healium.Profiles[currentSpec] 
end

function Healium_SetProfileSpell(profile, index, spellName, spellID, spellIcon, spellRank)
	profile.SpellNames[index] = spellName
	profile.SpellIcons[index] = spellIcon
	profile.SpellTypes[index] = Healium_Type_Spell
	profile.SpellRanks[index] = spellRank
	profile.IDs[index] = spellID
end

function Healium_SetProfileItem(profile, index, itemName, itemID, itemIcon)
	profile.SpellNames[index] = itemName
	profile.SpellIcons[index] = itemIcon
	profile.SpellTypes[index] = Healium_Type_Item
	profile.SpellRanks[index] = nil	
	profile.IDs[index] = itemID
end

function Healium_SetProfileMacro(profile, index, macroName, macroID, macroIcon)
	profile.SpellNames[index] = macroName
	profile.SpellIcons[index] = macroIcon
	profile.SpellTypes[index] = Healium_Type_Macro
	profile.SpellRanks[index] = nil
	profile.IDs[index] = macroID
end

function Healium_OnLoad(frame)
	HealiumFrame = frame
 	Healium_Print(Healium_Version.." |cFF00FF00Loaded |rClick The MiniMap button for options.")
	Healium_Print("Type " .. Healium_Slash .. " for a list of slash commands." )	

 	-- Do not use the VARIABLES_LOADED event for anything meaningful since VARIABLES_LOADED's order can no longer be relied upon. (it kind of seems random to me)	
	HealiumFrame:RegisterEvent("ADDON_LOADED")
	HealiumFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	HealiumFrame:RegisterEvent("SPELLS_CHANGED")
	if Healium_IsRetail then 
		HealiumFrame:RegisterEvent("UNIT_HEALTH")
		HealiumFrame:RegisterEvent("PET_BATTLE_OPENING_START")
		HealiumFrame:RegisterEvent("PET_BATTLE_CLOSE")
	else
		HealiumFrame:RegisterEvent("UNIT_HEALTH_FREQUENT")
	end
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_SENT")	
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	HealiumFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	HealiumFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	HealiumFrame:RegisterEvent("UNIT_NAME_UPDATE")
	HealiumFrame:RegisterEvent("UNIT_AURA")
	HealiumFrame:RegisterEvent("PLAYER_LOGIN")	
	
	if not Healium_IsClassic then
		HealiumFrame:RegisterEvent("PLAYER_TALENT_UPDATE")		
	end
end

local function Healium_ShowHidePercentage(frame)
	if Healium.ShowPercentage and (frame.HasRole == nil) then
		frame.HealthBar.HPText:Show()
	else
		frame.HealthBar.HPText:Hide()
	end
end

function Healium_UpdatePercentageVisibility()
	for _, k in ipairs(Healium_Frames) do
		Healium_ShowHidePercentage(k)
	end
end

-- Sets the health bar color based on the unit's health ONLY
local function UpdateHealthBar(HPPercent, frame)
	if (HPPercent > LowHP) then 
		frame.HealthBar:SetStatusBarColor(0,1,0,1) 
	end
	if (HPPercent < LowHP) then 
		frame.HealthBar:SetStatusBarColor(1,0.9,0,1) 
	end
	if (HPPercent < VeryLowHP) then
		frame.HealthBar:SetStatusBarColor(1,0,0,1) 
	end
end

function Healium_UpdateClassColors()
	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			if UnitExists(k.TargetUnit) then
				if Healium.UseClassColors then
					local class = select(2, UnitClass(k.TargetUnit)) or "WARRIOR"
					local color = RAID_CLASS_COLORS[class]
					k.HealthBar:SetStatusBarColor(color.r, color.g, color.b)		
				else
					local Health = UnitHealth(k.TargetUnit)
					local MaxHealth = UnitHealthMax(k.TargetUnit)

					-- Guarded the way Healium_UpdateUnitHealth already does: without
					-- this the result is nan, every comparison in UpdateHealthBar
					-- fails and the bar silently keeps its previous colour.
					local HPPercent = 0
					if MaxHealth > 0 then HPPercent = Health / MaxHealth end
					UpdateHealthBar(HPPercent, k)
				end
			end
		end
	end
end

function Healium_UpdateUnitName(unitName, NamePlate)
	if not NamePlate then return end
	if not UnitExists(unitName) then return end

	local playerName = UnitName(unitName)
	
	if playerName ~= nil and Healium.UppercaseNames then
		playerName = strupper(playerName)
	end
	
	NamePlate.HealthBar.name:SetText(playerName)
end

function Healium_UpdateUnitNames()
	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			Healium_UpdateUnitName(k.TargetUnit, k)
		end
	end
end

function Healium_UpdateUnitHealth(unitName, NamePlate)
	if not unitName then return end
	if not NamePlate then return end
	if not UnitExists(unitName) then return end
		
	local Health = UnitHealth(unitName)
	local MaxHealth = UnitHealthMax(unitName)
	
	local isDead 
		
	if UnitIsDeadOrGhost(unitName) then
		Health = 0
		isDead = 1
	end
	
	local HPPercent 
	
	if MaxHealth == 0 then 
		Health = 0
		HPPercent = 0
	else
		HPPercent = Health / MaxHealth
	end	 
	
	if HPPercent > 1 then 
		HPPercent = 1
	end
	
	if HPPercent < 0 then
		HPPercent = 0
	end
	
	if isDead then
		NamePlate.HealthBar.HPText:SetText( "dead" )	
	else
		NamePlate.HealthBar.HPText:SetText( format("%.1i%%", HPPercent*100))
	end
	
	NamePlate.HealthBar:SetMinMaxValues(0,MaxHealth)
	NamePlate.HealthBar:SetValue(Health)
	
	if Healium.EnableDebufs and Healium.EnableDebufHealthbarColoring and NamePlate.hasDebuf then
		NamePlate.HealthBar:SetStatusBarColor(NamePlate.debuffColor.r, NamePlate.debuffColor.g, NamePlate.debuffColor.b)					
	elseif Healium.UseClassColors then
		local class = select(2, UnitClass(unitName)) or "WARRIOR"
		local color = RAID_CLASS_COLORS[class]
		NamePlate.HealthBar:SetStatusBarColor(color.r, color.g, color.b)					
	else
		UpdateHealthBar(HPPercent, NamePlate)
	end
	
	-- incoming heals
	
	if Healium.ShowIncomingHeals then
		local IncomingHealth = UnitGetIncomingHeals(unitName)

		if IncomingHealth then
			Health = Health + IncomingHealth
		else
			Health = 0
		end

		NamePlate.PredictBar:SetMinMaxValues(0,MaxHealth)
		NamePlate.PredictBar:SetValue(Health)
	end
end

function Healium_UpdateUnitMana(unitName, NamePlate)
	if not Healium.ShowMana then return end
	if not NamePlate then return end
	if not UnitExists(unitName) then return end
	
	local Mana = UnitPower(unitName, Enum.PowerType.Mana)
	local MaxMana = UnitPowerMax(unitName, Enum.PowerType.Mana)

	if Healium_Debug then Healium_DebugPrint("Mana: ", Mana, " MaxMana: ", MaxMana) end
	
	if UnitIsDeadOrGhost(unitName) then
		Mana = 0
	end
	
	local grayBar 
	
	if unitName == "player" then 
		grayBar = MaxMana == 0
		-- Can't use MaxMana to properly tell if a unit can have mana. 
		-- It will work fine if you're the player, but it will not work correctly for others when their primary power is not mana. For others it will always report their current Mana as 0, when their primary power is not mana.
		-- This check here prevents stuff like showing gray bar for yourself if you are elemental shaman
	else
		local _, powerType = UnitPowerType(unitName)
		if powerType ~= "MANA" then 
			grayBar = true
		end
	end

	if grayBar then
		-- unit can't have mana so set to gray mana bar
		if (NamePlate.showingMana) then
			if Healium_Debug then Healium_DebugPrint("Graying out manabar for " , unitName) end
			NamePlate.ManaBar:SetStatusBarColor( .5, .5, .5 )
			NamePlate.ManaBar:SetMinMaxValues(0,1)
			NamePlate.ManaBar:SetValue(1)
			NamePlate.showingMana = nil
		end
	else
		if not NamePlate.showingMana then
			if Healium_Debug then Healium_DebugPrint("Configuring manabar for " , unitName) end
			local powerColor = PowerBarColor["MANA"];
			NamePlate.ManaBar:SetStatusBarColor( powerColor.r, powerColor.g, powerColor.b )
			NamePlate.showingMana = true				
		end
		NamePlate.ManaBar:SetMinMaxValues(0,MaxMana)
		NamePlate.ManaBar:SetValue(Mana)
		if Healium_Debug then Healium_DebugPrint("Set ManaBar to: ", Mana, " MaxMana: ", MaxMana) end
	end
end

function Healium_UpdateShowMana()
	if Healium.ShowMana then
		HealiumFrame:RegisterEvent("UNIT_POWER_UPDATE")
		HealiumFrame:RegisterEvent("UNIT_DISPLAYPOWER")		
	else
		HealiumFrame:UnregisterEvent("UNIT_POWER_UPDATE")	
		HealiumFrame:UnregisterEvent("UNIT_DISPLAYPOWER")				
	end

	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			Healium_UpdateUnitMana(k.TargetUnit, k)
		end
		
		if InCombatLockdown() then
			k.fixShowMana = true
		else
			Healium_UpdateManaBarVisibility(k)
		end
	end
end

function Healium_UpdateManaBarVisibility(frame)
	if Healium.ShowMana then
		frame.ManaBar:Show()
		frame.HealthBar:SetWidth(111)
		frame.HealthBar:SetPoint("TOPLEFT", 7, -2)
		frame.PredictBar:SetWidth(111)
		frame.PredictBar:SetPoint("TOPLEFT", 7, -2)
	else
		frame.ManaBar:Hide()
		frame.HealthBar:SetWidth(116)			
		frame.HealthBar:SetPoint("TOPLEFT", 2, -2)
		frame.PredictBar:SetWidth(116)			
		frame.PredictBar:SetPoint("TOPLEFT", 2, -2)
	end		
	
	Healium_UpdateUnitHealth(frame.TargetUnit, frame)
end

function Healium_UpdateShowBuffs()
	-- Healium_ShownFrames is keyed by frame, not an array.
	for k in pairs(Healium_ShownFrames) do
		if (k.TargetUnit) then
			Healium_UpdateUnitBuffs(k.TargetUnit, k)
		end
	end	
end


function Healium_UpdateUnitThreat(unitName, NamePlate)
	if not NamePlate then return end
	if not UnitExists(unitName) then return end
	
	if Healium.ShowThreat == nil then
		NamePlate.AggroBar:SetAlpha(0)	
		return
	end
	
	local status = UnitThreatSituation(unitName)

	if status and status > 1 then 
		local r, g, b
		if Healium_IsClassic then
			r = 255
			g = 0
			b = 0
		else
			r, g, b = GetThreatStatusColor(status) -- GetThreatStatusColor not on classic. Is on LK classic.		
		end
		NamePlate.AggroBar:SetBackdropBorderColor(r,g,b,1)
		NamePlate.AggroBar:SetAlpha(1)
	else
		NamePlate.AggroBar:SetAlpha(0)
	end
end

function Healium_UpdateShowThreat()
	if Healium.ShowThreat then
		HealiumFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
	else
		HealiumFrame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
	end

	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			if Healium.ShowThreat then	
				Healium_UpdateUnitThreat(k.TargetUnit, k)
			else
				k.AggroBar:SetAlpha(0)				
			end
		end
	end
end


function Healium_UpdateUnitRole(unitName, NamePlate)
	if Healium_IsClassic then return end
	if not NamePlate then return end
	if not UnitExists(unitName) then return end
	
	local icon = NamePlate.HealthBar.RoleIcon
	
	if not Healium.ShowRole then
		icon:Hide()
		NamePlate.HasRole = nil
		Healium_ShowHidePercentage(NamePlate)
		return
	end
	
	local role = UnitGroupRolesAssigned(unitName);	
	
	if ( role == "TANK" or role == "HEALER" or role == "DAMAGER") then
		NamePlate.HasRole = true
		if Healium_IsRetail then 
			local enum = UnitGroupRolesAssignedEnum(unitName)
			icon:SetAtlas(GetMicroIconForRoleEnum(enum), TextureKitConstants.IgnoreAtlasSize);
		else
			icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
		end
		icon:Show()
	else
		NamePlate.HasRole = nil
		icon:Hide()
	end
	
	Healium_ShowHidePercentage(NamePlate)	
end

local function Healium_UpdateRoles()
	if Healium_IsClassic then return end
	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			Healium_UpdateUnitRole(k.TargetUnit, k)
		end
	end
end

function Healium_UpdateShowRole()
	if Healium_IsClassic then return end
	if Healium.ShowRole then
		HealiumFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	else
		HealiumFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
	end
	
	Healium_UpdateRoles()
end

function Healium_UpdateShowIncomingHeals()
	if Healium.ShowIncomingHeals then
		HealiumFrame:RegisterEvent("UNIT_HEAL_PREDICTION")
	else
		HealiumFrame:UnregisterEvent("UNIT_HEAL_PREDICTION")
	end
	
	for _, k in ipairs(Healium_Frames) do
		if Healium.ShowIncomingHeals then
			k.PredictBar:Show()
		else
			k.PredictBar:Hide()
		end
	end	
end

local function Healium_UpdateRaidIcons()
	for _, k in ipairs(Healium_Frames) do
		Healium_UpdateRaidTargetIcon(k)
	end	
end

function Healium_UpdateShowRaidIcons()
	if Healium.ShowRaidIcons then
		HealiumFrame:RegisterEvent("RAID_TARGET_UPDATE")
	else
		HealiumFrame:UnregisterEvent("RAID_TARGET_UPDATE")
	end
	
	Healium_UpdateRaidIcons()
end

function Healium_UpdateShowMinimapButton()
	if Healium.ShowMinimapButton then
		Healium_MMButton:Show()
	else
		Healium_MMButton:Hide()
	end
end

function Healium_UpdateShowTargetFrame()
	if Healium.ShowTargetFrame then 
		Healium_DebugPrint("registering PLAYER_TARGET_CHANGED")	
		HealiumFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	else
		Healium_DebugPrint("UNregistering PLAYER_TARGET_CHANGED")		
		HealiumFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")	
	end
end

function Healium_UpdateShowFocusFrame()
	if Healium_IsClassic then return end -- focus not on classic
	if Healium.ShowFocusFrame then 
		Healium_DebugPrint("registering PLAYER_FOCUS_CHANGED")
		HealiumFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	else
		Healium_DebugPrint("UNregistering PLAYER_FOCUS_CHANGED")	
		HealiumFrame:UnregisterEvent("PLAYER_FOCUS_CHANGED")	
	end
end

local function GetSpellCount()
	local tabs
	if Healium_IsRetail then 
		tabs = C_SpellBook.GetNumSpellBookSkillLines()
	else
		tabs = GetNumSpellTabs()
	end
	if tabs == nil then return 0 end
	local name, texture, offset, numSpells

	if Healium_IsRetail then 
		local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(tabs)
		if skillLineInfo then
			offset = skillLineInfo.itemIndexOffset
			numSpells = skillLineInfo.numSpellBookItems
		end
	else
		name, texture, offset, numSpells = GetSpellTabInfo(tabs)
	end
	if offset == nil or numSpells == nil then return 0 end
	return offset + numSpells
end

-- Spellbook slot lookups used to rescan the whole spellbook once per spell,
-- which cost thousands of API calls on every SPELLS_CHANGED.  The book is now
-- indexed once into SpellSlotCache and reused until the cache is invalidated.
local SpellSlotCache = nil

local function GetSpellBookName(index)
	if Healium_IsRetail then
		return C_SpellBook.GetSpellBookItemName(index, Enum.SpellBookSpellBank.Player)
	end

	return GetSpellBookItemName(index, BOOKTYPE_SPELL)
end

local function IsFutureSpellSlot(index)
	if Healium_IsRetail then
		local info = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
		return info and (info.itemType == Enum.SpellBookItemType.FutureSpell) or false
	end

	return GetSpellBookItemInfo(index, BOOKTYPE_SPELL) == "FUTURESPELL"
end

local function BuildSpellSlotCache()
	local cache = {}
	local count = GetSpellCount()

	for i = 1, count do
		local spellName, spellSubName = GetSpellBookName(i)

		if not spellName then
			break
		end

		local entries = cache[spellName]

		if not entries then
			entries = {}
			cache[spellName] = entries
		end

		table.insert(entries, { slot = i, subtext = spellSubName })

		if (i > 300) then
			break
		end
	end

	return cache
end

-- Must be called whenever the spellbook may have changed.
function Healium_InvalidateSpellSlotCache()
	SpellSlotCache = nil
end

local function GetSpellSlotID(spell, subtext)
	if spell == nil then return end
	--new check in MoP.
	--This is required because spells for other specs appear in the spell book and are disabled, and we don't want disabled spells appearing by default.
	--GetSpellInfo() will return nil for those disabled spells. 
	--Warning passing an index to GetSpellInfo() will still return a name for disabled spells, but passing the spell name causes it to return nil
	local name = Healium_GetSpellName(spell)
	if not name then
		return nil
	end

	Healium_DebugPrint("GetSpellSlotID: ", spell);

	-- Blizzard's own lookup understands spells that are listed more than once in
	-- the spellbook (the same heal also appearing under an inactive
	-- specialisation).  The scan below cannot: it stops at the first, disabled,
	-- copy and reports the spell as missing, which is why Flash Heal and Renew
	-- came back with no slot on a Discipline priest.
	if (subtext == nil or subtext == "") and C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spell)

		if info and info.spellID then
			local slot = C_SpellBook.FindSpellBookSlotForSpell(info.spellID)

			if slot then
				return slot
			end
		end
	end

	if not SpellSlotCache then
		SpellSlotCache = BuildSpellSlotCache()
	end

	local entries = SpellSlotCache[spell]

	if not entries then
		return nil
	end

	for _, entry in ipairs(entries) do
		-- A disabled/future rank ends the search, exactly as the original
		-- spellbook scan did when it ran into one.
		if IsFutureSpellSlot(entry.slot) then
			return nil
		end

		Healium_DebugPrint("spell: ", spell, "subtext:", entry.subtext);

		if not subtext then
			return entry.slot
		end

		if entry.subtext == subtext then
			return entry.slot
		end
	end

	return nil
end

-- Loops through Healium_Spell.Name[] and updates it's corresponding .ID[] and .Icon[]
-- Warning UpdateSpells() is a global function from Blizzard. 
-- This does not refresh the buttons: callers must follow it with
-- Healium_UpdateButtonAttributes() or Healium_UpdateButtons().  It used to do
-- that itself, which made SPELLS_CHANGED rebuild every button attribute (and
-- every retail Aura Container) twice in a row.
local function Healium_UpdateSpells()
	for k, v in ipairs (Healium_Spell.Name) do
		Healium_Spell.ID[k] = GetSpellSlotID(Healium_Spell.Name[k])
		if (Healium_Spell.ID[k]) then
			if Healium_IsRetail then
				Healium_Spell.Icon[k] = C_Spell.GetSpellTexture(Healium_Spell.Name[k])
			else
				Healium_Spell.Icon[k] = GetSpellTexture(Healium_Spell.ID[k], BOOKTYPE_SPELL)
			end
			Healium_DebugPrint("Found ID for Spell Name: " .. Healium_Spell.Name[k] .. " ID:" .. Healium_Spell.ID[k])
			Healium_DebugPrint("Texture: " .. Healium_Spell.Icon[k])
		else 
			Healium_DebugPrint("Could not find ID, Spell Name: ", Healium_Spell.Name[k])
			Healium_Spell.Icon[k] = nil
		end
	end 
end

-- SPELLS_CHANGED can fire many times in a row (login, talent swaps, procs).
-- Rebuilding every spell slot and every button on each one is wasted work, so
-- the updates are coalesced into a single pass.
local SpellsChangedPending = false

local function DoSpellsChangedUpdate()
	SpellsChangedPending = false

	if HealiumFrame and HealiumFrame.Respecing then return end

	Healium_InitSpells(HealiumClass, HealiumRace) -- I have observed swapping around talents not sending PLAYER_TALENT_UPDATE, but instead sending SPELLS_CHANGED, so we need to call this here to handle the case the talent effects cures
	Healium_InvalidateSpellSlotCache()
	Healium_UpdateSpells()
	Healium_UpdateButtons()
end

local function QueueSpellsChangedUpdate()
	Healium_InvalidateSpellSlotCache()

	if SpellsChangedPending then return end

	SpellsChangedPending = true
	C_Timer.After(0.2, DoSpellsChangedUpdate)
end

-- does special checks for specific buffs/debuffs
function Healium_UpdateSpecialBuffs(unit)

	if HealiumClass == "PRIEST" then 
		local Profile = Healium_GetProfile()
		
		for i=1, Profile.ButtonCount, 1 do				
		
			-- special check for Power Word: Shield		
			if Profile.SpellNames[i] == PWSName then 
				local units = Healium_Units[unit]

				if units then 	
					local name, _, _, _, weakendSoulduration, expirationTime, _, _, _, _, _, _, _, _, _ = AuraUtil.FindAuraByName(WeakendSoulName, unit)

					if name then 
						local startTime = expirationTime - weakendSoulduration										
				
						for _, frame in pairs(units) do 
							local button = frame.buttons[i]
							if button and button:IsShown() then
								button.cooldown:SetCooldown(startTime, weakendSoulduration)
							end
						end
					end
				end
			end
		end
		return
	end
	
	if HealiumClass == "DRUID" then
		local Profile = Healium_GetProfile()
		
		for i=1, Profile.ButtonCount, 1 do				
		
			-- special check for Swift Mend	
			if Profile.SpellNames[i] == SwiftMendName then 
				local units = Healium_Units[unit]

				if units then 	
					local buff1 = RejuvinationName and RejuvinationName ~= "" and AuraUtil.FindAuraByName(RejuvinationName, unit)
					local buff2 = RegrowthName and RegrowthName ~= "" and AuraUtil.FindAuraByName(RegrowthName, unit)
					local buff3 = WildGrowthName and WildGrowthName ~= "" and AuraUtil.FindAuraByName(WildGrowthName, unit)

					local enabled = buff1 or buff2 or buff3
					
					for _, frame in pairs(units) do 
						local button = frame.buttons[i]
						if button then
							if enabled then 
								button.icon.disabled = nil
								button.icon:SetVertexColor(1.0, 1.0, 1.0)
							else
								button.icon.disabled = true
								button.icon:SetVertexColor(0.4, 0.4, 0.4)
							end
						end
					end
					

				end
			end
		end
		return
		
	end	

end

-- Efficient cooldowns
local function GetCooldown(Profile, column)
	local start, duration, enable

	if Profile.IDs[column] ~= nil then 
		
		if Profile.SpellTypes[column] == Healium_Type_Macro then 
			local name = GetMacroSpell(Profile.SpellNames[column])
			if name then 
				if Healium_IsRetail then
					local spellCooldownInfo = C_Spell.GetSpellCooldown(name)
					if spellCooldownInfo == nil then return end					
					start = spellCooldownInfo.startTime
					duration = spellCooldownInfo.duration
					enable = spellCooldownInfo.isEnabled

				else
					start, duration, enable = GetSpellCooldown(name)
				end
			else
				enable = false
			end
		elseif Profile.SpellTypes[column] == Healium_Type_Item then
			-- Handle "item" cooldowns
			GetItemInfo(Profile.SpellNames[column])
			start, duration, enable = C_Container.GetItemCooldown(Profile.IDs[column])
		else
			-- Handle "spell" cooldowns	
			local name = Profile.SpellNames[column]
			if name then 
				-- GetSpellCooldown doesn't seem to work with slotIDs but does with ranked spell names
				local rankedSpellName = Healium_MakeRankedSpellName(Profile.SpellNames[column], Profile.SpellRanks[column])
				if Healium_IsRetail then
					local spellCooldownInfo = C_Spell.GetSpellCooldown(name)
					if spellCooldownInfo == nil then return end
					start = spellCooldownInfo.startTime
					duration = spellCooldownInfo.duration
					enable = spellCooldownInfo.isEnabled

				else
					start, duration, enable = GetSpellCooldown(name)
				end
			else
				enable = false
			end
		end
	end
	
	return start, duration, enable
end

function Healium_UpdateButtonCooldown(frame, start, duration, enable)
	if frame then 
		if frame:IsShown() and stable then 
		
			-- temp fix for lua errors caused in patch 5.1.. Somehow these values are sometimes invalid for a few seconds after loading, and these explicit checks seem to fix it
			if start == nil then
				start = GetTime()
			end
			
			if duration == nil then
				duration = 0
			end

			if enable == nil then 
				enable = 0
			end		
			
			CooldownFrame_Set(frame.cooldown, start, duration, enable) 
		end
	end
end

function Healium_UpdateButtonCooldownByUnitFrame(frame)
	local Profile = Healium_GetProfile()
	local count = Profile.ButtonCount
	
	for i=1, count do
		local start, duration, enable = GetCooldown(Profile, i)
		if start == nil or duration == nil then return end
		local button = frame.buttons[i]
		if button then 
			Healium_UpdateButtonCooldown(button, start, duration, enable)
		end
	end	
end

function Healium_UpdateButtonCooldownsByColumn(column)
	local Profile = Healium_GetProfile()
	
	local start, duration, enable = GetCooldown(Profile, column)
	if start == nil or duration == nil then return end
	for unit, j in pairs(Healium_Units) do
		for x,y in pairs(j) do
			local button = y.buttons[column]
			if button then 
				Healium_UpdateButtonCooldown(button, start, duration, enable)
			end
		end
		Healium_UpdateSpecialBuffs(unit)
	end
end

local function Healium_UpdateButtonCooldowns()
	local count = Healium_GetProfile().ButtonCount
	
	for i=1, count, 1 do
		Healium_UpdateButtonCooldownsByColumn(i)
	end
end

function Healium_UpdateButtonIcon(button, texture)
	button.icon.disabled = nil
	
	if InCombatLockdown() then
		return
	end

	if (texture) then
		button.icon:SetTexture(texture)
	else
		button.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
	end		
end

function Healium_UpdateButtonIcons()
	if InCombatLockdown() then
		return
	end

	local Profile = Healium_GetProfile()
	for i=1, Healium_MaxButtons, 1 do
		local texture = Profile.SpellIcons[i]
		
		for _, k in ipairs(Healium_Frames) do
			local button = k.buttons[i]
			if button then 
				Healium_UpdateButtonIcon(button, texture)
			end
		end
   end
end

function Healium_SetButtonAttributes(button)
	-- update button.id even while in combat.
	-- This is needed because we use this for a number of things, including tooltips, and the IDs can now change while in combat due to spells dynamically changing.
	-- Spells (possibly not even configured in Healium) can dynamically change/rename, causing all other spellid to shift/change, so in those cases, we need to 
	-- update the button.id to keep on the same spell.
	-- This actually fixed a hard to find Druid bug in 5.0 with Hurricane changing to Astral Storm and causing some spellIDs to shift around.
	local Profile = Healium_GetProfile()	
	local index = button.index
	button.id = Profile.IDs[index]
	
	if InCombatLockdown() then
		return
	end
	
	local stype, spell, macro, item
	
	if Profile.SpellTypes[index] == Healium_Type_Macro then
		stype = "macro"
		macro = Profile.SpellNames[index]
	elseif Profile.SpellTypes[index] == Healium_Type_Item then
		stype = "item"
		item = Profile.SpellNames[index]
	else
		stype = "spell"
		--spell = Profile.SpellNames[index]
		local spellName = Profile.SpellNames[index]
		local spellSubtext = Profile.SpellRanks[index]
		spell = Healium_MakeRankedSpellName(spellName, spellSubtext)
	end
	
	
	button:SetAttribute("type", stype)
	button:SetAttribute("spell", spell)
	button:SetAttribute("macro", macro)
	button:SetAttribute("item", item)
end

function Healium_UpdateButtonAttributes()
	local Profile = Healium_GetProfile()
	
	for i=1, Healium_MaxButtons, 1 do
	
		-- update spell IDs
		if (Profile.SpellTypes[i] == nil) or (Profile.SpellTypes[i] == Healium_Type_Spell) then 
			local name = Profile.SpellNames[i]
			local subtext = Profile.SpellRanks[i]
			if name then 
				Profile.IDs[i] = GetSpellSlotID(name, subtext)
			end
		end
		
		for _,k in ipairs(Healium_Frames) do
			local button = k.buttons[i]
			if button then 
				Healium_SetButtonAttributes(button)
			end
		end
	end
	
	Healium_InvalidateRangeCheckCache()
	if Healium_InvalidateArmedBuffNames then Healium_InvalidateArmedBuffNames() end
	Healium_UpdateCures()
end

local function UpdateButtonVisibility(frame)
	if InCombatLockdown() then
		return
	end

	-- Hide all buttons
	for i=1, Healium_MaxButtons, 1 do 
		local button = frame.buttons[i]
		if button then 
			button:Hide()
		end
	end

	-- Show buttons.  The buttons will not actually show up unless their nameplate are visible so it's fine to show them like this.	
	local count = Healium_GetProfile().ButtonCount
	
	for i=1, count, 1 do 
		local button = frame.buttons[i]	
		if button then 
			button:Show()
		end
	end
end

function Healium_UpdateButtonVisibility()
	if InCombatLockdown() then
		return
	end
	
	for _,k in ipairs(Healium_Frames) do
		UpdateButtonVisibility(k)
	end
end

function Healium_UpdateButtons()
	Healium_UpdateButtonVisibility()
	Healium_UpdateButtonAttributes()
	Healium_UpdateButtonIcons()
end

-- IsSpellUsable() and SpellHasRange() depend only on the button column, not
-- on the unit, but the range check used to call them once per button per
-- tick (15 buttons x 40 raid frames).  They are now computed once per column
-- and shared by every unit frame.
local ColumnHasRange = {}
local ColumnUsableTime = {}
local ColumnNoMana = {}

-- Clears the per-tick usable/mana answers only.  Called on SPELL_UPDATE_USABLE.
function Healium_InvalidateUsableCache()
	ColumnUsableTime = {}
	ColumnNoMana = {}
end

-- Clears everything.  Called whenever the button configuration changes.
function Healium_InvalidateRangeCheckCache()
	ColumnHasRange = {}
	Healium_InvalidateUsableCache()
end

function Healium_RangeCheckButton(button)
	local Profile = Healium_GetProfile()
	local index = button.index

	if (Profile.SpellTypes[index] == nil) or (Profile.SpellTypes[index] == Healium_Type_Spell) then 
		if (button.id) then
			local now = GetTime()

			if ColumnUsableTime[index] == nil or (now - ColumnUsableTime[index]) >= Healium.RangeCheckPeriod then
				local noMana

				if Healium_IsRetail then
					_, noMana = C_Spell.IsSpellUsable(Profile.SpellNames[index])
				else
					_, noMana = IsUsableSpell(button.id, BOOKTYPE_SPELL)
				end

				ColumnUsableTime[index] = now
				ColumnNoMana[index] = noMana and true or false
			end

			if ColumnNoMana[index] then
				button.icon:SetVertexColor(0.5, 0.5, 1.0)
			else
				if not button.icon.disabled then 
					button.icon:SetVertexColor(1.0, 1.0, 1.0)
				end
			end

			local inRange

			if Healium_IsRetail then
				inRange = C_Spell.IsSpellInRange(Profile.SpellNames[index], button:GetParent().TargetUnit)
			else
				inRange = IsSpellInRange(button.id, BOOKTYPE_SPELL, button:GetParent().TargetUnit)
			end

			if ColumnHasRange[index] == nil then
				if Healium_IsRetail then
					ColumnHasRange[index] = C_Spell.SpellHasRange(Profile.SpellNames[index]) and true or false
				else
					ColumnHasRange[index] = SpellHasRange(button.id, BOOKTYPE_SPELL) and true or false
				end
			end

			if ColumnHasRange[index] then
				if (inRange == false) or (inRange == 0) or (inRange == nil) then
					button.icon:SetVertexColor(1.0, 0.3, 0.3)
				end
			end
		end
	end

	-- todo range check macros, and items
end

function Healium_UpdateRaidTargetIcon(frame)
	if (frame.TargetUnit) then
		if not UnitExists(frame.TargetUnit) then return end
		local index = GetRaidTargetIndex(frame.TargetUnit);
		if ( index  and Healium.ShowRaidIcons ) then
			SetRaidTargetIconTexture(frame.HealthBar.raidTargetIcon, index);
			frame.HealthBar.raidTargetIcon:Show();
		else
			frame.HealthBar.raidTargetIcon:Hide();
		end
	end
end

local function ApplyDefaults(currentValues, defaults)
    for key, value in pairs(defaults) do
        if currentValues[key] == nil then
            currentValues[key] = value
        end
    end
end
-- Sets persisted variables to their default, if they do not exist.
local function InitVariables()
	ApplyDefaults(Healium, HealiumDefaults)
	
	if HealiumGlobal.Friends == nil then
		HealiumGlobal.Friends = { }
	end
	
	if Healium.Profiles == nil then
		Healium.Profiles = { }
	end

	-- Healium.Profiles may exist at this point, but may not be fully inited
	local DefaultProfile = { 
		ButtonCount = DefaultButtonCount,
		PartyFrameOrder = "DEFAULT",
		SpellNames = { },
		SpellIcons = { },
		SpellTypes = { },
		SpellRanks = { },
		IDs = { },
	}

	-- Make sure all Profile member tables exist. This is needed since new tables get added over various releases, and since Profiles variable gets saved/recalled by wow, the values may or may not exist depending on what verison of wow was last used when saving the variable.
	for i = 1,5 do
		if Healium.Profiles[i] == nil then	
			Healium.Profiles[i] = Healium_DeepCopy(DefaultProfile)
		end

		if Healium.Profiles[i].PartyFrameOrder == nil then
			Healium.Profiles[i].PartyFrameOrder = DefaultProfile.PartyFrameOrder
		end

		-- SpellTypes was added in 2.0
		if Healium.Profiles[i].SpellTypes == nil then
			Healium.Profiles[i].SpellTypes = {}
		end

		-- IDs was added in 2.0
		if Healium.Profiles[i].IDs == nil then
			Healium.Profiles[i].IDs = {}
		end

		-- SpellRanks was added in 2.7.0
		if Healium.Profiles[i].SpellRanks == nil then 
			Healium.Profiles[i].SpellRanks = {}
		end
	end

	-- remove old saved variables
	HealiumDropDownButton = nil
	HealiumDropDownButtonIcon = nil
end

function Healium_OnEvent(frame, event, ...)
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)

	-------------------------------------------------------------
	-- [[ Update Unit Health Display Whenever Their HP Changes ]]
	-------------------------------------------------------------
    if (event == "UNIT_HEALTH") or (event == "UNIT_HEAL_PREDICTION") or (event == "UNIT_HEALTH_FREQUENT")  then
--		if (not HealiumActive) then return 0 end
		
		if Healium_Units[arg1] then
			for _,v  in pairs(Healium_Units[arg1]) do
				Healium_UpdateUnitHealth(arg1, v)
			end
		end
		return
	end

	if event == "UNIT_DISPLAYPOWER" then
		if Healium_Units[arg1] then
			for i,v  in pairs(Healium_Units[arg1]) do
				Healium_UpdateUnitMana(arg1, v)
			end
		end
		return
	end
	
    if event == "UNIT_POWER_UPDATE" then
		if (arg2 == "MANA") and Healium_Units[arg1] then
			for _,v  in pairs(Healium_Units[arg1]) do
				Healium_UpdateUnitMana(arg1, v)
			end
		end
		return
	end
	
	if event == "UNIT_AURA" then
		if Healium_Units[arg1] then
			-- Healium_UpdateUnitBuffs also drives the dispel warning system, so it
			-- has to run whenever either buffs or debuffs are enabled.
			if Healium.ShowBuffs or Healium.EnableDebufs then
				for _,v  in pairs(Healium_Units[arg1]) do
					Healium_UpdateUnitBuffs(arg1, v)
				end
			end

			-- Walks Healium_Units[unit] itself, so it must not be called once per
			-- frame showing that unit.
			Healium_UpdateSpecialBuffs(arg1)
		end
		return
	end
	
	if (event == "UNIT_THREAT_SITUATION_UPDATE") and Healium.ShowThreat then
		if Healium_Units[arg1] then
			for _,v  in pairs(Healium_Units[arg1]) do
				Healium_UpdateUnitThreat(arg1, v)
			end
		end
		return
	end

	if (event == "SPELL_UPDATE_COOLDOWN") and Healium.EnableCooldowns then
		Healium_UpdateButtonCooldowns()
		return
	end	
		
	if event == "PLAYER_REGEN_ENABLED" then
		Healium_UpdatePartyFrameOrder()
		for _,v in ipairs(Healium_FixNameplates) do
			Healium_ShowHidePercentage(v)

			if v.fixCreateButtons then 
				Healium_CreateButtonsForNameplate(v)
				UpdateButtonVisibility(v)
				v.fixCreateButtons = nil
			end
			
			if v.fixShowMana then
				Healium_UpdateManaBarVisibility(v)
				v.fixShowMana = nil
			end
		end
		
		Healium_FixNameplates = {}
		return
	end
	
	if ((event == "UNIT_SPELLCAST_SENT") and ( (arg2 == ActivatePrimarySpecSpellName) or (arg2 == ActivateSecondarySpecSpellName))  ) then
--		DEFAULT_CHAT_FRAME:AddMessage("Healium Debug: Respecing Start")
		frame.Respecing = true
		return
	end

	if ( ((event == "UNIT_SPELLCAST_INTERRUPTED") or (event == "UNIT_SPELLCAST_SUCCEEDED")) and (arg1 == "player") and ( (arg2 == ActivatePrimarySpecSpellName) or (arg2 == ActivateSecondarySpecSpellName))  ) then
--		DEFAULT_CHAT_FRAME:AddMessage("Healium Debug: Respecing Interrupt or succeeded")
		frame.Respecing = nil
	end
	
	-- This is not sent during initialization during a reload
	if (event == "PLAYER_TALENT_UPDATE") then
		Healium_DebugPrint("PLAYER_TALENT_UPDATE")
		frame.Respecing = nil	
		
		-- mainly to reset cures.  
		Healium_InitSpells(HealiumClass, HealiumRace) 

		Healium_InvalidateSpellSlotCache()
		Healium_UpdateSpells()
		Healium_UpdateButtons()
		Healium_Update_ConfigPanel()
		Healium_UpdatePartyFrameOrder()
		return
	end

	if ((event == "SPELLS_CHANGED") and (not frame.Respecing)) then
		Healium_DebugPrint("SPELLS_CHANGED")
		QueueSpellsChangedUpdate()
	end
	
	if ((event == "PLAYER_ENTERING_WORLD") and (not frame.Respecing)) then
		stable = true
		Healium_DebugPrint("PLAYER_ENTERING_WORLD")
		-- Populate the Healium_Spell Table with ID and Icon data.
		Healium_InvalidateSpellSlotCache()
		Healium_UpdateSpells()
		Healium_UpdateButtonAttributes()
	end
	
	if (event == "RAID_TARGET_UPDATE") and Healium.ShowRaidIcons then
		Healium_UpdateRaidIcons()
		return		
	end
	
	if event == "UNIT_NAME_UPDATE" then
		if Healium_Units[arg1] then
			local name = UnitName(arg1)

			-- UnitName is nil until the unit is fully available, and strupper(nil)
			-- throws.  The uppercase option was ignored here too.
			if name and Healium.UppercaseNames then
				name = strupper(name)
			end
			for _,v  in pairs(Healium_Units[arg1]) do
				v.HealthBar.name:SetText(name)			
			end
		end
		return
	end
	
	if (event == "GROUP_ROSTER_UPDATE") and Healium.ShowRole then
		Healium_UpdateRoles()
		return
	end
	
	if (event == "PLAYER_TARGET_CHANGED") and Healium.ShowTargetFrame then
		Healium_DebugPrint("PLAYER_TARGET_CHANGED")
		Healium_UpdateTargetFrame()
		return
	end
	
	if (event == "PLAYER_FOCUS_CHANGED") and Healium.ShowFocusFrame then
		Healium_DebugPrint("PLAYER_FOCUS_CHANGED")
		Healium_UpdateFocusFrame()
		return
	end

	if (event == "PET_BATTLE_OPENING_START") then 
		--Healium_DebugPrint("PET_BATTLE_OPENING_START")	
		Healium_ToggleAllFrames(true, true)
	end
	
	if (event == "PET_BATTLE_CLOSE") then 
		--Healium_DebugPrint("PET_BATTLE_CLOSE")		
		Healium_ToggleAllFrames(false, true)	
	end
	
	-- Use this ADDON_LOADED event instead of VARIABLES_LOADED.
	-- ADDON_LOADED will not be called until the variables are loaded.
	if ((event == "ADDON_LOADED") and (string.lower(arg1) == string.lower(Healium_AddonName))) then
		Healium_DebugPrint("ADDON_LOADED")  	

		InitVariables()
		Healium_InitSpells(HealiumClass, HealiumRace) 		
		Healium_InitDebuffSound()		
		Healium_CreateMiniMapButton()
		Healium_UpdateShowMinimapButton()
		Healium_CreateConfigPanel(HealiumClass, Healium_Version)
		Healium_InitSlashCommands()
		Healium_InitMenu()		
		Healium_CreateUnitFrames()
		Healium_SetScale()		
		Healium_UpdatePercentageVisibility()		
		Healium_UpdateClassColors()
		Healium_UpdateShowMana()
		Healium_UpdateShowBuffs()
		Healium_UpdateFriends()
		Healium_UpdateShowThreat()
		Healium_UpdateShowIncomingHeals()		
		Healium_UpdateShowRaidIcons()
		Healium_UpdateButtons()		
		Healium_UpdateShowRole()	
		LoadedTime = GetTime()
		
		return
	end	
	
	if (event == "PLAYER_LOGIN") then
		-- moving the showing of frames to here from ADDON_LOADED to try to overcome units not being shown right after player logs in 
		Healium_DebugPrint("PLAYER_LOGIN")  

		Healium_ShowHidePartyFrame()
		Healium_ShowHidePetsFrame()
		Healium_ShowHideMeFrame()
		Healium_ShowHideDamagersFrame()
		Healium_ShowHideHealersFrame()
		Healium_ShowHideTanksFrame()
		Healium_ShowHideFriendsFrame()
		Healium_ShowHideTargetFrame()
		Healium_ShowHideFocusFrame()
		
		for i=1, 8, 1 do
			Healium_ShowHideGroupFrame(i)
		end
		
		return
	end
end

