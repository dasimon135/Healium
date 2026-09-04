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
  --ShowPercentage = true,						-- Whether or not to display the health percentage
  UseClassColors = false,						-- Whether or not to color the healthbar the color of the class instead of green/yellow/red
  OpaqueHealthbarBackground = false,			-- Whether or not to show a dark opaque background behind the healthbar
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
  EnableDebufHealthbarHighlighting = true,		-- Whether or not to highlight the healthbar of a player when they have a debuf which you can cure
  EnableDebufButtonHighlighting = true,			-- Whether or not to highlight buttons which are assigned a spell that can cure a debuff on a player
	ShowDebuffIcon = true,							-- Whether or not to show the debuff icon over matching cure buttons
  EnableDebufHealthbarColoring = false,			-- Whether or not to color the heatlhbar of a player when they have a debuf which you can cure
  ShowMana = true,								-- Whether or not to show mana
  ShowThreat = true,							-- Whether or not to show the threat warnings
  ShowRole = true,								-- Whether or not to show the role icon
  ShowIncomingHeals = true,						-- Whether or not to show incoming heals
  ShowRaidIcons = true,							-- Whether or not to show raid icons
  UppercaseNames = true,						-- Whether or not to show names in UPPERCASE
  ShowMinimapButton = true,						-- Whether or not to show the minimap button
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
	local name = C_Spell.GetSpellName(spellID)
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

local function Healium_TableToString(tbl, indent, visited)
    indent = indent or 0
    visited = visited or {}

    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    if visited[tbl] then
        return string.rep(" ", indent) .. "*RECURSION*"
    end

    visited[tbl] = true

    local lines = {}
    table.insert(lines, string.rep(" ", indent) .. "{")

    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        local valueStr

        if type(v) == "table" then
            valueStr = Healium_TableToString(v, indent + 4, visited)
        else
            valueStr = tostring(v)
        end

        table.insert(
            lines,
            string.rep(" ", indent + 4) .. keyStr .. " = " .. valueStr
        )
    end

    table.insert(lines, string.rep(" ", indent) .. "}")
    return table.concat(lines, "\n")
end

function Healium_DebugPrint(...)
    if not Healium_Debug then return end

    local result = "Debug:"

    for i = 1, select("#", ...) do
        local value = select(i, ...)
        local str

        if type(value) == "table" then
            str = "\n" .. Healium_TableToString(value)
        else
            str = tostring(value)
        end

        result = result .. " " .. str
    end

    Healium_Print(result)
end

function Healium_Warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000Warning|r: " .. tostring(msg))		
end

function Healium_GetProfile()
	local currentSpec = GetSpecialization()
	
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
	HealiumFrame:RegisterEvent("UNIT_HEALTH")
	HealiumFrame:RegisterEvent("UNIT_MAXHEALTH")
	HealiumFrame:RegisterEvent("PET_BATTLE_OPENING_START")
	HealiumFrame:RegisterEvent("PET_BATTLE_CLOSE")
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_SENT")	
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	HealiumFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	HealiumFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	HealiumFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	HealiumFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
	HealiumFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
	HealiumFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	HealiumFrame:RegisterEvent("UNIT_NAME_UPDATE")
	HealiumFrame:RegisterEvent("PLAYER_LOGIN")	
	HealiumFrame:RegisterEvent("PLAYER_TALENT_UPDATE")		
end


-- Sets the health bar color based on the unit's health ONLY
local function UpdateHealthBar(frame)
	frame.HealthBar:SetStatusBarColor(0,1,0,1) 
end

function Healium_UpdateClassColors()
	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			if UnitExists(k.TargetUnit) then
				if Healium.UseClassColors then
					local class = select(2, UnitClass(k.TargetUnit))
					if class and not issecretvalue(class) and RAID_CLASS_COLORS[class] then
						local color = RAID_CLASS_COLORS[class]
						k.HealthBar:SetStatusBarColor(color.r, color.g, color.b)
					else
						UpdateHealthBar(k)
					end
				else
					UpdateHealthBar(k)
				end
			end
		end
	end
end

function Healium_GetPlayerName(unitName)
	-- UnitName() may return secret now!
	local playerName = UnitName(unitName)
	
	if playerName ~= nil and Healium.UppercaseNames then
		if not issecretvalue(playerName) then
			playerName = strupper(playerName)
		end
	end

	return playerName
