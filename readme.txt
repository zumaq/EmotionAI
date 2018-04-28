SimpleAI v12 - 2017/05/10
------------------------

Contents
--------
1. Introduction
2. Usage
3. Parameters
4. Recommended configuration
5. Dependencies
6. License
7. Support

1. Introduction
---------------
SimpleAI is an AI written for OpenTTD, which tries to imitate the old AI 
(the one which was present in TTD, and OpenTTD versions until 0.6.3) in
its playing style.
The AI builds simple point-to-point routes using road vehicles, trains
and aircraft. Station layout is similar to that of the old AI.
SimpleAI supports all default cargoes, but it will try to use most NewGRF
cargoes as well.

2. Usage
--------
This AI can be used just like any other AI, see http://wiki.openttd.org/AI_settings
for details.

3. Parameters
-------------
Number of days to start this AI after the previous one (give or take) - You can configure
how much time the AI will wait before founding its company.

Use trains - Allows/disallows building trains for SimpleAI.

Use road vehicles - Allows/disallows building road vehicles for SimpleAI.

Use aircraft - Allows/disallows building aircraft for SimpleAI.

Note: If you disallow using a specific vehicle type for all AIs in the Advanced settings,
these settings are overridden. However, if you want to change these settings during the
game, changing the AI's own settings is preferred, as it still allows to finish the route
under construction and to maintain existing vehicles.

Build new routes if transported percentage is smaller than this value - With this setting
you can configure how much SimpleAI will compete with other companies. The higher the value,
the more competitive SimpleAI will be. When building a new connection, firstly it checks
how much of the cargo is transported from the given industry by other companies. If it is
higher than this value, the AI will move on to another industry.

The chance of taking subsidies - This setting allows you to configure how much the AI will
go for subsidies. The AI will ignore subsudies if it is set to 0, and will always try to get
subsidies if it is set to 10. It is recommended to set it to a lower value if more instances
of SimpleAI are present in the game.

The maximum number of road vehicles on a route - You can configure how much road vehicles
are allowed to run on a single route. This is useful to avoid congestion.

Days to wait between building two routes - If a new route is built successfully, the AI will
wait for the configured time before it tries to build a new one. If this setting is set to 0,
the AI will try to build a new route immediately after the previous one.

Slowdown effect (how much the AI will become slower over time) - If this is enabled, the
waiting time defined in the previous setting will increase over time. With this the AI
will slow down if it has plenty of routes. You can configure how fast the waiting time
will increase.

Build company headquarters near towns - If on, the AI will build its HQ in a town.
Otherwise it will build its HQ near its first station. (old AI behaviour)

Use a custom company name - If on, the AI will use a new naming scheme instead of the
"<town name> Transport" style.

Signal type to be used - You can configure the type of signals used by the AI. Path signals
allow the closing of level crossings much before the train arrives, thus protecting road
vehicles from collision, but they may increase congestion on the roads.

Use NewGRF rail stations if available - If enabled, the AI will try to use NewGRF rail
stations for freight trains. Tested with the Industrial Stations Renewal 0.8.0.

4. Recommended configuration
----------------------------
SimpleAI is not compatibile with articulated road vehicles (it is no problem if there
are articulated vehicles present, the AI just won't use them).

It is also recommended to enable building on slopes, as the AI doesn't terraform while
building tracks.

Disabling 90 degree turns for trains may cause problems, as trains may take 90 degree
turns to enter the depot at double rail stations.

This AI is suitable for running multiple instances of it, although it is better to lower
the subsidy chance factor if you're using multiple instances, so that not all instances
will try to build at the same place when a new subsidy appears.

5. Dependencies
---------------
SimpleAI depends on the following libraries:
- Pathfinder.Road v4
- Pathfinder.Rail v1
- Graph.AyStar v4 (a dependency of the rail pathfinder)
- Graph.AyStar v6 (a dependency of the road pathfinder)
- Queue.BinaryHeap v1 (a dependency of Graph.AyStar)
If you downloaded this AI from the in-game content downloading system, these libraries
also got installed automatically. However if you downloaded this AI manually from the
forums or somewhere else, then you need to install these libraries as well.
The libraries can be downloaded here: http://noai.openttd.org/downloads/Libraries/
Install these libraries into the ai/library subdirectory of OpenTTD.


6. License
----------
SimpleAI is licensed under version 2 of the GNU General Public License. See license.txt
for details.
SimpleAI reuses code from NoCAB (Terraform.nut), PAXLink (cBuilder::CostToFlattern) and
DictatorAI (cBuilder::GetEngineEfficiency, cBuilder::GetEngineRawEfficiency).
The AI contains code contributed by 3iff: setcompanyname.nut

7. Support
----------
Discussion about SimpleAI can be found here: http://www.tt-forums.net/viewtopic.php?f=65&t=44809
You're welcome to post bug reports and other comments :)