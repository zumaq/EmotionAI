/**
* @author Michal Zopp
* @file road_blockades.nut
* @note original licence can be found in licence.txt
*/

/**
* @brief class Road Blockades
*/
class RoadBlockade
{
	_available_trains=array(0);
	_blocking_trains=array(0);

	constructor(){
	}

	/**
	* @brief BuildRoadBlockade, builds a interception to prevent cars from going in that road.
	* @param buildTile, the tile where you want to build the interception.
	* @param roadDirection, direction in which you want to build, 1 for x-axes, 0 for y-axes.
	*/
	function BuildRoadBlockade(buildTile, roadDirection);

	/**
	* @brief BuildTrain, builds a train in given depo
	* @param depoTile, tile of the depo where you build the Train
	*/
	function BuildTrain(depoTile);

	/**
	* @brief MakeBlockadePassable, makes the alredy built blockade passable again
	*/
	function MakeBlockadePassable();

	/**
	* @brief WhoDidTheBlockade, decited who did the blockade based on depo/tracks.
	* Returns false if it could no be decited.
	* @param tile, the tile where the blockade starts.
	* @param roadDirection, the direction where the road goes, so it can be determined.
	*/
	function WhoDidTheBlockade(tile, roadDirection);

    /**
    * @brief IsBlockadeOnPath, finds and returns tiles if there is a blockade on given path
    * if not return false.
    * @param path, the path you want to check
    */
    function IsBlockadeOnPath(path);

	/**
    * @brief FindGoodRoadTile, finds out where is the the nearest road and returns it;
    * @param tile, tile where is original depo
    */
	function FindGoodRoadTile(tile);

	/**
    * @brief  IsBlockadeInFrontOfDepo, finds out if there is a tile in front of depo, builds
	* another one and decreese karma points
    * @param depoTile, tile where is depo
    */
    function IsBlockadeInFrontOfDepo(depoTile);

	/**
	* @brief GetAroundBlockedTile, figures out the starting and ending point for the blockade
	* and builds it
	* @param tile, blocked tile
	*/
	function GetAroundBlockedTile(tile);

	/**
	* @brief GetAroundBlockade, calls functions to get around the blockade.
	* @param startTile, starting tile
	* @param endTile, ending tile
	*/
	function GetAroundBlockade(startTile, endTile);

	/**
	* @brief TurnAroundVehicles, this forces all the vehicles in param to turn around
	* and get over the potential blockade.
	* @param vehicles, list of vehicles you want to turn around
	*/
	function TurnAroundVehicles(vehicles);

	/**
	* @brief BuildBridge
	* @param startTile
	* @param endTile
	*/
	function BuildBridge(startTile, endTile);

	/**
	* @brief BuildTunnel
	* @param startTile
	* @param endTile
	*/
	function BuildTunnel(startTile, endTile);

	/**
	* @brief BuildRoad, builds the road based on the path
	* @param path, best path
	*/
	function BuildRoad(path);

	/**
	* @brief FindBestPath Finds the best path around the blockade
	* @param startTile, first tile
	* @param endTile, last tile
	*/
	function FindBestPath(startTile, endTile);

	/**
	* @brief Save saves all the data and returns it
	*/
	function Save();

	/**
	* @brief Load loads all data from parameter
	* @param data
	*/
	function Load(data);

}

function RoadBlockade::BuildRoadBlockade(buildTile, roadDirection){
	if (this._available_trains.len() != 0) {
		local locomotive = this._available_trains.pop();
		AIVehicle.StartStopVehicle(locomotive);
		AIController.Sleep(10);
		AIVehicle.StartStopVehicle(locomotive);

		AILog.Info("Resuming the train that was already built");
		this._blocking_trains.push(locomotive);
		return true;
	}

	local types = AIRailTypeList();
	AIRail.SetCurrentRailType(types.Begin());
	//1 is S to N, 0 is W to E
	if(roadDirection){
		AIRail.BuildRailTrack(buildTile, AIRail.RAILTRACK_NE_SW);
		AIRail.BuildRailDepot(buildTile - AIMap.GetTileIndex(1,0), buildTile)
		RoadBlockade.BuildTrain(buildTile - AIMap.GetTileIndex(1,0));
	}else{
		AIRail.BuildRailTrack(buildTile , AIRail.RAILTRACK_NW_SE);
		AIRail.BuildRailDepot(buildTile - AIMap.GetTileIndex(0,1), buildTile)
		RoadBlockade.BuildTrain(buildTile - AIMap.GetTileIndex(0,1));
	}
	return true;
}

function RoadBlockade::MakeBlockadePassable(){
	if(this._blocking_trains.len() == 0){
		return;
	}
	local locomotive = this._blocking_trains.pop();
	if (locomotive != null){
		AILog.Info("Sending train to depot");
		AIVehicle.StartStopVehicle(locomotive);
		AIVehicle.SendVehicleToDepot(locomotive);
		_available_trains.push(locomotive);
	}
}

