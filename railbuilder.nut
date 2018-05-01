/**
 * Build a single (one-lane) rail station at a town or an industry.
 * Builder class variables used: crg, src, dst, srcplace, dstplace, srcistown, dstistown,
 *   statile, stafront, depfront, frontfront, statop, stationdir
 * Builder class variables set: stasrc, stadst, homedepot
 * @param is_source True if we are building the source station.
 * @param platform_length The length of the new station's platform. (2 or 3)
 * @return True if the construction succeeded.
 */
function cBuilder::BuildSingleRailStation(is_source, platform_length)
{
	local dir, tilelist, otherplace, isneartown = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	// Determine the direction of the station, and get tile lists
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
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepValue(1);
	// Sort the tile list
	if (isneartown) {
		tilelist.Valuate(AITile.GetCargoAcceptance, crg, 1, 1, rad);
		tilelist.KeepAboveValue(10);
	} else {
		tilelist.Valuate(AIMap.DistanceManhattan, otherplace);
	}
	tilelist.Sort(AIList.SORT_BY_VALUE, !isneartown);
	local success = false;
	foreach (tile, dummy in tilelist) {
		// Find a place where the station can bee built
		if (cBuilder.CanBuildSingleRailStation(tile, dir, platform_length)) {
			success = true;
			break;
		} else continue;
	}
	if (!success) return false;
	// Build the station itself
	if (AIController.GetSetting("newgrf_stations") == 1 && !srcistown && !dstistown) {
		// Build a NewGRF rail station
		success = success && AIRail.BuildNewGRFRailStation(statop, stationdir, 1, platform_length, AIStation.STATION_NEW,
							crg, AIIndustry.GetIndustryType(src), AIIndustry.GetIndustryType(dst), AIMap.DistanceManhattan(srcplace, dstplace), is_source);
	} else {
		// Build a standard railway station
		success = success && AIRail.BuildRailStation(statop, stationdir, 1, platform_length, AIStation.STATION_NEW);
	}
	if (!success) {
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
	}
	// Build the rails and the depot
	success = success && AIRail.BuildRail(statile, depfront, stafront);
	success = success && AIRail.BuildRail(statile, depfront, deptile);
	success = success && AIRail.BuildRail(deptile, depfront, stafront);
	success = success && AIRail.BuildRail(depfront, stafront, frontfront);
	success = success && AIRail.BuildRailDepot(deptile, depfront);
	if (AIController.GetSetting("signaltype") == 3) {
		// Build an extra path signal according to the setting
		success = success && AIRail.BuildSignal(stafront, depfront, AIRail.SIGNALTYPE_PBS);
	}
	if (!success) {
		// If we couldn't build the station for any reason
		AILog.Warning("Station construction was interrupted.")
		cBuilder.RemoveRailLine(statile);
		return false;
	}
	// Register the station
	if (is_source) {
		stasrc = AIStation.GetStationID(statile);
		homedepot = deptile;
	} else {
		stadst = AIStation.GetStationID(statile);
	}
	return true;

}

/**
 * Check whether a single rail station can be built at the given position.
 * Builder class variables set: statop, stabotton, statile, stafront, depfront, frontfront
 * @param tile The tile to be checked.
 * @param direction The direction of the proposed station.
 * @param platform_length The length of the proposed station's platform. (2 or 3)
 * @return True if a single rail station can be built at the given position.
 */
function cBuilder::CanBuildSingleRailStation(tile, direction, platform_length)
{
	if (!AITile.IsBuildable(tile)) return false;
	local vector, rvector = null;
	// Determine some direction vectors
	switch (direction) {
		case DIR_NW:
			vector = AIMap.GetTileIndex(0, -1);
			rvector = AIMap.GetTileIndex(-1, 0);
			stationdir = AIRail.RAILTRACK_NW_SE;
			break;
		case DIR_NE:
			vector = AIMap.GetTileIndex(-1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SW:
			vector = AIMap.GetTileIndex(1, 0);
			rvector = AIMap.GetTileIndex(0, -1);
			stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SE:
			vector = AIMap.GetTileIndex(0, 1);
			rvector = AIMap.GetTileIndex(1, 0);
			stationdir = AIRail.RAILTRACK_NW_SE;
			break;
	}
	// Determine the top and the bottom tile of the station, used for building the station itself
	if (direction == DIR_NW || direction == DIR_NE) {
		stabottom = tile;
		statop = tile + vector;
		if (platform_length == 3) statop = statop + vector;
		statile = statop;
	} else {
		statop = tile;
		stabottom = tile + vector;
		if (platform_length == 3) stabottom = stabottom + vector;
		statile = stabottom;
	}
	// Set the other positions
	depfront = statile + vector;
	deptile = depfront + rvector;
	stafront = depfront + vector;
	frontfront = stafront + vector;
	// Check if the station can be built
	local test = AITestMode();
	if (!AIRail.BuildRailStation(statop, stationdir, 1, platform_length, AIStation.STATION_NEW)) return false;
	if (!AIRail.BuildRailDepot(deptile, depfront)) return false;
	if (!AITile.IsBuildable(depfront)) return false;
	if (!AIRail.BuildRail(statile, depfront, stafront)) return false;
	if (!AIRail.BuildRail(statile, depfront, deptile)) return false;
	if (!AIRail.BuildRail(deptile, depfront, stafront)) return false;
	if (!AITile.IsBuildable(stafront)) return false;
	if (!AIRail.BuildRail(depfront, stafront, frontfront)) return false;
	if (!AITile.IsBuildable(frontfront)) return false;
	if (AITile.IsCoastTile(frontfront)) return false;
	// Check if there is a station just at the back of the proposed station
	if (AIRail.IsRailStationTile(statile - platform_length * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(statile - platform_length * vector)) && AIRail.GetRailStationDirection(statile - platform_length * vector) == stationdir)
			return false;
	}
	test = null;
	return true;
}

/**
 * Build a rail line between two given points.
 * @param head1 The starting points of the rail line.
 * @param head2 The ending points of the rail line.
 * @return True if the construction succeeded.
 */
