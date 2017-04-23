------------------------------------------------------------------------------
--	FILE:	 ScriptHSD.lua
--  Gedemon (2017)
------------------------------------------------------------------------------

local HSD_Version = GameInfo.GlobalParameters["HSD_VERSION"].Value
print ("Historical Spawn Dates version " .. tostring(HSD_Version) .." (2017) by Gedemon")
print ("loading ScriptHSD.lua")

local bHistoricalSpawnDates		= MapConfiguration.GetValue("HistoricalSpawnDates")
local bApplyBalance				= MapConfiguration.GetValue("BalanceHSD")

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
local settlersBonus		= 0
local tokenBonus		= 0
local faithBonus		= 0
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

local StartingEra = {}
function GetStartingEra(iPlayer)
	print("------------")
	local key = "StartingEra"..tostring(iPlayer)
	local value = GameConfiguration.GetValue(key)
	print("StartingEra[iPlayer] = "..tostring(StartingEra[iPlayer]))
	print("GameConfiguration.GetValue("..tostring(key)..") = "..tostring(value))
	return StartingEra[iPlayer] or value or 0
end

function SetStartingEra(iPlayer, era)
	LuaEvents.SetStartingEra(iPlayer, era)	-- saved/reloaded
	StartingEra[iPlayer] = era 				-- to keep the value in the current session, GameConfiguration.GetValue in this context will only work after a save/load
end


-- Remove Civilizations that can't be spawned on start date
function InitializeHSD()
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
		local spawnYear = spawnDates[CivilizationTypeName]
		print("---------")
		print("Check "..tostring(CivilizationTypeName)..", spawn year  = ".. tostring(spawnYear))
		local player = Players[iPlayer]
		if spawnYear and spawnYear > currentTurnYear then		
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
				print ("----------")
				print(" - Spawning", tostring(CivilizationTypeName), "Start Year = ", tostring(spawnYear), "Previous Turn Year = ", tostring(previousTurnYear), "Current Turn Year = ", tostring(currentTurnYear), "at", startingPlot:GetX(), startingPlot:GetY())
				LuaEvents.SpawnPlayer(iPlayer)
				if bApplyBalance then
					GetStartingBonuses(player) -- before placing city for era bonuses...
				end
				local city = player:GetCities():Create(startingPlot:GetX(), startingPlot:GetY())
				if not city then
					UnitManager.InitUnit(iPlayer, "UNIT_SETTLER", startingPlot:GetX(), startingPlot:GetY())
				end
				if player:IsHuman() then
					LuaEvents.RestoreAutoValues()
				end
				return true
			end	
		end
	else
		print("WARNING: player is nil in SpawnPlayer #"..tostring(iPlayer))
	end
end
GameEvents.PlayerTurnStarted.Add( SpawnPlayer )

function GetStartingBonuses(player)

	print(" - Starting era = "..tostring(currentEra))
	SetStartingEra(player:GetID(), currentEra)
	player:GetEras():SetStartingEra(currentEra)
	
	local kEraBonuses = GameInfo.StartEras[currentEra]
	
	-- gold
	local pTreasury = player:GetTreasury()
	local playerGoldBonus = goldBonus
	if currentEra > 0 and kEraBonuses.Gold then
		playerGoldBonus = playerGoldBonus + kEraBonuses.Gold
	end
	print(" - Gold bonus = "..tostring(playerGoldBonus))
	pTreasury:ChangeGoldBalance(playerGoldBonus)	
	
	-- science
	local pScience = player:GetTechs()	
	for iTech, number in pairs(knownTechs) do
		if number >= minCivForTech then
			pScience:SetTech(iTech, true)
		else
			pScience:TriggerBoost(iTech)
		end
	end	
	print(" - Science bonus = "..tostring(scienceBonus))
	pScience:ChangeCurrentResearchProgress(scienceBonus)
	
	-- culture
	local pCulture = player:GetCulture()
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
	
	-- faith
	local playerFaithBonus = faithBonus
	if currentEra > 0 and kEraBonuses.Faith then
		playerFaithBonus = playerFaithBonus + kEraBonuses.Faith
	end
	print(" - Faith bonus = "..tostring(playerFaithBonus))
	player:GetReligion():ChangeFaithBalance(playerFaithBonus)
	
	-- token
	print(" - Token bonus = "..tostring(tokenBonus))
	player:GetInfluence():ChangeTokensToGive(tokenBonus)
	
	
	-- units
	local startingPlot = player:GetStartingPlot()
		
	print(" - Settlers = "..tostring(settlersBonus))
	if settlersBonus > 0 then
		UnitManager.InitUnitValidAdjacentHex(player:GetID(), "UNIT_SETTLER", startingPlot:GetX(), startingPlot:GetY(), settlersBonus)
	end
	
	for kUnits in GameInfo.MajorStartingUnits() do
		if GameInfo.Eras[kUnits.Era].Index == currentEra and not (kUnits.AiOnly) then -- (player:IsHuman() and kUnits.AiOnly) -- to do : difficulty difference check
			local numUnit = math.max(kUnits.Quantity, 1)
			print(" - "..tostring(kUnits.Unit).." = "..tostring(numUnit))
			if kUnits.Unit == "UNIT_TRADER" then
				UnitManager.InitUnit(player:GetID(), kUnits.Unit, startingPlot:GetX(), startingPlot:GetY())
			else
				UnitManager.InitUnitValidAdjacentHex(player:GetID(), kUnits.Unit, startingPlot:GetX(), startingPlot:GetY(), numUnit)
			end
		end
	end	
