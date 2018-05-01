/*
 * @author Brumi (SimpleAI) Copyright (C) 2017
 * @file aircraft.nut
 * @note original licence can be found in licence.txt
 */

/**
 * Determines whether to use aircraft or not. This is done before selecting a route.
 * @return True if aircraft will be used.
 */
function cBuilder::UseAircraft()
{
	if (!root.use_aircraft) return false;
	if (Banker.MinimumMoneyToUseAircraft() > Banker.GetMaxBankBalance()) return false;
	if (!root.use_trains && !root.use_roadvehs) return true;
	local chance = 12;
	if (!root.use_trains || !root.use_roadvehs) chance *= 2;
	if (AIBase.Chance(chance, 100)) return true;
	else return false;
}

/**
 * Determines whether small aircraft are available.
 * @return True if small aircraft are available.
 */
function cBuilder::IsSmallAircraftAvailable()
{
	planelist = AIEngineList(AIVehicle.VT_AIR);
	planelist.Valuate(AIEngine.GetPlaneType);
	planelist.RemoveValue(AIAirport.PT_INVALID);
	planelist.RemoveValue(AIAirport.PT_BIG_PLANE);
	if (planelist.Count() > 0) return true;
	else return false;
}

/**
 * Builds an airport around the source or the destination town.
 * Builder class variables used: src, dst
 * Builder class variablse set: stasrc, stadst
 * The airport built is registered in the airports list.
 * @param is_source True if the source airport is to be built.
 * @return True if the airport was built.
 */
function cBuilder::BuildAirport(is_source)
{
	local tilelist = null;
	local airporttype = null;
	// Decide which airport type to use
	if (AIAirport.IsValidAirportType(AIAirport.AT_LARGE)) {
		airporttype = AIAirport.AT_LARGE;
	} else if (AIAirport.IsValidAirportType(AIAirport.AT_COMMUTER)) {
		airporttype = AIAirport.AT_COMMUTER;
	} else {
		airporttype = AIAirport.AT_SMALL;
	}
	// Get the tile list
	if (is_source) {
		tilelist = cBuilder.GetTilesAroundTown(src, AIAirport.GetAirportWidth(airporttype), AIAirport.GetAirportHeight(airporttype));
	} else {
		tilelist = cBuilder.GetTilesAroundTown(dst, AIAirport.GetAirportWidth(airporttype), AIAirport.GetAirportHeight(airporttype));
	}
	//local tilelist2 = tilelist;
	tilelist.Valuate(AITile.IsBuildableRectangle, AIAirport.GetAirportWidth(AIAirport.AT_SMALL), AIAirport.GetAirportHeight(AIAirport.AT_SMALL));
	tilelist.KeepValue(1);
	foreach (tile, dummy in tilelist) {
		tilelist.SetValue(tile, cBuilder.WhichAirportCanBeBuilt(tile));
	}
	tilelist.RemoveValue(AIAirport.AT_INVALID);
	if (tilelist.Count() == 0) return false;
	// Try to build the largest airport possible
	airporttype = cBuilder.GetLargestAirport(tilelist);
	tilelist.KeepValue(airporttype);
	tilelist.Valuate(AITile.GetCargoAcceptance, crg, AIAirport.GetAirportWidth(airporttype), AIAirport.GetAirportHeight(airporttype), AIAirport.GetAirportCoverageRadius(airporttype));
	tilelist.Sort(AIList.SORT_BY_VALUE, false);
	foreach (tile, dummy in tilelist) {
		// try to build the airport
		if (cBuilder.BuildAirportWithLandscaping(tile, airporttype, AIStation.STATION_NEW)) {
			if (is_source) {
				stasrc = AIStation.GetStationID(tile);
				root.airports.AddItem(src, stasrc);
				homedepot = AIAirport.GetHangarOfAirport(tile);
			} else {
				stadst = AIStation.GetStationID(tile);
				root.airports.AddItem(dst, stadst);
			}
			return true;
		}
	}
	AILog.Error("Airport could not be built: " + AIError.GetLastErrorString());
	return false;
}

/**
 * Get the largest airport type which can be built at a given tile.
 * @param tile The tile to be examined.
 * @return The largest airport type, AIAirport.AT_INVALID if none can be built.
 */
