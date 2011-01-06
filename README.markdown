Dungeon Clash
-------------

This aims to be a fun, mulitplayer fire-emblem type game. The design is 1 part fire emblem with 1 part pokemon. Two (or more) players have a troop of characters in a dungeon. Each character has a class, which has some combination of 4 moves. The players take turns moving these characters around, attacking, and in the end hopefully trying to defeat all of their opponents units.

Initially, there will just be both players units in the dungon, but eventually I hope to add
* treasure
* traps
* monsters
* and more.

This project uses [Oryx's lo-fi roguelike sprites](http://forums.tigsource.com/index.php?topic=8970.0) and the [permissive field of view implementation as seen on roguebasin](http://roguebasin.roguelikedevelopment.org/index.php?title=Ruby_precise_permissive_FOV_implementation). Both of these resources are sweet and better than I could make.

Usage
-----

You will need 3 terminals for this. Right now, the game automatically connects to localhost - I plan to change this, eventually, when I get to the point where I have a full game put together. Anyway, for now, run `ruby server.rb`, and two instances of `rsdl client.rb <player name>`

