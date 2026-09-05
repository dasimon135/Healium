local function ShowPartyFrame()
	Healium_ShowHidePartyFrame(true)
end

local function ShowMeFrame()
	Healium_ShowHideMeFrame(true)
end

local function ShowPetsFrame()
	Healium_ShowHidePetsFrame(true)
end

local function ShowDamagersFrame()
	Healium_ShowHideDamagersFrame(true)
end

local function ShowHealersFrame()
	Healium_ShowHideHealersFrame(true)
end

local function ShowTanksFrame()
	Healium_ShowHideTanksFrame(true)
end

local function ShowFriendsFrame()
	Healium_ShowHideFriendsFrame(true)
end

local function ShowTargetFrame()
	Healium_ShowHideTargetFrame(true)
end

local function ShowFocusFrame()
	Healium_ShowHideFocusFrame(true)
end

local function ToggleAllFrames()
	-- The dropdown calls func(button, arg1, arg2, checked), and
	-- Healium_ToggleAllFrames reads its first argument as forceHide.  Passed
	-- directly it therefore always received a truthy value and could only
	-- ever hide the frames, never bring them back.
	Healium_ToggleAllFrames()
end

local function CanConfigureButtons()
	if InCombatLockdown() then
		Healium_Warn("Can't configure buttons while in combat!")
		return false
	end
	
	return true
end

local function SetButtonCount(info, arg1)
	if CanConfigureButtons() == false then return end
	
	Healium_SetButtonCount(arg1)
end

local function SetCurrentSpell(info, btnIndex, spellIndex)
	if CanConfigureButtons() == false then return end
	
	local Profile = Healium_GetProfile()
	Healium_SetProfileSpell(Profile, btnIndex, Healium_Spell.Name[spellIndex], Healium_Spell.ID[spellIndex], Healium_Spell.Icon[spellIndex])
	
	Healium_Update_ConfigPanel()
	Healium_UpdateButtonIcons()
	Healium_UpdateButtonAttributes()
end

local function RotateButtonsLeft(info, btnIndex)
	if CanConfigureButtons() == false then return end

	local Profile = Healium_GetProfile()
	if Profile.ButtonCount <= 1 then return end
	
	local leftName = Profile.SpellNames[1]
	local leftIcon = Profile.SpellIcons[1]
	local leftType = Profile.SpellTypes[1]
	local leftRank = Profile.SpellRanks[1]
	local leftID = Profile.IDs[1]

	local startIndex = btnIndex or 1
	
	for i=startIndex, Profile.ButtonCount - 1 do
		Profile.SpellNames[i] = Profile.SpellNames[i+1]
		Profile.SpellIcons[i] = Profile.SpellIcons[i+1] 
		Profile.SpellTypes[i] = Profile.SpellTypes[i+1]
		Profile.SpellRanks[i] = Profile.SpellRanks[i+1]
		Profile.IDs[i] = Profile.IDs[i+1] 
    end

	if btnIndex == nil then
		Profile.SpellNames[Profile.ButtonCount] = leftName
		Profile.SpellIcons[Profile.ButtonCount] = leftIcon
		Profile.SpellTypes[Profile.ButtonCount] = leftType
		Profile.SpellRanks[Profile.ButtonCount] = leftRank
		Profile.IDs[Profile.ButtonCount] = leftID
		
		-- in the case we supply a button index, callers will update		
		Healium_Update_ConfigPanel()	
		Healium_UpdateButtonIcons()
		Healium_UpdateButtonAttributes()	
	end
end

local function RotateButtonsRight(info, btnIndex)
	if CanConfigureButtons() == false then return end

	local Profile = Healium_GetProfile()
	if Profile.ButtonCount <= 1 then return end	
	
	local rightName = Profile.SpellNames[Profile.ButtonCount]
	local rightIcon = Profile.SpellIcons[Profile.ButtonCount]
	local rightType = Profile.SpellTypes[Profile.ButtonCount]
	local rightRank = Profile.SpellRanks[Profile.ButtonCount]
	local rightID = Profile.IDs[Profile.ButtonCount]
	
	local stopIndex = btnIndex or 2
	
	for i=Profile.ButtonCount, stopIndex, -1 do
		Profile.SpellNames[i] = Profile.SpellNames[i-1]
		Profile.SpellIcons[i] = Profile.SpellIcons[i-1] 
		Profile.SpellTypes[i] = Profile.SpellTypes[i-1]
		Profile.SpellRanks[i] = Profile.SpellRanks[i-1]
		Profile.IDs[i] = Profile.IDs[i-1] 
    end

	if btnIndex == nil then
		Profile.SpellNames[1] = rightName
		Profile.SpellIcons[1] = rightIcon
		Profile.SpellTypes[1] = rightType
		Profile.SpellRanks[1] = rightRank
		Profile.IDs[1] = rightID

		-- in the case we supply a button index, callers will update		
		Healium_Update_ConfigPanel()	
		Healium_UpdateButtonIcons()
		Healium_UpdateButtonAttributes()
	end		
