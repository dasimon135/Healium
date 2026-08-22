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

local MaxBuffs = 10
local xSpacing = 2
local NamePlateHeight = 28

local UnitFrames = { } -- table of all unit frames

ClickCastFrames = ClickCastFrames or {} -- used by Clique and any other click cast frames

-- Retail 12.1 makes indexed aura data unavailable whenever auras are secret
-- (which includes more than combat). Aura Containers keep selection,
-- visibility, icons, stacks, and cooldowns inside Blizzard code.
local AuraContainerMinInterface = 120100
local BuffAuraGroupKey = "HealiumPlayerBuffs"
local HealthDebuffSlotKey = "HealiumHealthDebuff"
local SpecialPlayerBuffSpellIDs = {
	155777, -- Rejuvenation (Germination)
	156322, -- Eternal Flame
	194384, -- Atonement aura (81749 is the passive ability, not the applied buff)
	325983, -- Glimmer of Light
	740,    -- Tranquility
	400735, -- Temporal Beacon
	431415, -- Sun Sear
	54149,  -- Infusion of Light
	77489,  -- Echo of Light
}
local PlayerBuffAuraAliases = {
	[1126] = { 432661 },   -- Mark of the Wild: cast spell and applied buff use different IDs
	[33076] = { 41635 },   -- Prayer of Mending: cast spell and applied buff use different IDs
	[115151] = { 119611 }, -- Renewing Mist: cast spell and applied HoT use different IDs
	[121536] = { 121557 }, -- Angelic Feather: cast spell and applied speed buff use different IDs
}
local AuraContainersReported = false
local AuraContainerFailureReported = false
local AuraContainersAvailable
local DispelColorMap = {
	Magic = CreateColor(0.2, 0.6, 1.0),
	Curse = CreateColor(0.6, 0.0, 1.0),
	Disease = CreateColor(0.6, 0.4, 0.0),
	Poison = CreateColor(0.0, 0.6, 0.0),
}

local function AurasAreRestricted()
	return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
end

function Healium_UsesAuraContainers()
	if AuraContainersAvailable ~= nil then return AuraContainersAvailable end
	local interfaceVersion = select(4, GetBuildInfo())
	AuraContainersAvailable = type(interfaceVersion) == "number"
		and interfaceVersion >= AuraContainerMinInterface
		and C_XMLUtil and C_XMLUtil.GetTemplateInfo
		and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") ~= nil
	return AuraContainersAvailable and true or false
end

local function QueueAuraContainerRefresh(frame)
	if frame.AuraContainerRefreshPending then return end
	frame.AuraContainerRefreshPending = true
	table.insert(Healium_FixNameplates, frame)
end

local function SafeAuraContainerCall(frame, method, ...)
	local ok = pcall(method, frame, ...)
	return ok
end

local function AddDispelTintTexture(auraButton, texture)
	local addTexture = auraButton.AddDispelTypeTexture or auraButton.SetAuraBorder
	if not addTexture then return end
	local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
		and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
	local options = {
		showWhenHarmful = true,
		showWhenHelpful = false,
		customDispelColorMap = DispelColorMap,
	}
	if style ~= nil then options.style = style end
	pcall(addTexture, auraButton, texture, options)
end

local function CreateTintedBorder(auraButton, storage)
	local thickness = 2.5
	local holder = CreateFrame("Frame", nil, auraButton)
	holder:SetAllPoints(auraButton)
	holder:EnableMouse(false)
	table.insert(storage, holder)
	local edges = {
		{ first = "TOPLEFT", second = "TOPRIGHT", dimension = "height" },
		{ first = "BOTTOMLEFT", second = "BOTTOMRIGHT", dimension = "height" },
		{ first = "TOPLEFT", second = "BOTTOMLEFT", dimension = "width" },
		{ first = "TOPRIGHT", second = "BOTTOMRIGHT", dimension = "width" },
	}
	for _, edge in ipairs(edges) do
		local texture = holder:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		texture:SetPoint(edge.first, holder, edge.first, 0, 0)
		texture:SetPoint(edge.second, holder, edge.second, 0, 0)
		if edge.dimension == "height" then
			texture:SetHeight(thickness)
		else
			texture:SetWidth(thickness)
		end
		AddDispelTintTexture(auraButton, texture)
	end
