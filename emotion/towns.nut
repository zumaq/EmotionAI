/**
 * @author Michal Zopp
 * @file towns.nut
 */

 /** TODO: LOAD AND SAVE THE TOWN LIST
  * @brief class Towns, is a representation for each players cities, making construction work, etc.
  */
class Towns
{
	_town_list = null;
	_roadBlockade = null;

	constructor(){
		this._town_list = AIList();
		this._roadBlockade = RoadBlockade();
	}

	/**
	* @brief AddTown, adds the town to the list of towns and ratings
	* @param townId, id of the town you want to add
	* @param rating, rating the town has
	*/
	function AddTown(townId, rating);

	/**
	* @brief SortTownList, sorts the town list in order to pick the most for the
	* rating and make decisions based on that.
	*/
	function SortTownList();

	/**
	* @brief EmptyList, empties the list of towns and ratigins
	*/
	function EmptyList();

	/**
	* @brief BuildTownStatue, this chooses the most rating from towns(where can be applied)
	* and builds statue in town to increase rating.
	*/
	function BuildTownStatue();

	/**
	* @brief BribeTown, this chooses the most rating from towns(where can be applied)
	* and Bribes the town to increase rating.
	*/
	function BribeTown();

	/**
	* @brief RebuildRoads, this chooses the most rating from towns(where can be applied)
	* and funds the rebuilding of roads to increase rating and trap busses to enter city.
	*/
	function RebuildRoads();

	/**
	* @brief FundBuildings, this chooses the most rating from towns(where can be applied)
	* and funds the expanstion of buildings to increase rating.
	*/
	function FundBuildings();

	/**
	* @brief BuyRights, this chooses the most rating from towns(where can be applied)
	* and buys rights for building.
	*/
	function BuyRights();

	/**
	* @brief Advertise, this chooses the most rating from towns(where can be applied)
	* and funds a advertisement to increase rating.
	* @param size, size of advertisement, 0 = SMALL, 1 = MEDIUM, 2 = LARGE
	*/
	function Advertise(size);

	/**
	* @brief CheckAirportTiles, checks if there is a space around the center tile, with the distance,
	* returns the buildable tile, if not returns the original center tile.
	* @param tile, center tile of the city you want to build
	* @param distance, distance from the center tile you want to check.
	*/
	function CheckAirportTiles(tile, distance);

	/**
	* @brief BuildHeliPorts, build heliports in the most city rating a preson has to
	* avoid him getting to build airports.
	*/
	function BuildHeliPorts();

	/**
	* @brief RemoveRoadBeforeDepot, removes the road from the tile you get it from every direction.
	* @param tile, tile you want to remove completely.
	*/
	function RemoveRoadBeforeDepot(tile);

	/**
	* @brief BuildRailOnTile, builds a rail tile you cant build roads on a tile.
	* @param tile, tile you want to build on.
	*/
	function BuildRailOnTile(tile);

	/**
	* @brief DestroyDepoTileInCity, destroys and build rail in a tile that is right in front of depo.
	*/
	function DestroyDepoTileInCity();

	/**
	* @brief GetFourPointsAround, calculates 4 points around the city in the distance, return array
	* @param tile, center tile of the city you want to surround
	*/
	function GetFourPointsAround(tile);

	/**
	* @brief BuildRailsFromArray, builds a rail line from the 4 positions in array.
	* @param array, array you want to build from.
	*/
	function BuildRailsFromArray(array);

	/**
	* @brief BuildRailsAroundCity, builds rails in a x and y lines
	* @param tile, center tile of the city you want to surround
	*/
	function BuildRailsAroundCity(tile);

	/**
	* @brief SurroundCityWithRails, surround city with rails, in order to stop the growth of the city.
	*/
	function SurroundCityWithRails();

	/**
	* @brief CheckBlockadeCanBuild, checks if the blockade can be built, chcecks both directions and returns the better.
	* @param tile, tile to check,
	*/
	function CheckBlockadeCanBuild(tile);

	/**
	* @brief MakeBlockadePassable, this function sends the train to depot.
	*/
	function MakeBlockadePassable();

	/**
	* @brief ResumeStopedTrains, this function resumes the trains if built agains the player.
	*/
	function ResumeStopedTrains();

	/**
	* @brief BuildRoadBlockade, finds 2 best cities and build a blockade in the path.
	*/
	function BuildRoadBlockade();

	/**
	* @brief DecideAndPunish, this function decides what is the best way to punish the oponent
	* @param points, points that the player has to decide how to punish, range(0-100-200)
	*/
	function DecideAndPunish(points);