function cBuilder::BuildRail(head1, head2)
{
	local pathfinder = MyRailPF();
	// Set some pathfinder penalties
	pathfinder._cost_level_crossing = 900;
	pathfinder._cost_slope = 200;
	pathfinder._cost_coast = 100;
	pathfinder._cost_bridge_per_tile = 75;
	pathfinder._cost_tunnel_per_tile = 50;
	pathfinder._max_bridge_length = 20;
	pathfinder._max_tunnel_length = 20;
	pathfinder.InitializePath([head1], [head2]);
	AILog.Info("Pathfinding...");
	local counter = 0;
	local path = false;
	// Try to find a path
	while (path == false && counter < 150) {
		path = pathfinder.FindPath(150);
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
	local prevprev = null;
	local pp1, pp2, pp3 = null;
	while (path != null) {
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				// If we are building a tunnel or a bridge
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
					// If we are building a tunnel
					if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev)) {
						AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							AILog.Warning("That tunnel would be too expensive. Construction aborted.");
							return false;
						}
						// Try again if we have the money
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false;
						else return true;
					}
				} else {
					// If we are building a bridge
					local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					bridgelist.Valuate(AIBridge.GetMaxSpeed);
					if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), prev, path.GetTile())) {
						AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
						if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
							AILog.Warning("That bridge would be too expensive. Construction aborted.");
							return false;
						}
						// Try again if we have the money
						if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false;
						else return true;
					} else {
						// Register the new bridge
						root.railbridges.AddTile(path.GetTile());
					}
				}
				// Step these variables after a tunnel or bridge was built
				pp3 = pp2;
				pp2 = pp1;
				pp1 = prevprev;
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			} else {
				// If we are building a piece of rail track
				if (!AIRail.BuildRail(prevprev, prev, path.GetTile())) {
					AILog.Info("An error occured while I was building the rail: " + AIError.GetLastErrorString());
					if (!cBuilder.RetryRail(prevprev, pp1, pp2, pp3, head1)) return false;
					else return true;
				}
			}
		}
		// Step these variables at the start of the construction
		if (path != null) {
			pp3 = pp2;
			pp2 = pp1;
			pp1 = prevprev;
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent();
		}
		// Check if we still have the money
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < (AICompany.GetLoanInterval() + Banker.GetMinimumCashNeeded())) {
			if (!Banker.GetMoney(AICompany.GetLoanInterval())) {
				AILog.Warning("I don't have enough money to complete the route.");
				return false;
			}
		}
	}
	return true;
}

/**
 * Choose a rail wagon for the given cargo.
 * @param cargo The cargo which will be transported by te wagon.
 * @return The EngineID of the chosen wagon, null if no suitable wagon was found.
 */
function cBuilder::ChooseWagon(cargo, blacklist)
{
	local wagonlist = AIEngineList(AIVehicle.VT_RAIL);
	wagonlist.Valuate(AIEngine.CanRunOnRail, AIRail.GetCurrentRailType());
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsWagon);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.CanRefitCargo, cargo);
	wagonlist.KeepValue(1);
	wagonlist.Valuate(AIEngine.IsArticulated);
	// Only remove articulated wagons if there are non-articulated ones left
	local only_articulated = true;
	foreach (wagon, articulated in wagonlist) {
		if (articulated == 0) {
			only_articulated = false;
			break;
		}
	}
	if (!only_articulated) {
		wagonlist.KeepValue(0);
	}
	if (blacklist != null) {
		wagonlist.Valuate(EmotionAI.ListContainsValuator, blacklist);
		wagonlist.KeepValue(0);
	}
	wagonlist.Valuate(AIEngine.GetCapacity);
	if (wagonlist.Count() == 0) return null;
	return wagonlist.Begin();
}

/**
 * DEPRECATED
 * Choose a train locomotive.
 * @return The EngineID of the chosen locomotive, null if no suitable locomotive was found.
 */
function cBuilder::ChooseTrainEngine()
{
	local enginelist = AIEngineList(AIVehicle.VT_RAIL);
	enginelist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
	enginelist.KeepValue(1);
	enginelist.Valuate(AIEngine.IsWagon);
	enginelist.KeepValue(0);
	enginelist.Valuate(AIEngine.GetMaxSpeed);
	if (enginelist.Count() == 0) return null;
	return enginelist.Begin();
}

/**
 * Build and start trains for the current route.
 * @param number The number of trains to be built.
 * @param length The number of wagons to be attached to the train.
 * @param engine The EngineID of the locomotive.
 * @param wagon The EngineID of the wagons.
 * @param ordervehicle The vehicle to share orders with. Null, if there is no such vehicle.
 * @return True if at least one train was built.
 */