end

local function SetVisualsAlpha(visuals, alpha)
	if not visuals then return end
	for _, visual in ipairs(visuals) do visual:SetAlpha(alpha) end
end

local function BuildPlayerBuffSpellFilter()
	local includeSpellIDs = {}
	local profile = Healium_GetProfile()
	if profile and profile.SpellNames then
		for i = 1, profile.ButtonCount or 0 do
			local spellType = profile.SpellTypes and profile.SpellTypes[i]
			if spellType == nil or spellType == Healium_Type_Spell then
				local spellInfo = profile.SpellNames[i] and C_Spell.GetSpellInfo(profile.SpellNames[i])
				if spellInfo and spellInfo.spellID then
					includeSpellIDs[spellInfo.spellID] = true
					local auraAliases = PlayerBuffAuraAliases[spellInfo.spellID]
					if auraAliases then
						for _, auraSpellID in ipairs(auraAliases) do includeSpellIDs[auraSpellID] = true end
					end
				end
			end
		end
	end
	for _, spellID in ipairs(SpecialPlayerBuffSpellIDs) do includeSpellIDs[spellID] = true end
	return includeSpellIDs
end

local function InitializeBuffAuraButton(auraButton)
	auraButton:SetSize(24, 24)
	local icon = auraButton:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(auraButton)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	auraButton:SetIcon(icon)

	local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
	cooldown:SetAllPoints(auraButton)
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(true)
	cooldown:SetHideCountdownNumbers(true)
	auraButton:SetDurationCooldown(cooldown)

	local count = auraButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	count:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -1, 0)
	auraButton:SetApplicationCount(count, {})
	if auraButton.SetTooltipAnchorPoint then auraButton:SetTooltipAnchorPoint("ANCHOR_LEFT") end
end

local function GetBuffAuraLayout()
	return {
		elementWidth = 24,
		elementHeight = 24,
		elementSpacing = xSpacing,
		lineSpacing = 0,
	}
end

local function CreateBuffAuraContainer(frame, unit)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
	if not ok or not container then return false end

	container:SetSize(1, 1)
	container:SetPoint("RIGHT", frame, "LEFT", -2, 0)
	container:SetFrameLevel(frame:GetFrameLevel() + 20)
	container:SetUnit(unit)
	container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
	container:SetFlowLayoutAnchorPoint("RIGHT")
	container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
	container:AddAuraGroup(BuffAuraGroupKey, "HELPFUL|PLAYER", {
		maxFrameCount = MaxBuffs,
		candidateFilters = { includeSpellIDs = BuildPlayerBuffSpellFilter() },
		initializeFrame = InitializeBuffAuraButton,
		layout = GetBuffAuraLayout(),
	})
	container:SetEnabled(Healium.ShowBuffs and true or false)
	frame.BuffAuraContainer = container
	return true
end

local function InitializeHealthDebuffButton(frame)
	return function(auraButton)
		auraButton:SetSize(frame.HealthBar:GetWidth(), frame.HealthBar:GetHeight())
		frame.DebuffHealthBorderTextures = {}
		CreateTintedBorder(auraButton, frame.DebuffHealthBorderTextures)
		SetVisualsAlpha(frame.DebuffHealthBorderTextures,
			Healium.EnableDebufs and Healium.EnableDebufHealthbarHighlighting and 1 or 0)
		local overlayHolder = CreateFrame("Frame", nil, auraButton)
		overlayHolder:SetAllPoints(auraButton)
		overlayHolder:EnableMouse(false)
		local overlay = overlayHolder:CreateTexture(nil, "ARTWORK")
		overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
		overlay:SetAllPoints(overlayHolder)
		AddDispelTintTexture(auraButton, overlay)
		frame.DebuffHealthColorHolder = overlayHolder
		overlayHolder:SetAlpha(Healium.EnableDebufs and Healium.EnableDebufHealthbarColoring and 0.35 or 0)
		auraButton:SetMouseMotionEnabled(false)
	end