function cBuilder::WhichAirportCanBeBuilt(tile)
{
	local testmode = AITestMode();
	local airports = [AIAirport.AT_METROPOLITAN, AIAirport.AT_LARGE, AIAirport.AT_COMMUTER, AIAirport.AT_SMALL];
	for (local x = 0; x < airports.len(); x++) {
		if (AIAirport.BuildAirport(tile, airports[x], AIStation.STATION_NEW)) return airports[x];
		else if (AIError.GetLastError() == AIError.ERR_FLAT_LAND_REQUIRED) {
			if (!AIAirport.IsValidAirportType(airports[x])) continue;
			if (!cBuilder.IsWithinNoiseLimit(tile, airports[x])) continue;
			local width = AIAirport.GetAirportWidth(airports[x]);
			local height = AIAirport.GetAirportHeight(airports[x]);
			local cost = cBuilder.CostToFlattern(tile, width, height);
			if (cost >= 0 && cost < Banker.InflatedValue(10000)) return airports[x];
		}
	}
	return AIAirport.AT_INVALID;
}

/**
 * Get the largest airport which can be built in a given area.
 * @param tilelist The tiles to be examined.
 * @return The largest airport type, AIAirport.AT_INVALID if none can be built.
 */
function cBuilder::GetLargestAirport(tilelist)
{
	local airports = [AIAirport.AT_METROPOLITAN, AIAirport.AT_LARGE, AIAirport.AT_COMMUTER, AIAirport.AT_SMALL];
	for (local x = 0; x < airports.len(); x++) {
		if (AIAirport.IsValidAirportType(airports[x])) {
			local tilelist2 = AIList();
			tilelist2.AddList(tilelist);
			tilelist2.KeepValue(airports[x]);
			if (tilelist2.Count() > 0) return airports[x];
		}
	}
	return AIAirport.AT_INVALID;
}

/**
 * Demolishes a given airport if no vehicles are using it.
 */
function cBuilder::DeleteAirport(sta)
{
	if (sta == null || !AIStation.IsValidStation(sta)) return;
	local vehiclelist = AIVehicleList_Station(sta);
	if (vehiclelist.Count() > 0) return;
	local tile = AIStation.GetLocation(sta);
	if (AIAirport.RemoveAirport(tile)) root.airports.RemoveValue(sta);
}

/**
 * Determines whether an airport type is only fit for small planes.
 * @param airport_type The airport type to be examined.
 * @return True if it is a small airport type.
 */
function cBuilder::IsSmallAirport(airport_type)
{
	if (airport_type == AIAirport.AT_SMALL || airport_type == AIAirport.AT_COMMUTER) return true;
	else return false;
}

/**
 * Chooses a plane to be used. Helicopters are excluded.
 * @param crg The type of cargo to carry.
 * @param is_small If true, only small planes are accepted.
 * @param distance The order distance of the source and destination.
 * @param cheapest If true, the cheapest plane will be chosen. If false, the highest capacity plane that is still affordable.
 * @return The plane type. Null if there are none available.
 */
function cBuilder::ChoosePlane(crg, is_small, distance, cheapest)
{
	local planelist = AIEngineList(AIVehicle.VT_AIR);
	planelist.Valuate(AIEngine.GetMaximumOrderDistance);
	planelist.KeepAboveValue(distance);
	local planelist2 = AIEngineList(AIVehicle.VT_AIR);
	planelist2.Valuate(AIEngine.GetMaximumOrderDistance);
	planelist2.KeepValue(0);
	// The union of the above two lists
	planelist.AddList(planelist2);
	planelist.Valuate(AIEngine.GetPlaneType);
	planelist.RemoveValue(AIAirport.PT_INVALID);
	planelist.RemoveValue(AIAirport.PT_HELICOPTER);
	if (is_small) planelist.RemoveValue(AIAirport.PT_BIG_PLANE);
	planelist.Valuate(AIEngine.CanRefitCargo, crg);
	planelist.KeepValue(1);
	planelist.Valuate(AIEngine.GetPrice);
	if (cheapest) {
		// Sort ascending by price
		planelist.Sort(AIList.SORT_BY_VALUE, true);
	} else {
		// Sort descending by capacity, but discard those that are too expensive
		planelist.KeepBelowValue(Banker.GetMaxBankBalance());
		if (planelist.Count() == 0) return null;
		planelist.Valuate(AIEngine.GetCapacity);
		planelist.Sort(AIList.SORT_BY_VALUE, false);
	}
	return planelist.Begin();
}

/**
 * Unused function, BuildAndStartVehicles is used instead.
 * @see BuildAndStartVehicles()
 */