end

function SetCurrentBonuses()

	knownTechs		= {}
	knownCivics		= {}
	playersWithCity	= 0

	local totalScience 	= 0
	local totalCulture 	= 0
	local totalGold 	= 0
	local totalCities	= 0
	local totalToken	= 0
	local totalFaith	= 0
	
	for kEra in GameInfo.StartEras() do
		if kEra.Year and kEra.Year < currentTurnYear then
			local era = GameInfo.Eras[kEra.EraType].Index				
			if era > currentEra then
				print ("Changing current Era to current year's Era :" .. tostring(kEra.EraType))
				currentEra = era
			end		
		end
	end	
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and player:IsMajor() and player:GetCities():GetCount() > 0 then
			playersWithCity = playersWithCity + 1
			totalCities		= totalCities + player:GetCities():GetCount()
			
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
				
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
			
			-- Culture
			local pCulture = player:GetCulture()
			researchedCivics[pCulture:GetProgressingCivic()] = true
			for kCivic in GameInfo.Civics() do		
				local iCivic	= kCivic.Index
				if pCulture:HasCivic(iCivic) then
					if not knownCivics[iCivic] then knownCivics[iCivic] = 0 end
					knownCivics[iCivic] = knownCivics[iCivic] + 1
				end
			end
			
			-- Gold
			local pTreasury = player:GetTreasury()			
			totalGold = totalGold + pTreasury:GetGoldYield() + pTreasury:GetTotalMaintenance()			
			if pTreasury:GetGoldBalance() > 0 then
				totalGold = totalGold + pTreasury:GetGoldBalance()
			end
						
			-- Faith
			totalFaith = totalFaith + player:GetReligion():GetFaithYield()
			
			local playerUnits = player:GetUnits(); 	
			for i, unit in playerUnits:Members() do
				local unitInfo = GameInfo.Units[unit:GetType()];
				totalGold = totalGold + unitInfo.Cost
			end
			
			local era = player:GetEras():GetEra()
			if era > currentEra then
				print ("----------")
				print ("Changing current Era to "..tostring(CivilizationTypeName).." Era :" .. tostring(GameInfo.Eras[era].EraType))
				currentEra = era
			end
			
			tokenBonus = tokenBonus + player:GetInfluence():GetTokensToGive()
			for i, minorPlayer in ipairs(PlayerManager.GetAliveMinors()) do
				local iMinorPlayer 		= minorPlayer:GetID()				
				local minorInfluence	= minorPlayer:GetInfluence()		
				if minorInfluence ~= nil then
					tokenBonus = tokenBonus + minorInfluence:GetTokensReceived(iPlayer)
				end
			end
	
		end
	end
	
	if playersWithCity > 0 then
		scienceBonus 	= Round(totalScience/playersWithCity)
		minCivForTech	= playersWithCity*25/100
		minCivForCivic	= playersWithCity*10/100
		goldBonus 		= Round(totalGold/playersWithCity)
		settlersBonus 	= Round((totalCities-1)/playersWithCity)
		tokenBonus 		= Round(totalToken/playersWithCity)
		faithBonus		= Round(totalFaith * (currentEra+1) * 25/100)
	end
	
end
if bApplyBalance then
	GameEvents.OnGameTurnStarted.Add(SetCurrentBonuses)