end

local function InitializeCureDebuffButton(frame, index)
	return function(auraButton)
		local cureButton = frame.buttons and frame.buttons[index]
		local width = cureButton and cureButton:GetWidth() or 28
		local height = cureButton and cureButton:GetHeight() or 28
		auraButton:SetSize(width, height)

		frame.DebuffButtonBorderTextures[index] = {}
		CreateTintedBorder(auraButton, frame.DebuffButtonBorderTextures[index])
		SetVisualsAlpha(frame.DebuffButtonBorderTextures[index],
			Healium.EnableDebufs and Healium.EnableDebufButtonHighlighting and 1 or 0)
		local iconHolder = CreateFrame("Frame", nil, auraButton)
		iconHolder:SetAllPoints(auraButton)
		iconHolder:EnableMouse(false)
		local icon = iconHolder:CreateTexture(nil, "ARTWORK")
		icon:SetSize(width * 0.5, height * 0.5)
		icon:SetPoint("CENTER", iconHolder, "CENTER")
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		auraButton:SetIcon(icon)
		local count = iconHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		auraButton:SetApplicationCount(count, {})
		frame.DebuffButtonIconHolders[index] = iconHolder
		iconHolder:SetAlpha(Healium.EnableDebufs and Healium.ShowDebuffIcon and 1 or 0)
		if auraButton.SetTooltipAnchorPoint then auraButton:SetTooltipAnchorPoint("ANCHOR_RIGHT") end
	end
end

local GetConfiguredCureTypes

local function CreateDebuffAuraContainer(frame, unit)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
	if not ok or not container then return false end

	container:SetSize(1, 1)
	container:SetPoint("CENTER", frame)
	container:SetFrameLevel(frame:GetFrameLevel() + 25)
	container:SetUnit(unit)
	frame.DebuffButtonBorderTextures = {}
	frame.DebuffButtonIconHolders = {}
	local profile = Healium_GetProfile()
	local configuredTypes = {}
	local allCureTypes = {}
	for i = 1, Healium_MaxButtons do
		configuredTypes[i] = GetConfiguredCureTypes(profile, i)
		for dispelType in pairs(configuredTypes[i]) do allCureTypes[dispelType] = true end
	end

	local healthSlot = container:AddAuraSlot(HealthDebuffSlotKey, "HARMFUL|RAID_PLAYER_DISPELLABLE", {
		candidateFilters = { includeDispelTypes = Healium.EnableDebufs and allCureTypes or {} },
		initializeFrame = InitializeHealthDebuffButton(frame),
	})
	healthSlot:SetPoint("CENTER", frame.HealthBar, "CENTER")
	frame.DebuffHealthAuraButton = healthSlot

	frame.DebuffButtonAuraButtons = {}
	for i = 1, Healium_MaxButtons do
		local slotKey = "HealiumCureDebuff" .. i
		local auraButton = container:AddAuraSlot(slotKey, "HARMFUL|RAID_PLAYER_DISPELLABLE", {
			candidateFilters = { includeDispelTypes = Healium.EnableDebufs and configuredTypes[i] or {} },
			initializeFrame = InitializeCureDebuffButton(frame, i),
		})
		local cureButton = frame.buttons and frame.buttons[i]
		if cureButton then auraButton:SetPoint("CENTER", cureButton, "CENTER") end
		frame.DebuffButtonAuraButtons[i] = auraButton
	end

	frame.DebuffAuraContainer = container
	container:SetEnabled(Healium.EnableDebufs and true or false)
	return true
