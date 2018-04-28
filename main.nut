import("pathfinder.road", "RoadPathFinder", 4);
import("pathfinder.rail", "RailPathFinder", 1);

require("pathfinder.nut");
require("builder.nut");
require("railbuilder.nut");
require("manager.nut");
require("banker.nut");
require("aircraft.nut");
require("Terraform.nut");
require("setcompanyname.nut");
require("emotion/player_manager.nut");

class SimpleAI extends AIController
{
		// Building stages, needed to recover a savegame
		BS_NOTHING = 0;
		BS_BUILDING = 1;
		BS_REMOVING = 2;
		BS_ELECTRIFYING = 3;

		// Reasons to send a vehicle to a depot
		TD_SELL = 1;
		TD_REPLACE = 2;
		TD_ATTACH_WAGONS = 3;

		pathfinder = null; // Pathfinder instance. Possibly unused?
		builder = null; // Builder class instance
		manager = null; // Manager class instance
		routes = null; // The number of routes
		serviced = null; // Industry/town - cargo pairs already serviced
		groups = null; // The list of vehicle groups
		airports = null; // The airport of each town
		use_trains = null; // Whether using trains is allowed
		use_roadvehs = null; // Whether using road vehicles is allowed
		use_aircraft = null; // Whether using aircraft is allowed
		lastroute = null; // The date the last route was built
		loadedgame = null; // Whether the game is loaded from a savegame
		companyname_set = null; // True if the company name has already been set (only used with 3iff's naming system)
		buildingstage = null; // The current building stage
		inauguration = null; // The inauguration year of the company
		bridgesupgraded = null; // The year in which bridges were last upgraded
		removelist = null; // List used to continue rail removal and electrification
		toremove = { vehtype = null,
								 stasrc = null,
								 stadst = null,
								 list = null
							 }; // Table used to remove unfinished routes
		roadbridges = null; // The list of road bridges
		railbridges = null; // The list of rail bridges
		engineblacklist = null; // The blacklist of train engines

		players = null; // Used for storing players
		constructor() {
			routes = [];
			serviced = AIList();
			groups = AIList();
			airports = AIList();
			manager = cManager(this);
			loadedgame = false;
			lastroute = 0;
			buildingstage = BS_NOTHING;
			inauguration = 0;
			bridgesupgraded = null;
			removelist = [];
			roadbridges = AITileList();
			railbridges = AITileList();
			engineblacklist = AIList();


			players = PlayerManager();
			players.AssignTowns();
		}
}

/**
 * The main function of the AI.
 */
function SimpleAI::Start()
{
	AILog.Info("SimpleAI started.");
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	AICompany.SetAutoRenewStatus(false);
	AILog.Info("Maximum transported percentage is " + AIController.GetSetting("max_transported") + "%");
	if (loadedgame) {
		switch (buildingstage) {
			case BS_BUILDING:
				// Remove unfinished route id needed
				buildingstage = BS_NOTHING;
				this.RemoveUnfinishedRoute();
				break;
			case BS_REMOVING:
				// Continue the removal of rails
				AILog.Info("Finishing the removal of the rail line.")
				removelist = toremove.list;
				builder = cBuilder(this);
				builder.RemoveRailLine(AIMap.TILE_INVALID);
				builder = null;
				break;
			case BS_ELECTRIFYING:
				// Continue the electrification of rails
				AILog.Info("Finishing the electrification of the rail line.");
				removelist = toremove.list;
				this.SetRailType();
				builder = cBuilder(this);
				builder.ElectrifyRail(AIMap.TILE_INVALID);
				builder = null;
				break;
		}
		manager.CheckEvents();
		manager.CheckRoutes();
		Banker.PayLoan();
	} else {
		inauguration = AIDate.GetYear(AIDate.GetCurrentDate());
		bridgesupgraded = AIDate.GetYear(AIDate.GetCurrentDate());
	}
	// The main loop of the AI
	while(true) {
		this.SetRailType();
		this.CheckVehicleTypes();
		if (this.HasWaitingTimePassed()) {
			// Check if we have enough money
			if (Banker.GetMaxBankBalance() > Banker.MinimumMoneyToBuild(routes.len())) {
				if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < Banker.MinimumMoneyToBuild(routes.len())) {
					Banker.SetMinimumBankBalance(Banker.MinimumMoneyToBuild(routes.len()));
				}
				builder = cBuilder(this);
				builder.BuildSomething();
				builder = null;
				AILog.Info("_______________________");
				AILog.Info("");
			}
		}
		manager.CheckEvents();
		manager.CheckTodepotlist();
		manager.CheckRoutes();
		if (AIDate.GetYear(AIDate.GetCurrentDate()) > bridgesupgraded) this.UpgradeBridges();
		Banker.PayLoan();
		AIController.Sleep(10);
	}
}