function RoadBlockade::BuildTrain(depoTile){
	local vl = AIEngineList(AIVehicle.VT_RAIL);
	vl.Valuate(AIEngine.IsValidEngine);
	vl.KeepValue(1);
	vl.Valuate(AIEngine.IsBuildable);
	vl.KeepValue(1);
	vl.Valuate(AIEngine.IsWagon);
	vl.KeepValue(0);
	local locomotive_engine = vl.Begin();

	local locomotive = AIVehicle.BuildVehicle(depoTile, locomotive_engine);
	AIVehicle.StartStopVehicle(locomotive);
	AIController.Sleep(10);
	AIVehicle.StartStopVehicle(locomotive);
	this._blocking_trains.push(locomotive);
	return true;
}

function RoadBlockade::WhoDidTheBlockade(tile, roadDirection) {
	local candidateTile = tile;
	local x_coordinate = -1;
	local y_coordinate = -1;
	//1 is S to N, 0 is W to E
	if(roadDirection){
		while(AIRail.IsRailTile(candidateTile) && !AIRoad.IsRoadTile(candidateTile)){
			candidateTile = candidateTile + AIMap.GetTileIndex(x_coordinate,0);
			if(AIRail.IsDepoTile(candidateTile)){
				break;
			}
			if(!AIRail.IsRailTile(candidateTile)){
				x_coordinate = 1;
			}
		}
	}else{
		while(AIRail.IsRailTile(candidateTile) && !AIRoad.IsRoadTile(candidateTile)){
			candidateTile = candidateTile + AIMap.GetTileIndex(0,y_coordinate);
			if(AIRail.IsDepoTile(candidateTile)){
				break;
			}
			if(!AIRail.IsRailTile(candidateTile)){
				y_coordinate = 1;
			}
		}
	}
	local owner = AITile.GetOwner(candidateTile);
	return (owner > -1 && owner < 16) ? owner : false;
}

function RoadBlockade::IsBlockadeOnPath(_path) {
	if (_path == null) {
		AILog.Error("path is null");
		return false;
	}
	local path = _path
	local blockedTiles = array(0);
	while (path != null) {
		local par = path.GetParent();
		//AILog.Info("While Cycle tile:" + path.GetTile());
		if (par != null) {
			if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
				if (AIRail.IsLevelCrossingTile(par.GetTile())) {
					AILog.Info("Road is and intersection, punish the creator" + AITile.GetOwner(path.GetTile()));
					blockedTiles.push(par.GetTile());
				}
			}
		}
		path = par;
	}
	return (blockedTiles.len() != 0) ? blockedTiles : false;
}

function RoadBlockade::FindGoodRoadTile(tile){
	for (local k=0; k<4; k++){
		local candidateTile = tile + AIMap.GetTileIndex(-(k+1),-(k+1));
		for (local l = 0; l < 4; l++){
			for (local i = 0; i < 5; i++){
				if (AIRoad.IsRoadTile(candidateTile)
					&& !AIRail.IsRailTile(candidateTile)){
					return candidateTile;
				}
				if(l == 0){
					candidateTile = candidateTile + AIMap.GetTileIndex(0,1);
				}
				if(l == 1){
					candidateTile = candidateTile + AIMap.GetTileIndex(1,0);
				}
				if(l == 2){
					candidateTile = candidateTile + AIMap.GetTileIndex(0,-1);
				}
				if(l == 3){
					candidateTile = candidateTile + AIMap.GetTileIndex(-1,0);
				}
			}
		}
	}
}

function RoadBlockade::IsBlockadeInFrontOfDepo(depoTile){
	if (!AIRail.IsRailTile(AIRoad.GetRoadDepotFrontTile(depoTile))){
		AILog.Info("There is no blockade in front of depot tile");
		return null;
	}

	local roadTile = RoadBlockade.FindGoodRoadTile(depoTile);
	AILog.Info("Found Road Tile x: " + AIMap.GetTileX(roadTile) + " y: " + AIMap.GetTileY(roadTile));
	local newDepoTile = roadTile;

	if (AIRoad.BuildRoadDepot(newDepoTile + AIMap.GetTileIndex(0,1), roadTile)){
		return (newDepoTile + AIMap.GetTileIndex(0,1));
	}
	if (AIRoad.BuildRoadDepot(newDepoTile + AIMap.GetTileIndex(0,-1), roadTile)){
		return (newDepoTile + AIMap.GetTileIndex(0,-1));
	}
	if (AIRoad.BuildRoadDepot(newDepoTile + AIMap.GetTileIndex(1,0), roadTile)){
		return (newDepoTile + AIMap.GetTileIndex(1,0));
	}
	if (AIRoad.BuildRoadDepot(newDepoTile + AIMap.GetTileIndex(-1,0), roadTile)){
		return (newDepoTile + AIMap.GetTileIndex(-1,0));
	}
	AILog.Info("Couldn't find a good tile");
	return 0;
}