end

GetConfiguredCureTypes = function(profile, index)
	if not profile or not profile.SpellNames then return {} end
	local spellType = profile.SpellTypes and profile.SpellTypes[index]
	if spellType ~= nil and spellType ~= Healium_Type_Spell then return {} end
	return Healium_GetCureDispelTypes(profile.SpellNames[index]) or {}
end

local function RefreshFrameAuraContainers(frame)
	if not frame or not frame.TargetUnit or not Healium_UsesAuraContainers() then return end
	if not frame.buttons or not frame.buttons[1] then
		QueueAuraContainerRefresh(frame)
		return
	end
	local unit = frame.TargetUnit
	local ok, created
	if not frame.BuffAuraContainer then
		ok, created = pcall(CreateBuffAuraContainer, frame, unit)
	end
	if not frame.BuffAuraContainer and (not ok or not created) then
		if not AuraContainerFailureReported then
			Healium_Warn("Retail buff Aura Container initialization failed: " .. tostring(created))
			AuraContainerFailureReported = true
		end
		QueueAuraContainerRefresh(frame)
		return
	end
	if not frame.DebuffAuraContainer then
		ok, created = pcall(CreateDebuffAuraContainer, frame, unit)
	end
	if not frame.DebuffAuraContainer and (not ok or not created) then
		if not AuraContainerFailureReported then
			Healium_Warn("Retail debuff Aura Container initialization failed: " .. tostring(created))
			AuraContainerFailureReported = true
		end
		QueueAuraContainerRefresh(frame)
		return
	end

	local buffOK = SafeAuraContainerCall(frame.BuffAuraContainer, frame.BuffAuraContainer.SetUnit, unit)
	local debuffOK = SafeAuraContainerCall(frame.DebuffAuraContainer, frame.DebuffAuraContainer.SetUnit, unit)
	if not buffOK or not debuffOK then QueueAuraContainerRefresh(frame) end

	if not InCombatLockdown() and not AurasAreRestricted() then
		frame.BuffAuraContainer:SetAuraGroupCandidateFilters(BuffAuraGroupKey,
			{ includeSpellIDs = BuildPlayerBuffSpellFilter() })
		frame.BuffAuraContainer:SetEnabled(Healium.ShowBuffs and true or false)

		local profile = Healium_GetProfile()
		local allCureTypes = {}
		for i = 1, Healium_MaxButtons do
			local cureTypes = GetConfiguredCureTypes(profile, i)
			for dispelType in pairs(cureTypes) do allCureTypes[dispelType] = true end
			frame.DebuffAuraContainer:SetAuraSlotCandidateFilters("HealiumCureDebuff" .. i,
				{ includeDispelTypes = Healium.EnableDebufs and cureTypes or {} })
			SetVisualsAlpha(frame.DebuffButtonBorderTextures[i],
				Healium.EnableDebufs and Healium.EnableDebufButtonHighlighting and 1 or 0)
			if frame.DebuffButtonIconHolders[i] then
				frame.DebuffButtonIconHolders[i]:SetAlpha(Healium.EnableDebufs and Healium.ShowDebuffIcon and 1 or 0)
			end
		end
		frame.DebuffAuraContainer:SetAuraSlotCandidateFilters(HealthDebuffSlotKey,
			{ includeDispelTypes = Healium.EnableDebufs and allCureTypes or {} })
		frame.DebuffAuraContainer:SetEnabled(Healium.EnableDebufs and true or false)
		SetVisualsAlpha(frame.DebuffHealthBorderTextures,
			Healium.EnableDebufs and Healium.EnableDebufHealthbarHighlighting and 1 or 0)
		if frame.DebuffHealthColorHolder then
			frame.DebuffHealthColorHolder:SetAlpha(Healium.EnableDebufs and Healium.EnableDebufHealthbarColoring and 0.35 or 0)
		end
		frame.AuraContainerRefreshPending = nil
	else
		QueueAuraContainerRefresh(frame)
	end
