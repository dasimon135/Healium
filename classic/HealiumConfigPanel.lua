Healium_ConfigPanel_Category = nil

local PartyFrameOrderDropDown
local PartyFrameOrderOptions = {
	{ text = "Default", value = "DEFAULT" },
	{ text = "Tank-Healer-DPS", value = "TANK_HEALER_DPS" },
}

local function PartyFrameOrderDropDown_OnClick(dropdownbutton)
	local profile = Healium_GetProfile()
	profile.PartyFrameOrder = dropdownbutton.value
	Lib_UIDropDownMenu_SetSelectedValue(dropdownbutton.owner, dropdownbutton.value)
	Lib_UIDropDownMenu_SetText(dropdownbutton.owner, dropdownbutton:GetText())
	if not Healium_UpdatePartyFrameOrder() then
		Healium_Print("Party Frame Order will be applied when combat ends.")
	end
end

local function PartyFrameOrderDropDown_Init(frame, level)
	level = level or 1
	local selected = Healium_GetProfile().PartyFrameOrder or "DEFAULT"
	for _, option in ipairs(PartyFrameOrderOptions) do
		local info = Lib_UIDropDownMenu_CreateInfo()
		info.text = option.text
		info.value = option.value
		info.func = PartyFrameOrderDropDown_OnClick
		info.owner = frame
		info.checked = option.value == selected
		Lib_UIDropDownMenu_AddButton(info, level)
	end
end
local Healium_ConfigPanel_CategoryID = nil

local function CreateSliderFrame(name, parent)
	local template
	
	--if Healium_IsClassic then 
		template = "UISliderTemplate"
		--template = "UISliderTemplateWithLabels"
	--else
	--	template = "OptionsSliderTemplate"
	--end
	
	local slider = CreateFrame("Slider", name, parent, template)
	
	--if Healium_IsClassic then
	    slider.High = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT")
        slider.Low = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT")
        slider.Text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        slider.Text:SetPoint("BOTTOM", slider, "TOP")
        --slider.High:SetText(entry.highText)
		--slider.Low:SetText(entry.lowText)
	--end
	
	return slider
end

local function CreateDropDownMenu(name,parent,x,y)
  local f = CreateFrame("Frame", name, parent, "Lib_UIDropDownMenuTemplate") 
  f:SetPoint("TOPLEFT", parent, "TOPLEFT",x,y)
  Lib_UIDropDownMenu_SetWidth(f, 180)  
  
  f.Text = f:CreateFontString(nil, "OVERLAY","GameFontNormal")
  f.Text:SetPoint("TOPLEFT",f,"TOPLEFT",-50,-5)
  
  return f
end

local function DropDownMenuItem_OnClick(dropdownbutton)
	Lib_UIDropDownMenu_SetSelectedValue(dropdownbutton.owner, dropdownbutton.value) 

	local Profile = Healium_GetProfile()
	
	if (dropdownbutton.value == nil) then
--		Healium_SetProfileSpell(Profile, i, nil, nil, nil)
	end

	for i=1, Healium_MaxClassSpells, 1 do
		if (dropdownbutton.owner == HealiumDropDown[i]) then
			for j=0, Healium_MaxClassSpells - 1, 1 do
				if (dropdownbutton.value == j) then
					Healium_SetProfileSpell(Profile, i, Healium_Spell.Name[j+1], Healium_Spell.ID[j+1], Healium_Spell.Icon[j+1], nil)
				end
			end
		end
	end
	
	Healium_UpdateButtonIcons()
	Healium_UpdateButtonAttributes()	
end

-- Function called when the menu is opened, responsible for adding menu buttons
local function DropDownMenu_Init(frame,level)

	level = level or 1  
	local info = Lib_UIDropDownMenu_CreateInfo() 
	
	local DropDown = frame
	local spell = Lib_UIDropDownMenu_GetText(DropDown)
	
	for k, v in ipairs (Healium_Spell.Name) do
		info.text = Healium_Spell.Name[k] 
		info.value = k-1
		info.func = DropDownMenuItem_OnClick
		info.owner = DropDown
		info.checked = nil 
		info.icon = Healium_Spell.Icon[k]
		if (info.icon) then
			Lib_UIDropDownMenu_AddButton(info, level) 
			if Healium_Spell.Name[k] == spell then
				Lib_UIDropDownMenu_SetSelectedValue(DropDown , k-1)	
			end
		end
	end
	
	-- Add No Spell
	info.text = "No Spell"
	info.value = #Healium_Spell.Name
	info.func = DropDownMenuItem_OnClick
	info.ownder = DropDown
	info.checked = (spell == nil) or (spell == "No Spell")
	info.icon = nil
  
	Lib_UIDropDownMenu_AddButton(info, level)   
end

local function SoundDropDownMenuItem_OnClick(dropdownbutton)
	Lib_UIDropDownMenu_SetSelectedValue(dropdownbutton.owner, dropdownbutton.value) 
	Healium.DebufAudioFile = dropdownbutton.value
	Healium_InitDebuffSound()
	Healium_PlayDebuffSound()
end

local function SoundDropDownMenu_Init(frame, level)
	level = level or 1  
	local info = Lib_UIDropDownMenu_CreateInfo() 
	local sound = Lib_UIDropDownMenu_GetText(frame)
	
	for k, v in ipairs (Healium_Sounds) do
		local this_sound = next(v, nil)
		if Healium_IsRetail or not v[this_sound].retail then 
			info.text = this_sound
			info.value = this_sound
			info.func = SoundDropDownMenuItem_OnClick
			info.owner = frame
			info.checked = nil 
			Lib_UIDropDownMenu_AddButton(info, level) 
			if this_sound == sound then
				Lib_UIDropDownMenu_SetSelectedValue(frame, this_sound)	
			end
		end
	end
end


local function UpdateRangeCheckSliderText(frame)
    frame.Text:SetText("Range Check Frequency: |cFFFFFFFF".. format("%.1f",frame:GetValue()) .. " Hz")
end

function Healium_SetButtonCount(count)
	HealiumMaxButtonSlider.Text:SetText("Show |cFFFFFFFF"..count.. "|r Buttons")
	Healium_GetProfile().ButtonCount = count
	if Healium_InvalidateArmedBuffNames then Healium_InvalidateArmedBuffNames() end
	Healium_UpdateButtonVisibility()
end

local function MaxButtonSlider_Update(frame)
-- work around lame Blizzard slider bug in 5.4.0 and still in 5.4.1
	local step = frame:GetValueStep()
	local fixed_value = floor(frame:GetValue() / step + 0.5) * step;
	Healium_SetButtonCount(fixed_value)
end

local function TooltipsCheck_OnClick(frame)
	Healium.ShowToolTips = frame:GetChecked() or false
end

local function PercentageCheck_OnClick(frame)
	Healium.ShowPercentage = frame:GetChecked() or false
	Healium_UpdatePercentageVisibility()
end

local function ClassColorCheck_OnClick(frame)
	Healium.UseClassColors = frame:GetChecked() or false
	Healium_UpdateClassColors()
end