function cBuilder::BuildAndStartTrains(number, length, engine, wagon, ordervehicle)
{
	local srcplace = AIStation.GetLocation(stasrc);
	local dstplace = AIStation.GetLocation(stadst);
	// Check if we can afford building a train
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(engine)) {
		if (!Banker.SetMinimumBankBalance(AIEngine.GetPrice(engine))) {
			AILog.Warning("I don't have enough money to build the train.");
			return false;
		}
	}
	// Build and refit the train engine if needed
	local trainengine = AIVehicle.BuildVehicle(homedepot, engine);
	if (!AIVehicle.IsValidVehicle(trainengine)) {
		// safety, suggestion by krinn
		AILog.Error("The train engine did not get built: " + AIError.GetLastErrorString());
		return false;
	}
	AIVehicle.RefitVehicle(trainengine, crg);

	// Check if we have the money to build at least one wagon
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
		if (!Banker.SetMinimumBankBalance(AIEngine.GetPrice(wagon))) {
			AILog.Warning("I don't have enough money to build the train.");
			AIVehicle.SellVehicle(trainengine);
			return false;
		}
	}
	local firstwagon = AIVehicle.BuildVehicle(homedepot, wagon);
	// Blacklist the wagon if it is too long
	if (AIVehicle.GetLength(firstwagon) > 8) {
		root.engineblacklist.AddItem(wagon, 0);
		AILog.Warning(AIEngine.GetName(wagon) + " was blacklisted for being too long.");
		AIVehicle.SellVehicle(trainengine);
		AIVehicle.SellVehicle(firstwagon);
		return false;
	}
	// Try whether the engine is compatibile with the wagon
	{
		local testmode = AITestMode();
		if (!AIVehicle.MoveWagonChain(firstwagon, 0, trainengine, 0)) {
			root.engineblacklist.AddItem(engine, 0);
			AILog.Warning(AIEngine.GetName(engine) + " was blacklisted for not being compatibile with " + AIEngine.GetName(wagon) + ".");
			local execmode = AIExecMode();
			AIVehicle.SellVehicle(trainengine);
			AIVehicle.SellVehicle(firstwagon);
			return false;
		}
	}
	// Build a mail wagon
	local mailwagontype = null, mailwagon = null;
	if ((length > 3) && (AICargo.GetTownEffect(crg) == AICargo.TE_PASSENGERS)) {
		// Choose a wagon for mail
		local mailcargo = EmotionAI.GetMailCargo();
		mailwagontype = cBuilder.ChooseWagon(mailcargo, root.engineblacklist);
		if (mailwagontype == null) mailwagontype = wagon;
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(mailwagontype)) {
			Banker.SetMinimumBankBalance(AIEngine.GetPrice(mailwagontype));
		}
		mailwagon = AIVehicle.BuildVehicle(homedepot, mailwagontype);
		if (mailwagon != null) {
			// Try to refit the mail wagon if needed
			local mailwagoncargo = AIEngine.GetCargoType(AIVehicle.GetEngineType(mailwagon));
			if (AICargo.GetTownEffect(mailwagoncargo) != AICargo.TE_MAIL) {
				if (mailwagontype == wagon) {
					// Some workaround if the mail wagon type is the same as the wagon type
					MailWagonWorkaround(mailwagon, firstwagon, trainengine, mailcargo);
				} else {
					if (!AIVehicle.RefitVehicle(mailwagon, mailcargo)) {
						// If no mail wagon was found, and the other wagons needed to be refitted, refit the "mail wagon" as well
						if (mailwagoncargo != crg) AIVehicle.RefitVehicle(mailwagon, crg);
					}
				}
			}
		}
	}
	local wagon_length = AIVehicle.GetLength(firstwagon);
	local mailwagon_length = 0;
	if (mailwagon != null) {
		if (mailwagontype == wagon) {
			wagon_length /= 2;
			mailwagon_length = wagon_length;
		} else {
			mailwagon_length = AIVehicle.GetLength(mailwagon);
		}
	}
	local cur_wagons = 1;
	local platform_length = length / 2 + 1;
	while (AIVehicle.GetLength(trainengine) + (cur_wagons + 1) * wagon_length + mailwagon_length <= platform_length * 16) {
		//AILog.Info("Current length: " + (AIVehicle.GetLength(trainengine) + (cur_wagons + 1) * wagon_length + mailwagon_length));
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
			Banker.SetMinimumBankBalance(AIEngine.GetPrice(wagon));
		}
		if (!AIVehicle.BuildVehicle(homedepot, wagon)) break;
		cur_wagons++;
	}
	local price = AIEngine.GetPrice(engine) + cur_wagons * AIEngine.GetPrice(wagon);
	// Refit the wagons if needed
	if (AIEngine.GetCargoType(wagon) != crg) AIVehicle.RefitVehicle(firstwagon, crg);
	// Attach the wagons to the engine
	if (mailwagon != null) {
		price += AIVehicle.GetCurrentValue(mailwagon);
		if (wagon != mailwagontype && !AIVehicle.MoveWagonChain(mailwagon, 0, trainengine, 0) ||
		    wagon == mailwagontype && !AIVehicle.MoveWagon(firstwagon, 1, trainengine, 0)) {
			root.engineblacklist.AddItem(engine, 0);
			AILog.Warning(AIEngine.GetName(engine) + " was blacklisted for not being compatibile with " + AIEngine.GetName(mailwagontype) + ".");
			AIVehicle.SellVehicle(trainengine);
			AIVehicle.SellWagonChain(firstwagon, 0);
			AIVehicle.SellVehicle(mailwagon);
			return false;
		}
	}
	if (!AIVehicle.MoveWagonChain(firstwagon, 0, trainengine, 0)) {
		AILog.Error("Could not attach the wagons.");
		AIVehicle.SellWagonChain(trainengine, 0);
		AIVehicle.SellWagonChain(firstwagon, 0);
	}
	if (ordervehicle == null) {
		// Set the train's orders
		local firstorderflag = null;
		if (AICargo.GetTownEffect(crg) == AICargo.TE_PASSENGERS || AICargo.GetTownEffect(crg) == AICargo.TE_MAIL) {
			// Do not full load a passenger train
			firstorderflag = AIOrder.OF_NON_STOP_INTERMEDIATE;
		} else {
			firstorderflag = AIOrder.OF_FULL_LOAD_ANY + AIOrder.OF_NON_STOP_INTERMEDIATE;
		}
		AIOrder.AppendOrder(trainengine, srcplace, firstorderflag);
		AIOrder.AppendOrder(trainengine, dstplace, AIOrder.OF_NON_STOP_INTERMEDIATE);
	} else {
		AIOrder.ShareOrders(trainengine, ordervehicle);
	}
	AIVehicle.StartStopVehicle(trainengine);
	AIGroup.MoveVehicle(group, trainengine);
	// Build the second train if needed
	if (number > 1) {
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < price) {
			Banker.SetMinimumBankBalance(price);
		}
		local nexttrain = AIVehicle.CloneVehicle(homedepot, trainengine, true);
		AIVehicle.StartStopVehicle(nexttrain);
	}
	return true;
}

/**
 * Delete a rail station together with the rail line.
 * Builder class variables used and set:
 * @param sta The StationID of the station to be deleted.
 */
function cBuilder::DeleteRailStation(sta)
{
	if (sta == null || !AIStation.IsValidStation(sta)) return;
	// Don't delete the station if there are trains using it
	local vehiclelist = AIVehicleList_Station(sta);
	if (vehiclelist.Count() > 0) {
		AILog.Error(AIStation.GetName(sta) + " cannot be removed, it's still in use!");
		return;
	}
	local place = AIStation.GetLocation(sta);
	if (!AIRail.IsRailStationTile(place)) return;
	// Get the positions of the station parts
	local dir = AIRail.GetRailStationDirection(place);
	local vector, rvector = null;
	local twolane = false;
	local depfront, stafront, depot, frontfront = null;
	if (dir == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
	}
	// Determine if it is a single or a double rail station
	if (AIRail.IsRailStationTile(place + rvector)) {
		local otherstation = AIStation.GetStationID(place + rvector);
		if (AIStation.IsValidStation(otherstation) && otherstation == sta) twolane = true;
	}
	if (twolane) {
		// Deleting a double rail station
		// Get the front tile of the station
		if (cBuilder.AreConnectedRailTiles(place, place - vector)) {
			// The station is pointing upwards
			stafront = place - vector;
		} else {
			// The station is pointing downwards
			stafront = place;
			while (AIRail.IsRailStationTile(stafront)) {
				stafront += vector;
			}
		}
		AITile.DemolishTile(place);
		// Remove the rail line, including the station parts, and the other station if it is connected
		cBuilder.RemoveRailLine(stafront);
	} else {
		// Deleting a single rail station
		if (cBuilder.AreConnectedRailTiles(place, place - vector)) {
			// The station is pointing upwards
			depfront = place - vector;
			if (dir == AIRail.RAILTRACK_NE_SW) {
				vector = AIMap.GetTileIndex(-1, 0);
			} else {
				vector = AIMap.GetTileIndex(0, -1);
				rvector = AIMap.GetTileIndex(-1, 0);
			}
		} else {
			// The station is pointing downwards
			depfront = place;
			while (AIRail.IsRailStationTile(depfront)) {
				depfront += vector;
			}
			if (dir == AIRail.RAILTRACK_NE_SW) rvector = AIMap.GetTileIndex(0, -1);
		}
		// Remove the station parts
		stafront = depfront + vector;
		depot = depfront + rvector;
		frontfront = stafront + vector;
		AITile.DemolishTile(place);
		AITile.DemolishTile(depfront);
		AITile.DemolishTile(depot);
		// Remove the rail line, including the other station if it is connected
		cBuilder.RemoveRailLine(stafront);
		AIRail.RemoveRail(depfront, stafront, frontfront)
	}
}