end

function OnCityInitialized(iPlayer, cityID, x, y)
	local city = CityManager.GetCity(iPlayer, cityID)
	local player = Players[iPlayer]
	if not player:IsMajor() then return end
	local cityPlot = Map.GetPlot(x, y)
	local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
	print("------------")
	print("Initializing new city for " .. tostring(CivilizationTypeName))
	
	local playerEra = GetStartingEra(iPlayer)
	
	local kEraBonuses = GameInfo.StartEras[playerEra]
	print("Era = "..tostring(playerEra))
	print("StartingPopulationCapital = "..tostring(kEraBonuses.StartingPopulationCapital))
	print("StartingPopulationOtherCities = "..tostring(kEraBonuses.StartingPopulationOtherCities))
	
	if kEraBonuses.StartingPopulationCapital and city == player:GetCities():GetCapitalCity() then 
		city:ChangePopulation(kEraBonuses.StartingPopulationCapital-1)
	elseif kEraBonuses.StartingPopulationOtherCities then
		city:ChangePopulation(kEraBonuses.StartingPopulationOtherCities-1)
	end
	
	for kBuildings in GameInfo.StartingBuildings() do
		if GameInfo.Eras[kBuildings.Era].Index <= playerEra and kBuildings.District == "DISTRICT_CITY_CENTER" then
			local iBuilding = GameInfo.Buildings[kBuildings.Building].Index
			if not city:GetBuildings():HasBuilding(iBuilding) then
				print("Starting Building = "..tostring(kBuildings.Building))
				WorldBuilder.CityManager():CreateBuilding(city, kBuildings.Building, 100, cityPlot)
			end
		end
	end
	
	-- City plazza for Era bonuses
	local EraBuilding = "BUILDING_CENTER_"..tostring(GameInfo.Eras[playerEra].EraType)
	print("Starting Era Building = "..tostring(EraBuilding))
	if GameInfo.Buildings[EraBuilding] then
		--WorldBuilder.CityManager():CreateBuilding(city, EraBuilding, 100, cityPlot)
		local pCityBuildQueue = city:GetBuildQueue();
		pCityBuildQueue:CreateIncompleteBuilding(GameInfo.Buildings[EraBuilding].Index, 100);
	end	
	
	for kUnits in GameInfo.MajorStartingUnits() do
		if GameInfo.Eras[kUnits.Era].Index == playerEra and kUnits.OnDistrictCreated and not (kUnits.AiOnly) then -- (player:IsHuman() and kUnits.AiOnly) -- to do : difficulty difference check
			local numUnit = math.max(kUnits.Quantity, 1)
			print(" - "..tostring(kUnits.Unit).." = "..tostring(numUnit))			
			if kUnits.Unit == "UNIT_TRADER" then
				UnitManager.InitUnit(iPlayer, kUnits.Unit, x, y, numUnit)
			else
				UnitManager.InitUnitValidAdjacentHex(iPlayer, kUnits.Unit, x, y, numUnit)
			end
		end
	end	
	
end

-- test capture or creation
local cityCaptureTest = {}
function CityCaptureDistrictRemoved(iPlayer, districtID, cityID, iX, iY)
	local key = iX..","..iY
	cityCaptureTest[key]			= {}
	cityCaptureTest[key].Turn 		= Game.GetCurrentGameTurn()
	cityCaptureTest[key].iPlayer 	= iPlayer
	cityCaptureTest[key].CityID 	= cityID
end
function CityCaptureCityInitialized(iPlayer, cityID, iX, iY)
	local key = iX..","..iY
	local bCaptured = false
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn() )
	then
		cityCaptureTest[key].CityInitializedXY = true
		local city = CityManager.GetCity(iPlayer, cityID)
		local originalOwnerID 	= city:GetOriginalOwner()
		if cityCaptureTest[key].iPlayer == originalOwnerID then
			print("City captured")
			cityCaptureTest[key] = {}
			bCaptured = true
		end
	end
	if not bCaptured then
		OnCityInitialized(iPlayer, cityID, iX, iY)
	end
end


-- Initialize
function OnLoadScreenClosed()
	if bApplyBalance then
		Events.DistrictRemovedFromMap.Add(CityCaptureDistrictRemoved)
		Events.CityInitialized.Add(CityCaptureCityInitialized)
	end
end
Events.LoadScreenClose.Add(OnLoadScreenClosed)

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