	/**
	* @brief DecideAndPunishMore, this function decides and punishes the player, but more!
	* @param points, points that the player has to decide how to punish, range(0-100-200)
	*/
	function DecideAndPunishMore(points);

	/**
	* @brief PrintTownRaiting, prints the town raiting and town names for the
	* particular player
	*/
	function PrintTownRatings();

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

function Towns::AddTown(townId, rating){
	if(!AITown.IsValidTown(townId)){
		return false;
	}
	this._town_list.AddItem(townId, rating);
	return true;
}

function Towns::SortTownList(){
	//_town_list.Valuate(AITown.GetRating); dosent need a valuator, there altredy is a value in the list
	this._town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
}

function EmptyList(){
	this._town_list.Clear();
}

function Towns::BuildTownStatue(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while (HasStatue(candidateTown) || this._town_list.GetValue(candidateTown) == 0) {
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if (AITown.IsActionAvailable(candidateTown, AITown.TOWN_ACTION_BUILD_STATUE)){
		return AITown.PerformTownAction(candidateTown, AITown.TOWN_ACTION_BUILD_STATUE);
	}
	return false;
}

function Towns::BribeTown(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while(!AITown.IsActionAvailable(candidateTown, AITown.TOWN_ACTION_BRIBE)){
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if(this._town_list.GetValue(candidateTown) == 0 ){
		return false;
	}
	return AITown.PerformTownAction(candidateTown, AITown.TOWN_ACTION_BRIBE);
}

function Towns::RebuildRoads(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	AILog.Info("Starting rebuild roads");
	while(!AITown.IsActionAvailable(candidateTown, AITown.TOWN_ACTION_ROAD_REBUILD)){
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if(this._town_list.GetValue(candidateTown) == 0 ){
		return false;
	}
	return AITown.PerformTownAction(candidateTown, AITown.TOWN_ACTION_ROAD_REBUILD);
}

function Towns::FundBuildings(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while(!AITown.IsActionAvailable(candidateTown, AITown.TOWN_ACTION_FUND_BUILDINGS)){
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if(this._town_list.GetValue(candidateTown) == 0 ){
		return false;
	}
	return AITown.PerformTownAction(candidateTown, AITown.TOWN_ACTION_FUND_BUILDINGS);
}

function Towns::BuyRights(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while(!AITown.IsActionAvailable(candidateTown, AITown.TOWN_ACTION_BUY_RIGHTS)){
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if(this._town_list.GetValue(candidateTown) == 0 ){
		return false;
	}
	return AITown.PerformTownAction(candidateTown, AITown.TOWN_ACTION_BUY_RIGHTS);
}

function Towns::Advertise(size){
	if (size != 0 || size != 1 || size != 2){
		return false;
	}
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while(!AITown.IsActionAvailable(candidateTown, size)){
		candidateTown = this._town_list.Next();
		AILog.Info("While cycle.");
		if(this._town_list.IsEnd()){
			return false;
		}
	}
	if(this._town_list.GetValue(candidateTown) == 0 ){
		return false;
	}
	return AITown.PerformTownAction(candidateTown, size);
}

function Towns::CheckAirportTiles(tile, distance){
	local candidateTile = tile + AIMap.GetTileIndex(-distance,-distance);
	local moves = distance * 2;
	for (local l = 0; l < 4; l++){
		for (local i = 0; i < moves; i++){
			AILog.Info("CheckAirportTiles cycle: " + i +
						"tile x: " + AIMap.GetTileX(candidateTile) + "tile y: " + AIMap.GetTileY(candidateTile));
			if (AITile.IsBuildable(candidateTile)){
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
	//this is here so that the for cycle has something to catch the build an continues, 1 tile always is false
	return tile;
}

function Towns::BuildHeliPorts(){
	if (!AIAirport.IsValidAirportType(AIAirport.AT_HELIPORT)){
		AILog.Info("Its not a time to build Helicopters yet");
		return false;
	}
	SortTownList();
	local candidateTown = this._town_list.Begin();
	while(AITown.GetAllowedNoise(candidateTown) == 0){
		candidateTown = this._town_list.Next();
	}
	if(this._town_list.IsEnd() || this._town_list.GetValue(candidateTown) == 0){
		return false;
	}
	local candidateTile = AITown.GetLocation(candidateTown);
	AILog.Info("town with tile: " + candidateTile + " has noise level: " + AITown.GetAllowedNoise(candidateTown));
	for (local i=0; !AIAirport.BuildAirport(candidateTile, AIAirport.AT_HELIPORT, AIStation.STATION_NEW); i++){
		AILog.Info("BuildHeliPorts cycle: " + i);
		candidateTile = Towns.CheckAirportTiles(candidateTile, i);
	}
	return candidateTile;
}

function Towns::CheckDepoTileInCity(tile, distance){
	local candidateTile = tile + AIMap.GetTileIndex(-distance,-distance);
	local moves = distance * 2;
	for (local l = 0; l < 4; l++){
		for (local i = 0; i < moves; i++){
			if (AIRoad.IsRoadDepotTile(candidateTile)
				&& !AICompany.IsMine(AITile.GetOwner(candidateTile))
				&& !AIRail.IsRailTile(AIRoad.GetRoadDepotFrontTile(candidateTile))){
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
	return tile;
}

function Towns::RemoveRoadBeforeDepot(tile){
	AIRoad.RemoveRoad(tile, tile + AIMap.GetTileIndex(0, 1));
	AIRoad.RemoveRoad(tile, tile + AIMap.GetTileIndex(1, 0));
	AIRoad.RemoveRoad(tile, tile + AIMap.GetTileIndex(0, -1));
	AIRoad.RemoveRoad(tile, tile + AIMap.GetTileIndex(-1, 0));
	Towns.BuildRailOnTile(tile);
}

function Towns::BuildRailOnTile(tile){
	local types = AIRailTypeList();
	AIRail.SetCurrentRailType(types.Begin());
	if (AITile.HasTreeOnTile(tile)) {
		AITile.DemolishTile(tile);
	}
	if (AIRail.IsRailTile(tile)){
		return false;
	}
	return (AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_NE)) ? true : AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SW);
}

function Towns::DestroyDepoTileInCity(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	if(this._town_list.IsEnd() || this._town_list.GetValue(candidateTown) == 0){
		return false;
	}

	local depoTile = AITown.GetLocation(candidateTown);
	for (local l=0; depoTile == AITown.GetLocation(candidateTown) && l < 2; l++){
		AILog.Info("Checking town with name: " + AITown.GetName(candidateTown));
		for (local i=0; depoTile == AITown.GetLocation(candidateTown) && i < 8; i++){
			AILog.Info("Depofinding cycle: " + i);
			depoTile = Towns.CheckDepoTileInCity(depoTile, i);
		}
		if (depoTile == AITown.GetLocation(candidateTown)){ // if you cant find one then check other city
			candidateTown = this._town_list.Next();
			depoTile = AITown.GetLocation(candidateTown);
			if(this._town_list.IsEnd()){
				return false;
			}
		}
	}

	if (depoTile != AITown.GetLocation(candidateTown)){
		local tile = AIRoad.GetRoadDepotFrontTile(depoTile);
		AILog.Info("Tile in front of the Depot x: " + AIMap.GetTileX(tile) + " y: " + AIMap.GetTileY(tile));
		Towns.RemoveRoadBeforeDepot(tile);
		return true;
	}
	return false;
}

function Towns::GetFourPointsAround(tile){
	local array = array(0);
	local candidateTile = null;
	local distance = 4;
	if (AITown.GetPopulation(AITile.GetTownAuthority(tile)) > 2500){
		distance = 7;
	}
	for (local l = 0; l < distance; ++l){
	candidateTile = tile;
		for (local i = 1; i < 6; ++i){
			if(l == 0){
				candidateTile = candidateTile + AIMap.GetTileIndex(-1,-1);
			}
			if(l == 1){
				candidateTile = candidateTile + AIMap.GetTileIndex(-1,1);
			}
			if(l == 2){
				candidateTile = candidateTile + AIMap.GetTileIndex(1,1);
			}
			if(l == 3){
				candidateTile = candidateTile + AIMap.GetTileIndex(1,-1);
			}
			if (AITile.IsBuildable(candidateTile)){
				AILog.Info("candidate Tile: " + candidateTile + " l = " + l + " i = " + i);
				array.push(candidateTile);
				break;
			}
			AILog.Info("Tile x: " + AIMap.GetTileX(candidateTile) + " y: "
						+ AIMap.GetTileY(candidateTile) + " l = " + l + " i = " + i);
		}
	}
	return (array.len() != 4) ? false : array;
}

//TODO: Funguje, ale niekedy su tam miesta prazdne.
function Towns::BuildRailsFromArray(array){
	local types = AIRailTypeList();
	AIRail.SetCurrentRailType(types.Begin());
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

	for (local i=0; i<4; ++i){
		local tile_a = array[i];
		local tile_b = null;
		if (i == 3){
			tile_b = array[0];
		} else {
			tile_b = array[i+1];
		}
		AILog.Info("tile a x: " + AIMap.GetTileX(tile_a) + "tile a y: " + AIMap.GetTileY(tile_a)
				+ "tile b x: " + AIMap.GetTileX(tile_b) + "tile b y: " + AIMap.GetTileY(tile_b));
		local pathfinder = RoadPathFinder();
		//pathfinder.cost.tile=50;
		pathfinder.cost.no_existing_road=-110;
		//pathfinder.cost.turn=5;
		pathfinder.cost.slope=0;
		pathfinder.cost.max_bridge_length=0;
		pathfinder.cost.max_tunnel_length=0;
		/*pathfinder.InitializePath([tile_a, tile_a + AIMap.GetTileIndex(-1, 0), tile_a + AIMap.GetTileIndex(1, 0),
								  tile_a + AIMap.GetTileIndex(0, -1), tile_a + AIMap.GetTileIndex(0, 1)],
								  [tile_b, tile_b + AIMap.GetTileIndex(-1, 0), tile_b + AIMap.GetTileIndex(1, 0),
								  tile_b + AIMap.GetTileIndex(0, -1), tile_b + AIMap.GetTileIndex(0, 1)]);*/
		pathfinder.InitializePath([tile_a], [tile_b]);

		local path = false;
		while (path == false) {
			path = pathfinder.FindPath(50);
			AIController.Sleep(1);
		}
		if (path == null) {
			/* No path was found. */
			AILog.Error("pathfinder.FindPath return null");
			continue;
		}

		path = path.GetParent();
		while (path != null) {
			local par = path.GetParent();
			if (par != null) {
				Towns.BuildRailOnTile(path.GetTile());
				AILog.Info("tile a x: " + AIMap.GetTileX(path.GetTile()) + "tile a y: " + AIMap.GetTileY(path.GetTile()));
			}
			path = par;
		}
	}
}

function Towns::BuildRailsAroundCity(tile){
	local candidateTile = tile;
	local buildTile = null;
	local distance = 4;
	if (AITown.GetPopulation(AITile.GetTownAuthority(tile)) > 2500){
		distance = 6;
	}
	for (local l=0; l<2; l++){
		if (l == 0){
			candidateTile = tile + AIMap.GetTileIndex(0, -distance);
		}
		if (l == 1){
			candidateTile = tile + AIMap.GetTileIndex(-distance, 0);
		}
		for (local i=0; i<2*distance; i++){
			if(l == 0){
				candidateTile = candidateTile + AIMap.GetTileIndex(0,1);
			}
			if(l == 1){
				candidateTile = candidateTile + AIMap.GetTileIndex(1,0);
			}
			buildTile = candidateTile;
			for (local k=0; k<2; k++){
				while (!Towns.BuildRailOnTile(buildTile) || !AIRail.IsRailTile(buildTile)){
					if (l == 0){
						if (k == 0) {
							buildTile = buildTile + AIMap.GetTileIndex(-1,0);
						}
						if (k == 1){
							buildTile = buildTile + AIMap.GetTileIndex(1,0);
						}
					}
					if (l== 1){
						if (k == 0) {
							buildTile = buildTile + AIMap.GetTileIndex(0,-1);
						}
						if (k == 1){
							buildTile = buildTile + AIMap.GetTileIndex(0,-1);
						}
					}
				}
				AILog.Info("Build tile on x: " + AIMap.GetTileX(buildTile) + " y: " + AIMap.GetTileY(buildTile));
			}
		}
	}
}

function Towns::SurroundCityWithRails(){
	SortTownList();
	local candidateTown = this._town_list.Begin();
	//candidateTown = this._town_list.Next();
	local candidateTile = AITown.GetLocation(candidateTown);
	AILog.Info("Surround city: " + candidateTown + " value: " + this._town_list.GetValue(candidateTown));
	if(this._town_list.IsEnd() || this._town_list.GetValue(candidateTown) == 0){
		return false;
	}

	//this.BuildRailsAroundCity(candidateTile);
	local array = GetFourPointsAround(candidateTile);

	if(array == false){
		AILog.Info("Couldn't find a path");
		return false;
	}

	this.BuildRailsFromArray(array);
}

function Towns::CheckBlockadeCanBuild(tile){
	if (AITile.IsBuildable(tile + AIMap.GetTileIndex(0,-1))
		&& AITile.GetSlope(tile + AIMap.GetTileIndex(0,-1)) == AITile.SLOPE_FLAT
		&& AIRoad.AreRoadTilesConnected(tile, tile + AIMap.GetTileIndex(1, 0))
		&& AIRoad.AreRoadTilesConnected(tile, tile + AIMap.GetTileIndex(-1, 0))) {
		return 0;
	}
	if (AITile.IsBuildable(tile + AIMap.GetTileIndex(-1,0))
		&& AITile.GetSlope(tile + AIMap.GetTileIndex(-1,0)) == AITile.SLOPE_FLAT
		&& AIRoad.AreRoadTilesConnected(tile, tile + AIMap.GetTileIndex(0, 1))
		&& AIRoad.AreRoadTilesConnected(tile, tile + AIMap.GetTileIndex(0, -1))) {
		return 1;
	}
	return false;
}

function Towns::MakeBlockadePassable(){
	this._roadBlockade.MakeBlockadePassable();
}

function Towns::ResumeStopedTrains(){
	SortTownList();
	local firstTown = this._town_list.Begin();
	if(this._town_list.IsEnd() || this._town_list.GetValue(firstTown) == 0){
		return false;
	}
	//there is no way that you can build in center tile,
	//so this is here just to call resume trains if possible
	this._roadBlockade.BuildRoadBlockade(AITown.GetLocation(firstTown), 1);
}

function Towns::BuildRoadBlockade(){
	SortTownList();
	local firstTown = this._town_list.Begin();
	local secondTown = this._town_list.Next();
	if(this._town_list.IsEnd() || this._town_list.GetValue(firstTown) == 0
		|| this._town_list.GetValue(secondTown) == 0){
		return false;
	}
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	AILog.Info("1: " + AITown.GetName(firstTown) + "2: " + AITown.GetName(secondTown));
	local pathfinder = RoadPathFinder();
	//pathfinder.cost.tile=1000;
	pathfinder.cost.no_existing_road=20000;
	pathfinder.InitializePath([AITown.GetLocation(firstTown)], [AITown.GetLocation(secondTown)]);

	local path = false;
	while (path == false) {
		path = pathfinder.FindPath(100);
		AIController.Sleep(1);
	}
	if (path == null) {
		/* No path was found. */
		AILog.Error("pathfinder.FindPath return null");
		// try to call if there are available locomotives in depots
		// if there are not, the function will fail it is ok.
		this._roadBlockade.BuildRoadBlockade(AITown.GetLocation(firstTown), 1);
		return;
	}

	local direction = false;
	path = path.GetParent();
	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
			direction = this.CheckBlockadeCanBuild(path.GetTile());
			AILog.Info("tile x: " + AIMap.GetTileX(path.GetTile()) + "tile y: " + AIMap.GetTileY(path.GetTile()));
			if (direction != false){
				this._roadBlockade.BuildRoadBlockade(path.GetTile(),direction);
				AILog.Info("!!Building blockade on tile x: " + AIMap.GetTileX(path.GetTile())
							+ "tile y: " + AIMap.GetTileY(path.GetTile()));
				break;
			}
		}
		path = par;
	}
}

function Towns::DecideAndPunish(points){
	//points - 0 100 200 case has bad syntax
	if (points > 140) {
		Towns.Advertise((points-140) % 20);
		return;
	} else if (points > 120) {
		Towns.BuildTownStatue();
		return;
	} else if (points > 100) {
		Towns.FundBuildings();
		return;
	} else if (points > 80) {
		Towns.RebuildRoads();
		return;
	} else if (points > 60) {
		Towns.BuyRights();
		return;
	} else if (points > 40) {
		Towns.BribeTown();
		return;
	}
}

function Towns::DecideAndPunishMore(points){
	if (points > 120) {
		Towns.BuildRoadBlockade();
		return;
	} else if (points > 100) {
		Towns.DestroyDepoTileInCity();
		return;
	} else if (points > 80) {
		Towns.BuildHeliPorts();
		return;
	} else if (points > 60) {
		Towns.SurroundCityWithRails();
		return;
	} else if (points > 40) {
		//Towns.BribeTown();
		return;
	}
}

function Towns::PrintTownRatings(){
	for(local l = this._town_list.Begin(); !this._town_list.IsEnd(); l = this._town_list.Next()) {
		AILog.Info("- -> Town Name: " + AITown.GetName(l) + " has rating: " + this._town_list.GetValue(l));
	}
}

function Towns::Save(){
	//AILog.Info("Towns save");
	local data = {
		road_blockade = this._roadBlockade.Save()
	};
	return data;
}

function Towns::Load(data){
	local towns = Towns();
	if(data.rawin("road_blockade")){
		towns._roadBlockade.Load(data["road_blockade"]);
	}
	return towns;
}