/**
 * The function called when stopping the AI.
 */
function SimpleAI::Stop()
{
}

/**
 * Saves the current state of the AI.
 */
function SimpleAI::Save()
{
	local table = {	lastroute = lastroute,
									todepotlist = [],
									routes = routes,
									serviced = [],
									groups = [],
									airports = [],
									eventqueue = null,
									buildingstage = null,
									inauguration = inauguration,
									bridgesupgraded = bridgesupgraded,
									roadbridges = [],
									railbridges = [],
									engineblacklist = [],
									toremove = { vehtype = null,
															 stasrc = null,
															 stadst = null,
															 list = null
														 },
									player_manager = null
								};
	table.todepotlist = SimpleAI.ListToArray(manager.todepotlist);
	table.serviced = SimpleAI.ListToArray(serviced);
	table.groups = SimpleAI.ListToArray(groups);
	table.airports = SimpleAI.ListToArray(airports);
	table.eventqueue = this.SaveEventQueue();
	table.roadbridges = SimpleAI.ListToArray(roadbridges);
	table.railbridges = SimpleAI.ListToArray(railbridges);
	table.engineblacklist = SimpleAI.ListToArray(engineblacklist);
	table.buildingstage = buildingstage;
	switch (buildingstage) {
		case BS_BUILDING:
			if (builder != null) {
				table.toremove.vehtype = builder.vehtype;
				table.toremove.stasrc = builder.stasrc;
				table.toremove.stadst = builder.stadst;
				table.toremove.list = [builder.ps1_entry[1], builder.ps2_entry[1]];
			} else {
				AILog.Error("Invalid save state, probably the game is being saved right after loading");
				table.buildingstage = BS_NOTHING;
			}
			break;
		case BS_REMOVING:
		case BS_ELECTRIFYING:
			table.toremove.list = removelist;
			break;
	}
	table.player_manager = this.players.Save();
	AILog.Warning("Game saved.");
	return table;
}

/**
 * Loads the state of the AI from a savegame.
 */
function SimpleAI::Load(version, data)
{
	AILog.Info("Loading a saved game with SimpleAI.");
	if ("lastroute" in data) lastroute = data.lastroute;
	else lastroute = 0;
	if ("routes" in data) routes = data.routes;
	if ("todepotlist" in data) manager.todepotlist.AddList(SimpleAI.ArrayToList(data.todepotlist));
	if ("serviced" in data) serviced.AddList(SimpleAI.ArrayToList(data.serviced));
	if ("groups" in data) groups.AddList(SimpleAI.ArrayToList(data.groups));
	if ("airports" in data) airports.AddList(SimpleAI.ArrayToList(data.airports));
	if ("inauguration" in data) inauguration = data.inauguration;
	else inauguration = AIGameSettings.GetValue("game_creation.starting_year");
	if ("eventqueue" in data) manager.eventqueue = data.eventqueue;
	if ("bridgesupgraded" in data) bridgesupgraded = data.bridgesupgraded;
	if ("roadbridges" in data) roadbridges.AddList(SimpleAI.ArrayToList(data.roadbridges));
	if ("railbridges" in data) railbridges.AddList(SimpleAI.ArrayToList(data.railbridges));
	if ("engineblacklist" in data) engineblacklist.AddList(SimpleAI.ArrayToList(data.engineblacklist));
	if ("buildingstage" in data) buildingstage = data.buildingstage;
	if (data.rawin("player_manager")) players = PlayerManager.Load(data.rawget("player_manager"));
	else buildingstage = BS_NOTHING;
	if (buildingstage != BS_NOTHING) {
		toremove = data.toremove;
	}
	loadedgame = true;
}

/**
 * Builds the company headquarters.
 * @param centre The town or station around which the HQ will be built.
 * @param istown Whether the HQ will be built in a town.
 * @return True if the construction succeeded.
 */