local function ShowBuffsCheck_OnClick(frame)
	Healium.ShowBuffs = frame:GetChecked() or false
	Healium_UpdateShowBuffs()
end

local function RangeCheckCheck_OnClick(frame)
	Healium.DoRangeChecks = frame:GetChecked() or false
end

local function EnableCooldownsCheck_OnClick(frame)
	Healium.EnableCooldowns = frame:GetChecked() or false
end

local function HideCloseButtonCheck_OnClick(frame)
	Healium.HideCloseButton = frame:GetChecked() or false
	Healium_UpdateCloseButtons()
end

local function HideCaptionsCheck_OnClick(frame)
	Healium.HideCaptions = frame:GetChecked() or false
	Healium_UpdateHideCaptions()
end

local function LockFramePositionsCheck_OnClick(frame)
	Healium.LockFrames = frame:GetChecked() or false
end

local function EnableCliqueCheck_OnClick(frame)
	Healium.EnableClique = frame:GetChecked() or false
	Healium_UpdateEnableClique()
end

local function ShowManaCheck_OnClick(frame)
	Healium.ShowMana = frame:GetChecked() or false
	Healium_UpdateShowMana()
end

local function ShowThreatCheck_OnClick(frame)
	Healium.ShowThreat = frame:GetChecked() or false
	Healium_UpdateShowThreat()
end

local function ShowRoleCheck_OnClick(frame)
	Healium.ShowRole = frame:GetChecked() or false
	Healium_UpdateShowRole()
end

local function ShowIncomingHealsCheck_OnClick(frame)
	Healium.ShowIncomingHeals = frame:GetChecked() or false
	Healium_UpdateShowIncomingHeals()
end

local function ShowRaidIconsCheck_OnClick(frame)
	Healium_DebugPrint("ShowRaidIconsCheck_OnClick")
	Healium.ShowRaidIcons = frame:GetChecked() or false
	Healium_UpdateShowRaidIcons()
end

local function UppercaseNamesCheck_OnClick(frame)
	Healium.UppercaseNames = frame:GetChecked() or false
	Healium_UpdateUnitNames()
end

local function ShowMinimapButtonCheck_OnClick(frame)
	Healium.ShowMinimapButton = frame:GetChecked() or false
	Healium_UpdateShowMinimapButton()
end

local function UpdateEnableDebuffsControls(frame)
	local color 
	if frame:GetChecked() then
		color = NORMAL_FONT_COLOR
	else
		color = GRAY_FONT_COLOR
	end
	
	for _,j in ipairs(frame.children) do
		j:SetTextColor(color.r, color.g, color.b)
	end
end

local function EnableDebuffsCheck_OnClick(frame)
	UpdateEnableDebuffsControls(frame)
	Healium.EnableDebufs = frame:GetChecked() or false
	Healium_UpdateEnableDebuffs()
end

local function EnableDebuffAudioCheck_OnClick(frame)
	Healium.EnableDebufAudio = frame:GetChecked() or false
end

local function EnableDebuffHealthbarHighlightingCheck_OnClick(frame)
	Healium.EnableDebufHealthbarHighlighting = frame:GetChecked() or false
	Healium_UpdateEnableDebuffs()
end

local function EnableDebuffButtonHighlightingCheck_OnClick(frame)
	Healium.EnableDebufButtonHighlighting = frame:GetChecked() or false
	Healium_UpdateEnableDebuffs()
end

local function EnableDebuffHealthbarColoringCheck_OnClick(frame)
	Healium.EnableDebufHealthbarColoring = frame:GetChecked() or false
	Healium_UpdateEnableDebuffs()
end

local function ScaleSlider_OnValueChanged(frame)
	Healium.Scale = frame:GetValue()
	Healium_SetScale()
	frame.Text:SetText("Scale: |cFFFFFFFF".. format("%.1f",Healium.Scale))
end

local function RangeCheckSlider_OnValueChanged(frame)
	Healium.RangeCheckPeriod = 1.0 / frame:GetValue()
	UpdateRangeCheckSliderText(frame)
end

function Healium_ShowConfigPanel()
	if not InCombatLockdown() then
		if Healium_IsClassic or Healium_IsClassicMists or Healium_IsClassicBCC then 
			Settings.OpenToCategory(Healium_ConfigPanel_CategoryID)
		else
			Settings.OpenToCategory(Healium_ConfigPanel_Category.ID)
		end
	end
end


local function CreateCheck(checkName, scrollchild, parent, tip, text)
	local check = CreateFrame("CheckButton", checkName,  scrollchild, "ChatConfigCheckButtonTemplate")
	check:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 0)
	check.tooltipText = tip
	check.Text = check:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	check.Text:SetPoint("LEFT", check, "RIGHT", 0)
	check.Text:SetText(text)
	return check
end

-- Used to update the config panel controls when the profile changes
function Healium_Update_ConfigPanel()
	local Profile = Healium_GetProfile()
	if PartyFrameOrderDropDown then
		local order = Profile.PartyFrameOrder or "DEFAULT"
		local text = order == "TANK_HEALER_DPS" and "Tank-Healer-DPS" or "Default"
		Lib_UIDropDownMenu_SetSelectedValue(PartyFrameOrderDropDown, order)
		Lib_UIDropDownMenu_SetText(PartyFrameOrderDropDown, text)
	end
	
	HealiumMaxButtonSlider:SetValue(Healium_GetProfile().ButtonCount)
	
	if Healium_IsRetail then 
		for i=1, Healium_MaxButtons, 1 do    
			local name
			if Profile.SpellTypes[i] == Healium_Type_Macro then 
				name =  "Macro: " .. Profile.SpellNames[i]
			elseif Profile.SpellTypes[i] == Healium_Type_Item then
				name = "Item: " .. Profile.SpellNames[i]
			else
				name = Profile.SpellNames[i]
				if name == nil then
					name = "No Spell"
				end
			end
		
			Lib_UIDropDownMenu_SetText(HealiumDropDown[i], name)
		end
	end
end

