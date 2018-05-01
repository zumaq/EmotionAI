class cBuilder
{
		DIR_NE = 2;
		DIR_NW = 0;
		DIR_SE = 1;
		DIR_SW = 3;

		root = null; // Reference to the AI instance
		crglist = null;
		crg = null; // The list of possible cargoes; The cargo selected to be transported
		srclist = null;
		src = null; // The list of sources for the given cargo; The source (StationID/TownID) selected
		dstlist = null;
		dst = null; // The list of destinations for the given source; The destination (StationID/TownID) selected
		statile = null;
		deptile = null; // The tile of the station; The tile of the depot
		stafront = null;
		depfront = null; // The tile in front of the station; The tile in front of the depot
		statop = null;
		stabottom = null;
		frontfront = null; // Some variables needed to build a train station
		front1 = null;
		front2 = null;
		lane2 = null;
		morefront = null; // Some more variables needed to build a double rail station
		stationdir = null; // The direction of the station
		stasrc = null;
		stadst = null;
		homedepot = null; // The source station; The destination station; The depot at the source station
		srcistown = null;
		dstistown = null; // Whether the source is a town; Whether the destination is a town
		srcplace = null;
		dstplace = null; // The place of the source (town/industry); The place of the destination (town/industry)
		group = null; // The current vehicle group
		vehtype = null; // The vehicle type selected
		double = null; // Whether it is a double rail
		holes = null;
		holestart = null;
		holeend = null; // Variables needed to correct roads which weren't built fully
		ps1_entry = null;
		ps1_exit = null;
		ps2_entry = null;
		ps2_exit = null; // Passing lane starting/ending points
		recursiondepth = null; // The recursion depth used to catch infinite recursions
		constructor(that) {
			root = that;
			ps1_entry = [null, null];
			ps2_entry = [null, null];
		}

}

/**
 * The main function to build a new route.
 * @return True if a new route was built.
 */
