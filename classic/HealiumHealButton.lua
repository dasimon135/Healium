function Healium_HealButton_OnLoad(frame)
	frame.TimeSinceLastUpdate = 0
	frame:RegisterEvent("SPELL_UPDATE_USABLE")
	frame:RegisterForDrag("LeftButton")
	if Healium_IsClassic or Healium_IsClassicBCC or Healium_IsClassicMists then	
		frame:RegisterForClicks("AnyUp", "AnyDown")							
	else
		frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
end

function Healium_HealButton_OnUpdate(frame, elapsed)
	if ( not Healium.DoRangeChecks ) then return 0 end 	
	frame.TimeSinceLastUpdate = frame.TimeSinceLastUpdate + elapsed 	

	if (frame.TimeSinceLastUpdate > Healium.RangeCheckPeriod) then
		Healium_RangeCheckButton(frame)
		frame.TimeSinceLastUpdate = 0
	end
end

function Healium_HealButton_OnEnter(frame, motion)
	if (not Healium.ShowToolTips) then return end	
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT", -30, 5)
	local stype = frame:GetAttribute("type")
	
    if frame.id and (stype == "spell") then 
		GameTooltip_SetDefaultAnchor(GameTooltip, frame)	
		if Healium_IsRetail then 
			GameTooltip:SetSpellBookItem(frame.id, Enum.SpellBookSpellBank.Player)
		else
			GameTooltip:SetSpellBookItem(frame.id, SpellBookFrame.bookType)
		end
		local Profile = Healium_GetProfile()
		local rank = Profile.SpellRanks[frame.index]
		if rank then 
			GameTooltip:AddLine(Healium_AddonColor .. rank .. "|r",1,1,1)
		end
		local unit = frame:GetParent().TargetUnit
		if not UnitExists(unit) then return end
		local Name = UnitName(unit)
		if (not Name) then Name = "-" end
        GameTooltip:AddLine("Target: |cFF00FF00"..Name,1,1,1)
		if Healium_IsRetail and Healium_Debug then 
			GameTooltip:AddLine("icon = " .. frame.icon:GetTexture())
		end
	elseif frame.id and (stype == "item") then
		GameTooltip_SetDefaultAnchor(GameTooltip, frame)	
		GameTooltip:SetHyperlink("item:"..frame.id)
		local unit = frame:GetParent().TargetUnit
		if not UnitExists(unit) then return end
		local Name = UnitName(unit)
		if (not Name) then Name = "-" end
        GameTooltip:AddLine("Target: |cFF00FF00"..Name,1,1,1)	
	elseif (stype == "macro") then 
		GameTooltip_SetDefaultAnchor(GameTooltip, frame)	
		GameTooltip:AddLine("Macro: " .. frame:GetAttribute("macro"))
		local unit = frame:GetParent().TargetUnit
		if not UnitExists(unit) then return end
		local Name = UnitName(unit)
		if (not Name) then Name = "-" end
        GameTooltip:AddLine("Target: |cFF00FF00"..Name,1,1,1)			
	else
		-- Safely Handle Empty Buttons	
		GameTooltip:SetText("|cFFFFFFFFNo Spell|n|cFF00FF00You may drag-and-drop a spell from your|nspellbook onto this button, or you may go|nto Game Menu, Interface, Addons, " ..Healium_AddonName .. " and|nselect your spells from the list.")
    end
	
	GameTooltip:Show()			
end

function Healium_HealButton_OnLeave()
	GameTooltip:Hide()
end

function Healium_HealButton_OnEvent(frame, event)
	if (not frame.id) then return 0 end   
	
	if event == "SPELL_UPDATE_USABLE" then
		Healium_InvalidateUsableCache()
		Healium_RangeCheckButton(frame)
	end
end

local function PickupOldSpell(old) 
	-- if shift is held down put old spell on cursor
	if IsShiftKeyDown() and (old.name ~= nil) then

		if old.type == Healium_Type_Spell then
			if Healium_IsRetail then 
				if old.ID ~= nil then 
					C_SpellBook.PickupSpellBookItem(old.ID, Enum.SpellBookSpellBank.Player)
				end
			else
				PickupSpellBookItem(old.name)
			end
			return
		end
		
		if old.type == Healium_Type_Macro then
			PickupMacro(old.name)
			return
		end
		
		if old.type == Healium_Type_Item then
			PickupItem(old.ID)
			return 
		end
	end
