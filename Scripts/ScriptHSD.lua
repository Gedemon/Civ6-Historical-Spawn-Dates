------------------------------------------------------------------------------
--	FILE:	 ScriptHSD.lua
--  Gedemon (2017)
------------------------------------------------------------------------------

local HSD_Version = GameInfo.GlobalParameters["HSD_VERSION"].Value
print ("Historical Spawn Dates version " .. tostring(HSD_Version) .." (2017) by Gedemon")
print ("loading ScriptHSD.lua")

local bHistoricalSpawnDates		= MapConfiguration.GetValue("HistoricalSpawnDates")

----------------------------------------------------------------------------------------
-- Historical Spawn Dates <<<<<
----------------------------------------------------------------------------------------
if bHistoricalSpawnDates then
----------------------------------------------------------------------------------------

print("Activating Historical Spawn Dates...")
local minimalStartYear 	= -4000000 -- Should cover every prehistoric start mod...
local previousTurnYear 	= GameConfiguration.GetValue("PreviousTurnYear") or minimalStartYear
local currentTurnYear 	= GameConfiguration.GetValue("CurrentTurnYear")
local nextTurnYear 		= GameConfiguration.GetValue("NextTurnYear")

local knownTechs		= {} 	-- Table to track each known tech (with number of civs) 
local knownCivics		= {}	-- Table to track each known civic (with number of civs) 
local researchedCivics	= {}	-- Table to track each researched civic 
local playersWithCity	= 0		-- Total number of major players with at least one city
local scienceBonus		= 0
local goldBonus			= 0
local minCivForTech		= 1
local minCivForCivic	= 1
local currentEra		= 0

function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

local isInGame = {}
-- Create list of Civilizations and leaders in game
for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
	local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
	local LeaderTypeName = PlayerConfigurations[iPlayer]:GetLeaderTypeName()
	if CivilizationTypeName then isInGame[CivilizationTypeName] = true end
	if LeaderTypeName 		then isInGame[LeaderTypeName] 		= true end
end

-- Create list of spawn dates
print("Building spawn year table...")
local spawnDates = {}
for row in GameInfo.HistoricalSpawnDates() do
	if isInGame[row.Civilization]  then
		spawnDates[row.Civilization] = row.StartYear
		print(tostring(row.Civilization), " spawn year = ", tostring(row.StartYear))
	end
end

--[[
-- Set Starting Plots
for iPlayer, position in pairs(ExposedMembers.HistoricalStartingPlots) do
	local player = Players[iPlayer]
	if player then
		local startingPlot = Map.GetPlot(position.X, position.Y)
		player:SetStartingPlot(startingPlot)
	else
		print("WARNING: player #"..tostring(iPlayer) .." is nil for Set Starting Plots at ", position.X, position.Y)
	end
end
ExposedMembers.HistoricalStartingPlots = nil
--]]

function SetPreviousTurnYear(year)
	previousTurnYear = year
end
LuaEvents.SetPreviousTurnYear.Add( SetPreviousTurnYear )

function SetCurrentTurnYear(year)
	currentTurnYear = year
end
LuaEvents.SetCurrentTurnYear.Add( SetCurrentTurnYear )

function SetNextTurnYear(year)
	nextTurnYear = year
end
LuaEvents.SetNextTurnYear.Add( SetNextTurnYear )

-- Remove Civilizations that can't be spawned on start date
function InitializeHSD()
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
		local spawnYear = spawnDates[CivilizationTypeName]
		local player = Players[iPlayer]
		if not (spawnYear and spawnYear >= previousTurnYear and spawnYear < currentTurnYear) then		
			if player:IsMajor() then
				local playerUnits = player:GetUnits()
				local toKill = {}
				for i, unit in playerUnits:Members() do
					table.insert(toKill, unit)
				end
				for i, unit in ipairs(toKill) do
					playerUnits:Destroy(unit)
				end
				if player:IsHuman() then
					LuaEvents.SetAutoValues()
				end
			end
		end
		
	end
end
LuaEvents.InitializeHSD.Add(InitializeHSD)

function SpawnPlayer(iPlayer)
	local player = Players[iPlayer]
	if player then
		if not player:IsBarbarian() and player:IsMajor() then-- and not player:IsAlive() then
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			local spawnYear = spawnDates[CivilizationTypeName]
			--print("Check Spawning Date for ", tostring(CivilizationTypeName), "Start Year = ", tostring(spawnYear), "Previous Turn Year = ", tostring(previousTurnYear), "Current Turn Year = ", tostring(currentTurnYear))
			local iTurn = Game.GetCurrentGameTurn()
			if spawnYear and spawnYear >= previousTurnYear and spawnYear < currentTurnYear then
				local startingPlot = player:GetStartingPlot()
				print(" - Spawning", tostring(CivilizationTypeName), "Start Year = ", tostring(spawnYear), "Previous Turn Year = ", tostring(previousTurnYear), "Current Turn Year = ", tostring(currentTurnYear), "at", startingPlot:GetX(), startingPlot:GetY())
				GetStartingBonuses(player) -- before placing city for era bonuses...	
				local city = player:GetCities():Create(startingPlot:GetX(), startingPlot:GetY())
				if not city then
					UnitManager.InitUnit(iPlayer, "UNIT_SETTLER", startingPlot:GetX(), startingPlot:GetY())
				end			
				if player:IsHuman() then
					LuaEvents.RestoreAutoValues()
				end
				LuaEvents.SpawnPlayer(iPlayer)
				return true
			end	
		end
	else
		print("WARNING: player is nil in SpawnPlayer #"..tostring(iPlayer))
	end