function cBuilder::BuildSomething()
{
	// Determine whether we're going for a subsidy
	if (cBuilder.CheckSubsidies()) {
		AILog.Warning("Trying to get subsidy:");
	} else {
		// Determine whether we're using aircraft
		if (UseAircraft()) vehtype = AIVehicle.VT_AIR;
		else vehtype = null;
		// Find a cargo, a source and a destination
		if (cBuilder.FindService()) {
			AILog.Warning("Trying to build new service:");
		} else return false;
	}
	root.buildingstage = root.BS_NOTHING;
	local srcname, dstname = null;
	if (srcistown) srcname = AITown.GetName(src);
	else srcname = AIIndustry.GetName(src);
	if (dstistown) dstname = AITown.GetName(dst);
	else dstname = AIIndustry.GetName(dst);
	AILog.Info(AICargo.GetCargoLabel(crg) + " from " + srcname + " to " + dstname);
	// If not using aircraft, decide whether to use road or rail
	if (vehtype != AIVehicle.VT_AIR) vehtype = cBuilder.RoadOrRail();
	if (vehtype == null) {
		AILog.Error("No vehicle type available!");
		return false;
	}
	// Build HQ if not built already
	if (!AIMap.IsValidTile(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF))) {
		local place_id = src;
		local placeistown = srcistown;
		if (AIController.GetSetting("hq_in_town")) {
			place_id = AITile.GetClosestTown(srcplace);
			placeistown = true;
		}
		root.BuildHQ(place_id, placeistown);
	}
	double = false;
	local platform = null;
	switch (vehtype) {

			/* Road building */
		case AIVehicle.VT_ROAD:
			AILog.Info("Using road");
			if (AIMap.DistanceManhattan(srcplace, dstplace) > 110) {
				AILog.Warning("This route would be too long for a road service");
				return false;
			}
			// Choose a road vehicle
			local veh = cBuilder.ChooseRoadVeh(crg);
			if (veh == null) {
				AILog.Warning("No suitable road vehicle available!");
				return false;
			} else {
				AILog.Info("Selected road vehicle: " + AIEngine.GetName(veh));
			}
			// Try to build the source station
			if (cBuilder.BuildRoadStation(true)) {
				root.buildingstage = root.BS_BUILDING;
				AILog.Info("New station successfully built: " + AIStation.GetName(stasrc));
			} else {
				AILog.Warning("Could not build source station at " + srcname);
				root.buildingstage = root.BS_NOTHING;
				return false;
			}
			// Try to build the destination station
			if (cBuilder.BuildRoadStation(false)) {
				AILog.Info("New station successfully built: " + AIStation.GetName(stadst));
			} else {
				AILog.Warning("Could not build destination station at " + dstname);
				cBuilder.DeleteRoadStation(stasrc);
				root.buildingstage = root.BS_NOTHING;
				return false;
			}
			// Build the road
			holes = [];
			if (cBuilder.BuildRoad(AIRoad.GetRoadStationFrontTile(AIStation.GetLocation(stadst)), AIRoad.GetRoadStationFrontTile(AIStation.GetLocation(stasrc)))) {
				AILog.Info("Road built successfully!");
			} else {
				cBuilder.DeleteRoadStation(stasrc);
				cBuilder.DeleteRoadStation(stadst);
				root.buildingstage = root.BS_NOTHING;
				return false;
			}
			// Correct the road if needed
			recursiondepth = 0;
			while (holes.len() > 0) {
				recursiondepth++;
				if (!cBuilder.RepairRoute()) {
					cBuilder.DeleteRoadStation(stasrc);
					cBuilder.DeleteRoadStation(stadst);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
			}
			root.buildingstage = root.BS_NOTHING;
			group = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
			cBuilder.SetGroupName(group, crg, stasrc);
			cBuilder.BuildAndStartVehicles(veh, 5, null);
			break;

			/* Railway building */

		case AIVehicle.VT_RAIL:
			local trains = null;
			// Decide whether to use double rails
			if (AIMap.DistanceManhattan(srcplace, dstplace) > 80) double = true;
			if (!double) AILog.Info("Using single rail");
			else AILog.Info("Using double rail");
			// Determine the length of the train station
			if (double || AIMap.DistanceManhattan(srcplace, dstplace) > 50) platform = 3;
			else platform = 2;
			// Choose wagon and locomotive
			local wagon = cBuilder.ChooseWagon(crg, root.engineblacklist);
			if (wagon == null) {
				AILog.Warning("No suitable wagon available!");
				return false;
			} else {
				AILog.Info("Chosen wagon: " + AIEngine.GetName(wagon));
			}
			local engine = cBuilder.ChooseTrainEngine(crg, AIMap.DistanceManhattan(srcplace, dstplace), wagon, platform * 2 - 1, root.engineblacklist);
			if (engine == null) {
				AILog.Warning("No suitable engine available!");
				return false;
			} else {
				AILog.Info("Chosen engine: " + AIEngine.GetName(engine));
			}

			if (!double) {

				/* Single rail */

				trains = 1;
				local start, end = null;

				// Build the source station
				if (cBuilder.BuildSingleRailStation(true, platform)) {
					end = [frontfront, stafront];
					root.buildingstage = root.BS_BUILDING;
					AILog.Info("New station successfully built: " + AIStation.GetName(stasrc));
				} else {
					AILog.Warning("Could not build source station at " + srcname);
					return false;
				}
				// Build the destination station
				if (cBuilder.BuildSingleRailStation(false, platform)) {
					start = [frontfront, stafront];
					AILog.Info("New station successfully built: " + AIStation.GetName(stadst));
				} else {
					AILog.Warning("Could not build destination station at " + dstname);
					cBuilder.DeleteRailStation(stasrc);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
				// Build the rail
				recursiondepth = 0;
				if (cBuilder.BuildRail(start, end)) {
					AILog.Info("Rail built successfully!");
				} else {
					cBuilder.DeleteRailStation(stasrc);
					cBuilder.DeleteRailStation(stadst);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
			} else {

				/* Double rail */

				trains = 2;
				local start, end = null;
				local temp_ps = null;
				// Build the source station
				if (cBuilder.BuildDoubleRailStation(true)) {
					end = [morefront, frontfront];
					root.buildingstage = root.BS_BUILDING;
					AILog.Info("New station successfully built: " + AIStation.GetName(stasrc));
				} else {
					AILog.Warning("Could not build source station at " + srcname);
					return false;
				}
				// Build the destination station
				if (cBuilder.BuildDoubleRailStation(false)) {
					start = [morefront, frontfront];
					AILog.Info("New station successfully built: " + AIStation.GetName(stadst));
				} else {
					AILog.Warning("Could not build destination station at " + dstname);
					cBuilder.DeleteRailStation(stasrc);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
				// Build the first passing lane section
				temp_ps = cBuilder.BuildPassingLaneSection(true);
				if (temp_ps == null) {
					AILog.Warning("Could not build first passing lane section");
					cBuilder.DeleteRailStation(stasrc);
					cBuilder.DeleteRailStation(stadst);
					root.buildingstage = root.BS_NOTHING;
					return false;
				} else {
					if (AIMap.DistanceManhattan(end[0], temp_ps[0][0]) < AIMap.DistanceManhattan(end[0], temp_ps[1][0])) {
						ps1_entry = [temp_ps[0][0], temp_ps[0][1]];
						ps1_exit = [temp_ps[1][0], temp_ps[1][1]];
					} else {
						ps1_entry = [temp_ps[1][0], temp_ps[1][1]];
						ps1_exit = [temp_ps[0][0], temp_ps[0][1]];
					}
				}
				// Build the second passing lane section
				temp_ps = cBuilder.BuildPassingLaneSection(false);
				if (temp_ps == null) {
					AILog.Warning("Could not build second passing lane section");
					cBuilder.DeleteRailStation(stasrc);
					cBuilder.DeleteRailStation(stadst);
					cBuilder.RemoveRailLine(ps1_entry[1]);
					root.buildingstage = root.BS_NOTHING;
					return false;
				} else {
					if (AIMap.DistanceManhattan(start[0], temp_ps[0][0]) < AIMap.DistanceManhattan(start[0], temp_ps[1][0])) {
						ps2_entry = [temp_ps[1][0], temp_ps[1][1]];
						ps2_exit = [temp_ps[0][0], temp_ps[0][1]];
					} else {
						ps2_entry = [temp_ps[0][0], temp_ps[0][1]];
						ps2_exit = [temp_ps[1][0], temp_ps[1][1]];
					}
				}
				// Build the rail between the source station and the first passing lane section
				recursiondepth = 0;
				if (cBuilder.BuildRail(ps1_entry, end)) {
					AILog.Info("Rail built successfully!");
				} else {
					cBuilder.DeleteRailStation(stadst);
					cBuilder.DeleteRailStation(stasrc);
					cBuilder.RemoveRailLine(ps1_entry[1]);
					cBuilder.RemoveRailLine(ps2_entry[1]);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
				// Build the rail between the two passing lane sections
				recursiondepth = 0;
				if (cBuilder.BuildRail(ps2_entry, ps1_exit)) {
					AILog.Info("Rail built successfully!");
				} else {
					cBuilder.DeleteRailStation(stadst);
					cBuilder.DeleteRailStation(stasrc);
					cBuilder.RemoveRailLine(ps2_entry[1]);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
				// Build the rail between the second passing lane section and the destination station
				recursiondepth = 0;
				if (cBuilder.BuildRail(start, ps2_exit)) {
					AILog.Info("Rail built successfully!");
				} else {
					cBuilder.DeleteRailStation(stadst);
					cBuilder.DeleteRailStation(stasrc);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
			}
			root.buildingstage = root.BS_NOTHING;
			group = AIGroup.CreateGroup(AIVehicle.VT_RAIL);
			cBuilder.SetGroupName(group, crg, stasrc);
			cBuilder.BuildAndStartTrains(trains, 2 * platform - 2, engine, wagon, null);
			break;

			/* Aircraft building */

		case AIVehicle.VT_AIR:
			AILog.Info("Using air");
			// Exit if no planes are available
			local planelist = AIEngineList(AIVehicle.VT_AIR);
			if (planelist.Count() == 0) {
				AILog.Warning("No aircraft available!");
				return false;
			}
			// Build the source airport if it doesn't exist yet
			if (!root.airports.HasItem(src)) {
				if (cBuilder.BuildAirport(true)) {
					root.buildingstage = root.BS_BUILDING;
					AILog.Info("New airport successfully built: " + AIStation.GetName(stasrc));
				} else {
					AILog.Warning("Could not build source airport at " + srcname);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
			} else {
				stasrc = root.airports.GetValue(src);
				homedepot = AIAirport.GetHangarOfAirport(AIStation.GetLocation(stasrc));
				AILog.Info("Using existing airport at " + AITown.GetName(src) + ": " + AIStation.GetName(stasrc));
			}
			// Build the destination airport if it doesn't exist yet
			if (!root.airports.HasItem(dst)) {
				if (cBuilder.BuildAirport(false)) {
					root.buildingstage = root.BS_BUILDING;
					AILog.Info("New airport successfully built: " + AIStation.GetName(stadst));
				} else {
					AILog.Warning("Could not build destination airport at " + dstname);
					cBuilder.DeleteAirport(stasrc);
					root.buildingstage = root.BS_NOTHING;
					return false;
				}
			} else {
				stadst = root.airports.GetValue(dst);
				AILog.Info("Using existing airport at " + AITown.GetName(dst) + ": " + AIStation.GetName(stadst));
			}
			// Depending on the type of the airports, choose a plane
			local is_small = cBuilder.IsSmallAirport(AIAirport.GetAirportType(AIStation.GetLocation(stasrc))) || cBuilder.IsSmallAirport(AIAirport.GetAirportType(AIStation.GetLocation(stadst)));
			local planetype = cBuilder.ChoosePlane(crg, is_small, AIOrder.GetOrderDistance(AIVehicle.VT_AIR, srcplace, dstplace), false);
			if (planetype == null) {
				AILog.Warning("No suitable plane available!");
				cBuilder.DeleteAirport(stasrc);
				cBuilder.DeleteAirport(stadst);
				root.buildingstage = root.BS_NOTHING;
				return false;
			}
			AILog.Info("Selected aircraft: " + AIEngine.GetName(planetype));
			AILog.Info("Distance: " + AIOrder.GetOrderDistance(AIVehicle.VT_AIR, srcplace, dstplace) + "   Range: " + AIEngine.GetMaximumOrderDistance(planetype));
			root.buildingstage = root.BS_NOTHING;
			group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
			cBuilder.SetGroupName(group, crg, stasrc);
			cBuilder.BuildAndStartVehicles(planetype, 2, null);
			break;
	}

	local new_route = cBuilder.RegisterRoute();
	// Retry if route was abandoned due to blacklisting
	local vehicles = AIVehicleList_Group(group);
	if (vehicles.Count() == 0 && vehtype == AIVehicle.VT_RAIL) {
		AILog.Info("The new route may be empty because of blacklisting, retrying...")
		// Choose wagon and locomotive
		local wagon = cBuilder.ChooseWagon(crg, root.engineblacklist);
		if (wagon == null) {
			AILog.Warning("No suitable wagon available!");
			return false;
		} else {
			AILog.Info("Chosen wagon: " + AIEngine.GetName(wagon));
		}
		local engine = cBuilder.ChooseTrainEngine(crg, AIMap.DistanceManhattan(srcplace, dstplace), wagon, platform * 2 - 1, root.engineblacklist);
		if (engine == null) {
			AILog.Warning("No suitable engine available!");
			return false;
		} else {
			AILog.Info("Chosen engine: " + AIEngine.GetName(engine));
		}
		local manager = cManager(root);
		manager.AddVehicle(new_route, null, engine, wagon);
		if (double) manager.AddVehicle(new_route, null, engine, wagon);
	}
	AILog.Info("New route done!");
	return true;
}

/**
 * Find a cargo, a source and a destination to build a new service.
 * Builder class variables set: crglist, crg, srclist, src, dstlist, dst,
 *   srcistown, dstistown, srcplace, dstplace
 * @return True if a potential connection was found.
 */
function cBuilder::FindService()
{
	crglist = AICargoList();
	crglist.Valuate(AIBase.RandItem);
	// Choose a source
	foreach (icrg, dummy in crglist) {
		// Passengers only if we're using air
		if (vehtype == AIVehicle.VT_AIR && AICargo.GetTownEffect(icrg) != AICargo.TE_PASSENGERS) continue;
		if (AICargo.GetTownEffect(icrg) != AICargo.TE_PASSENGERS && AICargo.GetTownEffect(icrg) != AICargo.TE_MAIL) {
			// If the source is an industry
			srclist = AIIndustryList_CargoProducing(icrg);
			// Should not be built on water
			srclist.Valuate(AIIndustry.IsBuiltOnWater);
			srclist.KeepValue(0);
			// There should be some production
			srclist.Valuate(AIIndustry.GetLastMonthProduction, icrg)
			srclist.KeepAboveValue(0);
			// Try to avoid excessive competition
			srclist.Valuate(cBuilder.GetLastMonthTransportedPercentage, icrg);
			srclist.KeepBelowValue(AIController.GetSetting("max_transported"));
			srcistown = false;
		} else {
			// If the source is a town
			srclist = AITownList();
			srclist.Valuate(AITown.GetLastMonthProduction, icrg);
			if (vehtype == AIVehicle.VT_AIR) srclist.KeepAboveValue(60);
			else srclist.KeepAboveValue(40);
			srcistown = true;
		}
		srclist.Valuate(AIBase.RandItem);
		foreach (isrc, dummy2 in srclist) {
			// Jump source if already serviced
			if (root.serviced.HasItem(isrc * 256 + icrg)) continue;
			// Jump if an airport exists there and it has no free capacity
			local noairportcapacity = false;
			if (vehtype == AIVehicle.VT_AIR) {
				if (root.airports.HasItem(isrc)) {
					local airport = root.airports.GetValue(isrc);
					local airporttype = AIAirport.GetAirportType(AIStation.GetLocation(airport));
					if ((cBuilder.GetAirportTypeCapacity(airporttype) - AIVehicleList_Station(airport).Count()) < 2) noairportcapacity = true;
				}
			}
			if (noairportcapacity) continue;
			if (srcistown) srcplace = AITown.GetLocation(isrc);
			else srcplace = AIIndustry.GetLocation(isrc);
			if (AICargo.GetTownEffect(icrg) == AICargo.TE_NONE || AICargo.GetTownEffect(icrg) == AICargo.TE_WATER) {
				// If the destination is an industry
				dstlist = AIIndustryList_CargoAccepting(icrg);
				dstistown = false;
				dstlist.Valuate(AIIndustry.GetDistanceManhattanToTile, srcplace);
			} else {
				// If the destination is a town
				dstlist = AITownList();
				// Some minimum population values for towns
				switch (AICargo.GetTownEffect(icrg)) {
					case AICargo.TE_FOOD:
						dstlist.Valuate(AITown.GetPopulation);
						dstlist.KeepAboveValue(100);
						break;
					case AICargo.TE_GOODS:
						dstlist.Valuate(AITown.GetPopulation);
						dstlist.KeepAboveValue(1500);
						break;
					default:
						dstlist.Valuate(AITown.GetLastMonthProduction, icrg);
						if (vehtype == AIVehicle.VT_AIR) dstlist.KeepAboveValue(60);
						else dstlist.KeepAboveValue(40);
						break;
				}
				dstistown = true;
				dstlist.Valuate(AITown.GetDistanceManhattanToTile, srcplace);
			}
			// Check the distance of the source and the destination
			if (vehtype == AIVehicle.VT_AIR) {
				dstlist.KeepAboveValue(128);
				// Get the maximum range of airplanes
				local max_range = cBuilder.GetMaximumAircraftRange();
				if (max_range == 0) {
					// maximum range is 0 if range is not supported by the plane set
					dstlist.KeepBelowValue(1536);
				} else {
					dstlist.Valuate(cBuilder.GetTownAircraftOrderDistanceToTile, srcplace);
					dstlist.KeepBelowValue((max_range * 0.8).tointeger());
				}
			} else {
				dstlist.KeepBelowValue(130);
				dstlist.KeepAboveValue(40);
				if (AICargo.GetTownEffect(icrg) == AICargo.TE_MAIL) dstlist.KeepBelowValue(110);
			}
			dstlist.Valuate(AIBase.RandItem);
			foreach (idst, dummy3 in dstlist) {
				// Chech if the destination capacity for more planes
				noairportcapacity = false;
				if (vehtype == AIVehicle.VT_AIR) {
					if (root.airports.HasItem(idst)) {
						local airport = root.airports.GetValue(idst);
						local airporttype = AIAirport.GetAirportType(AIStation.GetLocation(airport));
						if ((cBuilder.GetAirportTypeCapacity(airporttype) - AIVehicleList_Station(airport).Count()) < 2) noairportcapacity = true;
					}
				}
				if (noairportcapacity) continue;
				if (dstistown)
					dstplace = AITown.GetLocation(idst);
				else dstplace = AIIndustry.GetLocation(idst);
				crg = icrg;
				src = isrc;
				dst = idst;
				return true;
			}
		}
	}
	return false;
}

/**
 * Build a road station at a town or an industry.
 * Builder class variables used: crg, src, dst, srcistown, dstistown, srcplace, dstplace,
 *   statile, deptile, stafront, depfront
 * Builder class variables set: stasrc, stadst, homedepot
 * @param is_source True if we're building the source station.
 * @return True if the construction succeeded.
 */
function cBuilder::BuildRoadStation(is_source)
{
	local dir, tilelist, otherplace, isneartown = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	// Determine the possible list of tiles
	if (is_source) {
		dir = cBuilder.GetDirection(srcplace, dstplace);
		if (srcistown) {
			tilelist = cBuilder.GetTilesAroundTown(src, 1, 1);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryProducing(src, rad);
			isneartown = false;
		}
		otherplace = dstplace;
	} else {
		dir = cBuilder.GetDirection(dstplace, srcplace);
		if (dstistown) {
			tilelist = cBuilder.GetTilesAroundTown(dst, 1, 1);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryAccepting(dst, rad);
			tilelist.Valuate(AITile.GetCargoAcceptance, crg, 1, 1, rad);
			tilelist.RemoveBelowValue(8);
			isneartown = false;
		}
		otherplace = srcplace;
	}
	// Decide whether to use a bus or a lorry station
	local stationtype = null;
	if (AICargo.GetTownEffect(crg) == AICargo.TE_PASSENGERS)
		stationtype = AIRoad.ROADVEHTYPE_BUS;
	else stationtype = AIRoad.ROADVEHTYPE_TRUCK;
	// Filter the tile list
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepValue(1);
	if (isneartown) {
		tilelist.Valuate(AITile.GetCargoAcceptance, crg, 1, 1, rad);
		tilelist.KeepAboveValue(10);
	} else {
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	}
	tilelist.Sort(AIList.SORT_BY_VALUE, !isneartown);
	local success = false;
	// Find a place where the station can be built
	foreach (tile, dummy in tilelist) {
		if (cBuilder.CanBuildRoadStation(tile, dir)) {
			success = true;
			break;
		} else continue;
	}
	// Build the parts of the station
	if (!success) return false;
	AIRoad.BuildRoad(stafront, statile);
	AIRoad.BuildRoad(depfront, deptile);
	AIRoad.BuildRoad(stafront, depfront);
	if (!AIRoad.BuildRoadStation(statile, stafront, stationtype, AIStation.STATION_NEW)) {
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
	}
	if (!AIRoad.BuildRoadDepot(deptile, depfront)) {
		AILog.Error("Depot could not be built: " + AIError.GetLastErrorString());
		AITile.DemolishTile(statile);
		return false;
	}
	if (is_source) {
		stasrc = AIStation.GetStationID(statile);
		homedepot = deptile;
	} else {
		stadst = AIStation.GetStationID(statile);
	}
	return true;
}

/**
 * Get the direction from one tile to another.
 * @param tilefrom The first tile.
 * @param tileto The second tile
 * @return The direction from the first tile to the second tile.
 */
function cBuilder::GetDirection(tilefrom, tileto)
{
	local distx = AIMap.GetTileX(tileto) - AIMap.GetTileX(tilefrom);
	local disty = AIMap.GetTileY(tileto) - AIMap.GetTileY(tilefrom);
	local ret = 0;
	if (abs(distx) > abs(disty)) {
		ret = 2;
		disty = distx;
	}
	if (disty > 0) {
		ret = ret + 1;
	}
	return ret;
}

/**
 * Check if a road station can be built at a given place.
 * Builder class variables set: statile, deptile, stafront, depfront
 * @param tile The tile to be checked.
 * @param direction The direction of the proposed station.
 * @return True if a road station can be built.
 */
function cBuilder::CanBuildRoadStation(tile, direction)
{
	if (!AITile.IsBuildable(tile)) return false;
	local offsta = null;
	local offdep = null;
	local middle = null;
	local middleout = null;
	// Calculate the offsets depending on the direction
	switch (direction) {
		case DIR_NE:
			offdep = AIMap.GetTileIndex(0, -1);
			offsta = AIMap.GetTileIndex(-1, 0);
			middle = AITile.CORNER_W;
			middleout = AITile.CORNER_N;
			break;
		case DIR_NW:
			offdep = AIMap.GetTileIndex(1, 0);
			offsta = AIMap.GetTileIndex(0, -1);
			middle = AITile.CORNER_S;
			middleout = AITile.CORNER_W;
			break;
		case DIR_SE:
			offdep = AIMap.GetTileIndex(-1, 0);
			offsta = AIMap.GetTileIndex(0, 1);
			middle = AITile.CORNER_N;
			middleout = AITile.CORNER_E;
			break;
		case DIR_SW:
			offdep = AIMap.GetTileIndex(0, 1);
			offsta = AIMap.GetTileIndex(1, 0);
			middle = AITile.CORNER_E;
			middleout = AITile.CORNER_S;
			break;
	}
	statile = tile;
	deptile = tile + offdep;
	stafront = tile + offsta;
	depfront = tile + offsta + offdep;
	// Check if the place is buildable
	if (!AITile.IsBuildable(deptile)) {
		return false;
	}
	if (!AITile.IsBuildable(stafront) && !AIRoad.IsRoadTile(stafront)) {
		return false;
	}
	if (!AITile.IsBuildable(depfront) && !AIRoad.IsRoadTile(depfront)) {
		return false;
	}
	local height = AITile.GetMaxHeight(statile);
	local tiles = AITileList();
	tiles.AddTile(statile);
	tiles.AddTile(stafront);
	tiles.AddTile(deptile);
	tiles.AddTile(depfront);
	// Check the slopes
	if (!AIGameSettings.GetValue("construction.build_on_slopes")) {
		foreach (idx, dummy in tiles) {
			if (AITile.GetSlope(idx) != AITile.SLOPE_FLAT) return false;
		}
	} else {
		if ((AITile.GetCornerHeight(stafront, middle) != height) && (AITile.GetCornerHeight(stafront, middleout) != height)) return false;
	}
	foreach (idx, dummy in tiles) {
		if (AITile.GetMaxHeight(idx) != height) return false;
		if (AITile.IsSteepSlope(AITile.GetSlope(idx))) return false;
	}
	// Check if the station can be built
	local test = AITestMode();
	if (!AIRoad.BuildRoad(stafront, statile)) {
		if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
	if (!AIRoad.BuildRoad(depfront, deptile)) {
		if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
	if (!AIRoad.BuildRoad(stafront, depfront)) {
		if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) return false;
	}
	if (!AIRoad.BuildRoadStation(statile, stafront, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) return false;
	if (!AIRoad.BuildRoadDepot(deptile, depfront)) return false;
	test = null;
	return true;
}

/**
 * Build a road from one point to another.
 * Builder class variables set: holes
 * @param head1 The starting point.
 * @param head2 The ending point.
 * @return True if the construction succeeded. Note: the function also returns true if the road was
 * constructed, but there are holes remaining.
 */
function cBuilder::BuildRoad(head1, head2)
{
	local pathfinder = MyRoadPF();
	// Set some pathfinder penalties
	pathfinder._cost_level_crossing = 1000;
	pathfinder._cost_coast = 100;
	pathfinder._cost_slope = 100;
	pathfinder._cost_bridge_per_tile = 80;
	pathfinder._cost_tunnel_per_tile = 60;
	pathfinder._max_bridge_length = 20;
	pathfinder.InitializePath([head1], [head2]);
	AILog.Info("Pathfinding...");
	local counter = 0;
	local path = false;
	// Try to find a path
	while (path == false && counter < 150) {
		path = pathfinder.FindPath(100);
		counter++;
		AIController.Sleep(1);
	}
	if (path != null && path != false) {
		AILog.Info("Path found. (" + counter + ")");
	} else {
		AILog.Warning("Pathfinding failed.");
		return false;
	}
	local prev = null;
	local waserror = false;
	// Build the road itself
	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
			if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1) {
				// If it is not a bridge or a tunnel
				if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
					local error = AIError.GetLastError();
					if (error != AIError.ERR_ALREADY_BUILT) {
						// If there was some error building the road
						if (error == AIError.ERR_VEHICLE_IN_THE_WAY) {
							// Try again if a vehicle was in the way
							AILog.Info("A vehicle was in the way while I was building the road. Retrying...");
							counter = 0;
							AIController.Sleep(75);
							while (!AIRoad.BuildRoad(path.GetTile(), par.GetTile()) && counter < 3) {
								counter++;
								AIController.Sleep(75);
							}
							if (counter > 2) {
								// Report a hole if the vehicles aren't going out of the way
								AILog.Info("An error occured while I was building the road: " + AIError.GetLastErrorString());
								cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
								waserror = true;
							} else {
								// Report the end of the hole if the vehicle got out of the way
								if (waserror) {
									waserror = false;
									holes.push([holestart, holeend]);
								}
							}
						} else {
							// If the error was something other than a vehicle in the way
							AILog.Info("An error occured while I was building the road: " + AIError.GetLastErrorString());
							cBuilder.ReportHole(path.GetTile(), par.GetTile(), waserror);
							waserror = true;
						}
					} else {
						// If the road has been already built and there was an error beforehand
						if (waserror) {
							waserror = false;
							holes.push([holestart, holeend]);
						}
					}
				} else {
					// If the contruction suceeded normally and there was an error beforehand
					if (waserror) {
						waserror = false;
						holes.push([holestart, holeend]);
					}
				}
			} else {
				// Build a bridge or a tunnel
				if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
					if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
						// Build a tunnel
						if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
							// If the tunnel couldn't be built
							AILog.Info("An error occured while I was building the road: " + AIError.GetLastErrorString());
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
								AILog.Warning("That tunnel would be too expensive. Construction aborted.");
								return false;
							}
							cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
							waserror = true;
						} else {
							// If the tunnel was built and there was an error beforehand
							if (waserror) {
								waserror = false;
								holes.push([holestart, holeend]);
							}
						}
					} else {
						// Build a bridge
						local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
						bridgelist.Valuate(AIBridge.GetMaxSpeed);
						if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgelist.Begin(), path.GetTile(), par.GetTile())) {
							// If the bridge couldn't be built
							AILog.Info("An error occured while I was building the road: " + AIError.GetLastErrorString());
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
								AILog.Warning("That bridge would be too expensive. Construction aborted.");
								return false;
							}
							cBuilder.ReportHole(prev.GetTile(), par.GetTile(), waserror);
							waserror = true;
						} else {
							// Register the bridge if the construction suceeded
							root.roadbridges.AddTile(path.GetTile());
							if (waserror) {
								waserror = false;
								holes.push([holestart, holeend]);
							}
						}
					}
				}
			}
		}
		prev = path;
		path = par;
		// Check the cash on hand
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (AICompany.GetLoanInterval() + Banker.GetMinimumCashNeeded())) {
			if (!Banker.GetMoney(AICompany.GetLoanInterval())) {
				AILog.Warning("I don't have enough money to complete the route.");
				return false;
			}
		}
	}
	// If the last piece of road couldn't be built
	if (waserror) {
		waserror = false;
		holes.push([holestart, holeend]);
	}
	return true;
}

