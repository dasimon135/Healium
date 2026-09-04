local CanCureMagic = false
local CanCureDisease = false
local CanCurePoison = false
local CanCureCurse = false

local Cures = { } 
local CuresCount = 0

local function AddSpell(spellID)
	local name = Healium_GetSpellName(spellID)
	table.insert(Healium_Spell.Name, name)
end

local function Count(tab)
	local cnt = 0
	
	for _, k in pairs(tab) do
		cnt = cnt + 1
	end
	
	return cnt
end

-- These spellIDs are from wowhead
function Healium_InitSpells(class, race)
	local CureName
	Healium_DebugPrint("Healium_InitSpells class = " .. class .. " race = " .. race)
	
	-- clear cures
	Healium_Spell.Name = {}
	Healium_Spell.Icon = {}
	Healium_Spell.ID = {}
	
	Cures = {}
	

	-- Init spell list
	if (class == "DRUID") then 
		AddSpell(774)		-- Rejuvenation
		AddSpell(8936)		-- Regrowth
		AddSpell(33763)		-- Lifebloom
		AddSpell(5185)		-- Healing Touch
		AddSpell(18562)		-- Swiftmend
		AddSpell(48438)		-- Wild Growth
		AddSpell(88423)		-- Nature's Cure
		AddSpell(102342)	-- Ironbark
		AddSpell(102351)	-- Cenarion Ward
		AddSpell(2782)		-- Remove Corruption
		AddSpell(20484)		-- Rebirth (battle rez)
		AddSpell(50769)		-- Revive (rez)
		AddSpell(50464)     -- Nourish
		AddSpell(203651)    -- Overgrowth
		AddSpell(29166)     -- Innervate	

		-- Druid Remove Corruption, retail version.. retail version can cure poision too?
		CureName = Healium_GetSpellName(2782) 
		if CureName then 
			Cures[CureName] = { 
				CanCurePoison = true, 
				CanCureCurse = true,
			}
		end
		
		-- Druid Nature's Cure		
		CureName = Healium_GetSpellName(88423)
		if CureName then 
			Cures[CureName] = { 
				CanCurePoison = true, 
				CanCureCurse = true,
				CanCureMagic = true,
			}
		end		
	end

	if (class == "PRIEST") then 
		AddSpell(527)		-- Purify		
		AddSpell(213634)	-- Purify Disease (shadow spec)
		AddSpell(139)		-- Renew
		AddSpell(2061)		-- Flash Heal
		AddSpell(2060)		-- Heal
		AddSpell(32546)		-- Binding Heal
		AddSpell(596)		-- Prayer of Healing
		AddSpell(33076)		-- Prayer of Mending
		AddSpell(200829)	-- Plea
		AddSpell(186263)	-- Shadow Mend
		AddSpell(34861)		-- Circle of Healing
		AddSpell(17)		-- Power Word: Shield
		AddSpell(152118)	-- Clarity of Will
		AddSpell(47788)		-- Guardian Spirit
		AddSpell(47540)		-- Penance
		AddSpell(2050)     	-- Holy Word: Serenity		
		AddSpell(121135)	-- Cascade (not sure if correct Cascade)
		AddSpell(2006)		-- Resurrection (rez)
		AddSpell(194509)    -- Power Word: Radiance
		AddSpell(33206)     -- Pain Suppression
		AddSpell(47536)     -- Rapture		

		-- Priest Purify, retail version
		CureName = Healium_GetSpellName(527)
		if CureName then 
			Cures[CureName] = { 
				CanCureDisease = IsPlayerSpell(390632), -- Purify can only cure disease if the player has the "improved purify" talent
				CanCureMagic = true 
			}
		end					
		
		-- Priest Purify Disease, retail version
		CureName = Healium_GetSpellName(213634)
		if CureName then 
			Cures[CureName] = { 
				CanCureDisease = true,
			}
		end	
	end

	if (class == "SHAMAN") then
		AddSpell(51886)		-- Cleanse Spirit	
		AddSpell(77130)		-- Purify Spirit
		AddSpell(8004)		-- Healing Surge
		AddSpell(77472)     -- Healing Wave		
		AddSpell(1064)		-- Chain Heal		
		AddSpell(61295)		-- Riptide		
		AddSpell(974)		-- Earth Shield
		AddSpell(16188)		-- Nature's Swiftness
		AddSpell(73685)		-- Unleash Life
		AddSpell(2008)		-- Ancestral Spirit (rez)
		
		-- Shaman Cleanse Spirit
		CureName = Healium_GetSpellName(51886)
		if CureName then 
			Cures[CureName] = { 
				CanCureCurse = true,
			} 
		end
		
		-- Shaman Purify Spirit
		CureName = Healium_GetSpellName(77130)
		if CureName then
			Cures[CureName] = {
				CanCureCurse = true,
				CanCureMagic = true
			}
		end		
	end

	if (class == "PALADIN") then
		AddSpell(19750) -- Flash of Light
		AddSpell(20473) -- Holy Shock
		AddSpell(633) 	-- Lay on Hands
		AddSpell(4987) 	-- Cleanse
		AddSpell(213644) -- Cleanse Toxins
		AddSpell(1022)	-- Hand of Protection
		AddSpell(1038)	-- Hand of Salvation
		AddSpell(1044)	-- Hand of Freedom
		AddSpell(6940) -- Blessing of Sacrifice		
		AddSpell(53563)	-- Beacon of Light
		AddSpell(200025) -- Beacon of Virtue
		AddSpell(20925)	-- Sacred Shield
		AddSpell(85673)	-- Word of Glory
		AddSpell(82326) -- Holy Light
		AddSpell(85222)	-- Light of Dawn
		AddSpell(82327)	-- Holy Radiance
		AddSpell(114163) -- Eternal Flame
		AddSpell(114039) -- Hand of Purity
		AddSpell(114165) -- Holy Prism
		AddSpell(114916) -- Execution Sentence
		AddSpell(7328) -- Redemption (rez)
		AddSpell(183998) -- Light of the Martyr
		AddSpell(391054) -- Intercession
		AddSpell(204018) -- blessing of spellwarding
		
		-- Paladin Cleanse Toxins
		CureName = Healium_GetSpellName(213644)
		if CureName then 
			Cures[CureName] = {
				CanCurePoison = true, 
				CanCureDisease = true,		
			}		
		end
		
		-- Paladin Cleanse -- classic and retail
		CureName = Healium_GetSpellName(4987)
		if CureName then 
			Cures[CureName] = {	
				CanCurePoison = true, 
				CanCureDisease = true,
				CanCureMagic = true
			}
		end
	end
	
	if (class == "MAGE") then
		AddSpell(475) -- Remove Curse
		
		-- Retail
		AddSpell(475) -- Remove Curse

		CureName = Healium_GetSpellName(475)
		if CureName then 
			Cures[CureName] = {	
				CanCureCurse = true, 
			}
		end		
	end
	
	if (class == "EVOKER") then
		AddSpell(364343) -- Echo
		AddSpell(360995) -- Verdant Embrace
		AddSpell(355913) -- Emerald Blossom
		AddSpell(361469) -- Living Flame
		AddSpell(355936) -- Dream Breath
		AddSpell(360823) -- Naturalize
		AddSpell(361227) -- Return 
		AddSpell(365585) -- Expunge
		AddSpell(374251) -- Cauterizing Flame
		AddSpell(367226) -- Spiritbloom
		AddSpell(367364) -- Reversion
		AddSpell(357170) -- Time Dilation
		AddSpell(370665) -- Rescue
	
		-- Naturalize
		CureName = Healium_GetSpellName(360823)
		if CureName then 
			Cures[CureName] = {	
				CanCureMagic = true, 
				CanCurePoison = true, 					
			}
		end
		
		-- Expunge
		CureName = Healium_GetSpellName(365585)
		if CureName then 
			Cures[CureName] = {	
				CanCurePoison = true, 					
			}
		end

		-- Cauterizing Flame			
		CureName = Healium_GetSpellName(374251)
		if CureName then 
			Cures[CureName] = {	
				CanCurePoison = true, 
				CanCureDisease = true,
				CanCureCurse = true, 					
			}
		end				

	end	

	if (class == "MONK") then
		AddSpell(116694) 	-- Surging Mist
		AddSpell(115175)	-- Soothing Mist
		AddSpell(115151)	-- Renewing Mist
		AddSpell(116841)	-- Tiger's Lust
		AddSpell(116849)	-- Life Cocoon
		AddSpell(124682) 	-- Enveloping Mist