function Healium_CreateConfigPanel(Class, Version)
	local Profile = Healium_GetProfile()
	
	local panel = CreateFrame("Frame", nil, UIParent)
	Healium_ConfigPanel = panel
	panel.name = Healium_AddonName
	panel.okay = function (frame)frame.originalValue = MY_VARIABLE end    -- [[ When the player clicks okay, set the original value to the current setting ]] --
	panel.cancel = function (frame) MY_VARIABLE = frame.originalValue end    -- [[ When the player clicks cancel, set the current setting to the original value ]] --
	
	local layout
	Healium_ConfigPanel_Category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
	if not (Healium_IsClassic or Healium_IsClassicMists or Healium_IsClassicBCC) then 
		Healium_ConfigPanel_Category.ID = panel.name
	end
	Settings.RegisterAddOnCategory(Healium_ConfigPanel_Category);
	if Healium_IsClassic or Healium_IsClassicMists or Healium_IsClassicBCC then 
		Healium_ConfigPanel_CategoryID = Healium_ConfigPanel_Category:GetID()
	end

	local scrollframe = CreateFrame("ScrollFrame", "HealiumPanelScrollFrame", panel, "UIPanelScrollFrameTemplate") 
	scrollframe:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -25)
	scrollframe:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25,0)	
	scrollframe:Show()
	
    scrollframe.scrollbar = _G["HealiumPanelScrollFrameScrollBar"]   
	
	if (BackdropTemplateMixin) then 
		Mixin(scrollframe.scrollbar, BackdropTemplateMixin)
	end

    scrollframe.scrollbar:SetBackdrop({   
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",   
        edgeSize = 8,   
        tileSize = 32,   
        insets = { left = 0, right =0, top =5, bottom = 5 }})   
	
	
	local scrollchild = CreateFrame("Frame", "$parentScrollChild", scrollframe)
	scrollframe:SetScrollChild(scrollchild)	
	scrollchild:SetSize(1,1) 
	scrollchild:SetPoint("TOPRIGHT", -30, 0)
	scrollchild:Show()
	
	-- Title text
	local TitleText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
	TitleText:SetJustifyH("LEFT")
	TitleText:SetPoint("TOPLEFT", 10, -10)
	TitleText:SetText(Healium_AddonColoredName .. Version)
	-- Title subtext
	local TitleSubText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
	TitleSubText:SetJustifyH("LEFT")
	TitleSubText:SetPoint("TOPLEFT", 10, -30)
	TitleSubText:SetText("Welcome to the " .. Healium_AddonColoredName .. " options screen.|nUse the scrollbar to access more options.")
	TitleSubText:SetTextColor(1,1,1,1) 
  
	-- Create the Class Icon 
  	local HealiumClassIcon = CreateFrame("Frame", "HealiumClassIcon", scrollchild)
	HealiumClassIcon:SetPoint("TOPRIGHT", scrollframe, -35, 0)
	HealiumClassIconTexture = HealiumClassIcon:CreateTexture(nil, "BACKGROUND")
	HealiumClassIconTexture:SetAllPoints()
	HealiumClassIconTexture:SetTexture("Interface/Glues/CHARACTERCREATE/UI-CHARACTERCREATE-CLASSES")
	local coords = CLASS_ICON_TCOORDS[Class];
	HealiumClassIconTexture:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);	
	HealiumClassIcon:SetHeight(60)
	HealiumClassIcon:SetWidth(60)
	HealiumClassIcon.Text = HealiumClassIcon:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
	HealiumClassIcon.Text:SetText(strupper(Class))
	HealiumClassIcon.Text:SetPoint("CENTER",0,-38)
	HealiumClassIcon.Text:SetTextColor(1,1,0.2,1)

 	
	-- ToolTips Check Button
    local TooltipsCheck = CreateFrame("CheckButton","$parentShowTooltipCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
	TooltipsCheck:SetPoint("TOPLEFT",5,-70)	
    
    TooltipsCheck.Text = TooltipsCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	TooltipsCheck.Text:SetPoint("LEFT", TooltipsCheck, "RIGHT", 0)
    TooltipsCheck.Text:SetText("Show Button ToolTips")
	
    TooltipsCheck:SetScript("OnClick", TooltipsCheck_OnClick)
	TooltipsCheck.tooltipText = "Shows spell tooltips when hovering the mouse over the " .. Healium_AddonColoredName .. " buttons."

	-- ShowMana Check Button
	local ShowManaCheck = CreateCheck("$parentShowManaCheckButton",scrollchild,TooltipsCheck, "Shows the unit's mana.", "Show Mana")
	ShowManaCheck:SetScript("OnClick", ShowManaCheck_OnClick)
	
	-- Percentage Check button
	local PercentageCheck = CreateCheck("$parentShowPercentageCheckButton",scrollchild,ShowManaCheck, "Shows the unit's health as a percentage on the right side of the health bar.", "Show Health Percentage")
	PercentageCheck:SetScript("OnClick", PercentageCheck_OnClick)
	
	-- ClassColor Check button
	local ClassColorCheck = CreateCheck("$parentClassColorCheckButton",scrollchild,PercentageCheck, 
	"Colors the healthbar based on the unit's class instead of green/yellow/red based on it's current health.", "Use Class Colors")
    ClassColorCheck:SetScript("OnClick", ClassColorCheck_OnClick)
	
	-- Hide Close Check button
	local HideCloseButtonCheck = CreateCheck("$parentHideCloseCheckButton",scrollchild,ClassColorCheck,
		"Hides the X (close) button on the upper-right of the " .. Healium_AddonColoredName ..	" caption bar.", "Hide Close Buttons")		
	HideCloseButtonCheck:SetScript("OnClick", HideCloseButtonCheck_OnClick)	

	-- Hide Captions Check button
	local HideCaptionsCheck = CreateCheck("$parentHideCaptionsCheckButton",scrollchild,HideCloseButtonCheck,
		"Automatically hides the caption bar of " .. Healium_AddonColoredName .. " frames when the mouse leaves the caption.", "Hide Captions")		
	HideCaptionsCheck:SetScript("OnClick", HideCaptionsCheck_OnClick)	
	
	-- Lock Frame Positions Check button
	local LockFramePositionsCheck = CreateCheck("$parentLockFramePositionsCheckButton",scrollchild,HideCaptionsCheck, "Prevents dragging of any " .. Healium_AddonColoredName .. " frames.", "Lock Frame Positions")		
	LockFramePositionsCheck:SetScript("OnClick", LockFramePositionsCheck_OnClick)	
	
	-- Enable Clique check button
	local EnableCliqueCheck = CreateCheck("$parentEnableCliqueCheckButton",scrollchild,LockFramePositionsCheck,
		"Allows use of the Clique addon on the healthbar.  Clique will override the ability to LeftClick to target the unit unless you configure Clique to do that, which it can.", "Enable Clique Support")		
	EnableCliqueCheck:SetScript("OnClick", EnableCliqueCheck_OnClick)	
	
	-- Show Threat check button
	local ShowThreatCheck = CreateCheck("$parentShowRoleCheckButton",scrollchild,EnableCliqueCheck,	"Shows a threat indicator that displays if the unit has threat on any mob.", "Show Threat")	
	ShowThreatCheck:SetScript("OnClick", ShowThreatCheck_OnClick)	

	-- Show Role check button
	local ShowRoleCheck	
	if not Healium_IsClassic then 
		ShowRoleCheck = CreateCheck("$parentShowRoleCheckButton",scrollchild,ShowThreatCheck,
			"Shows unit's role icon (healer, tank, damage) when in random dungeons.  Will override Health Percentage text when unit is assigned a role.", "Show Role Icons")
		ShowRoleCheck:SetScript("OnClick", ShowRoleCheck_OnClick)	
	end
	
	local ShowIncomingHealsCheckParent
	
	if Healium_IsClassic then 
		ShowIncomingHealsCheckParent = ShowThreatCheck
	else
		ShowIncomingHealsCheckParent = ShowRoleCheck
	end

	-- Show Incoming Heals check button
	local ShowIncomingHealsCheck = CreateCheck("$parentShowIncomingHealsCheckButton",scrollchild,ShowIncomingHealsCheckParent,
		"Shows incoming heals from all units as a dark green bar extending beyond the unit's current health.", "Show Incoming Heals")
	ShowIncomingHealsCheck:SetScript("OnClick", ShowIncomingHealsCheck_OnClick)	
	
	-- Show Raid Icons check button
	local ShowRaidIconsCheck = CreateCheck("$parentShowRaidIconsCheckButton",scrollchild,ShowIncomingHealsCheck, "Shows the raid icon assigned to this unit.", "Show Raid Icons")
	ShowRaidIconsCheck:SetScript("OnClick", ShowRaidIconsCheck_OnClick)	
	
	-- Uppercase names check button
	local UppercaseNamesCheck = CreateCheck("$parentShowUppercaseNamesCheckButton",scrollchild,ShowRaidIconsCheck, "Shows names in UPPERCASE text.", "UPPERCASE names")
	UppercaseNamesCheck:SetScript("OnClick", UppercaseNamesCheck_OnClick)

	-- Show minimap button check
	local ShowMinimapButtonCheck = CreateCheck("$parentShowMinimapButtonCheckButton",scrollchild,UppercaseNamesCheck, "Shows the Minimap button", "Show Minimap button")
	ShowMinimapButtonCheck:SetScript("OnClick", ShowMinimapButtonCheck_OnClick)

	if Healium_IsClassicMists then
		PartyFrameOrderDropDown = CreateFrame("Frame", "$parentPartyFrameOrderDropDown", scrollchild, "Lib_UIDropDownMenuTemplate")
		PartyFrameOrderDropDown:SetPoint("TOPLEFT", ShowMinimapButtonCheck, "BOTTOMLEFT", 130, 0)
		Lib_UIDropDownMenu_SetWidth(PartyFrameOrderDropDown, 150)
		PartyFrameOrderDropDown.Text = PartyFrameOrderDropDown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		PartyFrameOrderDropDown.Text:SetPoint("TOPLEFT", ShowMinimapButtonCheck, "BOTTOMLEFT", 0, -8)
		PartyFrameOrderDropDown.Text:SetText("Party Frame Order")
		PartyFrameOrderDropDown.tooltipText = "Controls ordering only in the Party frame."
		Lib_UIDropDownMenu_Initialize(PartyFrameOrderDropDown, PartyFrameOrderDropDown_Init)
	end
	
	
	local ClassicConfigButtonsText
	
	if Healium_IsRetail then		
		-- Dropdown menus
		local ButtonConfigTitleText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
		ButtonConfigTitleText:SetJustifyH("LEFT")
		if PartyFrameOrderDropDown then
			ButtonConfigTitleText:SetPoint("TOPLEFT", PartyFrameOrderDropDown, "BOTTOMLEFT", -130, -20)
		else
			ButtonConfigTitleText:SetPoint("TOPLEFT", ShowMinimapButtonCheck, "BOTTOMLEFT", 0, -20)
		end
		ButtonConfigTitleText:SetText("Button Configuration")	
		
		local ButtonConfigTitleSubText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
		ButtonConfigTitleSubText:SetJustifyH("LEFT")
		ButtonConfigTitleSubText:SetPoint("TOPLEFT", ButtonConfigTitleText, "BOTTOMLEFT", 0, 0)
		ButtonConfigTitleSubText:SetText("Click the dropdowns to configure each button.|nYou may now drag and drop directly from the spellbook|nonto buttons to configure them, including buffs!")
		ButtonConfigTitleSubText:SetTextColor(1,1,1,1) 	

		local y = -480
		local y_inc = 20
		
		for i=1, Healium_MaxButtons, 1 do
			HealiumDropDown[i] = CreateDropDownMenu("HealiumDropDown[" .. i .. "]",scrollchild,60,y)
			y = y - y_inc
			HealiumDropDown[i].Text:SetText("Button " .. i)
	--		HealiumDropDown[i].tooltipText = Healium_AddonColoredName .. " button"
		end
	else
		ClassicConfigButtonsText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
		ClassicConfigButtonsText:SetJustifyH("LEFT")
		if PartyFrameOrderDropDown then
			ClassicConfigButtonsText:SetPoint("TOPLEFT", PartyFrameOrderDropDown, "BOTTOMLEFT", -130, -20)
		else
			ClassicConfigButtonsText:SetPoint("TOPLEFT", ShowMinimapButtonCheck, "BOTTOMLEFT", 0, -30)
		end
		ClassicConfigButtonsText:SetText("In Classic, to configure buttons, drag and drop directly from the spellbook onto buttons.")
		ClassicConfigButtonsText:SetTextColor(1,1,1,1) 	
	end

	-- Slider for controlling how many buttons to show
    HealiumMaxButtonSlider = CreateSliderFrame("$parentMaxButtonSlider",scrollchild)
    HealiumMaxButtonSlider:SetWidth(128)
    HealiumMaxButtonSlider:SetHeight(16)
          
    HealiumMaxButtonSlider:SetPoint("TOPLEFT", 220, -110)
      
    HealiumMaxButtonSlider:SetMinMaxValues(0,Healium_MaxButtons)
--	HealiumMaxButtonSlider:SetStepsPerPage(1)	
    HealiumMaxButtonSlider:SetValueStep(1)
    HealiumMaxButtonSlider:SetValue(Healium_GetProfile().ButtonCount)
	HealiumMaxButtonSlider.tooltipText = "How many " .. Healium_AddonColoredName .. " buttons to show."
      
    HealiumMaxButtonSlider.Text = HealiumMaxButtonSlider:CreateFontString(nil, "BACKGROUND","GameFontNormalLarge")
    HealiumMaxButtonSlider.Text:SetPoint("CENTER", 0, 17)
    HealiumMaxButtonSlider.Text:SetText("Show |cFFFFFFFF"..HealiumMaxButtonSlider:GetValue().. "|r Buttons")
      
	HealiumMaxButtonSlider.Low:SetText("0")
	HealiumMaxButtonSlider.High:SetText(Healium_MaxButtons)
    --_G[HealiumMaxButtonSlider:GetName().."Low"]:SetText("0")
    --_G[HealiumMaxButtonSlider:GetName().."High"]:SetText(Healium_MaxButtons)
      
    HealiumMaxButtonSlider:SetScript("OnValueChanged",MaxButtonSlider_Update)
    HealiumMaxButtonSlider:Show()
  
    -- Slider for Scaling
    local ScaleSlider = CreateSliderFrame("HealiumScaleSlider",scrollchild)
    ScaleSlider:SetWidth(100)
    ScaleSlider:SetHeight(16)
    
	ScaleSlider.Low:SetText("Small")
	ScaleSlider.High:SetText("Large")
    --_G[ScaleSlider:GetName().."Low"]:SetText("Small")
    --_G[ScaleSlider:GetName().."High"]:SetText("Large")
    
    ScaleSlider:SetMinMaxValues(0.6,5.0)
    ScaleSlider:SetValueStep(0.1)
    ScaleSlider:SetValue(Healium.Scale)
    
    ScaleSlider:SetPoint("TOPLEFT", HealiumMaxButtonSlider, "BOTTOMLEFT", 0, -30)
    
    ScaleSlider.Text = ScaleSlider:CreateFontString(nil, "BACKGROUND","GameFontNormalLarge")
    ScaleSlider.Text:SetPoint("CENTER", -5, 17)
    ScaleSlider.Text:SetText("Scale: |cFFFFFFFF".. format("%.1f",ScaleSlider:GetValue()))
 
    ScaleSlider:SetScript("OnValueChanged", ScaleSlider_OnValueChanged)
	ScaleSlider.tooltipText = "Sets the scale of all " .. Healium_AddonColoredName .. " frames."

	-- Show Frames Settings
	local ShowFramesTitleText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
	ShowFramesTitleText:SetJustifyH("LEFT")
	local ShowFramesParent
	if not Healium_IsRetail then 
		ShowFramesTitleText:SetPoint("TOPLEFT", ClassicConfigButtonsText, "BOTTOMLEFT", 0, -30)
	else
		ShowFramesTitleText:SetPoint("TOPLEFT", HealiumDropDown[Healium_MaxButtons].Text, "BOTTOMLEFT", 0, -30)
	end
	ShowFramesTitleText:SetText("Show Frames")	
	
	local ShowFramesTitleSubText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
	ShowFramesTitleSubText:SetJustifyH("LEFT")
	ShowFramesTitleSubText:SetPoint("TOPLEFT", ShowFramesTitleText, "BOTTOMLEFT", 0, 0)
	ShowFramesTitleSubText:SetText("Check each frame to show.")
	ShowFramesTitleSubText:SetTextColor(1,1,1,1) 
	
	-- Show Party Check
    Healium_ShowPartyCheck = CreateFrame("CheckButton","$parentShowPartyCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    Healium_ShowPartyCheck:SetPoint("TOPLEFT",ShowFramesTitleSubText, "BOTTOMLEFT", 0, -10)
	Healium_ShowPartyCheck.tooltipText = "Shows the Party " .. Healium_AddonColoredName .. " frame."
    Healium_ShowPartyCheck.Text = Healium_ShowPartyCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
    Healium_ShowPartyCheck.Text:SetPoint("LEFT", Healium_ShowPartyCheck, "RIGHT", 0)
    Healium_ShowPartyCheck.Text:SetText("Party")
    
    Healium_ShowPartyCheck:SetScript("OnClick",function()
        Healium.ShowPartyFrame = Healium_ShowPartyCheck:GetChecked() or false
		Healium_ShowHidePartyFrame()
    end)

	-- Show Pets Check
	Healium_ShowPetsCheck = CreateCheck("$parentShowPetsCheckButton",scrollchild,Healium_ShowPartyCheck, "Shows the Pets " .. Healium_AddonColoredName .. " frame.", "Pets")
    
    Healium_ShowPetsCheck:SetScript("OnClick",function()
        Healium.ShowPetsFrame = Healium_ShowPetsCheck:GetChecked() or false
		Healium_ShowHidePetsFrame()
    end)

	-- Show Me Check
	Healium_ShowMeCheck = CreateCheck("$parentShowMeCheckButton",scrollchild,Healium_ShowPetsCheck, "Shows the Me " .. Healium_AddonColoredName .. " frame.", "Me")
    
    Healium_ShowMeCheck:SetScript("OnClick",function()
        Healium.ShowMeFrame = Healium_ShowMeCheck:GetChecked() or false
		Healium_ShowHideMeFrame()
    end)
	
	-- Show Friends Check
	Healium_ShowFriendsCheck = CreateCheck("$parentShowFriendsCheckButton",scrollchild,Healium_ShowMeCheck, "Shows the Friends " .. Healium_AddonColoredName .. " frame.", "Friends")
    
    Healium_ShowFriendsCheck:SetScript("OnClick",function()
        Healium.ShowFriendsFrame = Healium_ShowFriendsCheck:GetChecked() or false
		Healium_ShowHideFriendsFrame()
    end)	
	
	-- Show Target Check
	Healium_ShowTargetCheck = CreateCheck("$parentShowTargetCheckButton",scrollchild,Healium_ShowFriendsCheck, "Shows the Target " .. Healium_AddonColoredName .. " frame.", "Target")
    
    Healium_ShowTargetCheck:SetScript("OnClick",function()
        Healium.ShowTargetFrame = Healium_ShowTargetCheck:GetChecked() or false
		Healium_ShowHideTargetFrame()
    end)		
	
	-- Show Focus Check
	if not Healium_IsClassic then 
		Healium_ShowFocusCheck = CreateCheck("$parentShowFocusCheckButton",scrollchild,Healium_ShowTargetCheck, "Shows the Focus " .. Healium_AddonColoredName .. " frame.", "Focus")
		
		Healium_ShowFocusCheck:SetScript("OnClick",function()
			Healium.ShowFocusFrame = Healium_ShowFocusCheck:GetChecked() or false
			Healium_ShowHideFocusFrame()
		end)		
	end
	
	-- Show Group 1 Check
	local Group1Parent
	if Healium_IsClassic then 
		Group1Parent = Healium_ShowTargetCheck
	else
		Group1Parent = Healium_ShowFocusCheck
	end
	
	Healium_ShowGroup1Check = CreateCheck("$parentShowGroup1CheckButton",scrollchild,Group1Parent, "Shows the Group 1 " .. Healium_AddonColoredName .. " frame.", "Group 1")
    
    Healium_ShowGroup1Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[1] = Healium_ShowGroup1Check:GetChecked() or false
		Healium_ShowHideGroupFrame(1)		
    end)	
	
	-- Show Group 2 Check
	Healium_ShowGroup2Check = CreateCheck("$parentShowGroup2CheckButton",scrollchild,Healium_ShowGroup1Check, "Shows the Group 2 " .. Healium_AddonColoredName .. " frame.", "Group 2")
    
    Healium_ShowGroup2Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[2] = Healium_ShowGroup2Check:GetChecked() or false
		Healium_ShowHideGroupFrame(2)
    end)		
	
	-- Show Group 3 Check
	Healium_ShowGroup3Check = CreateCheck("$parentShowGroup3CheckButton",scrollchild,Healium_ShowGroup2Check, "Shows the Group 3 " .. Healium_AddonColoredName .. " frame.", "Group 3")
    
    Healium_ShowGroup3Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[3] = Healium_ShowGroup3Check:GetChecked() or false
		Healium_ShowHideGroupFrame(3)		
    end)		

	-- Show Group 4 Check
	Healium_ShowGroup4Check = CreateCheck("$parentShowGroup4CheckButton",scrollchild,Healium_ShowGroup3Check, "Shows the Group 4 " .. Healium_AddonColoredName .. " frame.", "Group 4")
    
    Healium_ShowGroup4Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[4]= Healium_ShowGroup4Check:GetChecked() or false
		Healium_ShowHideGroupFrame(4)		
    end)			
	
	-- Show Group 5 Check
    Healium_ShowGroup5Check = CreateCheck("$parentShowGroup5CheckButton",scrollchild,Healium_ShowGroup4Check, "Shows the Group 5 " .. Healium_AddonColoredName .. " frame.", "Group 5")
    
    Healium_ShowGroup5Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[5] = Healium_ShowGroup5Check:GetChecked() or false
		Healium_ShowHideGroupFrame(5)
    end)		

	-- Show Group 6 Check
    Healium_ShowGroup6Check = CreateCheck("$parentShowGroup6CheckButton",scrollchild,Healium_ShowGroup5Check, "Shows the Group 6 " .. Healium_AddonColoredName .. " frame.", "Group 6")
    
    Healium_ShowGroup6Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[6] = Healium_ShowGroup6Check:GetChecked() or false
		Healium_ShowHideGroupFrame(6)
    end)	
	
	-- Show Group 7 Check
    Healium_ShowGroup7Check = CreateCheck("$parentShowGroup7CheckButton",scrollchild,Healium_ShowGroup6Check, "Shows the Group 7 " .. Healium_AddonColoredName .. " frame.", "Group 7")
    
    Healium_ShowGroup7Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[7] = Healium_ShowGroup7Check:GetChecked() or false
		Healium_ShowHideGroupFrame(7)		
    end)	
	
	-- Show Group 8 Check
    Healium_ShowGroup8Check = CreateCheck("$parentShowGroup8CheckButton",scrollchild,Healium_ShowGroup7Check, "Shows the Group 8 " .. Healium_AddonColoredName .. " frame.", "Group 8")
    
    Healium_ShowGroup8Check:SetScript("OnClick",function()
        Healium.ShowGroupFrames[8] = Healium_ShowGroup8Check:GetChecked() or false
		Healium_ShowHideGroupFrame(8)
    end)		