/**
 * Choose a road vehicle for the given cargo.
 * @param cargo The cargo that the road vehicle will transport.
 * @return The EngineID of the selected vehicle. Null if no suitable vehicle was found.
 */
function cBuilder::ChooseRoadVeh(cargo)
{
	local vehlist = AIEngineList(AIVehicle.VT_ROAD);
	vehlist.Valuate(AIEngine.GetRoadType);
	vehlist.KeepValue(AIRoad.ROADTYPE_ROAD);
	// Exclude articulated vehicles
	vehlist.Valuate(AIEngine.IsArticulated);
	vehlist.KeepValue(0);
	// Remove zero cost cars
	vehlist.Valuate(AIEngine.GetPrice);
	vehlist.RemoveValue(0);
	// Filter by cargo
	vehlist.Valuate(AIEngine.CanRefitCargo, cargo);
	vehlist.KeepValue(1);
	// Valuate the vehicles using krinn's valuator
	vehlist.Valuate(cBuilder.GetEngineRawEfficiency, cargo, true);
	vehlist.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
	local veh = vehlist.Begin();
	if (vehlist.Count() == 0) veh = null;
	/* TODO: Choose another vehicle if we don't have enough money. */
	return veh;
}

/**
 * Build and start road vehicles or planes for the current route.
 * Builder class variables used: stasrc, stadst, homedepot
 * @param veh The EngineID of the desired vehicle.
 * @param number How many vehicles are needed.
 * @param ordervehicle The vehicle to share orders with. Null if there's no such vehicle.
 * @return True if at least one vehicle was built.
 */