--		AddSpell(115310)	-- Revival (has cures, but is AOE)
		AddSpell(116670)	-- Vivify
		AddSpell(115450)	-- Detox 		
		AddSpell(115178)	-- Resuscitate (rez)
--		AddSpell(124081)	-- zen pulse now a passive
		AddSpell(197945)	-- mistwalk	
	
		-- Monk Detox
		CureName = Healium_GetSpellName(115450)
		if CureName then 
			Cures[CureName] = {
				CanCurePoison = true, 
				CanCureDisease = true,
				CanCureMagicFunc = function() return (GetSpecialization() == 2) end	-- if monk is mistweaver then Detox cures magic
			}
		end		
	end

	if (class == "DEATHKNIGHT") then
		AddSpell(61999) 		-- Raise Ally (battle rez)
	end
	
	if (race == "Draenei") then -- race isn't in all uppercase like class
		AddSpell(59547)		-- Gift of the Naaru
	end
	
	CuresCount = Count(Cures)
end


local function GetCanCureMagic(cure)
	local flag = nil
	
	if cure.CanCureMagic then 
		flag = true
	elseif cure.CanCureMagicFunc ~= nil then 	
		flag = cure.CanCureMagicFunc()
	end
	
	return flag
end

function Healium_UpdateCures()
	local Profile = Healium_GetProfile()
	
	-- Handle Cures
	CanCureMagic = false
	CanCureDisease = false
	CanCurePoison = false
	CanCureCurse = false	

	if CuresCount > 0 then
		for i=1, Profile.ButtonCount,1 do
			local spell = Profile.SpellNames[i]
			local cure = Cures[spell]
			if cure ~= nil then
				if GetCanCureMagic(cure) then CanCureMagic = true end
				if cure.CanCureDisease then CanCureDisease = true end
				if cure.CanCurePoison then CanCurePoison = true end
				if cure.CanCureCurse then CanCureCurse = true end
			end
		end
	end
	
