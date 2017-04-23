------------------------------------------------------------------------------
--	FILE:	 InGameHSD.lua
--  Gedemon (2017)
------------------------------------------------------------------------------

print ("loading InGameHSD.lua")

----------------------------------------------------------------------------------------
-- Historical Spawn Dates <<<<<
----------------------------------------------------------------------------------------

local defaultQuickMovement 	= UserConfiguration.GetValue("QuickMovement")
local defaultQuickCombat 	= UserConfiguration.GetValue("QuickCombat")
local defaultAutoEndTurn	= UserConfiguration.GetValue("AutoEndTurn") 

function SetTurnYear(iTurn)
	previousTurnYear 	= Calendar.GetTurnYearForGame( iTurn )
	currentTurnYear 	= Calendar.GetTurnYearForGame( iTurn + 1 )
	nextTurnYear 		= Calendar.GetTurnYearForGame( iTurn + 2 )
	GameConfiguration.SetValue("PreviousTurnYear", previousTurnYear)
	GameConfiguration.SetValue("CurrentTurnYear", currentTurnYear)
	GameConfiguration.SetValue("NextTurnYear", nextTurnYear)
	LuaEvents.SetPreviousTurnYear(previousTurnYear)
	LuaEvents.SetCurrentTurnYear(currentTurnYear)
	LuaEvents.SetNextTurnYear(nextTurnYear)
end
Events.TurnEnd.Add( SetTurnYear )

function SetAutoValues()
	--UserConfiguration.SetValue("QuickMovement", 1)
	--UserConfiguration.SetValue("QuickCombat", 1)
	UserConfiguration.SetValue("AutoEndTurn", 1)
end
LuaEvents.SetAutoValues.Add(SetAutoValues)

function RestoreAutoValues()
	--UserConfiguration.SetValue("QuickMovement", defaultQuickMovement)
	--UserConfiguration.SetValue("QuickCombat", 	defaultQuickCombat 	)
	UserConfiguration.SetValue("AutoEndTurn", 	defaultAutoEndTurn	)
end
LuaEvents.RestoreAutoValues.Add(RestoreAutoValues)

function SetStartingEra(iPlayer, era)
	local key = "StartingEra"..tostring(iPlayer)
	print ("saving key = "..key..", value = ".. tostring(era))
	GameConfiguration.SetValue(key, era)
end
LuaEvents.SetStartingEra.Add( SetStartingEra )


-- Set current & next turn year ASAP when (re)loading
LuaEvents.SetCurrentTurnYear(Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()))
LuaEvents.SetNextTurnYear(Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()+1))

-- Broacast that we're ready to set HSD
LuaEvents.InitializeHSD()