function cBuilder::BuildAndStartVehicles(veh, number, ordervehicle)
{
	// These local variables are needed because this function may be called from the manager
	local srcplace = AIStation.GetLocation(stasrc);
	local dstplace = AIStation.GetLocation(stadst);
	local price = AIEngine.GetPrice(veh);
	// Check if we have enough money
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
		if (!Banker.SetMinimumBankBalance(price)) {
			AILog.Warning("I don't have enough money to build the road vehicles.");
			return false;
		}
	}
	// Build and refit the first vehicle
	local firstveh = AIVehicle.BuildVehicle(homedepot, veh);
	if (AIEngine.GetCargoType(veh) != crg) AIVehicle.RefitVehicle(firstveh, crg);
	if (ordervehicle == null) {
		// If there is no other vehicle to share orders with
		local firstorderflag = null;
		local secondorderflag = AIOrder.OF_NON_STOP_INTERMEDIATE;
		// Non-stop is not needed for planes
		if (AIEngine.GetVehicleType(veh) == AIVehicle.VT_AIR) firstorderflag = secondorderflag = AIOrder.OF_NONE;
		else {
			if (AICargo.GetTownEffect(crg) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(crg) == AICargo.TE_MAIL) {
				firstorderflag = AIOrder.OF_NON_STOP_INTERMEDIATE;
			} else {
				firstorderflag = AIOrder.OF_FULL_LOAD_ANY + AIOrder.OF_NON_STOP_INTERMEDIATE;
			}
		}
		AIOrder.AppendOrder(firstveh, srcplace, firstorderflag);
		AIOrder.AppendOrder(firstveh, dstplace, secondorderflag);
	} else {
		AIOrder.ShareOrders(firstveh, ordervehicle);
	}
	AIVehicle.StartStopVehicle(firstveh);
	AIGroup.MoveVehicle(group, firstveh);
	for (local idx = 2; idx <= number; idx++) {
		// Clone the first vehicle if we need more than one vehicle
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
			Banker.SetMinimumBankBalance(price);
		}
		local nextveh = AIVehicle.CloneVehicle(homedepot, firstveh, true);
		AIVehicle.StartStopVehicle(nextveh);
	}
	return true;
}