end

function Healium_RefreshAuraContainers()
	if not Healium_UsesAuraContainers() then return end
	local initialized = false
	for _, frame in ipairs(Healium_Frames) do
		RefreshFrameAuraContainers(frame)
		if frame.BuffAuraContainer and frame.DebuffAuraContainer then initialized = true end
	end
	if initialized and not AuraContainersReported then
		Healium_Print("Retail aura displays initialized.")
		AuraContainersReported = true
	end
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
		name = frame:GetName()
		button = CreateButton(name.."_Heal"..i, frame, x)
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
	if profile and profile.PartyFrameOrder == "TANK_HEALER_DPS" then
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
	if order == "TANK_HEALER_DPS" then
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
	
	if frame == FocusFrame then
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
	frame.PredictBar:SetShown(Healium.ShowIncomingHeals and true or false)

	local healthbarBackgroundBase = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	healthbarBackgroundBase:SetTexture("Interface\\Buttons\\WHITE8X8")
	healthbarBackgroundBase:SetVertexColor(0, 0, 0, 1)
	healthbarBackgroundBase:SetPoint("TOPLEFT", frame.HealthBar, "TOPLEFT")
	healthbarBackgroundBase:SetPoint("BOTTOMRIGHT", frame.HealthBar, "BOTTOMRIGHT")

	local healthbarBackgroundTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	healthbarBackgroundTexture:SetTexture("Interface\\TutorialFrame\\TutorialFrameBackground")
	healthbarBackgroundTexture:SetPoint("TOPLEFT", frame.HealthBar, "TOPLEFT")
	healthbarBackgroundTexture:SetPoint("BOTTOMRIGHT", frame.HealthBar, "BOTTOMRIGHT")
	healthbarBackgroundTexture:SetHorizTile(true)
	healthbarBackgroundTexture:SetVertTile(true)

	local showHealthbarBackground = Healium.OpaqueHealthbarBackground and true or false
	healthbarBackgroundBase:SetShown(showHealthbarBackground)
	healthbarBackgroundTexture:SetShown(showHealthbarBackground)
	frame.HealthbarOpaqueBackgrounds = { healthbarBackgroundBase, healthbarBackgroundTexture }
	
	table.insert(Healium_Frames, frame)
	
	if Healium.EnableClique then
		ClickCastFrames[frame] = true	
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

function Healium_UpdateOpaqueHealthbarBackgrounds()
	for _, frame in ipairs(Healium_Frames) do
		if frame.HealthbarOpaqueBackgrounds then
			for _, background in ipairs(frame.HealthbarOpaqueBackgrounds) do
				background:SetShown(Healium.OpaqueHealthbarBackground and true or false)
			end
		end
	end
end

function HealiumUnitFrames_Button_OnShow(frame)
	table.insert(Healium_ShownFrames, frame)
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
		
		if newUnit then
			-- update cooldowns
--			Healium_UpdateButtonCooldownByUnitFrame(frame)

			if not Healium_Units[newUnit] then
				Healium_Units[newUnit] = { }
			end
			
			table.insert(Healium_Units[newUnit], frame)

			Healium_UpdateManaBarVisibility(frame) -- This is important to do here.
			Healium_UpdateUnitName(newUnit, frame)
			Healium_UpdateUnitHealth(newUnit, frame)
			Healium_UpdateUnitMana(newUnit, frame)
			Healium_UpdateUnitThreat(newUnit, frame)
			Healium_UpdateUnitRole(newUnit, frame)
			Healium_UpdateRaidTargetIcon(frame)
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
		if newUnit then RefreshFrameAuraContainers(frame) end
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
		if FocusFrame:IsShown() then hide = true end


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
		FocusFrameWasShown = FocusFrame:IsShown()

		PartyFrame:Hide()
		PetsFrame:Hide()
		MeFrame:Hide()
		FriendsFrame:Hide()
		DamagersFrame:Hide()
		HealersFrame:Hide()
		TanksFrame:Hide()
		TargetFrame:Hide()
		FocusFrame:Hide()

		
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
	if FocusFrameWasShown then FocusFrame:Show() end

	
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