/**
 * Determine whether two tiles are connected with rail directly.
 * @param tilefrom The first tile to check.
 * @param tileto The second tile to check.
 * @return True if the two tiles are connected.
 */
function cBuilder::AreConnectedRailTiles(tilefrom, tileto)
{
	// Check some preconditions
	if (!AITile.HasTransportType(tilefrom, AITile.TRANSPORT_RAIL)) return false;
	if (!AITile.HasTransportType(tileto, AITile.TRANSPORT_RAIL)) return false;
	if (!AICompany.IsMine(AITile.GetOwner(tilefrom))) return false;
	if (!AICompany.IsMine(AITile.GetOwner(tileto))) return false;
	if (AIRail.GetRailType(tilefrom) != AIRail.GetRailType(tileto)) return false;
	// Determine the dircetion
	local dirfrom = cBuilder.GetDirection(tilefrom, tileto);
	local dirto = null;
	// Some magic bitmasks
	local acceptable = [22, 42, 37, 25];
	// Determine the direction pointing backwards
	if (dirfrom == 0 || dirfrom == 2) dirto = dirfrom + 1;
	else dirto = dirfrom - 1;
	if (AITunnel.IsTunnelTile(tilefrom)) {
		// Check a tunnel
		local otherend = AITunnel.GetOtherTunnelEnd(tilefrom);
		if (cBuilder.GetDirection(otherend, tilefrom) != dirfrom) return false;
	} else {
		if (AIBridge.IsBridgeTile(tilefrom)) {
			// Check a bridge
			local otherend = AIBridge.GetOtherBridgeEnd(tilefrom);
			if (cBuilder.GetDirection(otherend, tilefrom) != dirfrom) return false;
		} else {
			// Check rail tracks
			local tracks = AIRail.GetRailTracks(tilefrom);
			if ((tracks & acceptable[dirfrom]) == 0) return false;
		}
	}
	// Do this check the other way around as well
	if (AITunnel.IsTunnelTile(tileto)) {
		local otherend = AITunnel.GetOtherTunnelEnd(tileto);
		if (cBuilder.GetDirection(otherend, tileto) != dirto) return false;
	} else {
		if (AIBridge.IsBridgeTile(tileto)) {
			local otherend = AIBridge.GetOtherBridgeEnd(tileto);
			if (cBuilder.GetDirection(otherend, tileto) != dirto) return false;
		} else {
			local tracks = AIRail.GetRailTracks(tileto);
			if ((tracks & acceptable[dirto]) == 0) return false;
		}
	}
	return true;
}

/**
 * Remove a continuous segment of rail track starting from a single point. This includes depots
 * and stations, in all directions and braches. Basically the function deletes all rail tiles
 * which are reachable by a train from the starting point. This function is not static.
 * @param start_tile The starting point of the rail.
 */
function cBuilder::RemoveRailLine(start_tile)
{
	if (start_tile == null) return;
	// Rail line removal works without a valid start tile if the root object's removelist is not empty, needed for save/load compatibility
	if (!AIMap.IsValidTile(start_tile) && root.removelist.len() == 0) return;
	// Starting date is needed to avoid infinite loops
	local startingdate = AIDate.GetCurrentDate();
	root.buildingstage = root.BS_REMOVING;
	// Get the four directions
	local all_vectors = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
	if (AIMap.IsValidTile(start_tile)) root.removelist = [start_tile];
	local tile = null;
	while (root.removelist.len() > 0) {
		// Avoid infinite loops
		if (AIDate.GetCurrentDate() - startingdate > 120) {
			AILog.Error("It looks like I got into an infinite loop.");
			root.removelist = [];
			return;
		}
		tile = root.removelist.pop();
		// Step further if it is a tunnel or a bridge, because it takes two tiles
		if (AITunnel.IsTunnelTile(tile)) tile = AITunnel.GetOtherTunnelEnd(tile);
		if (AIBridge.IsBridgeTile(tile)) {
			root.railbridges.RemoveTile(tile);
			tile = AIBridge.GetOtherBridgeEnd(tile);
			root.railbridges.RemoveTile(tile);
		}
		if (!AIRail.IsRailDepotTile(tile)) {
			// Get the connecting rail tiles
			foreach (idx, vector in all_vectors) {
				if (cBuilder.AreConnectedRailTiles(tile, tile + vector)) {
					root.removelist.push(tile + vector);
				}
			}
		}
		// Removing rail from a level crossing cannot be done with DemolishTile
		if (AIRail.IsLevelCrossingTile(tile)) {
			local track = AIRail.GetRailTracks(tile);
			if (!AIRail.RemoveRailTrack(tile, track)) {
				// Try again a few times if a road vehicle was in the way
				local counter = 0;
				AIController.Sleep(75);
				while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
					counter++;
					AIController.Sleep(75);
				}
			}
		} else {
			AITile.DemolishTile(tile);
		}
	}
	root.buildingstage = root.BS_NOTHING;
}

/**
 * Removes a piece of rail from a level crossing. This function is obsolete,
 * it was used while AIRail.RemoveRailTrack didn't work due to some bug in the API.
 * @param tile The level crossing tile from which the piece of rail is removed.
 * @return True if the removal succeeded.
 */
function cBuilder::RemoveRailFromLevelCrossing(tile)
{
	local track = AIRail.GetRailTracks(tile);
	local end1, end2 = null;
	if (track == AIRail.RAILTRACK_NE_SW) {
		end1 = tile + AIMap.GetTileIndex(-1, 0);
		end2 = tile + AIMap.GetTileIndex(1, 0);
	} else {
		end1 = tile + AIMap.GetTileIndex(0, -1);
		end2 = tile + AIMap.GetTileIndex(0, 1);
	}
	if (AIRail.RemoveRail(end1, tile, end2)) return true;
	else return false;
}

/**
 * Retry building a rail track after it was interrupted. The last three pieces of track
 * are removed, and then pathfinding is restarted from the other end.
 * @param prevprev The last successfully built piece of track.
 * @param pp1 The piece of track before prevprev.
 * @param pp2 The piece of track before pp1.
 * @param pp3 The piece of track before pp2. It is not removed.
 * @param head1 The other end to be connected.
 * @return True if the construction succeeded.
 */
