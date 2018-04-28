class MyRoadPF extends RoadPathFinder
{
		_cost_level_crossing = null;
		_goals = null;
}

/**
 * Overrides the road pathfinder's InitialzePath function in order to store the goals.
 * This is needed to avoid having roads ending with a bridge.
 */
function MyRoadPF::InitializePath(sources, goals)
{
	::RoadPathFinder.InitializePath(sources, goals);
	_goals = AIList();
	for (local i = 0; i < goals.len(); i++) {
		_goals.AddItem(goals[i], 0);
	}
}

/**
 * Overrides the road pathfinder's _Cost function to add a penalty for level crossings.
 */
function MyRoadPF::_Cost(self, path, new_tile, new_direction)
{
	local cost = ::RoadPathFinder._Cost(self, path, new_tile, new_direction);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) cost += self._cost_level_crossing;
	return cost;
}

/**
 * Overrides the road pathfinder's _GetTunnelsBridges function in order to enable the AI
 * to build road bridges on flat terrain. (e.g. to avoid level crossings)
 */
function MyRoadPF::_GetTunnelsBridges(last_node, cur_node, bridge_dir)
{
	local slope = AITile.GetSlope(cur_node);
	if (slope == AITile.SLOPE_FLAT && AITile.IsBuildable(cur_node + (cur_node - last_node))) return [];
	local tiles = [];
	for (local i = 2; i < this._max_bridge_length; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		if (!bridge_list.IsEmpty() && !_goals.HasItem(target) &&
				AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), cur_node, target)) {
			tiles.push([target, bridge_dir]);
		}
	}

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
			prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir]);
	}
	return tiles;
}

class MyRailPF extends RailPathFinder
{
		_cost_level_crossing = null;
}

/**
 * Overrides the rail pathfinder's _Cost function to add a penalty for level crossings.
 */
function MyRailPF::_Cost(path, new_tile, new_direction, self)
{
	local cost = ::RailPathFinder._Cost(path, new_tile, new_direction, self);
	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_ROAD)) cost += self._cost_level_crossing;
	return cost;
}