end

function Healium_UpdateUnitName(unitName, NamePlate)
	if not NamePlate then return end
	if not UnitExists(unitName) then return end

	local playerName = Healium_GetPlayerName(unitName)
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
		
	local deadOrGhost = UnitIsDeadOrGhost(unitName)
	if not issecretvalue(deadOrGhost) and deadOrGhost then
		Health = 0
		isDead = 1
	end
	
	if isDead then
		NamePlate.HealthBar.HPText:SetText( "dead" )	
	else
		NamePlate.HealthBar.HPText:SetText( "" )
	end
	
	NamePlate.HealthBar:SetMinMaxValues(0,MaxHealth)
	NamePlate.HealthBar:SetValue(Health)

	if Healium.ShowIncomingHeals then
		-- Secret combat values can be passed directly to StatusBar widgets, but
		-- must not be inspected or combined in Lua.
		local IncomingHealth = UnitGetIncomingHeals(unitName)
		NamePlate.PredictBar:Show()
		NamePlate.PredictBar:SetMinMaxValues(0, MaxHealth)
		if issecretvalue(IncomingHealth) then
			NamePlate.PredictBar:SetValue(IncomingHealth)
		else
			NamePlate.PredictBar:SetValue(IncomingHealth or 0)
		end
	end
	
	if Healium.EnableDebufs and Healium.EnableDebufHealthbarColoring and NamePlate.hasDebuf then
		NamePlate.HealthBar:SetStatusBarColor(NamePlate.debuffColor.r, NamePlate.debuffColor.g, NamePlate.debuffColor.b)	
	elseif Healium.UseClassColors then
		local class = select(2, UnitClass(unitName))
		if class and not issecretvalue(class) and RAID_CLASS_COLORS[class] then
			local color = RAID_CLASS_COLORS[class]
			NamePlate.HealthBar:SetStatusBarColor(color.r, color.g, color.b)
		else
			UpdateHealthBar(NamePlate)
		end
	else
		UpdateHealthBar(NamePlate)
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
	else
		frame.ManaBar:Hide()
		frame.HealthBar:SetWidth(116)			
		frame.HealthBar:SetPoint("TOPLEFT", 2, -2)
		frame.PredictBar:SetWidth(116)
	end		
	
	Healium_UpdateUnitHealth(frame.TargetUnit, frame)
end

function Healium_UpdateShowBuffs()
	Healium_RefreshAuraContainers()
end

function Healium_UpdateShowIncomingHeals()
	if Healium.ShowIncomingHeals then
		HealiumFrame:RegisterEvent("UNIT_HEAL_PREDICTION")
	else
		HealiumFrame:UnregisterEvent("UNIT_HEAL_PREDICTION")
	end

	for _, frame in ipairs(Healium_Frames) do
		if Healium.ShowIncomingHeals then
			frame.PredictBar:Show()
			Healium_UpdateUnitHealth(frame.TargetUnit, frame)
		else
			frame.PredictBar:Hide()
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
		r, g, b = GetThreatStatusColor(status) -- GetThreatStatusColor not on classic. Is on LK classic.		
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
	if not NamePlate then return end
	if not UnitExists(unitName) then return end
	
	local icon = NamePlate.HealthBar.RoleIcon
	
	if not Healium.ShowRole then
		icon:Hide()
		NamePlate.HasRole = nil
		return
	end
	
	local role = UnitGroupRolesAssigned(unitName);	
	if issecretvalue(role) then
		NamePlate.HasRole = nil
		icon:Hide()
		return
	end
	
	if ( role == "TANK" or role == "HEALER" or role == "DAMAGER") then
		NamePlate.HasRole = true
		local enum = UnitGroupRolesAssignedEnum(unitName)
		if enum and not issecretvalue(enum) then
			icon:SetAtlas(GetMicroIconForRoleEnum(enum), TextureKitConstants.IgnoreAtlasSize);
			icon:Show()
		else
			NamePlate.HasRole = nil
			icon:Hide()
		end
	else
		NamePlate.HasRole = nil
		icon:Hide()
	end
end

local function Healium_UpdateRoles()
	for _, k in ipairs(Healium_Frames) do
		if (k.TargetUnit) then
			Healium_UpdateUnitRole(k.TargetUnit, k)
		end
	end
end