function cBuilder::RetryRail(prevprev, pp1, pp2, pp3, head1)
{
	// Avoid infinite loops
	recursiondepth++;
	if (recursiondepth > 10) {
		AILog.Error("It looks like I got into an infinite loop.");
		return false;
	}
	// pp1 is null if no track was built at all
	if (pp1 == null) return false;
	local head2 = [null, null];
	local tiles = [pp3, pp2, pp1, prevprev];
	// Set the rail end correctly
	foreach (idx, tile in tiles) {
		if (tile != null) {
			head2[1] = tile;
			break;
		}
	}
	tiles = [prevprev, pp1, pp2, pp3]
	foreach (idx, tile in tiles) {
		if (tile == head2[1]) {
			// Do not remove it if we reach the station
			break;
		} else {
			// Removing rail from a level crossing cannot be done with DemolishTile
			if (AIRail.IsLevelCrossingTile(tile)) {
				local track = AIRail.GetRailTracks(tile);
				if (!AIRail.RemoveRailTrack(tile, track)) {
					// Try again a few times if a road vehicle was in the way
					local counter = 0;
					AIController.Sleep(75);
					while (!AIRail.RemoveRailTrack(tile, track) && counter < 3) {
						counter++;
						AIController.Sleep(75);
					}
				}
			} else {
				AITile.DemolishTile(tile);
			}
			head2[0] = tile;
		}
	}
	// Restart pathfinding from the other end
	if (cBuilder.BuildRail(head2, head1)) return true;
	else return false;
}

/**
 * Upgrade a segment of normal rail to electrified rail from a given starting point.
 * Tiles which are reachable by a train from a given starting point are electrified,
 * including stations and depots. This function is not static.
 * @param start_tile The starting point from which rails are electrified.
 */
function cBuilder::ElectrifyRail(start_tile)
{
	// The starting date is needed to avoid infinite loops
	local startingdate = AIDate.GetCurrentDate();
	root.buildingstage = root.BS_ELECTRIFYING;
	// Get all four directions
	local all_vectors = [AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(-1, 0), AIMap.GetTileIndex(0, -1)];
	// If start_tile is not a valid tile we're probably loading a game
	if (AIMap.IsValidTile(start_tile)) root.removelist = [start_tile];
	local tile = null;
	while (root.removelist.len() > 0) {
		// Avoid infinite loops
		if (AIDate.GetCurrentDate() - startingdate > 120) {
			AILog.Error("It looks like I got into an infinite loop.");
			root.removelist = [];
			return;
		}
		tile = root.removelist.pop();
		// Step further if it is a tunnel or a bridge
		if (AITunnel.IsTunnelTile(tile)) tile = AITunnel.GetOtherTunnelEnd(tile);
		if (AIBridge.IsBridgeTile(tile)) tile = AIBridge.GetOtherBridgeEnd(tile);
		if (!AIRail.IsRailDepotTile(tile) && (AIRail.GetRailType(tile) != AIRail.GetCurrentRailType())) {
			// Check the neighboring rail tiles, only tiles from the old railtype are considered
			foreach (idx, vector in all_vectors) {
				if (cBuilder.AreConnectedRailTiles(tile, tile + vector)) {
					root.removelist.push(tile + vector);
				}
			}
		}
		AIRail.ConvertRailType(tile, tile, AIRail.GetCurrentRailType());
	}
	root.buildingstage = root.BS_NOTHING;
}

/**
 * Build a double (two-lane) rail station at a town or an industry.
 * Builder class variables used: crg, src, dst, srcplace, dstplace, srcistown, dstistown,
 *   statile, deptile, stafront, depfront, frontfront, front1, front2, lane2, morefront
 * Builder class variables set: stasrc, stadst, homedepot
 * @param is_source True if we are building the source station.
 * @return True if the construction succeeded.
 */
function cBuilder::BuildDoubleRailStation(is_source)
{
	local dir, tilelist, otherplace, isneartown = null;
	local rad = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	// Get the tile list
	if (is_source) {
		dir = cBuilder.GetDirection(srcplace, dstplace);
		if (srcistown) {
			tilelist = cBuilder.GetTilesAroundTown(src, 2, 2);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryProducing(src, rad);
			isneartown = false;
		}
		otherplace = dstplace;
	} else {
		dir = cBuilder.GetDirection(dstplace, srcplace);
		if (dstistown) {
			tilelist = cBuilder.GetTilesAroundTown(dst, 2, 2);
			isneartown = true;
		} else {
			tilelist = AITileList_IndustryAccepting(dst, rad);
			tilelist.Valuate(AITile.GetCargoAcceptance, crg, 1, 1, rad);
			tilelist.RemoveBelowValue(8);
			isneartown = false;
		}
		otherplace = srcplace;
	}
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.KeepValue(1);
	// Sort the tile list
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
		if (cBuilder.CanBuildDoubleRailStation(tile, dir)) {
			success = true;
			break;
		} else continue;
	}
	if (!success) return false;
	// Build the station itself
	if (AIController.GetSetting("newgrf_stations") == 1 && !srcistown && !dstistown) {
		// Build a NewGRF rail station
		success = success && AIRail.BuildNewGRFRailStation(statop, stationdir, 2, 3, AIStation.STATION_NEW,
							crg, AIIndustry.GetIndustryType(src), AIIndustry.GetIndustryType(dst), AIMap.DistanceManhattan(srcplace, dstplace), is_source);
	} else {
		// Build a standard rail station
		success = success && AIRail.BuildRailStation(statop, stationdir, 2, 3, AIStation.STATION_NEW);
	}
	if (!success) {
		AILog.Error("Station could not be built: " + AIError.GetLastErrorString());
		return false;
	}
	// Build the station parts
	success = success && AIRail.BuildRail(statile, front1, depfront);
	success = success && AIRail.BuildRail(lane2, front2, stafront);
	success = success && AIRail.BuildRail(front1, depfront, deptile);
	success = success && AIRail.BuildRail(front2, stafront, frontfront);
	success = success && AIRail.BuildRail(front1, depfront, stafront);
	success = success && AIRail.BuildRail(front2, stafront, depfront);
	success = success && AIRail.BuildRail(depfront, stafront, frontfront);
	success = success && AIRail.BuildRail(stafront, depfront, deptile);
	success = success && AIRail.BuildRail(stafront, frontfront, morefront);
	success = success && AIRail.BuildRailDepot(deptile, depfront);
	local signaltype = (AIController.GetSetting("signaltype") >= 2) ? AIRail.SIGNALTYPE_PBS : AIRail.SIGNALTYPE_NORMAL_TWOWAY;
	success = success && AIRail.BuildSignal(front1, statile, signaltype);
	success = success && AIRail.BuildSignal(front2, lane2, signaltype);
	// Handle it if the construction was interrupted for any reason
	if (!success) {
		AILog.Warning("Station construction was interrupted.");
		cBuilder.RemoveRailLine(statile);
		cBuilder.RemoveRailLine(front2);
		return false;
	}
	// Register the station
	if (is_source) {
		stasrc = AIStation.GetStationID(statile);
		homedepot = deptile;
	} else {
		stadst = AIStation.GetStationID(statile);
	}
	return true;
}

