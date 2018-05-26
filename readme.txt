EmotionAI v1 - 2018/03/12
------------------------

Introduction
---------------
EmotionAI is my first attempt to create an AI that responds to an interaction
from other players.
AI in OpenTTD in general are pretty "dumb" in a way that if you start making
their existance hard, for example place a road blockade on a path, they will
do nothing about that and start loosing heavy money on that path.

So EmotionAI "scans" her paths and is looking for a intervention from other player,
if something like this is found she will make adjustments to that path (build a
workaround or so on).
EmotionAI checks if some player:
  - destroyed a path
  - tries to steel material from her stations
  - tries to block her path
  - destroyed a path in form of her depot

EmotionAI also has a mechanism to "attack back" the author of those things.
She has a model, in which she stores players "karma" points and if they have low
enough makes an attack back.
Attack include:
  - blocking players path with road blockade
  - destroying his road tile in a path of his vehicles
  - buys rights/advertisement/rebuilds roads in a players city
  - surrounds his city with rails in order to stop the city growth

The building and money portion of the AI is from SimpleAI by Brumi.

Dependencies
---------------
EmotionAI depends on the following libraries:
- Pathfinder.Road v4
- Pathfinder.Rail v1
- Graph.AyStar v4 (a dependency of the rail pathfinder)
- Graph.AyStar v6 (a dependency of the road pathfinder)
- Queue.BinaryHeap v1 (a dependency of Graph.AyStar)

License
----------
EmotionAI is licensed under version 2 of the GNU General Public License. See license.txt
for details.
EmotionAI reuses code from SimpleAI, all files are named in their headers and
rightfully stated where is the code originated from and if it was modified.