function SimpleAI::BuildHQ(centre, istown)
{
	local tilelist = null;
	// Get a tile list
	if (istown) {
		tilelist = cBuilder.GetTilesAroundTown(centre, 1, 1);
	} else {
		tilelist = AITileList_IndustryProducing(centre, 6);
	}
	tilelist.Valuate(AIBase.RandItem);
	foreach (tile, dummy in tilelist) {
    if (AIController.GetSetting("use_custom_companyname")) {
      // Using test mode here because the name of the company has to be set before the HQ is built.
      local test_mode = AITestMode();
      if (AICompany.BuildCompanyHQ(tile)) {
        test_mode = null;
        //  Call the company naming routine
        SetCo.SetCompanyName(AITile.GetClosestTown(tile));
        AILog.Info("The company is named " + AICompany.GetName(AICompany.COMPANY_SELF));
      }
    }
		if (AICompany.BuildCompanyHQ(tile)) {
      // This sleep is needed to ensure that the company gets its name after the HQ town
      AIController.Sleep(25);
			local name = null;
			if (istown) {
				name = AITown.GetName(centre);
			} else {
				name = AIIndustry.GetName(centre);
			}
			AILog.Info("Built company headquarters near " + name);
			return true;
		}
	}
	return false;
}

/**
 * Sets the current rail type of the AI based on the maximum number of cargoes transportable.
 */
function SimpleAI::SetRailType()
{
	local railtypes = AIRailTypeList();
	local cargoes = AICargoList();
	local max_cargoes = 0;
	// Check each rail type for the number of available cargoes
	foreach (railtype, dummy in railtypes) {
		// Avoid the universal rail in NUTS and other similar ones
		local buildcost = AIRail.GetBuildCost(railtype, AIRail.BT_TRACK);
		if (buildcost > Banker.InflatedValue(2000)) continue;
		local current_railtype = AIRail.GetCurrentRailType();
		AIRail.SetCurrentRailType(railtype);
		local num_cargoes = 0;
		// Count the number of available cargoes
		foreach (cargo, dummy2 in cargoes) {
			if (cBuilder.ChooseWagon(cargo, null) != null) num_cargoes++;
		}
		if (num_cargoes > max_cargoes) {
			max_cargoes = num_cargoes;
			current_railtype = railtype;
		}
		AIRail.SetCurrentRailType(current_railtype);
	}
}

/**
 * Checks the game settings for the particular vehicle types.
 */
function SimpleAI::CheckVehicleTypes()
{
	if (AIController.GetSetting("use_roadvehs") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD))
		use_roadvehs = 1;
	else use_roadvehs = 0;
	if (AIController.GetSetting("use_trains") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL))
		use_trains = 1;
	else use_trains = 0;
	if (AIController.GetSetting("use_aircraft") && !AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR))
		use_aircraft = 1;
	else use_aircraft = 0;

	/* Checking vehicle limits */

	local vehiclelist = AIVehicleList();
	vehiclelist.Valuate(AIVehicle.GetVehicleType);
	vehiclelist.KeepValue(AIVehicle.VT_ROAD);
	if (vehiclelist.Count() + 5 > AIGameSettings.GetValue("vehicle.max_roadveh")) use_roadvehs = 0;

	vehiclelist = AIVehicleList();
	vehiclelist.Valuate(AIVehicle.GetVehicleType);
	vehiclelist.KeepValue(AIVehicle.VT_RAIL);
	if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_trains")) use_trains = 0;

	vehiclelist = AIVehicleList();
	vehiclelist.Valuate(AIVehicle.GetVehicleType);
	vehiclelist.KeepValue(AIVehicle.VT_AIR);
	if (vehiclelist.Count() + 1 > AIGameSettings.GetValue("vehicle.max_aircraft")) use_aircraft = 0;
}

/**
 * Gets the CargoID associated with mail.
 * @return The CargoID of mail.
 */
function SimpleAI::GetMailCargo()
{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist) {
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_MAIL) return cargo;
	}
	return null;
}

/**
 * Gets the CargoAI associated with passengers.
 * @return The CargoID of passengers.
 */
function SimpleAI::GetPassengersCargo()
{
	local cargolist = AICargoList();
	foreach (cargo, dummy in cargolist) {
		if (AICargo.GetTownEffect(cargo) == AICargo.TE_PASSENGERS) return cargo;
	}
	return null;
}

/**
 * Converts an AIList to an array.
 * @param list The AIList to be converted.
 * @return The converted array.
 */
function SimpleAI::ListToArray(list)
{
	local array = [];
	local templist = AIList();
	templist.AddList(list);
	while (templist.Count() > 0) {
		local arrayitem = [templist.Begin(), templist.GetValue(templist.Begin())];
		array.append(arrayitem);
		templist.RemoveTop(1);
	}
	return array;
}