/**
 * Determine whether a double rail station can be built at a given place.
 * Builder class variables set: statile, deptile, stafront, depfront, front1, front2,
 *   lane2, frontfront, morefront, statop, stabottom
 * @param tile The tile to be checked.
 * @param direction The direction of the proposed station.
 * @return Ture if a double rail station can be built at the given position.
 */
function cBuilder::CanBuildDoubleRailStation(tile, direction)
{
	if (!AITile.IsBuildable(tile)) return false;
	local vector, rvector = null;
	// Set the direction vectors
	switch (direction) {
		case DIR_NW:
			vector = AIMap.GetTileIndex(0, -1);
			rvector = AIMap.GetTileIndex(1, 0);
			stationdir = AIRail.RAILTRACK_NW_SE;
			break;
		case DIR_NE:
			vector = AIMap.GetTileIndex(-1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SW:
			vector = AIMap.GetTileIndex(1, 0);
			rvector = AIMap.GetTileIndex(0, 1);
			stationdir = AIRail.RAILTRACK_NE_SW;
			break;
		case DIR_SE:
			vector = AIMap.GetTileIndex(0, 1);
			rvector = AIMap.GetTileIndex(1, 0);
			stationdir = AIRail.RAILTRACK_NW_SE;
			break;
	}
	// Set the top and the bottom tile of the station
	if (direction == DIR_NW || direction == DIR_NE) {
		stabottom = tile;
		statop = tile + vector + vector;
		statile = statop;
	} else {
		statop = tile;
		stabottom = tile + vector + vector;
		statile = stabottom;
	}
	local test = AITestMode();
	// Set the tiles for the station parts
	lane2 = statile + rvector;
	front1 = statile + vector;
	front2 = lane2 + vector;
	depfront = front1 + vector;
	stafront = front2 + vector;
	deptile = depfront + vector;
	// Try the second place for the depot if the first one is not suitable
	if (!AIRail.BuildRailDepot(deptile, depfront)) deptile = depfront - rvector;
	frontfront = stafront + vector;
	morefront = frontfront + vector;
	// Try the second place for the station exit if the first one is not suitable
	if ((!AITile.IsBuildable(frontfront)) || (!AITile.IsBuildable(morefront)) || (!AIRail.BuildRail(stafront, frontfront, morefront)) || (AITile.IsCoastTile(morefront))) {
		frontfront = stafront + rvector;
		morefront = frontfront + rvector;
	}
	// Do the tests
	if (!AIRail.BuildRailStation(statop, stationdir, 2, 3, AIStation.STATION_NEW)) return false;
	if (!AITile.IsBuildable(front1)) return false;
	if (!AIRail.BuildRail(statile, front1, depfront)) return false;
	if (!AITile.IsBuildable(front2)) return false;
	if (!AIRail.BuildRail(lane2, front2, stafront)) return false;
	if (!AITile.IsBuildable(depfront)) return false;
	if (!AIRail.BuildRail(front1, depfront, deptile)) return false;
	if (!AITile.IsBuildable(stafront)) return false;
	if (!AIRail.BuildRail(front2, stafront, frontfront)) return false;
	if (!AIRail.BuildRail(front1, depfront, stafront)) return false;
	if (!AIRail.BuildRail(front2, stafront, depfront)) return false;
	if (!AIRail.BuildRail(depfront, stafront, frontfront)) return false;
	if (!AIRail.BuildRail(stafront, depfront, deptile)) return false;
	if (!AITile.IsBuildable(frontfront)) return false;
	if (!AITile.IsBuildable(morefront)) return false;
	if (AITile.IsCoastTile(morefront)) return false;
	if (!AIRail.BuildRail(stafront, frontfront, morefront)) return false;
	if (!AIRail.BuildRailDepot(deptile, depfront)) return false;
	// Check if there is a station just at the back of the proposed station
	if (AIRail.IsRailStationTile(statile - 3 * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(statile - 3 * vector)) && AIRail.GetRailStationDirection(statile - 3 * vector) == stationdir)
			return false;
	}
	if (AIRail.IsRailStationTile(lane2 - 3 * vector)) {
		if (AICompany.IsMine(AITile.GetOwner(lane2 - 3 * vector)) && AIRail.GetRailStationDirection(lane2 - 3 * vector) == stationdir)
			return false;
	}
	test = null;
	return true;
}

/**
 * Build a passing lane section between the current source and destination.
 * Builder class variables used: stasrc, stadst
 * @param near_source True if we're building the first passing lane section. (the one closer to the source station)
 * @return True if the construction succeeded.
 */
function cBuilder::BuildPassingLaneSection(near_source)
{
	local dir, tilelist, centre;
	local src_x, src_y, dst_x, dst_y, ps_x, ps_y;
	local end = [[], []];
	local reverse = false;
	// Get the direction of the passing lane section
	dir = AIRail.GetRailTracks(AIStation.GetLocation(stasrc));
	// Get the places of the stations
	src_x = AIMap.GetTileX(AIStation.GetLocation(stasrc));
	src_y = AIMap.GetTileY(AIStation.GetLocation(stasrc));
	dst_x = AIMap.GetTileX(AIStation.GetLocation(stadst));
	dst_y = AIMap.GetTileY(AIStation.GetLocation(stadst));
	// Determine whether we're building a flipped passing lane section
	if ((!(dst_x > src_x) && (dst_y > src_y)) || ((dst_x > src_x) && !(dst_y > src_y))) reverse = true;
	// Propose a place for the passing lane section, it is 1/3 on the line between the two stations
	if (near_source) {
		ps_x = ((2 * src_x + dst_x) / 3).tointeger();
		ps_y = ((2 * src_y + dst_y) / 3).tointeger();
	} else {
		ps_x = ((src_x + 2 * dst_x) / 3).tointeger();
		ps_y = ((src_y + 2 * dst_y) / 3).tointeger();
	}
	// Get a tile list around the proposed place
	tilelist = AITileList();
	centre = AIMap.GetTileIndex(ps_x, ps_y);
	tilelist.AddRectangle(centre - AIMap.GetTileIndex(10, 10), centre + AIMap.GetTileIndex(10, 10));
	tilelist.Valuate(AIMap.DistanceManhattan, centre);
	tilelist.Sort(AIList.SORT_BY_VALUE, true);
	local success = false;
	local tile = null;
	// Find a place where the passing lane section can be built
	foreach (itile, dummy in tilelist) {
		if (cBuilder.CanBuildPassingLaneSection(itile, dir, reverse)) {
			success = true;
			tile = itile;
			break;
		} else continue;
	}
	if (!success) return null;
	// Get the direction vectors
	local vector, rvector;
	if (dir == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
	}
	// Determine what signal type to use
	local signaltype = AIRail.SIGNALTYPE_NORMAL;
	if (AIController.GetSetting("signaltype") > 0) {
		signaltype = (AIController.GetSetting("signaltype") < 2) ? AIRail.SIGNALTYPE_TWOWAY : AIRail.SIGNALTYPE_PBS_ONEWAY;
	}
	// Build the passing lane section
	if (reverse) rvector = -rvector;
	centre = tile;
	tile = centre - vector - vector - vector;
	end[0] = [tile - vector, tile];
	for (local x = 0; x < 6; x++) {
		success = success && AIRail.BuildRail(tile - vector, tile, tile + vector);
		tile += vector;
	}
	success = success && AIRail.BuildRail(tile - vector, tile, tile + rvector);
	success = success && AIRail.BuildRail(tile, tile + rvector, tile + rvector + vector);
	tile = centre + rvector + vector + vector + vector + vector;
	end[1] = [tile + vector, tile];
	for (local x = 0; x < 6; x++) {
		success = success && AIRail.BuildRail(tile + vector, tile, tile - vector);
		tile -= vector;
	}
	success = success && AIRail.BuildRail(tile + vector, tile, tile - rvector);
	success = success && AIRail.BuildRail(tile, tile - rvector, tile - rvector - vector);
	success = success && AIRail.BuildSignal(centre - vector, centre - 2*vector, signaltype);
	success = success && AIRail.BuildSignal(centre - 2*vector + rvector, centre - vector + rvector, signaltype);
	success = success && AIRail.BuildSignal(centre + rvector + 2*vector, centre + rvector + 3*vector, signaltype);
	success = success && AIRail.BuildSignal(centre + 3*vector, centre + 2*vector, signaltype);
	if (!success) {
		AILog.Warning("Passing lane construction was interrupted.");
		cBuilder.RemoveRailLine(end[0][1]);
		return null;
	}
	return end;
}