local function CanChangeFrameVisibility()
	if InCombatLockdown() then
		Healium_Warn("Can't show or hide frames while in combat.")
		return false
	end
	return true
end

function Healium_ShowHidePartyFrame(show)
	if PartyFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowPartyFrame = show end
	
	if Healium.ShowPartyFrame then
		PartyFrame:Show()
	else
		PartyFrame:Hide()
	end
end

function Healium_ShowHidePetsFrame(show)
	if PetsFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowPetsFrame = show end
	
	if Healium.ShowPetsFrame then
		PetsFrame:Show()
	else
		PetsFrame:Hide()
	end
end

function Healium_ShowHideMeFrame(show)
	if MeFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowMeFrame = show end
	
	if Healium.ShowMeFrame then
		MeFrame:Show()
	else
		MeFrame:Hide()
	end
end

function Healium_ShowHideFriendsFrame(show)
	if FriendsFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowFriendsFrame = show end
	
	if Healium.ShowFriendsFrame then
		FriendsFrame:Show()
	else
		FriendsFrame:Hide()
	end
end

function Healium_ShowHideDamagersFrame(show)
	if DamagersFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowDamagersFrame = show end
	
	if Healium.ShowDamagersFrame then
		DamagersFrame:Show()
	else
		DamagersFrame:Hide()
	end
end

function Healium_ShowHideHealersFrame(show)
	if HealersFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowHealersFrame = show end
	
	if Healium.ShowHealersFrame then
		HealersFrame:Show()
	else
		HealersFrame:Hide()
	end
end

function Healium_ShowHideTanksFrame(show)
	if TanksFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowTanksFrame = show end
	
	if Healium.ShowTanksFrame then
		TanksFrame:Show()
	else
		TanksFrame:Hide()
	end
end

function Healium_ShowHideTargetFrame(show)
	if TargetFrame == nil then return end
	if not CanChangeFrameVisibility() then return end
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
	if not CanChangeFrameVisibility() then return end
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
	if not CanChangeFrameVisibility() then return end
	if (show ~= nil) then Healium.ShowGroupFrames[group] = show end
	
	if Healium.ShowGroupFrames[group] then
		GroupFrames[group]:Show()
	else
		GroupFrames[group]:Hide()
	end
end

function Healium_HideAllRaidFrames()
	if not CanChangeFrameVisibility() then return end
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
	if not CanChangeFrameVisibility() then return end
	GroupFrames[1]:Show()
	GroupFrames[2]:Show()
end

function Healium_Show25ManRaidFrames()
	if GroupFrames == nil then return end
	if not CanChangeFrameVisibility() then return end
	for i=1, 5, 1 do
		if GroupFrames[i] ~= nil then 
			GroupFrames[i]:Show()
		end
	end
end

function Healium_Show40ManRaidFrames()
	if GroupFrames == nil then return end
	if not CanChangeFrameVisibility() then return end
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
	FocusFrame = CreateFocusUnitFrame("HealiumFocusFrame", "Focus")

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
	FocusFrame:SetScale(Scale)

	
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

function Healium_UpdateEnableDebuffs()
	if Healium_UsesAuraContainers() then
		Healium_RefreshAuraContainers()
		return
	end

	for _,frame in pairs(UnitFrames) do
		if frame.hasDebuf then
			frame.CurseBar:SetAlpha(0)
			frame.hasDebuf = nil
			
			for i=1, Healium_MaxButtons, 1 do
				local button = frame.buttons[i]
				if button then
					button.CurseBar:SetAlpha(0)
					button.CurseBar.hasDebuf = nil
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
	HealiumUnitFrames_Button_OnAttributeChanged(FocusFrame.hdr, "unit")
end