-- TODO DAMAGERS/HEALERS frame

	-- Show Damagers Check
    Healium_ShowDamagersCheck = CreateCheck("$parentShowDamagersCheckButton",scrollchild,Healium_ShowGroup8Check, "Shows the Damagers " .. Healium_AddonColoredName .. " frame.", "Damagers")
	
    Healium_ShowDamagersCheck:SetScript("OnClick",function()
        Healium.ShowDamagersFrame = Healium_ShowDamagersCheck:GetChecked() or false
		Healium_ShowHideDamagersFrame()
    end)			

	-- Show Healers Check
    Healium_ShowHealersCheck = CreateCheck("$parentShowHealersCheckButton",scrollchild,Healium_ShowDamagersCheck, "Shows the Healers " .. Healium_AddonColoredName .. " frame.", "Healers")
	
    Healium_ShowHealersCheck:SetScript("OnClick",function()
        Healium.ShowHealersFrame = Healium_ShowHealersCheck:GetChecked() or false
		Healium_ShowHideHealersFrame()
    end)				

	-- Show Tanks Check
    Healium_ShowTanksCheck = CreateCheck("$parentShowTanksCheckButton",scrollchild,Healium_ShowHealersCheck, "Shows the Tanks " .. Healium_AddonColoredName .. " frame.", "Tanks")
    
    Healium_ShowTanksCheck:SetScript("OnClick",function()
        Healium.ShowTanksFrame = Healium_ShowTanksCheck:GetChecked() or false
		Healium_ShowHideTanksFrame()
    end)			

	
	-- Debuff Warnings
	local DebuffWarningsTitleText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
	DebuffWarningsTitleText:SetJustifyH("LEFT")
	DebuffWarningsTitleText:SetPoint("TOPLEFT", Healium_ShowTanksCheck, "BOTTOMLEFT", 0, -30)
	DebuffWarningsTitleText:SetText("Debuff Warnings")
	
	local DebuffWarningsSubText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
	DebuffWarningsSubText:SetJustifyH("LEFT")
	DebuffWarningsSubText:SetPoint("TOPLEFT", DebuffWarningsTitleText, "BOTTOMLEFT", 0, 0)
	DebuffWarningsSubText:SetText("Debuff warnings are audible and visual indicators that|nnotify you when you can cure a debuff on a player.")
	DebuffWarningsSubText:SetTextColor(1,1,1,1) 

	
	-- Enable Debuffs check button
    local EnableDebuffsCheck = CreateFrame("CheckButton","$parentEnableDebuffsCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
	EnableDebuffsCheck.children = { }
    EnableDebuffsCheck:SetPoint("TOPLEFT", DebuffWarningsSubText, "BOTTOMLEFT", 0, -10)
    
    EnableDebuffsCheck.Text = EnableDebuffsCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableDebuffsCheck.Text:SetPoint("LEFT", EnableDebuffsCheck, "RIGHT", 0)
    EnableDebuffsCheck.Text:SetText("Enable Debuff Warnings")

	EnableDebuffsCheck:SetScript("OnClick", EnableDebuffsCheck_OnClick)	
	EnableDebuffsCheck.tooltipText = "Enables debuff warnings"

	-- Enable Debuff Healthbar coloring check button 
	local EnableDebufHealthbarColoringCheck	= CreateFrame("CheckButton","$parentEnableDebuffHealthbarColoringCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    EnableDebufHealthbarColoringCheck:SetPoint("TOPLEFT", EnableDebuffsCheck, "BOTTOMLEFT", 20, 0)
    
    EnableDebufHealthbarColoringCheck.Text = EnableDebufHealthbarColoringCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableDebufHealthbarColoringCheck.Text:SetPoint("LEFT", EnableDebufHealthbarColoringCheck, "RIGHT", 0)
    EnableDebufHealthbarColoringCheck.Text:SetText("Healthbar Coloring")
	table.insert(EnableDebuffsCheck.children, EnableDebufHealthbarColoringCheck.Text)
	
	EnableDebufHealthbarColoringCheck:SetScript("OnClick", EnableDebuffHealthbarColoringCheck_OnClick)	
	EnableDebufHealthbarColoringCheck.tooltipText = "Enables coloring of the healthbar of a player that has a debuff which you can cure"
	
	
	-- Enable Debuff Healthbar highlighting check button
    local EnableDebuffHealthbarHighlightingCheck = CreateFrame("CheckButton","$parentEnableDebuffHealthbarHighlightingCheck",scrollchild,"ChatConfigCheckButtonTemplate")
    EnableDebuffHealthbarHighlightingCheck:SetPoint("TOPLEFT", EnableDebufHealthbarColoringCheck, "BOTTOMLEFT", 0, 0)
    
    EnableDebuffHealthbarHighlightingCheck.Text = EnableDebuffHealthbarHighlightingCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableDebuffHealthbarHighlightingCheck.Text:SetPoint("LEFT", EnableDebuffHealthbarHighlightingCheck, "RIGHT", 0)
    EnableDebuffHealthbarHighlightingCheck.Text:SetText("Healthbar Highlight Warning")
	table.insert(EnableDebuffsCheck.children, EnableDebuffHealthbarHighlightingCheck.Text)
	
	EnableDebuffHealthbarHighlightingCheck:SetScript("OnClick", EnableDebuffHealthbarHighlightingCheck_OnClick)	
	EnableDebuffHealthbarHighlightingCheck.tooltipText = "Enables highlighting of the healthbar of a player that has a debuff which you can cure"


	-- Enable Debuff Button highlighting check button
    local EnableDebuffButtonHighlightingCheck = CreateFrame("CheckButton","$parentEnableDebuffButtonHighlightingCheck",scrollchild,"ChatConfigCheckButtonTemplate")
    EnableDebuffButtonHighlightingCheck:SetPoint("TOPLEFT", EnableDebuffHealthbarHighlightingCheck, "BOTTOMLEFT", 0, 0)
    
    EnableDebuffButtonHighlightingCheck.Text = EnableDebuffButtonHighlightingCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableDebuffButtonHighlightingCheck.Text:SetPoint("LEFT", EnableDebuffButtonHighlightingCheck, "RIGHT", 0)
    EnableDebuffButtonHighlightingCheck.Text:SetText("Button Highlight Warning")
	table.insert(EnableDebuffsCheck.children, EnableDebuffButtonHighlightingCheck.Text)
	
	EnableDebuffButtonHighlightingCheck:SetScript("OnClick", EnableDebuffButtonHighlightingCheck_OnClick)	
	EnableDebuffButtonHighlightingCheck.tooltipText = "Enables highlighting of buttons which have been assigned a spell that can cure a debuff on a player"

	-- Enable Debuff Audio check button
    local EnableDebuffAudioCheck = CreateFrame("CheckButton","$parentEnableDebuffAudioCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    EnableDebuffAudioCheck:SetPoint("TOPLEFT", EnableDebuffButtonHighlightingCheck, "BOTTOMLEFT", 0, 0)
    
    EnableDebuffAudioCheck.Text = EnableDebuffAudioCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
	EnableDebuffAudioCheck.Text:SetPoint("LEFT", EnableDebuffAudioCheck, "RIGHT", 0)
    EnableDebuffAudioCheck.Text:SetText("Audio Warning")
	table.insert(EnableDebuffsCheck.children, EnableDebuffAudioCheck.Text)
	
	EnableDebuffAudioCheck:SetScript("OnClick", EnableDebuffAudioCheck_OnClick)	
	EnableDebuffAudioCheck.tooltipText = "Enables an audio warning when a player has a debuff which you can cure, and is within 40yds"
	
	-- Sound drop down
	local SoundDropDown = CreateFrame("Frame", "$parentSoundDropDown", scrollchild, "Lib_UIDropDownMenuTemplate") 
	SoundDropDown:SetPoint("TOPLEFT", EnableDebuffAudioCheck, "BOTTOMLEFT",65, 0)
	SoundDropDown.Text = SoundDropDown:CreateFontString(nil, "OVERLAY","GameFontNormal")
	SoundDropDown.Text:SetText("Audio File")
	SoundDropDown.Text:SetPoint("TOPLEFT",SoundDropDown,"TOPLEFT",-60,-5)
	Lib_UIDropDownMenu_Initialize(SoundDropDown, SoundDropDownMenu_Init)
	table.insert(EnableDebuffsCheck.children, SoundDropDown.Text)	
	
	-- Play sound button
	local PlayButton = CreateFrame("Button", "$parentPlaySoundButton", scrollchild, "UIPanelButtonTemplate")
	PlayButton:SetText("Play")
	PlayButton:SetWidth(54)
	PlayButton:SetHeight(22)
	PlayButton:SetPoint("LEFT", SoundDropDown, "RIGHT", 120, 0)
	PlayButton:SetScript("OnClick", Healium_PlayDebuffSound)
	
	-- CPU Intensive Settings text
	local UpdatingTitleText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalLarge")
	UpdatingTitleText:SetJustifyH("LEFT")
	UpdatingTitleText:SetPoint("TOPLEFT", EnableDebuffAudioCheck, "BOTTOMLEFT", -20, -60)
	UpdatingTitleText:SetText("CPU Intensive Settings")

	local UpdatingTitleSubText = scrollchild:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
	UpdatingTitleSubText:SetJustifyH("LEFT")
	UpdatingTitleSubText:SetPoint("TOPLEFT", UpdatingTitleText, "BOTTOMLEFT", 0, 0)
	UpdatingTitleSubText:SetText("Enabling these settings may cause extra lag.")
	UpdatingTitleSubText:SetTextColor(1,1,1,1) 
	
    -- EnableColldowns Check Button
    local EnableCooldownsCheck = CreateFrame("CheckButton","$parentEnableCooldownsCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    EnableCooldownsCheck:SetPoint("TOPLEFT", UpdatingTitleSubText, "BOTTOMLEFT", 0, -10)
    EnableCooldownsCheck.tooltipText = "Enables cooldown animations on the " .. Healium_AddonColoredName .. " buttons."
	
    EnableCooldownsCheck.Text = EnableCooldownsCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
    EnableCooldownsCheck.Text:SetPoint("LEFT", EnableCooldownsCheck, "RIGHT", 0)
    EnableCooldownsCheck.Text:SetText("Enable Cooldowns")
    EnableCooldownsCheck:SetScript("OnClick", EnableCooldownsCheck_OnClick)
	

	-- RangeCheck Check Button
    local RangeCheckCheck = CreateFrame("CheckButton","$parentRangeCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    RangeCheckCheck:SetPoint("TOPLEFT",EnableCooldownsCheck, "BOTTOMLEFT", 0, 0)
    RangeCheckCheck.tooltipText = "Enables range checks on the " .. Healium_AddonColoredName .. " buttons."
	
    RangeCheckCheck.Text = RangeCheckCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
    RangeCheckCheck.Text:SetPoint("LEFT", RangeCheckCheck, "RIGHT", 0)
    RangeCheckCheck.Text:SetText("Enable Range Checks")
    RangeCheckCheck:SetScript("OnClick",RangeCheckCheck_OnClick)
	
	-- RangeCheck Slider
	local RangeCheckSlider = CreateSliderFrame("$parentRangeCheckSlider", scrollchild)
    RangeCheckSlider:SetWidth(180)
    RangeCheckSlider:SetHeight(16)
    
	RangeCheckSlider.Low:SetText("Slower\n(Less CPU)")
	RangeCheckSlider.High:SetText("Faster\n(More CPU)")
    --_G[RangeCheckSlider:GetName().."Low"]:SetText("Slower\n(Less CPU)")
    --_G[RangeCheckSlider:GetName().."High"]:SetText("Faster\n(More CPU)")
    
    RangeCheckSlider:SetMinMaxValues(.5,5.0)
    RangeCheckSlider:SetValueStep(0.1)
    RangeCheckSlider:SetValue(1.0/Healium.RangeCheckPeriod)
    
    RangeCheckSlider:SetPoint("TOPLEFT", RangeCheckCheck.Text, "TOPRIGHT", 15, 0)
    RangeCheckSlider.tooltipText = "Controls how often to do range checks.  The further to the right, the more often range checks are performed and the more CPU it will use."
	
    RangeCheckSlider.Text = RangeCheckSlider:CreateFontString(nil, "BACKGROUND","GameFontNormalSmall")
    RangeCheckSlider.Text:SetPoint("CENTER", -5, 17)
    UpdateRangeCheckSliderText(RangeCheckSlider)
    
    RangeCheckSlider:SetScript("OnValueChanged", RangeCheckSlider_OnValueChanged)
	
	-- ShowBuffs check
	local ShowBuffsCheck = CreateFrame("CheckButton","$parentShowBuffsCheckButton",scrollchild,"ChatConfigCheckButtonTemplate")
    ShowBuffsCheck:SetPoint("TOPLEFT",RangeCheckCheck, "BOTTOMLEFT", 0, 0)
    ShowBuffsCheck.tooltipText = "Shows the buffs and HOTs you have personally cast on the player to the left of the healthbar.  It will only show spells that are configured in " .. Healium_AddonColoredName .. "."
	
    ShowBuffsCheck.Text = ShowBuffsCheck:CreateFontString(nil, "BACKGROUND","GameFontNormal")
    ShowBuffsCheck.Text:SetPoint("LEFT", ShowBuffsCheck, "RIGHT", 0)
    ShowBuffsCheck.Text:SetText("Show Buffs")
	ShowBuffsCheck:SetScript("OnClick", ShowBuffsCheck_OnClick);

    -- About Frame
    local AboutTitle = CreateFrame("Frame","",scrollchild)
--    AboutTitle:SetFrameStrata("TOOLTIP")
    AboutTitle:SetWidth(160)
    AboutTitle:SetHeight(20)
    
    AboutTitle.Text = AboutTitle:CreateFontString(nil, "BACKGROUND","GameFontNormalLarge")
    AboutTitle.Text:SetPoint("TOPLEFT",ShowBuffsCheck, "BOTTOMLEFT", 0, -30)
    AboutTitle.Text:SetText("About " .. Healium_AddonColoredName)
    
    local AboutFrame = CreateFrame("Frame","AboutHealium",scrollchild,BackdropTemplateMixin and "BackdropTemplate")
    AboutFrame:SetWidth(340)
    AboutFrame:SetHeight(80)
    AboutFrame:SetPoint("TOPLEFT", AboutTitle.Text, "BOTTOMLEFT", 0, 0)

    AboutFrame:SetBackdrop({bgFile = "",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }})

    AboutFrame.Text = AboutFrame:CreateFontString(nil, "BACKGROUND","GameFontNormal")
    AboutFrame.Text:SetWidth(330)
    AboutFrame.Text:SetJustifyH("LEFT")
    AboutFrame.Text:SetPoint("TOPLEFT", 7,-10)
    AboutFrame.Text:SetText(Healium_AddonColoredName .. Version .. " |cFFFFFFFFCreated by Engee of Durotan.|n|n|cFFFFFFFFOriginally based on FB Heal Box, which was created by Dourd of Argent Dawn EU.")

	-- Init Config Panel controls
	if Healium_IsRetail then 
		for i=1, Healium_MaxButtons, 1 do
			Lib_UIDropDownMenu_Initialize(HealiumDropDown[i], DropDownMenu_Init)
		end
	end
	
	Healium_Update_ConfigPanel()
	
	TooltipsCheck:SetChecked(Healium.ShowToolTips)		
	ShowManaCheck:SetChecked(Healium.ShowMana)
	PercentageCheck:SetChecked(Healium.ShowPercentage)
	ClassColorCheck:SetChecked(Healium.UseClassColors)
	ShowBuffsCheck:SetChecked(Healium.ShowBuffs)
	RangeCheckCheck:SetChecked(Healium.DoRangeChecks)
	EnableCooldownsCheck:SetChecked(Healium.EnableCooldowns)	
	HideCloseButtonCheck:SetChecked(Healium.HideCloseButton)
	HideCaptionsCheck:SetChecked(Healium.HideCaptions)
	LockFramePositionsCheck:SetChecked(Healium.LockFrames)
	EnableDebuffsCheck:SetChecked(Healium.EnableDebufs)
	EnableCliqueCheck:SetChecked(Healium.EnableClique)
			
	ShowThreatCheck:SetChecked(Healium.ShowThreat)
	ShowIncomingHealsCheck:SetChecked(Healium.ShowIncomingHeals)

	if not Healium_IsClassic then 
		ShowRoleCheck:SetChecked(Healium.ShowRole)	
		Healium_ShowFocusCheck:SetChecked(Healium.ShowFocusFrame)		
	end
	
	ShowRaidIconsCheck:SetChecked(Healium.ShowRaidIcons)
	UppercaseNamesCheck:SetChecked(Healium.UppercaseNames)
	ShowMinimapButtonCheck:SetChecked(Healium.ShowMinimapButton)
	EnableDebuffAudioCheck:SetChecked(Healium.EnableDebufAudio)
	EnableDebuffHealthbarHighlightingCheck:SetChecked(Healium.EnableDebufHealthbarHighlighting)
	EnableDebuffButtonHighlightingCheck:SetChecked(Healium.EnableDebufButtonHighlighting)
	EnableDebufHealthbarColoringCheck:SetChecked(Healium.EnableDebufHealthbarColoring)
	
	Lib_UIDropDownMenu_SetText(SoundDropDown, Healium.DebufAudioFile)
	
	Healium_ShowPartyCheck:SetChecked(Healium.ShowPartyFrame)
	Healium_ShowPetsCheck:SetChecked(Healium.ShowPetsFrame)
	Healium_ShowMeCheck:SetChecked(Healium.ShowMeFrame)
	Healium_ShowFriendsCheck:SetChecked(Healium.ShowFriendsFrame)

-- TODO DAMAGERS/HEALERS frame	
	Healium_ShowDamagersCheck:SetChecked(Healium.ShowDamagersFrame)	
	Healium_ShowHealersCheck:SetChecked(Healium.ShowHealersFrame)		
	Healium_ShowTanksCheck:SetChecked(Healium.ShowTanksFrame)
	Healium_ShowTargetCheck:SetChecked(Healium.ShowTargetFrame)
	Healium_ShowGroup1Check:SetChecked(Healium.ShowGroupFrames[1])
	Healium_ShowGroup2Check:SetChecked(Healium.ShowGroupFrames[2])
	Healium_ShowGroup3Check:SetChecked(Healium.ShowGroupFrames[3])
	Healium_ShowGroup4Check:SetChecked(Healium.ShowGroupFrames[4])
	Healium_ShowGroup5Check:SetChecked(Healium.ShowGroupFrames[5])
	Healium_ShowGroup6Check:SetChecked(Healium.ShowGroupFrames[6])
	Healium_ShowGroup7Check:SetChecked(Healium.ShowGroupFrames[7])
	Healium_ShowGroup8Check:SetChecked(Healium.ShowGroupFrames[8])
	
	ScaleSlider:SetValue(Healium.Scale)
	RangeCheckSlider:SetValue(1.0/Healium.RangeCheckPeriod)
	
	UpdateEnableDebuffsControls(EnableDebuffsCheck)

end