/**
 * Determine whether a passing lane section can be built at a given position.
 * @param centre The centre tile of the proposed passing lane section.
 * @param direction The direction of the proposed passing lane section.
 * @param reverse True if we are trying to build a flipped passing lane section.
 * @return True if a passing lane section can be built.
 */
function cBuilder::CanBuildPassingLaneSection(centre, direction, reverse)
{
	if (!AITile.IsBuildable(centre)) return false;
	local vector, rvector = null;
	// Get the direction vectors
	if (direction == AIRail.RAILTRACK_NE_SW) {
		vector = AIMap.GetTileIndex(1, 0);
		rvector = AIMap.GetTileIndex(0, 1);
		local topcorner = centre - vector - vector;
		if (reverse) topcorner -= rvector;
		if (!AITile.IsBuildableRectangle(topcorner, 6, 2)) return false;
	} else {
		vector = AIMap.GetTileIndex(0, 1);
		rvector = AIMap.GetTileIndex(1, 0);
		local topcorner = centre - vector - vector;
		if (reverse) topcorner -= rvector;
		if (!AITile.IsBuildableRectangle(topcorner, 2, 6)) return false;
	}
	if (reverse) rvector = -rvector;
	local test = AITestMode();
	local tile = centre - vector - vector - vector;
	// Do the tests
	if (!AITile.IsBuildable(tile)) return false;
	if (!AITile.IsBuildable(tile - vector)) return false;
	// Do not build on the coast
	if (AITile.IsCoastTile(tile - vector)) return false;
	if (!AIRail.BuildRail(tile, tile + vector, tile + vector + rvector)) return false;
	if (!AIRail.BuildRail(tile + vector, tile + vector + rvector, tile + vector + vector + rvector)) return false;
	if (!AIRail.BuildRail(tile + vector + rvector, tile + vector, tile + vector + vector)) return false;
	for (local x = 0; x < 6; x++) {
		if (!AIRail.BuildRail(tile - vector, tile, tile + vector)) return false;
		tile += vector;
	}
	tile = centre + rvector + vector + vector + vector + vector;
	if (!AITile.IsBuildable(tile)) return false;
	if (!AITile.IsBuildable(tile + vector)) return false;
	// Do not build on the coast
	if (AITile.IsCoastTile(tile + vector)) return false;
	if (!AIRail.BuildRail(tile, tile - vector, tile - vector - rvector)) return false;
	if (!AIRail.BuildRail(tile - vector, tile - vector - rvector, tile - vector - vector - rvector)) return false;
	if (!AIRail.BuildRail(tile - vector - rvector, tile - vector, tile - vector - vector)) return false;
	for (local x = 0; x < 6; x++) {
		if (!AIRail.BuildRail(tile + vector, tile, tile - vector)) return false;
		tile -= vector;
	}
	test = null;
	return true;
}

/**
 * Get the platform length of a station.
 * @param sta The StationID of the station.
 * @return The length of the station's platform in tiles.
 */
function cBuilder::GetRailStationPlatformLength(sta)
{
	if (!AIStation.IsValidStation(sta)) return 0;
	local place = AIStation.GetLocation(sta);
	if (!AIRail.IsRailStationTile(place)) return 0;
	local dir = AIRail.GetRailStationDirection(place);
	local vector = null;
	if (dir == AIRail.RAILTRACK_NE_SW) vector = AIMap.GetTileIndex(1, 0);
	else vector = AIMap.GetTileIndex(0, 1);
	local length = 0;
	while (AIRail.IsRailStationTile(place) && AIStation.GetStationID(place) == sta) {
		length++;
		place += vector;
	}
	return length;
}

/**
 * Attach more wagons to a train after it has been sent to the depot.
 * @param vehicle The VehicleID of the train.
 */
function cBuilder::AttachMoreWagons(vehicle)
{
	// Get information about the train's group
	local group = AIVehicle.GetGroupID(vehicle);
	local route = root.routes[root.groups.GetValue(group)];
	local railtype = AIRail.GetCurrentRailType();
	AIRail.SetCurrentRailType(route.railtype);
	local depot = AIVehicle.GetLocation(vehicle);
	// Choose a wagon
	local wagon = cBuilder.ChooseWagon(route.crg, root.engineblacklist);
	if (wagon == null) return;
	// Build the first wagon
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
		if (!Banker.SetMinimumBankBalance(AIEngine.GetPrice(wagon))) {
			AILog.Warning("I don't have enough money to attach more wagons.");
			return;
		}
	}
	local firstwagon = AIVehicle.BuildVehicle(depot, wagon);
	// Blacklist the wagon if it is too long
	if (AIVehicle.GetLength(firstwagon) > 8) {
		root.engineblacklist.AddItem(wagon, 0);
		AILog.Warning(AIEngine.GetName(wagon) + " was blacklisted for being too long.");
		AIVehicle.SellVehicle(firstwagon);
		return;
	}
	// Attach additional wagons
	local wagon_length = AIVehicle.GetLength(firstwagon);
	local cur_wagons = 1;
	local platform_length = cBuilder.GetRailStationPlatformLength(route.stasrc);
	while (AIVehicle.GetLength(vehicle) + (cur_wagons + 1) * wagon_length <= platform_length * 16) {
		if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(wagon)) {
			Banker.SetMinimumBankBalance(AIEngine.GetPrice(wagon));
		}
		if (!AIVehicle.BuildVehicle(depot, wagon)) break;
		cur_wagons++;
	}
	// Refit the wagons if needed
	if (AIEngine.GetCargoType(wagon) != route.crg) AIVehicle.RefitVehicle(firstwagon, route.crg);
	// Attach the wagons to the engine
	AIVehicle.MoveWagonChain(firstwagon, 0, vehicle, AIVehicle.GetNumWagons(vehicle) - 1);
	AILog.Info("Added more wagons to " + AIVehicle.GetName(vehicle) + ".");
	// Restore the previous railtype
	AIRail.SetCurrentRailType(railtype);
}