function RoadBlockade::GetAroundBlockedSwitchTile(tile){
	local startTile = tile;
	local endTile = tile;
	//determines what way the road goes and sets start and end tile
	if (AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(-1,0))){
		do {
			startTile = startTile + AIMap.GetTileIndex(-1,0);
		} while (AIRail.IsRailTile(startTile))
		do {
			endTile = endTile + AIMap.GetTileIndex(1,0);
		} while (AIRail.IsRailTile(endTile))
	}
	else {
		do {
			startTile = startTile + AIMap.GetTileIndex(0,-1);
		} while (AIRail.IsRailTile(startTile))
		do {
			endTile = endTile + AIMap.GetTileIndex(0,1);
		} while (AIRail.IsRailTile(endTile))

	}
	local tmp = startTile;
	startTile = endTile;
	endTile = tmp;
	AILog.Info("statTile x: " + AIMap.GetTileX(startTile)+ " y: " + AIMap.GetTileY(startTile));
	AILog.Info("endTile x: " + AIMap.GetTileX(endTile)+ " y: " + AIMap.GetTileY(endTile));
	local path = RoadBlockade.FindBestPath(startTile, endTile);
	if(path != false){
		return RoadBlockade.BuildRoad(path);
	} else {
		return false;
	}
}

function RoadBlockade::GetAroundBlockedTile(tile){
	local startTile = tile;
	local endTile = tile;
	//determines what way the road goes and sets start and end tile
	if (AIRoad.IsRoadTile(tile + AIMap.GetTileIndex(-1,0))){
		do {
			startTile = startTile + AIMap.GetTileIndex(-1,0);
		} while (AIRail.IsRailTile(startTile))
		do {
			endTile = endTile + AIMap.GetTileIndex(1,0);
		} while (AIRail.IsRailTile(endTile))
	}
	else {
		do {
			startTile = startTile + AIMap.GetTileIndex(0,-1);
		} while (AIRail.IsRailTile(startTile))
		do {
			endTile = endTile + AIMap.GetTileIndex(0,1);
		} while (AIRail.IsRailTile(endTile))

	}
	AILog.Info("statTile x: " + AIMap.GetTileX(startTile)+ " y: " + AIMap.GetTileY(startTile));
	AILog.Info("endTile x: " + AIMap.GetTileX(endTile)+ " y: " + AIMap.GetTileY(endTile));
	local path = RoadBlockade.FindBestPath(startTile, endTile);
	if(path != false){
		return RoadBlockade.BuildRoad(path);
	} else {
		return false;
	}
}

function RoadBlockade::GetAroundBlockade(startTile, endTile){
	local path = RoadBlockade.FindBestPath(startTile, endTile);
	RoadBlockade.BuildRoad(path);
}

function RoadBlockade::TurnAroundVehicles(vehicles){
	if(vehicles == null) {
		AILog.Warning("Vehicles are null!");
		return false;
	}
	local count = vehicles.len();
	for(local i = 0; i<count; ++i) {
		AIVehicle.ReverseVehicle(vehicles[i]);
	}
	return true;
}

function RoadBlockade::BuildBridge(startTile, endTile){
	if (AIRoad.IsRoadTile(startTile)) {
		AITile.DemolishTile(startTile);
	}
	local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(startTile, endTile) + 1);
	bridge_list.Valuate(AIBridge.GetMaxSpeed);
	bridge_list.Sort(AIList.SORT_BY_VALUE, true);
	if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), startTile, endTile)) {

	}
}

function RoadBlockade::BuildTunnel(startTile, endTile){

}

function RoadBlockade::BuildRoad(roadPath){
	local path = roadPath;
	local lastTile = null;
	while (path != null) {
		local par = path.GetParent();

		if (par != null) {
		  lastTile = path.GetTile();
			if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1){
				if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
				  AILog.Info("Problem, cant build road, could be already built.");
				  //if(AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY){
						while(AIRoad.BuildRoad(path.GetTile(), par.GetTile())){
							AILog.Info("building road, waiting for vehicle");
						}
				  //}
				}
			} else {
				RoadBlockade.BuildBridge(path.GetTile(), par.GetTile());
			}
		}
		path = par;
	}
}

function RoadBlockade::FindBestPath(startTile, endTile){
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

	local pathfinder = MyRoadPF();

	pathfinder._cost_level_crossing = 0xFFFFFF;
  /*
	pathfinder.cost.slope = -10;
	pathfinder.cost.max_bridge_length = 10;
	pathfinder.cost.max_cost = 50;
	pathfinder.cost.tile=10;
	pathfinder.cost.no_existing_road=-20;
	pathfinder.cost.turn=0;
  */
	pathfinder.cost.bridge_per_tile = 1;

	pathfinder.InitializePath([startTile], [endTile]);
	local counter = 0;
	local path = false;
	while (path == false && counter < 4) {
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
	return path;
}

function RoadBlockade::Save(){
	//AILog.Info("Road Blockade save");
	local data = {
		available_trains = this._available_trains,
		blocking_trains = this._blocking_trains
	};
	return data;
}

function RoadBlockade::Load(data){
	local blockade = RoadBlockade();
	blockade._available_trains = data.available_trains;
	blockade._blocking_trains = data.blocking_trains;

	return blockade;
}