function Healium_UpdateShowRole()
	if Healium.ShowRole then
		HealiumFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	else
		HealiumFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
	end
	
	Healium_UpdateRoles()
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
	if Healium.ShowFocusFrame then 
		Healium_DebugPrint("registering PLAYER_FOCUS_CHANGED")
		HealiumFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	else
		Healium_DebugPrint("UNregistering PLAYER_FOCUS_CHANGED")	
		HealiumFrame:UnregisterEvent("PLAYER_FOCUS_CHANGED")	
	end
end

local function GetSpellCount()
	local tabs = C_SpellBook.GetNumSpellBookSkillLines()

	if tabs == nil then return 0 end
	local name, texture, offset, numSpells
	local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(tabs)
	if skillLineInfo then
		offset = skillLineInfo.itemIndexOffset
		numSpells = skillLineInfo.numSpellBookItems
	end

	if offset == nil or numSpells == nil then return 0 end
	return offset + numSpells
end

-- Spellbook slot lookups used to rescan the whole spellbook once per spell,
-- which cost thousands of API calls on every SPELLS_CHANGED.  The book is now
-- indexed once into SpellSlotCache and reused until the cache is invalidated.
local SpellSlotCache = nil

local function BuildSpellSlotCache()
	local cache = {}
	local count = GetSpellCount()

	for i = 1, count do
		local spellName, spellSubName = C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Player)

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
		local info = C_SpellBook.GetSpellBookItemInfo(entry.slot, Enum.SpellBookSpellBank.Player)

		if (info and info.itemType == Enum.SpellBookItemType.FutureSpell) then
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
			Healium_Spell.Icon[k] = C_Spell.GetSpellTexture(Healium_Spell.Name[k])
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
	if Healium_UsesAuraContainers and Healium_UsesAuraContainers() then return end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end

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


-- Efficient cooldowns (Midnight-safe)
--
-- Midnight restricts direct use of cooldown start/duration/enabled values in combat ("secret values").
-- To remain combat-safe, we drive cooldown visuals using Blizzard-provided "duration objects"
-- and the Cooldown widget's SetCooldownFromDurationObject().

local function Healium_ApplyDurationObject(cooldownFrame, durObj)
	if not cooldownFrame then return end
	if not durObj then
		cooldownFrame:Hide()
		return
	end

	local ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, durObj)
	if ok then
		-- Preserve user's preference for numbers if possible
		pcall(cooldownFrame.SetDrawEdge, cooldownFrame, false)
		pcall(cooldownFrame.SetHideCountdownNumbers, cooldownFrame, false)
		cooldownFrame:Show()
	else
		cooldownFrame:Hide()
	end
end

local function Healium_ResolveSpellIDFromSlot(slotID)
	if not slotID then return nil end
	if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then return nil end
	local info = C_SpellBook.GetSpellBookItemInfo(slotID, Enum.SpellBookSpellBank.Player)
	if info and info.spellID then
		return info.spellID
	end
	return nil
end

local function Healium_GetCooldownDurationObject(Profile, index)
	if not Profile or not Profile.SpellTypes then return nil end
	if not C_Spell or not C_Spell.GetSpellCooldownDuration then
		return nil
	end

	local stype = Profile.SpellTypes[index]

	if stype == Healium_Type_Spell or stype == nil then
		-- In Healium 3.0.0 Profile.IDs holds a spellbook slot index, not a global spellID.
		local slotOrID = Profile.IDs and Profile.IDs[index]
		local spellID = Healium_ResolveSpellIDFromSlot(slotOrID) or slotOrID
		local name = Profile.SpellNames and Profile.SpellNames[index]

		-- Prefer spellID (most reliable); fall back to name
		if spellID then
			return C_Spell.GetSpellCooldownDuration(spellID)
		end
		if name then
			return C_Spell.GetSpellCooldownDuration(name)
		end
		return nil
	end

	if stype == Healium_Type_Macro then
		local macroName = Profile.SpellNames and Profile.SpellNames[index]
		if not macroName then return nil end
		local spellName = GetMacroSpell(macroName)
		if spellName then
			return C_Spell.GetSpellCooldownDuration(spellName)
		end
		return nil
	end

	-- Items and action slots are intentionally not handled here to avoid restricted cooldown values.
	return nil
end