/**
 * Get a TileList around a town.
 * @param town_id The TownID of the given town.
 * @param width The width of the proposed station.
 * @param height The height of the proposed station.
 * @return A TileList containing tiles around a town.
 */
function cBuilder::GetTilesAroundTown(town_id, width, height)
{
	local tiles = AITileList();
	local townplace = AITown.GetLocation(town_id);
	local distedge = AIMap.DistanceFromEdge(townplace);
	local offset = null;
	local radius = 15;
	if (AITown.GetPopulation(town_id) > 5000) radius = 30;
	// A bit different is the town is near the edge of the map
	if (distedge < radius + 1) {
		offset = AIMap.GetTileIndex(distedge - 1, distedge - 1);
	} else {
		offset = AIMap.GetTileIndex(radius, radius);
	}
	tiles.AddRectangle(townplace - offset, townplace + offset);
	tiles.Valuate(EmotionAI.IsRectangleWithinTownInfluence, town_id, width, height);
	tiles.KeepValue(1);
	return tiles;
}

/**
 * Choose a subsidy if there are some available.
 * Builder class variables set: crg, src, dst, srcistown, dstistown, srcplace, dstplace
 * @return True if a subsidy was chosen.
 */
function cBuilder::CheckSubsidies()
{
	local subs = AISubsidyList();
	// Exclude subsidies which have already been awarded to someone
	subs.Valuate(AISubsidy.IsAwarded);
	subs.KeepValue(0);
	if (subs.Count() == 0) return false;
	subs.Valuate(AIBase.RandItem);
	foreach (sub, dummy in subs) {
		crg = AISubsidy.GetCargoType(sub);
		srcistown = (AISubsidy.GetSourceType(sub) == AISubsidy.SPT_TOWN);
		src = AISubsidy.GetSourceIndex(sub);
		if (root.serviced.HasItem(src * 256 + crg)) continue;
		// Some random chance not to choose this subsidy
		if (!AIBase.Chance(AIController.GetSetting("subsidy_chance"), 11) || (!root.use_roadvehs && !root.use_trains)) continue;
		if (srcistown) {
			srcplace = AITown.GetLocation(src);
		} else {
			srcplace = AIIndustry.GetLocation(src);
			// Jump this if there is already some heavy competition there
			if (AIIndustry.GetLastMonthTransported(src, crg) > AIController.GetSetting("max_transported")) continue;
		}
		dstistown = (AISubsidy.GetDestinationType(sub) == AISubsidy.SPT_TOWN);
		dst = AISubsidy.GetDestinationIndex(sub);
		if (dstistown) {
			dstplace = AITown.GetLocation(dst);
		} else {
			dstplace = AIIndustry.GetLocation(dst);
		}
		// Check the distance
		if (AIMap.DistanceManhattan(srcplace, dstplace) > 140) continue;
		if (AIMap.DistanceManhattan(srcplace, dstplace) < 20) continue;
		return true;
	}
	return false;
}