/**
 * Converts an array to an AIList.
 * @param The array to be converted.
 * @return The converted AIList.
 */
function SimpleAI::ArrayToList(array)
{
	local list = AIList();
	local temparray = [];
	temparray.extend(array);
	while (temparray.len() > 0) {
		local arrayitem = temparray.pop();
		list.AddItem(arrayitem[0], arrayitem[1]);
	}
	return list;
}

/**
 * Saves the important elements of the event queue.
 * @return The event queue converted to an array which can be saved.
 */
function SimpleAI::SaveEventQueue()
{
	local array = manager.eventqueue;
	while (AIEventController.IsEventWaiting()) {
		local event = AIEventController.GetNextEvent();
		local vehicle = null;
		local isimportant = false;
		switch (event.GetEventType()) {
			case AIEvent.ET_VEHICLE_CRASHED:
				event = AIEventVehicleCrashed.Convert(event);
				vehicle = event.GetVehicleID();
				isimportant = true;
				break;

			case AIEvent.ET_VEHICLE_WAITING_IN_DEPOT:
				event = AIEventVehicleWaitingInDepot.Convert(event);
				vehicle = event.GetVehicleID();
				isimportant = true;
				break;

			case AIEvent.ET_VEHICLE_UNPROFITABLE:
				event = AIEventVehicleUnprofitable.Convert(event);
				vehicle = event.GetVehicleID();
				isimportant = true;
				break;
		}
		if (isimportant) {
			local arrayitem = [event.GetEventType(), vehicle];
			array.append(arrayitem);
		}
	}
	return array;
}

/**
 * Decides whether it is time to build a new route.
 * @return True if the waiting time has passed.
 */
function SimpleAI::HasWaitingTimePassed()
{
	local date = AIDate.GetCurrentDate();
	local waitingtime = AIController.GetSetting("waiting_time") + (AIDate.GetYear(date) - inauguration) * AIController.GetSetting("slowdown") * 4;
	if (date - lastroute > waitingtime) return true;
	else return false;
}

/**
 * Removes the unfinished route started before saving the game.
 */
function SimpleAI::RemoveUnfinishedRoute()
{
	AILog.Info("Removing the unfinished route after loading...");
	switch (toremove.vehtype) {
		case AIVehicle.VT_ROAD:
			cBuilder.DeleteRoadStation(toremove.stasrc);
			cBuilder.DeleteRoadStation(toremove.stadst);
			break;
		case AIVehicle.VT_RAIL:
			builder = cBuilder(this);
			builder.DeleteRailStation(toremove.stasrc);
			builder.DeleteRailStation(toremove.stadst);
			builder.RemoveRailLine(toremove.list[0]);
			builder.RemoveRailLine(toremove.list[1]);
			builder = null;
			break;
		case AIVehicle.VT_AIR:
			builder = cBuilder(this);
			builder.DeleteAirport(toremove.stasrc);
			builder.DeleteAirport(toremove.stadst);
			builder = null;
			break;
	}
}

/**
 * Checks whether a given rectangle is within the influence of a given town.
 * @param tile The topmost tile of the rectangle.
 * @param town_id The TownID of the town to be checked.
 * @param width The width of the rectangle.
 * @param height The height of the rectangle.
 * @return True if the rectangle is within the influence of the town.
 */
function SimpleAI::IsRectangleWithinTownInfluence(tile, town_id, width, height)
{
	if (width <= 1 && height <= 1) return AITile.IsWithinTownInfluence(tile, town_id);
	local offsetX = AIMap.GetTileIndex(width - 1, 0);
	local offsetY = AIMap.GetTileIndex(0, height - 1);
	return AITile.IsWithinTownInfluence(tile, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetX + offsetY, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetX, town_id) ||
				 AITile.IsWithinTownInfluence(tile + offsetY, town_id);
}

/**
 * Upgrades existing bridges.
 */
function SimpleAI::UpgradeBridges()
{
	local railtype = AIRail.GetCurrentRailType();
	builder = cBuilder(this);
	builder.UpgradeRailBridges();
	AIRail.SetCurrentRailType(railtype);
	builder.UpgradeRoadBridges();
	builder = null;
	bridgesupgraded = AIDate.GetYear(AIDate.GetCurrentDate());
}

function SimpleAI::ListContainsValuator(item, list)
{
	return list.HasItem(item);
}