function Healium_UpdateButtonCooldownByUnitFrame(frame)
	local Profile = Healium_GetProfile()
	if not Profile then return end
	local count = Profile.ButtonCount or 0

	for i = 1, count do
		local button = frame.buttons and frame.buttons[i]
		if button and button.cooldown then
			local durObj = Healium_GetCooldownDurationObject(Profile, i)
			Healium_ApplyDurationObject(button.cooldown, durObj)
		end
	end
end

function Healium_UpdateButtonCooldownsByColumn(column)
	local Profile = Healium_GetProfile()
	if not Profile then return end

	-- Common call site: numeric column index
	if type(column) == "number" then
		for _, frame in ipairs(Healium_Frames) do
			local button = frame.buttons and frame.buttons[column]
			if button and button.cooldown then
				local durObj = Healium_GetCooldownDurationObject(Profile, column)
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

function Healium_UpdateButtonCooldowns()
	for _, frame in ipairs(Healium_Frames) do
		Healium_UpdateButtonCooldownByUnitFrame(frame)
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
	Healium_UpdateCures()
	if Healium_RefreshAuraContainers then
		Healium_RefreshAuraContainers()
	end
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
				local _, noMana = C_Spell.IsSpellUsable(Profile.SpellNames[index])

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

			local inRange = C_Spell.IsSpellInRange(Profile.SpellNames[index], button:GetParent().TargetUnit)

			if ColumnHasRange[index] == nil then
				ColumnHasRange[index] = C_Spell.SpellHasRange(Profile.SpellNames[index]) and true or false
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

	-- Named, class-specific copies of button configurations. These are not
	-- active profiles; loading one copies it into the current specialization.
	if HealiumGlobal.ClassProfiles == nil then
		HealiumGlobal.ClassProfiles = { }
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
    if (event == "UNIT_HEALTH") or (event == "UNIT_MAXHEALTH") or (event == "UNIT_HEAL_PREDICTION") or (event == "UNIT_HEALTH_FREQUENT")  then
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
	
	if (event == "UNIT_THREAT_SITUATION_UPDATE") and Healium.ShowThreat then
		if Healium_Units[arg1] then
			for _,v  in pairs(Healium_Units[arg1]) do
				Healium_UpdateUnitThreat(arg1, v)
			end
		end
		return
	end
	
	if (event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES") and Healium.EnableCooldowns then
		Healium_UpdateButtonCooldowns()
		return
	end
		
	if event == "PLAYER_REGEN_ENABLED" then
		Healium_UpdatePartyFrameOrder()
		for _,v in ipairs(Healium_FixNameplates) do

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
		if Healium_RefreshAuraContainers then
			Healium_RefreshAuraContainers()
		end
		return
	end
	
	if event == "UNIT_SPELLCAST_SENT" then
		if issecretvalue(arg2) then 
			return 
		end
	
		if (arg2 == ActivatePrimarySpecSpellName) or (arg2 == ActivateSecondarySpecSpellName) then
--		DEFAULT_CHAT_FRAME:AddMessage("Healium Debug: Respecing Start")
			frame.Respecing = true
			return
		end
	end

	if (event == "UNIT_SPELLCAST_INTERRUPTED") or (event == "UNIT_SPELLCAST_SUCCEEDED") then
		if issecretvalue(arg2) then 
			return 
		end

		if (arg2 == ActivatePrimarySpecSpellName) or (arg2 == ActivateSecondarySpecSpellName) then
	--		DEFAULT_CHAT_FRAME:AddMessage("Healium Debug: Respecing Interrupt or succeeded")
			frame.Respecing = nil
		end
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
			local playerName = Healium_GetPlayerName(arg1)
			for _,v  in pairs(Healium_Units[arg1]) do
				v.HealthBar.name:SetText(playerName)			
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
		Healium_CreateMiniMapButton()
		Healium_UpdateShowMinimapButton()
		Healium_CreateConfigPanel(HealiumClass, Healium_Version)
		Healium_InitSlashCommands()
		Healium_InitMenu()		
		Healium_CreateUnitFrames()
		Healium_SetScale()		
		Healium_UpdateClassColors()
		Healium_UpdateShowMana()
		Healium_UpdateShowIncomingHeals()
		Healium_UpdateShowBuffs()
		Healium_UpdateFriends()
		Healium_UpdateShowThreat()
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

		if Healium.EnableCooldowns then
			Healium_UpdateButtonCooldowns()
		end

		return
	end
end