end

local function InsertButton(info, btnIndex)
	if CanConfigureButtons() == false then return end

	local Profile = Healium_GetProfile()
	if Profile.ButtonCount >= Healium_MaxButtons then 
		Healium_Warn("Can't insert more buttons! Max button count already reached!")
		return
	end
	
	Profile.ButtonCount = Profile.ButtonCount + 1
	
	RotateButtonsRight(nil, btnIndex + 1);
	
	Profile.SpellNames[btnIndex] = nil
	Profile.SpellIcons[btnIndex] = nil
	Profile.SpellTypes[btnIndex] = nil
	Profile.SpellRanks[btnIndex] = nil
	Profile.IDs[btnIndex] = nil
	
	Healium_Update_ConfigPanel()	
	Healium_UpdateButtonIcons()
	Healium_UpdateButtonAttributes()
end

local function DeleteButton(info, btnIndex)
	if CanConfigureButtons() == false then return end

	local Profile = Healium_GetProfile()
	RotateButtonsLeft(nil, btnIndex)

	-- The shift leaves a copy of the last entry behind, and with a single
	-- button RotateButtonsLeft does nothing at all.  Clear the trailing slot,
	-- or the deleted spell reappears as a duplicate as soon as the button
	-- count is raised again.
	local last = Profile.ButtonCount
	Profile.SpellNames[last] = nil
	Profile.SpellIcons[last] = nil
	Profile.SpellTypes[last] = nil
	Profile.SpellRanks[last] = nil
	Profile.IDs[last] = nil

	Profile.ButtonCount = math.max(last - 1, 0)

	Healium_Update_ConfigPanel()	
	Healium_UpdateButtonIcons()
	Healium_UpdateButtonAttributes()
end

local function HealiumMenu_InitializeDropDown(frame,level)
	level = level or 1
	
	local MenuTable = 
	{
		[1] = -- Define level one elements here
		{
			{ -- Title
				text = Healium_AddonColor .. Healium_AddonName .. "|r Menu",
				isTitle = 1,
				notCheckable = 1,
			},
			{ -- Config Panel
				text = Healium_AddonName .. " Config Panel",
				func = Healium_ShowConfigPanel,
				notCheckable = 1,
			},
			{ -- Set button count
				text = "Set button count",
				hasArrow = 1,
				value = "SetButtonCount",
				notCheckable = 1,
			},
			{ -- Configure Buttons
				text = "Configure Buttons",
				hasArrow = 1,
				value = "ConfigureButtons",
				notCheckable = 1,
			},
			{ -- Frames Submenu
				text = "Show / Hide Frames",
				hasArrow = 1,
				value = "Frames",
				notCheckable = 1,
			},
			{ -- Reset all frame positions
				text = "Reset all frame positions",
				func = Healium_ResetAllFramePositions,
				notCheckable = 1,
			},
			{ -- Close
				hasArrow  = nil,
				value  = nil,
				notCheckable = 1,
				text = "Close Menu",
				func = frame.HideMenu			
			}
		},
		[2] = -- Submenu items, keyed by value
		{
			["Frames"] = 
			{
				{
					text = "Toggle Frames",
					notCheckable = 1,
					func = ToggleAllFrames,
				},
				{	-- Party Frame
					text = "Show Party",
					notCheckable = 1,
					func = ShowPartyFrame,
				},
				{	-- Me Frame
					text = "Show Me",
					notCheckable = 1,
					func = ShowMeFrame,
				},
				{	-- Pet Frame
					text = "Show Pets",
					notCheckable = 1,					
					func = ShowPetsFrame,
				},
				{	-- Friends Frame
					text = "Show Friends",
					notCheckable = 1,					
					func = ShowFriendsFrame,
				},
-- TODO DAMAGERS/HEALERS frame	
--[[
				{	-- Damagers Frame
					text = "Show Damagers",
					notCheckable = 1,					
					func = ShowDamagersFrame,
				},
				{	-- Healers Frame
					text = "Show Healers",
					notCheckable = 1,					
					func = ShowHealersFrame,
				},
--]]				
				{	-- Tanks Frame
					text = "Show Tanks",
					notCheckable = 1,					
					func = ShowTanksFrame,
				},
				{	-- Target Frame
					text = "Show Target",
					notCheckable = 1,					
					func = ShowTargetFrame,
				},
				{	-- Focus Frame
					text = "Show Focus",
					notCheckable = 1,					
					func = ShowFocusFrame,
				},
				{
					text = "Hide All Raid Groups",
					notCheckable = 1,					
					func = Healium_HideAllRaidFrames,
				},
				{
					text = "Show Raid Groups 1 and 2 (10 man)",
					notCheckable = 1,					
					func = Healium_Show10ManRaidFrames,
				},
				{
					text = "Show Raid Groups 1-5 (25 man)",
					notCheckable = 1,					
					func = Healium_Show25ManRaidFrames,
				}, 
				{
					text = "Show Raid Groups 1-8 (40 man)",
					notCheckable = 1,					
					func = Healium_Show40ManRaidFrames,
				}, 
			},
		},
		[3] = {},
	}

	local sbc = { }
	local btnConfig = {}
	local Profile = Healium_GetProfile()	
	

	for i=0, Healium_MaxButtons, 1 do
	
		-- configure SetButtonCount
		local menuItem = { }
		menuItem.text = i
		menuItem.checked = i == Profile.ButtonCount
		menuItem.func = SetButtonCount
		menuItem.arg1 = i