end

local function FinishDrag(frame,old)
	Healium_UpdateButtonAttributes()
	Healium_UpdateButtonIcons()				
	Healium_UpdateButtonCooldownsByColumn(frame.index)	
	
	ClearCursor()
	Healium_Update_ConfigPanel()

	PickupOldSpell(old)
end

local function GetOldSpell(Index, Profile)
	local old = {}

	old.name = Profile.SpellNames[Index]
	old.icon = Profile.SpellIcons[Index]
	old.type = Profile.SpellTypes[Index]
	old.ID = Profile.IDs[Index]
	
	return old
end

local function Drag(frame)
	if InCombatLockdown() then
		Healium_Warn("Can't update button while in combat")
		return
	end
	
	if (frame.index < 0) or (frame.index > Healium_MaxButtons) then
		return
	end

	local Profile = Healium_GetProfile()
	local infoType, info1, info2, info3 = GetCursorInfo()
	Healium_DebugPrint("infoType:", infoType, "info1:", info1, "info2:", info2, "info3:", info3 )
	local old = GetOldSpell(frame.index, Profile)
	
	local spellName
	-- Handle spell drag
	if infoType == "spell" then 
		-- info1 holds spellid
		
		if info1 == 0 then  
			-- workaround for beacon of virtue nonsense by blizz
			spellName = Healium_GetSpellName(info3)
		else
			if Healium_IsRetail then 
				spellName = C_SpellBook.GetSpellBookItemName(info1, Enum.SpellBookSpellBank.Player)
			else
				spellName = GetSpellBookItemName(info1, BOOKTYPE_SPELL )	
			end
			Healium_DebugPrint("spellName:", spellName)
			local passive
			if Healium_IsRetail then
				passive = C_Spell.IsSpellPassive(spellName)
			else
				passive = IsPassiveSpell(info1, BOOKTYPE_SPELL)
			end
			if passive then
				local link
				if Healium_IsRetail then 
					link = C_Spell.GetSpellLink(spellName)
				else
					link = GetSpellLink(info1, BOOKTYPE_SPELL)
				end
				Healium_Warn(link .. " is a passive spell and cannot be used in " .. Healium_AddonName)
				return
			end
		end

		-- GetSpellInfo() is returning nil for everything for Holy Word: Chastise and any of it's transformed variations
		local icon
		if Healium_IsRetail then
			icon = C_Spell.GetSpellTexture(spellName)
		else
			icon = GetSpellTexture(spellName)
		end
		local subtext
		if Healium_IsRetail then
			subtext = C_Spell.GetSpellSubtext(info3)
		else
			subtext = GetSpellSubtext(info3)
		end
		local rankedSpellName = Healium_MakeRankedSpellName(spellName, subtext)
		Healium_DebugPrint("name:", spellName, "subtext:", subtext, "rankedSpellName:", rankedSpellName, "icon:", icon)
		Healium_SetProfileSpell(Profile, frame.index, spellName, info1, icon, subtext)
		FinishDrag(frame, old)
		return
	end
	
	-- Handle macro drag
	if infoType == "macro" then
		-- info1 holds macro index
		local name, icon, body, isLocal = GetMacroInfo(info1);
		Healium_SetProfileMacro(Profile, frame.index, name, info1, icon)		
		FinishDrag(frame, old)
		return
	end
	
	-- Handle item drag
	if infoType == "item" then
		-- info1 = itemId: Number - The itemId. 
		-- info2 = itemLink : String (ItemLink) - The item's link. 
		local name, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, iEquipLoc, icon, iSellPrice =  GetItemInfo(info1);
		Healium_SetProfileItem(Profile, frame.index, name, info1, icon)				
		FinishDrag(frame, old)
		return
	end
	
end 

-- drag stop
function Healium_HealButton_OnReceiveDrag(frame)
	Healium_DebugPrint("Healium_HealButton_OnReceiveDrag() called")
	Drag(frame, nil)
end

-- drag start
function Healium_HealButton_OnDragStart(frame)
	Healium_DebugPrint("Healium_HealButton_OnDragStart() called")
	-- starting drag requires shift to be pressed
	if IsShiftKeyDown() == nil then return end
	
	local Profile = Healium_GetProfile()
	local old = GetOldSpell(frame.index, Profile)
	
	PickupOldSpell(old)
end