/**
 * Register the new route into the database.
 * @return The new route registered.
 */
function cBuilder::RegisterRoute()
{
	local route = {
		src = null
		dst = null
		stasrc = null
		stadst = null
		homedepot = null
		group = null
		crg = null
		vehtype = null
		railtype = null
		maxvehicles = null
	}
	route.src = src;
	route.dst = dst;
	route.stasrc = stasrc;
	route.stadst = stadst;
	route.homedepot = homedepot;
	route.group = group;
	route.crg = crg;
	route.vehtype = vehtype;
	route.railtype = AIRail.GetCurrentRailType();
	switch (vehtype) {
		case AIVehicle.VT_ROAD:
			route.maxvehicles = AIController.GetSetting("max_roadvehs");
			break;
		case AIVehicle.VT_RAIL:
			route.maxvehicles = double ? 2 : 1;
			break;
		case AIVehicle.VT_AIR:
			route.maxvehicles = 0;
			break;
	}
	root.routes.push(route);
	root.serviced.AddItem(src * 256 + crg, 0);
	root.groups.AddItem(group, root.routes.len() - 1);
	root.lastroute = AIDate.GetCurrentDate();
	return route;
}

/**
 * Remove a road station.
 * @param sta The StationID of the station.
 */
function cBuilder::DeleteRoadStation(sta)
{
	if (sta == null || !AIStation.IsValidStation(sta)) return;
	// Don't remove the station if there are vehicles still using it
	local vehiclelist = AIVehicleList_Station(sta);
	if (vehiclelist.Count() > 0) {
		AILog.Error(AIStation.GetName(sta) + " cannot be removed, it's still in use!");
		return;
	}
	local place = AIStation.GetLocation(sta);
	local front = AIRoad.GetRoadStationFrontTile(place);
	local offx = AIMap.GetTileX(front) - AIMap.GetTileX(place);
	local offy = AIMap.GetTileY(front) - AIMap.GetTileY(place);
	local dir1 = AIMap.GetTileIndex(offx, offy);
	local placeholder = offx;
	offx = -offy;
	offy = placeholder;
	local dir2 = AIMap.GetTileIndex(offx, offy);
	local depot = place + dir2;
	local front2 = AIRoad.GetRoadDepotFrontTile(depot);
	AITile.DemolishTile(place);
	AITile.DemolishTile(depot);
	if (!AIRoad.AreRoadTilesConnected(front, front + dir1) && !AIRoad.AreRoadTilesConnected(front, front - dir2) && !AIRoad.AreRoadTilesConnected(front2, front2 + dir1) && !AIRoad.AreRoadTilesConnected(front2, front2 + dir2)) {
		AITile.DemolishTile(front);
		AITile.DemolishTile(front2);
	}
}