end

--debuffType is expected to be a return value from the wow api UnitDebuff()
function Healium_CanCureDebuff(debuffType)
	if   ( (debuffType == "Curse") and CanCureCurse) or
	     ( (debuffType == "Disease") and CanCureDisease) or
		 ( (debuffType == "Magic") and CanCureMagic) or
		 ( (debuffType == "Poison") and CanCurePoison) then	
		 return true
	end
	
	return false
end

function Healium_ShowDebuffButtons(Profile, frame, debuffTypes)

	for i=1, Profile.ButtonCount,1 do
		local button = frame.buttons[i]	
		
		if button then 
			local spell = Profile.SpellNames[i]
			local cure = Cures[spell]
			local flag
			local debuffColor 
			
			if cure ~= nil then
				if debuffTypes["Curse"] and cure.CanCureCurse then
					flag = true
					debuffColor = Healium_DebuffTypeColor["Curse"] 
				elseif debuffTypes["Disease"] and cure.CanCureDisease then
					flag = true
					debuffColor = Healium_DebuffTypeColor["Disease"]
				elseif debuffTypes["Magic"] and GetCanCureMagic(cure) then
					flag = true
					debuffColor = Healium_DebuffTypeColor["Magic"]
				elseif debuffTypes["Poison"] and cure.CanCurePoison then
					flag = true
					debuffColor = Healium_DebuffTypeColor["Poison"]
				elseif debuffTypes["Secret"] then
					flag = true
					debuffColor = Healium_DebuffTypeColor["Secret"]
				else 
					flag = false
				end
			end
			
			local curseBar = button.CurseBar
			
			if flag then
				curseBar:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b)
				curseBar:SetAlpha(1)
				curseBar.hasDebuf = true
			else
				if curseBar.hasDebuf then
					curseBar:SetAlpha(0)
					curseBar.hasDebuf = nil
				end
			end
		end
	end
end

function Healium_DebugCures()
	Healium_DebugPrint(Cures)
	Healium_Print("CanCureMagic = " .. tostring(CanCureMagic))
	Healium_Print("CanCureDisease = " .. tostring(CanCureDisease))
	Healium_Print("CanCurePoison = " .. tostring(CanCurePoison))
	Healium_Print("CanCureCurse = " .. tostring(CanCureCurse))
end

-- Returns the dispel types handled by a configured cure spell.  Retail 12.1
-- Aura Containers can consume this non-aura configuration safely, allowing
-- Blizzard to select the matching debuff without Healium reading aura data.
function Healium_GetCureDispelTypes(spellName)
	local cure = spellName and Cures[spellName]
	if not cure then return nil end

	local dispelTypes = {}
	if GetCanCureMagic(cure) then dispelTypes.Magic = true end
	if cure.CanCureDisease then dispelTypes.Disease = true end
	if cure.CanCurePoison then dispelTypes.Poison = true end
	if cure.CanCureCurse then dispelTypes.Curse = true end
	return dispelTypes
end
