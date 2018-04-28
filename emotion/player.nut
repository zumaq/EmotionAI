/**
 * @author Michal Zopp
 * @file player.nut
 */

require("towns.nut");

 /** TODO: LOAD AND SAVE THE PLAYERS WITH POINTS
  * @brief class Player, don't be fooled by the name. The name just states and handles
  *  one company as a one player. But in reality you can cooperate with other players
  *  in the same company. Currently Maximum Number of companies that can be on a server is 15.
  */
class Player
{
	static MAX_KARMA_POINTS = 200; // Maximum points you can have
	static DEFAULT_KARMA_POINTS = 100; // Default poins for karma
	static MIN_KARMA_POINTS = 0; // Minimum points you can have
	_player_id = null;
	_road_blockade_tiles = null; //this is a array of blocked tiles by the particular player
    _station_tiles = null; //this is an array of stations near mine, that are getting my passangers !
	_karma_points = null;
	_quotient = null; //quotient that represents how much the player gets points, depending
					  //on previous actions.
	_towns=null;

	constructor(id){
		this._player_id = id;
		this._road_blockade_tiles = array(0);
        this._station_tiles = array(0);
		this._towns = Towns();
		this._karma_points = DEFAULT_KARMA_POINTS;
		_quotient = 1;
	}

	function AddKarmaPoints(points);

	function ResetKarmaPoints();

	function AddRoadBlockedTile(tile);

    function AddStationTile(tile);

	function AddTown(townId);

	function ClearTowns();

	function PunishPlayer();

	function MorePunishPlayer();

	function CheckRoadBlockedTiles();

	function CheckStationTiles();

	function CalculateKarmaPointsForStation(tile);

	function RemoveRoadBlockedTile(tile);

	function RemoveStationTile(tile);

	function IsRoadBlockedTileSet(tile);

	function IsStationTileSet(tile);

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

function Player::AddKarmaPoints(points){
	this._karma_points = this._karma_points + (points * _quotient);

	// distribute the points
	if(this._karma_points > MAX_KARMA_POINTS){
		this._karma_points = MAX_KARMA_POINTS;
	}
	if(this._karma_points < MIN_KARMA_POINTS){
		this._karma_points = MIN_KARMA_POINTS;
	}

	//calculate new _quotient based on the points gained.
	if (points < 0){
		_quotient = _quotient * 1.2
	} else {
		_quotient = _quotient * 0.8
	}
	return this._karma_points
}

function Player::ResetKarmaPoints(){
	this._karma_points = DEFAULT_KARMA_POINTS;
	return true;
}

function Player::AddRoadBlockedTile(tile){
	if (Player.IsRoadBlockedTileSet(tile) != false) {
		AILog.Info("This tile was already set.");
		return false;
	}
	this._road_blocked_tile.push(tile);
	return true;
}

function Player::AddStationTile(tile){
	if (Player.IsStationTileSet(tile) != false) {
		AILog.Info("This tile was already set.");
		return false;
	}
	this._station_tiles.push(tile);
	return true;
}

function Player::AddTown(townId){
	local rating = AITown.GetRating(townId, this._player_id);
	return this._towns.AddTown(townId, rating);
}

function Player::ClearTowns(){
	this._towns.EmptyList();
}

function Player::CheckAndPunish(){
	if (this._karma_points >= 150){
		AILog.Info("Player has > 150 karma points, he is ok, removes blockade if any");
		this._towns.MakeBlockadePassable();
		return false;
	}

	if (this._karma_points >= 100 || this._quotient > 1){
		AILog.Info("Player has > 100 karma points, he gets light punish");
		this.LightPunishPlayer();
		return true;
	}

	AILog.Info("Player has >50 & <100 karma points, he gets more punish");
	this.MorePunishPlayer();
	return true;
}

function Player::LightPunishPlayer(){
	this._towns.DecideAndPunish(this._karma_points);
}

function Player::MorePunishPlayer(){
	this._towns.DecideAndPunishMore(this._karma_points);
}

function Player::CheckRoadBlockedTiles(){
	local count = this._road_blockade_tiles.len()-1;
  if (count == -1){
    return;
  }
	for(local i = count; i >= 0; --i) {
		if (!AIRail.IsRailTile(this._road_blockade_tiles[i])) {
			this.RemoveRoadBlockedTile(this._road_blockade_tiles[i]);
		}
	}
}

function Player::CheckStationTiles(){
	local count = this._station_tiles.len() - 1;
  if (count == -1){
    return;
  }
	for(local i = count; i >= 0; --i) {
    AILog.Info("cycle" + i);
		if (!AIRail.IsRailStationTile(this._station_tiles[i]) &&
        !AIRoad.IsRoadStationTile(this._station_tiles[i]) &&
        !AIAirport.IsAirportTile(this._station_tiles[i])) {
			this.RemoveStationTile(this._station_tiles[i]);
		}
	}
}

function Player::CalculateKarmaPointsForStation(tile){
  if (AIRoad.IsRoadStationTile(tile)){
    this.AddKarmaPoints(30);
    AILog.Info("RoadStation Tile");
    return;
  }
  if (AIRail.IsRailStationTile(tile)){
    this.AddKarmaPoints(5);
    AILog.Info("Rail Station Tile");
    return;
  }
  if (AIAirport.IsAirportTile(tile)){
    this.AddKarmaPoints(7);
    AILog.Info("Airport Tile");
    return;
  }
}

function Player::RemoveRoadBlockedTile(tile){
	local index = Player.IsRoadBlockedTileSet(tile);
	AILog.Info("Removeing Tile: " + tile + " with index: " + index);
	this._road_blockade_tiles.remove(index);
	this.CalculateKarmaPointsForStation(tile); //player has removed blockade so he deserves points.
	return true;
}

function Player::RemoveStationTile(tile){
	local index = Player.IsStationTileSet(tile);
	AILog.Info("Removeing Station Tile: " + tile + " with index: " + index);
	this._station_tiles.remove(index);
  this.CalculateKarmaPointsForStation(tile); //player has removed blockade so he deserves points.
	return true;
}

function Player::IsRoadBlockedTileSet(tile){
	local count = this._road_blockade_tiles.len();
	for(local i = 0; i < count; ++i) {
		if (this._road_blockade_tiles[i] == tile) {
			return i;
		}
	}
	return false;
}

function Player::IsStationTileSet(tile){
	local count = this._station_tiles.len();
	for(local i = 0; i < count; ++i) {
    AILog.Info("station tile set cycle" + i);
		if (this._station_tiles[i] == tile) {
			return i;
		}
	}
	return false;
}

function Player::Save(){
	//AILog.Info("Player save");
	local townsList = this._towns.Save();
	local data = {
		id = this._player_id,
		karma_points = this._karma_points.tointeger(),
		quotient = this._quotient.tointeger()
	};
	//AILog.Info("quotient: " + data.quotient);
	data.rawset("road_blocked_tiles", this._road_blockade_tiles);
	data.rawset("station_blocked_tiles", this._station_tiles);
	data.rawset("towns", townsList);
	return data;
}

function Player::Load(data){
	local player = Player(data["id"]);
	player._karma_points = data.rawget("karma_points");
	player._quotient = data.rawget("quotient");
	if(data.rawin("road_blocked_tiles")) player._road_blockade_tiles = data.rawget("road_blocked_tiles");
	if(data.rawin("station_blocked_tiles")) player._station_tiles = data.rawget("station_blocked_tiles");
	if(data.rawin("towns")) player._towns = Towns.Load(data.rawget("towns"));
	
	return player;
}