/**
 * Register a new hole in the route to be later corrected.
 */
function cBuilder::ReportHole(start, end, waserror)
{
	if (!waserror) {
		holestart = start;
	}
	holeend = end;
}

/**
 * Try to connect the holes in the route.
 * Builder class variables used: holes
 * @return True if the action succeeded.
 */
function cBuilder::RepairRoute()
{
	if (recursiondepth > 10) {
		AILog.Error("It looks like I got into an infinite loop.");
		return false;
	}
	local holelist = holes;
	holes = [];
	foreach (idx, hole in holelist) {
		if (!cBuilder.BuildRoad(hole[0], hole[1])) return false;
	}
	return true;
}

/**
 * Decide whether to use road or rail.
 * @return The vehicle type to use, null if there are none available.
 */
function cBuilder::RoadOrRail()
{
	local vehicles = root.use_roadvehs + root.use_trains * 2;
	switch (vehicles) {
		case 0: // neither road or rail
			return null;
			break;
		case 1: // road
			return AIVehicle.VT_ROAD;
			break;
		case 2: // rail
			if (AICargo.GetTownEffect(crg) == AICargo.TE_MAIL) return null;
			return AIVehicle.VT_RAIL;
			break;
		case 3: // both road and rail
			// Road if there is no suitable train engine
			local wagon = cBuilder.ChooseWagon(crg, root.engineblacklist);
			if (wagon == null) return AIVehicle.VT_ROAD;
			local trainengine = cBuilder.ChooseTrainEngine(crg, 130, wagon, 5, root.engineblacklist);
			if (trainengine == null) return AIVehicle.VT_ROAD;
			else {
				// Road if we cannot afford rail
				local price = Banker.InflatedValue(40000) + AIEngine.GetPrice(trainengine);
				if (Banker.GetMaxBankBalance() < price) return AIVehicle.VT_ROAD;
			}
			// Road if the cargo is mail
			if (AICargo.GetTownEffect(crg) == AICargo.TE_MAIL) return AIVehicle.VT_ROAD;
			local dist = AIMap.DistanceManhattan(srcplace, dstplace);
			// Rail if the route is too long
			if (dist > 110) return AIVehicle.VT_RAIL;
			// Road if the route is too short
			if (dist < 30) return AIVehicle.VT_ROAD;
			// Random choice if it is not decided yet
			if (AIBase.Chance(1, 2)) return AIVehicle.VT_ROAD;
			else return AIVehicle.VT_RAIL;
			break;
	}
}