/**
 * Upgrade the registered rail bridges.
 */
function cBuilder::UpgradeRailBridges()
{
	AILog.Info("Upgrading rail bridges (" + root.railbridges.Count() + " bridges registered)");
	foreach (tile, dummy in root.railbridges) {
		// Stop if we cannot afford it
		if (!Banker.SetMinimumBankBalance(Banker.InflatedValue(50000))) return;
		if (!AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL) || !AIBridge.IsBridgeTile(tile)) continue;
		AIRail.SetCurrentRailType(AIRail.GetRailType(tile));
		local otherend = AIBridge.GetOtherBridgeEnd(tile);
		local bridgelist = AIBridgeList_Length(AIMap.DistanceManhattan(tile, otherend) + 1);
		bridgelist.Valuate(AIBridge.GetMaxSpeed);
		if (AIBridge.GetBridgeID(tile) == bridgelist.Begin()) continue;
		AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridgelist.Begin(), tile, otherend);
	}
}

/**
 * Choose a train locomotive.
 * @param crg The cargo to carry.
 * @param distance The distance to be traveled.
 * @param wagon The EngineID of the wagons to be pulled.
 * @param num_wagons The number of wagons to be pulled.
 * @param blacklist A list of engines that cannot be used.
 * @return The EngineID of the chosen locomotive, null if no suitable locomotive was found.
 */
function cBuilder::ChooseTrainEngine(crg, distance, wagon, num_wagons, blacklist)
{
	local enginelist = AIEngineList(AIVehicle.VT_RAIL);
	enginelist.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
	enginelist.KeepValue(1);
	enginelist.Valuate(AIEngine.IsWagon);
	enginelist.KeepValue(0);
	enginelist.Valuate(AIEngine.CanPullCargo, crg);
	enginelist.KeepValue(1);
	if (blacklist != null) {
		enginelist.Valuate(EmotionAI.ListContainsValuator, blacklist);
		enginelist.KeepValue(0);
	}
	if (enginelist.IsEmpty()) return null;
	local money = Banker.GetMaxBankBalance();
	local cargo_weight_factor = 0.5;
	if (AICargo.HasCargoClass(crg, AICargo.CC_PASSENGERS)) cargo_weight_factor = 0.05;
	if (AICargo.HasCargoClass(crg, AICargo.CC_BULK) || AICargo.HasCargoClass(crg, AICargo.CC_LIQUID)) cargo_weight_factor = 1;
	local weight = num_wagons * (AIEngine.GetWeight(wagon) + AIEngine.GetCapacity(wagon) * cargo_weight_factor);
	local max_speed = AIEngine.GetMaxSpeed(wagon);
	if (max_speed == 0) max_speed = 500;
	//AILog.Info("Weight: " + weight + "  Max speed: " + max_speed);
	enginelist.Valuate(cBuilder.TrainEngineValuator, weight, max_speed, money);
	local i = 0;
	/*foreach (engine, value in enginelist) {
		i++;
		AILog.Info(i + ". " + AIEngine.GetName(engine) + " - " + value);
	}*/
	return enginelist.Begin();
}

/**
 * A valuator function for scoring train locomotives.
 * @param engine The engine to be scored.
 * @param weight The weight to be pulled.
 * @param max_speed The maximum speed allowed.
 * @param money The amount of money the company has.
 * @return The score of the engine.
 */
function cBuilder::TrainEngineValuator(engine, weight, max_speed, money)
{
	local value = 0;
	local weight_with_engine = weight + AIEngine.GetWeight(engine);
	//local hp_break = weight_with_engine.tofloat() * 3.0;
	//local power = AIEngine.GetPower(engine).tofloat();
	//value += (power > hp_break) ? (160 + 240 * power / (3 * hp_break)) : (240 * power / hp_break);
	local hp_per_tonne = AIEngine.GetPower(engine).tofloat() / weight_with_engine.tofloat();
	local power_points = (hp_per_tonne > 4.0) ? ((hp_per_tonne > 16.0) ? (620 + 10 * hp_per_tonne / 4.0) : (420 + 60 * hp_per_tonne / 4.0)) : (-480 + 960 * hp_per_tonne / 4.0);
	value += power_points;
	local speed = AIEngine.GetMaxSpeed(engine);
	local speed_points = (speed > max_speed) ? (360 * max_speed / 112.0) : (360 * speed / 112.0)
	value += speed_points;
	local runningcost_limit = (6000 / Banker.GetInflationRate()).tointeger();
	local runningcost = AIEngine.GetRunningCost(engine).tofloat();
	local runningcost_penalty = (runningcost > runningcost_limit) ? ((runningcost > 3 * runningcost_limit) ? (runningcost / 20.0 - 550.0) : (runningcost / 40.0 - 100.0)) : (runningcost / 120.0)
	value -= runningcost_penalty;
	/*AILog.Info(AIEngine.GetName(engine) + " : " + value);
	AILog.Info("     power points: " + power_points);
	AILog.Info("     speed points: " + speed_points);
	AILog.Info("     running cost penalty: " + runningcost_penalty);
	AILog.Info("     railtype: " + AIEngine.GetRailType(engine))*/

	return value.tointeger();
}

/**
 * A workaround for refitting the mail wagon separately.
 * @param mailwagon The mail wagon to be refitted.
 * @param firstwagon The wagon to which the mail wagon is attached.
 * @param trainengine The locomotive of the train, used to move the wagons.
 * @param crg The cargo which the mail wagon will be refitted to.
 */
function cBuilder::MailWagonWorkaround(mailwagon, firstwagon, trainengine, crg)
{
	AIVehicle.MoveWagon(firstwagon, 0, trainengine, 0);
	AIVehicle.RefitVehicle(mailwagon, crg);
	AIVehicle.MoveWagon(trainengine, 1, mailwagon, 0);
	AIVehicle.MoveWagon(mailwagon, 0, trainengine, 0);
	AIVehicle.MoveWagon(trainengine, 1, firstwagon, 0);
}
