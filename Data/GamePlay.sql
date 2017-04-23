/*
	Historical Spawn Dates
	by Gedemon (2017)
	
*/

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('HSD_VERSION', 'Alpha .1');

DELETE FROM MajorStartingUnits WHERE Unit="UNIT_SETTLER";

UPDATE StartingBuildings SET Era="ERA_CLASSICAL" WHERE Building="BUILDING_WALLS";
UPDATE StartingBuildings SET Era="ERA_MEDIEVAL" WHERE Building="BUILDING_GRANARY";