/**
 * Get the percentage of transported cargo from a given industry.
 * @param ind The IndustryID of the industry.
 * @param cargo The cargo to be checked.
 * @return The percentage transported, ranging from 0 to 100.
 */
function cBuilder::GetLastMonthTransportedPercentage(ind, cargo)
{
	return (100 * AIIndustry.GetLastMonthTransported(ind, cargo) / AIIndustry.GetLastMonthProduction(ind, cargo));
}

/**
 * Upgrade the registered road bridges.
 */
function cBuilder::UpgradeRoadBridges()
{
	AILog.Info("Upgrading road bridges (" + root.roadbridges.Count() + " bridges registered)");
	foreach (tile, dummy in root.roadbridges) {
		// Stop if we cannot afford it
		if (!Banker.SetMinimumBankBalance(Banker.InflatedValue(50000))) return;
		if (!AITile.HasTransportType(tile, AITile.TRANSPORT_ROAD) || !AIBridge.IsBridgeTile(tile)) continue;
		local otherend = AIBridge.GetOtherBridgeEnd(tile);
		local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(tile, otherend) + 1);
		bridgelist.Valuate(AIBridge.GetMaxSpeed);
		if (AIBridge.GetBridgeID(tile) == bridgelist.Begin()) continue;
		AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgelist.Begin(), tile, otherend);
	}
}

/**
 * Set the name of a vehicle group.
 * @param group The GroupID of the group.
 * @param crg The cargo transported.
 * @param stasrc The source station.
 */
function cBuilder::SetGroupName(group, crg, stasrc)
{
	local groupname = AICargo.GetCargoLabel(crg) + " - " + AIStation.GetName(stasrc);
	if (groupname.len() > 30) groupname = groupname.slice(0, 30);
	if (!AIGroup.SetName(group, groupname)) {
		// Shorten the name if it is too long (Unicode character problems)
		while (AIError.GetLastError() == AIError.ERR_PRECONDITION_STRING_TOO_LONG) {
			groupname = groupname.slice(0, groupname.len() - 1);
			AIGroup.SetName(group, groupname);
		}
	}
}

// Taken from DictatorAI
/**
 * Valuate a road vehicle.
 * @param engine The road vehicle to be valuated.
 * @param cargoID The cargo to be transported.
 * @return A numerical value representing the fitness of the engine, the lower the better.
 */
function cBuilder::GetEngineEfficiency(engine, cargoID)
{
	local price = AIEngine.GetPrice(engine);
	local capacity = AIEngine.GetCapacity(engine);
	local lifetime = AIEngine.GetMaxAge(engine);
	local runningcost = AIEngine.GetRunningCost(engine);
	local speed = AIEngine.GetMaxSpeed(engine);
	if (capacity == 0)	return 9999999;
	if (price <= 0)	return 9999999;
	local eff = (100000+ (price+(lifetime*runningcost))) / ((capacity*0.9)+speed).tointeger();
	return eff;
}

// Taken from DictatorAI
/**
 * Valuate a road vehicle based on raw capacity/speed ratio.
 * @param engine The road vehicle to be valuated.
 * @param cargoID The cargo to be trasported.
 * @param fast If true, try to get the fastest engine even if the capacity is a bit lower.
 * @return A numerical value representing the fitness of the engine, the lower the better.
 */
function cBuilder::GetEngineRawEfficiency(engine, cargoID, fast)
{
	local price = AIEngine.GetPrice(engine);
	local capacity = AIEngine.GetCapacity(engine);
	local speed = AIEngine.GetMaxSpeed(engine);
	local lifetime = AIEngine.GetMaxAge(engine);
	local runningcost = AIEngine.GetRunningCost(engine);
	if (capacity <= 0)	return 9999999;
	if (price <= 0)	return 9999999;
	local eff = 0;
	if (fast)	eff = 1000000 / ((capacity*0.9)+speed).tointeger();
		else	eff = 1000000-(capacity * speed);
	return eff;
}