--			menuItem.disabled = nil
		table.insert(sbc, menuItem)

		-- configure Configure Buttons	
		if i > 0 and i <= Profile.ButtonCount then
			local btnMenuItem = { }
			btnMenuItem.text = "Button " .. i
			btnMenuItem.value = i
			btnMenuItem.hasArrow = true
			btnMenuItem.notCheckable = 1
			table.insert(btnConfig, btnMenuItem)
		end
	end
	
	-- Add Rotate Left, Rotate Right, Insert Button, Delete Button to Configure Buttons
	local cmds = 
	{
		{ 
			text = "Rotate Buttons Left",
			notCheckable = 1,
			func = RotateButtonsLeft
		},
		{ 
			text = "Rotate Buttons Right",
			notCheckable = 1,
			func = RotateButtonsRight
		},
	}
		
	for k, v in ipairs (cmds) do
		table.insert(btnConfig, v)
	end		
	
	MenuTable[2].SetButtonCount = sbc
	MenuTable[2].ConfigureButtons = btnConfig

	local index = LIB_UIDROPDOWNMENU_MENU_VALUE or 1

	local spells =
	{
		{-- Title
			text = Healium_AddonColor .. Healium_AddonName .. "|r Button " .. index,
			isTitle = 1,
			notCheckable = 1
		}
	}

	local currentSpell = Profile.SpellNames[index]
	
	if Healium_IsRetail then 
		for k, v in ipairs (Healium_Spell.Name) do
			local spellmenuItem = { }
			spellmenuItem.text = Healium_Spell.Name[k]
			spellmenuItem.func = SetCurrentSpell
			spellmenuItem.icon = Healium_Spell.Icon[k]
			spellmenuItem.checked = currentSpell == Healium_Spell.Name[k]
			spellmenuItem.arg1 = index
			spellmenuItem.arg2 = k
			
			if (spellmenuItem.icon) then
				table.insert(spells, spellmenuItem)
			end
		end
	end

	-- Add No Spell, Insert Button, and Delete Button
	cmds = {}
	
	if Healium_IsRetail then 
		local noSpell = 
		{
			text = "No Spell",
			func = SetCurrentSpell,
			checked = currentSpell == nil,
			arg1 = index,
		}
		table.insert(cmds, noSpell)
	end
		
	local insert = 
	{
		text = "Insert Button",
		notCheckable = 1,
		func = InsertButton,
		arg1 = index
	}
	table.insert(cmds, insert)
	
	local delete = 
	{
		text = "Delete Button",
		notCheckable = 1,
		func = DeleteButton,
		arg1 = index
	}	
	table.insert(cmds, delete)

	for k, v in ipairs (cmds) do
		table.insert(spells, v)
	end		
	
	MenuTable[3][index] = spells

	
	local info = MenuTable[level]
	local menuval = LIB_UIDROPDOWNMENU_MENU_VALUE
	
	if (level > 1 and menuval) then
		if info[menuval] then
			info = info[menuval]
		end
	end

	for idx, entry in ipairs(info) do
		Lib_UIDropDownMenu_AddButton(entry, level)
	end

end

function Healium_InitMenu()
	HealiumMenu = CreateFrame("Frame", "HealiumOptionsMenu", Healium_MMButton, "Lib_UIDropDownMenuTemplate") 
	HealiumMenu:SetPoint("TOP", Healium_MMButton, "BOTTOM")
	Lib_UIDropDownMenu_Initialize(HealiumMenu, HealiumMenu_InitializeDropDown, "MENU");
end