end
GameEvents.PlayerTurnStarted.Add( SpawnPlayer )

function GetStartingBonuses(player)

	local pTreasury = player:GetTreasury()
	print(" - Gold bonus = "..tostring(goldBonus))
	pTreasury:ChangeGoldBalance(goldBonus)	
	
	local pCulture = player:GetCulture()
	local pScience = player:GetTechs()
	
	for iTech, number in pairs(knownTechs) do
		if number >= minCivForTech then
			pScience:SetTech(iTech, true)
		else
			pScience:TriggerBoost(iTech)
		end
	end	
	
	--[[
	for iCivic, number in pairs(knownCivics) do
		if number >= minCivForCivic then
			pCulture:SetCivic(iCivic, true)
		else
			pCulture:TriggerBoost(iCivic)
		end
	end
	--]]
	
	for kCivic in GameInfo.Civics() do
		local iCivic	= kCivic.Index
		if knownCivics[iCivic] then
			if knownCivics[iCivic] >= minCivForCivic then
				pCulture:SetCivic(iCivic, true)
			else
				pCulture:TriggerBoost(iCivic)
			end
		elseif researchedCivics[iCivic] then
			pCulture:TriggerBoost(iCivic)
		end
	end
	
	print(" - Science bonus = "..tostring(scienceBonus))
	if playersWithCity > 0 then
		pScience:ChangeCurrentResearchProgress(scienceBonus)
	end

	print(" - Starting era = "..tostring(currentEra))
	player:GetEras():SetStartingEra(currentEra)
end

function SetCurrentBonuses()

	knownTechs		= {}
	knownCivics		= {}
	playersWithCity	= 0

	local totalScience 	= 0
	local totalCulture 	= 0
	local totalGold 	= 0
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and player:IsMajor() and player:GetCities():GetCount() > 0 then
			playersWithCity = playersWithCity + 1
				
			-- Science	
			local pScience = player:GetTechs()
			totalScience = totalScience + pScience:GetResearchProgress( pScience:GetResearchingTech() )
			for kTech in GameInfo.Technologies() do		
				local iTech	= kTech.Index
				if pScience:HasTech(iTech) then
					if not knownTechs[iTech] then knownTechs[iTech] = 0 end
					knownTechs[iTech] = knownTechs[iTech] + 1
				end
			end
			
			local pCulture = player:GetCulture()
			researchedCivics[pCulture:GetProgressingCivic()] = true
			for kCivic in GameInfo.Civics() do		
				local iCivic	= kCivic.Index
				if pCulture:HasCivic(iCivic) then
					if not knownCivics[iCivic] then knownCivics[iCivic] = 0 end
					knownCivics[iCivic] = knownCivics[iCivic] + 1
				end
			end
			
			local pTreasury = player:GetTreasury()
			
			totalGold = totalGold + pTreasury:GetGoldYield() + pTreasury:GetTotalMaintenance()
			
			if pTreasury:GetGoldBalance() > 0 then
				totalGold = totalGold + pTreasury:GetGoldBalance()
			end
						
			local playerUnits = player:GetUnits(); 	
			for i, unit in playerUnits:Members() do
				local unitInfo = GameInfo.Units[unit:GetType()];
				totalGold = totalGold + unitInfo.Cost
			end
			
			local era = player:GetEras():GetEra()
			if era > currentEra then
				print ("Changing current Era to " .. tostring(GameInfo.Eras[era].EraType))
				currentEra = era
			end
	
		end
	end
	
	if playersWithCity > 0 then
		scienceBonus 	= Round(totalScience/playersWithCity)
		minCivForTech	= playersWithCity*25/100
		minCivForCivic	= playersWithCity*10/100
		goldBonus = Round(totalGold/playersWithCity)
	end
	
end
GameEvents.OnGameTurnStarted.Add(SetCurrentBonuses)

--[[
function FoundFirstPotentialSpawn()
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and not player:IsBarbarian() then-- and not player:IsAlive() then
			if SpawnPlayer(iPlayer) then return end
		end
	end
end
--GameEvents.OnGameTurnStarted.Add( FoundFirstPotentialSpawn )

function FoundNextPotentialSpawn(iCurrentAlivePlayer)
	for iPlayer = iCurrentAlivePlayer + 1, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and not player:IsBarbarian() then --and not player:IsAlive() then
			if SpawnPlayer(iPlayer) then return end
		end
	end
end
--Events.PlayerTurnDeactivated.Add( FoundNextPotentialSpawn )
--]]

----------------------------------------------------------------------------------------
end
----------------------------------------------------------------------------------------
-- Historical Spawn Dates >>>>>
----------------------------------------------------------------------------------------