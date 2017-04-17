/*
	Historical Spawn Dates
	by Gedemon (2017)
	
*/

-----------------------------------------------
-- Create Tables
-----------------------------------------------

CREATE TABLE IF NOT EXISTS HistoricalSpawnDates
	 (	Civilization TEXT NOT NULL UNIQUE,
		StartYear INTEGER DEFAULT -10000);