function cBuilder::BuildAndStartPlanes(veh, number, ordervehicle)
{
	local srcplace = AIStation.GetLocation(stasrc);
	local dstplace = AIStation.GetLocation(stadst);
	local price = AIEngine.GetPrice(veh);
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
		if (!Banker.SetMinimumBankBalance(price)) {
			AILog.Warning("I don't have enough money to build a plane.");
			return false;
		}
	}
	local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
	if (AIEngine.GetCargoType(veh) != crg) AIVehicle.RefitVehicle(firstveh, crg);
	if (ordervehicle == null) {
		AIOrder.AppendOrder(firstveh, srcplace, AIOrder.OF_NONE);
		AIOrder.AppendOrder(firstveh, dstplace, AIOrder.OF_NONE);
	} else {
		AIOrder.ShareOrders(firstveh, ordervehicle);
	}
	AIVehicle.StartStopVehicle(firstveh);
	AIGroup.MoveVehicle(group, firstveh);
	for (local idx = 2; idx <= number; idx++) {
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
			Banker.SetMinimumBankBalance(price);
		}
		local nextveh = AIVehicle.CloneVehicle(homedepot, firstveh, true);
		AIVehicle.StartStopVehicle(nextveh);
	}
	return true;
}

/**
 * Get the capacity of an airport type.
 * @param airport_type The airport type.
 * @return The maximum amount of planes which can use the airport.
 */
function cBuilder::GetAirportTypeCapacity(airport_type)
{
	if (!AIAirport.IsAirportInformationAvailable(airport_type)) return 0;
	switch (airport_type) {
		case AIAirport.AT_SMALL:
			return 4;
			break;
		case AIAirport.AT_COMMUTER:
			return 6;
			break;
		case AIAirport.AT_LARGE:
			return 6;
			break;
		case AIAirport.AT_METROPOLITAN:
			return 8;
			break;
	}
	return 0;
}

/**
 * Gives an estimate for the cost to flattern an area.
 * It is a function from PAXLink.
 * @param top_left_tile The top left tile of the area.
 * @param width The width of the area.
 * @param height The height of the area.
 * @return The estimated cost, -1 if not possible.
 */
function cBuilder::CostToFlattern(top_left_tile, width, height) // from PAXLink
{
	if(!AITile.IsBuildableRectangle(top_left_tile, width, height))
		return -1; // not buildable
	local level_cost = 0;
	{
		local test = AITestMode();
		local account = AIAccounting();
		local bottom_right_tile = top_left_tile + AIMap.GetTileIndex(width, height);
		if(!AITile.LevelTiles(top_left_tile, bottom_right_tile))
			return -1;
		level_cost = account.GetCosts();
	}
	return level_cost;
	return 0;
}

/**
 * Builds an airport at a given tile. The function uses landscaping if needed.
 * @param tile The tile where the airport will be built.
 * @param tpye The type of the airport.
 * @param station_id The StationID which will be used.
 * @return True if the construction succeeded.
 */
function cBuilder::BuildAirportWithLandscaping(tile, type, station_id)
{
	if (AIAirport.BuildAirport(tile, type, station_id)) return true;
	if (AIError.GetLastError() == AIError.ERR_FLAT_LAND_REQUIRED) {
		local width = AIAirport.GetAirportWidth(type);
		local height = AIAirport.GetAirportHeight(type);
		local account = AIAccounting();
		local result = Terraform.Terraform(tile, width, height, -1);
		if (account.GetCosts() > 0) AILog.Info("Terraforming cost was " + account.GetCosts());
		return (result && AIAirport.BuildAirport(tile, type, station_id));
	}
	return false;
}

/**
 * Determines whether an airport at a given tile is allowed by the town authorities
 * because of the noise level
 * @param tile The tile where the aiport would be built.
 * @param airport_type The type of the airport.
 * @return True if the construction would be allowed. If the noise setting is off, it defaults to true.
 */
function cBuilder::IsWithinNoiseLimit(tile, airport_type)
{
	if (!AIGameSettings.GetValue("economy.station_noise_level")) return true;
	local allowed = AITown.GetAllowedNoise(AIAirport.GetNearestTown(tile, airport_type));
	local increase = AIAirport.GetNoiseLevelIncrease(tile, airport_type);
	return (increase <= allowed);
}

/**
 * Get the maximum range that planes can support.
 * @return The maximum range that planes can support, 0 if unlimited.
 */
function cBuilder::GetMaximumAircraftRange()
{
	local planelist = AIEngineList(AIVehicle.VT_AIR);
	planelist.Valuate(AIEngine.GetPlaneType);
	planelist.RemoveValue(AIAirport.PT_INVALID);
	planelist.RemoveValue(AIAirport.PT_HELICOPTER);
	planelist.Valuate(AIEngine.GetMaximumOrderDistance);
	local max = planelist.GetValue(planelist.Begin());
	planelist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	if (planelist.GetValue(planelist.Begin()) == 0) return 0;
	else return max;
}

/**
 * Get the aircraft-basef order distance of a town to a tile.
 * @param town The townID of the town.
 * @param tile The tile to which the distance is measured.
 * @return The order distance.
 */
function cBuilder::GetTownAircraftOrderDistanceToTile(town, tile)
{
	return AIOrder.GetOrderDistance(AIVehicle.VT_AIR, AITown.GetLocation(town), tile);
}
