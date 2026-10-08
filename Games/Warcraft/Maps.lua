-- Warcraft III maps: a grid of text, one character per tile.
--   .  open ground        T  tree
--   1..9  a start (the top-left tile of its 4 x 4 hall)
--   G  a gold mine (the top-left tile of its 3 x 3 footprint)
--   S  a shop for everyone (the top-left tile of its 2 x 2 footprint): a Goblin Merchant
--   X  a Mercenary Camp (2 x 2): hire creeps there
--   e m h  a creep camp: easy, medium, hard (its middle; Creeps.lua)
-- mode: the game mode the map is for ("melee", "footmen", "td", "hd").
-- symmetry "rot180": the map is the same turned round (start 1 <-> 2,
-- 3 <-> 4), so both sides are fair; the tests check it. Made by a script
-- (dev/make_maps.py), but fine to edit by hand: keep it symmetric.
-- players: how many starts it has (a map fits games of that many or fewer).
local ADDON, ns = ...
local WC = ns.WC
WC.Maps = {}
WC.MAP_ORDER = {}

WC.Maps.riverford = { name = "Riverford", players = 2, symmetry = "rot180", mode = "melee",
    text = "The first map: two bases in opposite corners, a gold mine each and one to expand to.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT.................TTT........................................TT",
        "TT.................TTT........................................TT",
        "TT............G....TTT..........e.............................TT",
        "TT.................TTT........................................TT",
        "TT....1............TTTTTT...TT......TT.........m..............TT",
        "TT.................TTTTTT...TT......TT...........G............TT",
        "TT..........................TT............X...................TT",
        "TT..........................TT................................TT",
        "TT........................TTTT................................TT",
        "TT........................TTT.................................TT",
        "TTTTTTTTTT................TTT...........S.....................TT",
        "TTTTTTTTTT................TTT.................................TT",
        "TTTTTTTTTT................TTT.................................TT",
        "TTTTTTTTTT...........TT.......................................TT",
        "TT........TTT........TT.......................................TT",
        "TT........TTT........TT.........h.............................TT",
        "TT........TTT.................TTTT............................TT",
        "TT............................TTTT............................TT",
        "TT............................TTTT............................TT",
        "TT............................TTTT.................TTT........TT",
        "TT.............................h.........TT........TTT........TT",
        "TT.......................................TT........TTT........TT",
        "TT.......................................TT...........TTTTTTTTTT",
        "TT.................................TTT................TTTTTTTTTT",
        "TT....................S............TTT................TTTTTTTTTT",
        "TT.................................TTT................TTTTTTTTTT",
        "TT.................................TTT........................TT",
        "TT................................TTTT........................TT",
        "TT..........G.......X.............TT..................2.......TT",
        "TT................................TT..........................TT",
        "TT........................TT......TT...TTTTTT.................TT",
        "TT..............m.........TT......TT...TTTTTT..G..............TT",
        "TT........................................TTT.................TT",
        "TT.............................e..........TTT.................TT",
        "TT........................................TTT.................TT",
        "TT........................................TTT.................TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "riverford")

WC.Maps.echo_ford = { name = "Echo Ford", players = 2, symmetry = "rot180", mode = "melee",
    text = "Bigger (80 x 56): a forest band splits the map, crossed at three fords. A natural expansion by each base, two contested mines in the middle.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT............................................................................TT",
        "TT............................................................................TT",
        "TT.............G..................................TTTTTT......................TT",
        "TT................................................TTTTTT......................TT",
        "TT....1.......................e...................TTTTTT......................TT",
        "TT................................................TTTTTT......................TT",
        "TT....................TTTT................S.......TTTTTT......................TT",
        "TT....................TTTT........................TTTTTT......................TT",
        "TT....................TTTT....................................................TT",
        "TT....................TTTT....................................................TT",
        "TT....................TTTT....................................................TT",
        "TT....................TTTT....................................................TT",
        "TT........TTTTTT......TTTT....................................................TT",
        "TT........TTTTTT......TTTT....................................................TT",
        "TT........TTTTTT......TTTT..........G...........TTTT..........................TT",
        "TT....................TTTT......................TTTT..........................TT",
        "TT..............................................TTTT................X.........TT",
        "TT..............................................TTTT..........................TT",
        "TT..G..................................h......................................TT",
        "TT............................................................................TT",
        "TT............................................................................TT",
        "TT......m.....................................................................TT",
        "TT..................................TTTTTTTTTT................................TT",
        "TT..................................TTTTTTTTTT................................TT",
        "TTTTTTTTTTTTTT.....TTTTTTTTTTTTT....TTTTTTTTTT................................TT",
        "TTTTTTTTTTTTTT.....TTTTTTTTTTTTT................TTTTTTTTTTTTT.....TTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTT.....TTTTTTTTTTTTT................TTTTTTTTTTTTT.....TTTTTTTTTTTTTT",
        "TT................................TTTTTTTTTT....TTTTTTTTTTTTT.....TTTTTTTTTTTTTT",
        "TT................................TTTTTTTTTT..................................TT",
        "TT................................TTTTTTTTTT..................................TT",
        "TT.....................................................................m......TT",
        "TT.......................................................................G....TT",
        "TT............................................................................TT",
        "TT......................................h.....................................TT",
        "TT........X.................TTTT..............................................TT",
        "TT..........................TTTT.........G....................................TT",
        "TT..........................TTTT......................TTTT....................TT",
        "TT..........................TTTT......................TTTT......TTTTTT........TT",
        "TT....................................................TTTT......TTTTTT........TT",
        "TT....................................................TTTT......TTTTTT........TT",
        "TT....................................................TTTT....................TT",
        "TT....................................................TTTT....................TT",
        "TT....................................................TTTT....................TT",
        "TT....................................................TTTT....................TT",
        "TT......................TTTTTT......S.................TTTT............2.......TT",
        "TT......................TTTTTT........................TTTT....................TT",
        "TT......................TTTTTT................................................TT",
        "TT......................TTTTTT...................e............G...............TT",
        "TT......................TTTTTT................................................TT",
        "TT......................TTTTTT................................................TT",
        "TT............................................................................TT",
        "TT............................................................................TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "echo_ford")

WC.Maps.lost_grove = { name = "Lost Grove", players = 2, symmetry = "rot180", mode = "melee",
    text = "Square (64 x 64), bases top and bottom. A walled grove in the centre holds two mines; the side paths go round it.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT............................................................TT",
        "TT....................G.......................................TT",
        "TT............................1...............................TT",
        "TT............................................................TT",
        "TT............................................e...............TT",
        "TT............................................................TT",
        "TT..........TTTT..............................................TT",
        "TT..........TTTT..............................................TT",
        "TT..........TTTT........................TTTTTT................TT",
        "TT..........TTTT........................TTTTTT................TT",
        "TT......................................TTTTTT................TT",
        "TT......................................TTTTTT................TT",
        "TT..G...................................TTTTTT................TT",
        "TT......................................TTT...................TT",
        "TT..........................................X.................TT",
        "TT............................................................TT",
        "TT....m.......................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TT....................TT................TT....................TT",
        "TT......S.............TT..G.............TT....................TT",
        "TT....................TT......h....G....TT....................TT",
        "TT....................TT.........h......TT............S.......TT",
        "TT....................TT................TT....................TT",
        "TT....................TT................TT....................TT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TT......................TTTTTT....TTTTTT......................TT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT........................TTTTTTTTTTTTTTTTTTTT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT.......................................................m....TT",
        "TT................X...........................................TT",
        "TT.......................................................G....TT",
        "TT...................TTT......................................TT",
        "TT................TTTTTT......................................TT",
        "TT................TTTTTT......................................TT",
        "TT................TTTTTT......................................TT",
        "TT................TTTTTT........................TTTT..........TT",
        "TT................TTTTTT........................TTTT..........TT",
        "TT..............................................TTTT..........TT",
        "TT..............................................TTTT..........TT",
        "TT............................2...............................TT",
        "TT...............e............................................TT",
        "TT.....................................G......................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "lost_grove")

WC.Maps.duel_pass = { name = "Duel Pass", players = 2, symmetry = "rot180", mode = "melee",
    text = "Small and quick (48 x 32): one mine each, a pass in the middle and a long way round. Rush or be rushed.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT..............TTTT..........................TT",
        "TT.........G....TTTT..........................TT",
        "TT..1...........TTTT..........................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT......e...................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT..........................TT",
        "TT..............TTTT..........S...............TT",
        "TT..............TTTT........T....TTTTTTTTTTTTTTT",
        "TT..........................T....TTTTTTTTTTTTTTT",
        "TT..........................TTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTT..........................TT",
        "TTTTTTTTTTTTTTT....T..........................TT",
        "TTTTTTTTTTTTTTT.S..T........TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT........2.....TT",
        "TT...................e......TTTT..............TT",
        "TT..........................TTTT..G...........TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TT..........................TTTT..............TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "duel_pass")

WC.Maps.four_crowns = { name = "Four Crowns", players = 4, symmetry = "rot180", mode = "melee",
    text = "2v2 or four players (96 x 64): a base in each corner, expansions round a central clearing.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT.............G..............................................................G...............TT",
        "TT............................................................................................TT",
        "TT....1...............................................................................3.......TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT...m...............................m....TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT............................G...............................G...............................TT",
        "TT............................................................................................TT",
        "TT......e...................................S.........................................e.......TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TTTTTTTTTTTTTTTT................................................................TTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTT................................................................TTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTT........................TTTTTT....TTTTTT........................TTTTTTTTTTTTTTTT",
        "TT......................................TTTTTT....TTTTTT......................................TT",
        "TT......................................TTTTTT....TTTTTT......................................TT",
        "TT............................................................................................TT",
        "TT..................X.........................................................................TT",
        "TT.............................................h..............................................TT",
        "TT..............................................h.........................X...................TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT......................................TTTTTT....TTTTTT......................................TT",
        "TT......................................TTTTTT....TTTTTT......................................TT",
        "TTTTTTTTTTTTTTTT........................TTTTTT....TTTTTT........................TTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTT................................................................TTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTT................................................................TTTTTTTTTTTTTTTT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT................................................S...........................................TT",
        "TT.......e.....................G...............................G.......................e......TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT....m...............................m...TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT......................TTTT........................................TTTT......................TT",
        "TT....4...............................................................................2.......TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT.............G..............................................................G...............TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TT............................................................................................TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "four_crowns")

WC.Maps.frenzy_fields = { name = "Frenzy Fields", players = 4, symmetry = "rot180", mode = "footmen",
    text = "Footmen Frenzy for four: a barracks in each corner, paths to both neighbours and the middle, a shop in the centre.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT....1.........TTT..........................TTT......3.......TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT.......TTT......TTT.......TTT..............TT",
        "TT..............TTT.......TTT......TTT.......TTT..............TT",
        "TT........................TTT......TTT........................TT",
        "TT........................TTT......TTT........................TT",
        "TT........................TTT......TTT........................TT",
        "TT.............TTTT.......TTT......TTT.......TTTT.............TT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT......................TTT..........TTT......................TT",
        "TT......................TTT..........TTT......................TT",
        "TT........TTTTTT........TTT..........TTT........TTTTTT........TT",
        "TT........TTTTTT................................TTTTTT........TT",
        "TT........TTTTTT................................TTTTTT........TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT.............................S..............................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT........TTTTTT................................TTTTTT........TT",
        "TT........TTTTTT................................TTTTTT........TT",
        "TT........TTTTTT........TTT..........TTT........TTTTTT........TT",
        "TT......................TTT..........TTT......................TT",
        "TT......................TTT..........TTT......................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TTTTTTTTTTTT...TTTT..........................TTTT...TTTTTTTTTTTT",
        "TT.............TTTT.......TTT......TTT.......TTTT.............TT",
        "TT........................TTT......TTT........................TT",
        "TT........................TTT......TTT........................TT",
        "TT........................TTT......TTT........................TT",
        "TT..............TTT.......TTT......TTT.......TTT..............TT",
        "TT..............TTT.......TTT......TTT.......TTT..............TT",
        "TT....4.........TTT..........................TTT......2.......TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TT..............TTT..........................TTT..............TT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "frenzy_fields")

WC.Maps.td_duel = { name = "Tower Duel", players = 2, symmetry = "none", mode = "td",
    text = "Tower Defense for up to 2: a lane each. Build a maze of towers; what gets through costs a life.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTT..........TT..........TTTTTTTTT",
        "TTTTTTTTTTTT1...TTTTTTTT2...TTTTTTTTTTTT",
        "TTTTTTTTTTTT....TTTTTTTT....TTTTTTTTTTTT",
        "TTTTTTTTTTTT....TTTTTTTT....TTTTTTTTTTTT",
        "TTTTTTTTTTTT....TTTTTTTT....TTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "td_duel")

WC.Maps.td_four = { name = "Four Lanes", players = 4, symmetry = "none", mode = "td",
    text = "Tower Defense for up to 4: a lane each. Build a maze of towers; what gets through costs a life.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT",
        "TTTTT1...TTTTTTTT2...TTTTTTTT3...TTTTTTTT4...TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "td_four")

WC.Maps.td_eight = { name = "Eight Lanes", players = 8, symmetry = "none", mode = "td",
    text = "Tower Defense for up to 8: a lane each. Build a maze of towers; what gets through costs a life.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT..........TT",
        "TTTTT1...TTTTTTTT2...TTTTTTTT3...TTTTTTTT4...TTTTTTTT5...TTTTTTTT6...TTTTTTTT7...TTTTTTTT8...TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTTTTT....TTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "td_eight")

WC.Maps.hd_castle = { name = "The Last Castle", players = 8, symmetry = "none", mode = "hd",
    text = "Hero Defense for 1 to 8: a castle in the middle, four lanes in. Open more lanes when you are ready for them.",
    grid = {
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT..1....5..........6....2....TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT...S........................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TT......TT........................................T...........TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT............................................................TT",
        "TT...........T........................................TT......TT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT..3....7..........8....4....TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTT............................TTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTT......TTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    } }
table.insert(WC.MAP_ORDER, "hd_castle")

-- Read a map's grid once: size, trees, starts, mines.
function WC.ParseMap(key)
    local m = WC.Maps[key]
    if not m then return nil end
    if m.parsed then return m.parsed end
    local p = { h = #m.grid, w = #m.grid[1], trees = {}, starts = {}, mines = {}, shops = {}, camps = {}, mercs = {} }
    for y, row in ipairs(m.grid) do
        for x = 1, #row do
            local c = row:sub(x, x)
            if c == "T" then
                table.insert(p.trees, { x - 1, y - 1 })
            elseif c == "G" then
                table.insert(p.mines, { x - 1, y - 1 })
            elseif c == "S" then
                table.insert(p.shops, { x - 1, y - 1 })
            elseif c == "X" then
                table.insert(p.mercs, { x - 1, y - 1 })
            elseif c == "e" or c == "m" or c == "h" then
                table.insert(p.camps, { x - 1, y - 1, c })
            elseif c:match("%d") then
                p.starts[tonumber(c)] = { x - 1, y - 1 }
            end
        end
    end
    m.parsed = p
    return p
end

-- The maps that fit a game of n players (in a mode: default melee).
function WC.MapsFor(n, mode)
    local out = {}
    for _, key in ipairs(WC.MAP_ORDER) do
        local m = WC.Maps[key]
        if m.players >= (n or 2) and (m.mode or "melee") == (mode or "melee") then table.insert(out, key) end
    end
    return out
end

-- Problems with a map (for the tests): rows the same width, starts and
-- mines on open ground, a mine near every start, the starts reach each
-- other, and the symmetry holds.
function WC.CheckMap(key)
    local m, p = WC.Maps[key], WC.ParseMap(key)
    local bad = {}
    for y, row in ipairs(m.grid) do
        if #row ~= p.w then table.insert(bad, "row " .. y .. " is " .. #row .. " wide") end
    end
    local function Tile(x, y)
        local row = m.grid[y + 1]
        return row and row:sub(x + 1, x + 1) or "T"
    end
    local function Clear(x, y, size)
        for yy = y, y + size - 1 do
            for xx = x, x + size - 1 do
                local c = Tile(xx, yy)
                if c == "T" or (c ~= "." and not (xx == x and yy == y)) then return false end
            end
        end
        return true
    end
    for n = 1, m.players do
        local s = p.starts[n]
        if not s then
            table.insert(bad, "no start " .. n)
        else
            if not Clear(s[1], s[2], 4) then table.insert(bad, "start " .. n .. " is not clear") end
            local near = (m.mode or "melee") ~= "melee" -- (only melee needs mines)
            for _, g in ipairs(p.mines) do
                if math.abs(g[1] - s[1]) + math.abs(g[2] - s[2]) <= 16 then near = true end
            end
            if not near then table.insert(bad, "start " .. n .. " has no mine near") end
        end
    end
    for _, g in ipairs(p.mines) do
        if not Clear(g[1], g[2], 3) then table.insert(bad, "mine at " .. g[1] .. "," .. g[2] .. " is not clear") end
    end
    for _, list in ipairs({ p.shops, p.mercs }) do
        for _, g in ipairs(list) do
            if not Clear(g[1], g[2], 2) then table.insert(bad, "shop at " .. g[1] .. "," .. g[2] .. " is not clear") end
        end
    end
    -- Every start reaches start 1 (open tiles, four ways).
    local open, seen = {}, {}
    for y = 0, p.h - 1 do for x = 0, p.w - 1 do open[y * p.w + x] = Tile(x, y) ~= "T" end end
    for _, g in ipairs(p.mines) do
        for yy = g[2], g[2] + 2 do for xx = g[1], g[1] + 2 do open[yy * p.w + xx] = false end end
    end
    for _, list in ipairs({ p.shops, p.mercs }) do
        for _, g in ipairs(list) do
            for yy = g[2], g[2] + 1 do for xx = g[1], g[1] + 1 do open[yy * p.w + xx] = false end end
        end
    end
    local s1 = p.starts[1]
    if s1 and (m.mode or "melee") ~= "td" then -- (Tower Defense lanes are walled off on purpose)
        local q, head = { (s1[2] + 4) * p.w + s1[1] + 4 }, 1
        seen[q[1]] = true
        while head <= #q do
            local i = q[head]
            head = head + 1
            local x, y = i % p.w, math.floor(i / p.w)
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = x + d[1], y + d[2]
                local j = ny * p.w + nx
                if nx >= 0 and ny >= 0 and nx < p.w and ny < p.h and open[j] and not seen[j] then
                    seen[j] = true
                    table.insert(q, j)
                end
            end
        end
        for n = 2, m.players do
            local s = p.starts[n]
            if s and not seen[(s[2] + 4) * p.w + s[1] + 4] and not seen[(s[2] - 1) * p.w + s[1] - 1] then
                table.insert(bad, "start " .. n .. " can't be reached from start 1")
            end
        end
    end
    if m.symmetry == "rot180" then
        local pair = { ["1"] = "2", ["2"] = "1", ["3"] = "4", ["4"] = "3", ["5"] = "6", ["6"] = "5", ["7"] = "8", ["8"] = "7" }
        local function Same(a, b) return (a == "T") == (b == "T") and (a:match("[emh]") or ".") == (b:match("[emh]") or ".") end
        -- (2 x 2 anchors land on the other corner of their footprint when turned: checked by their twins)
        for y = 0, p.h - 1 do
            for x = 0, p.w - 1 do
                if not Same(Tile(x, y), Tile(p.w - 1 - x, p.h - 1 - y)) then
                    table.insert(bad, "not symmetric at " .. x .. "," .. y)
                    break
                end
            end
        end
        for n, s in pairs(p.starts) do
            local o = p.starts[tonumber(pair[tostring(n)] or n)]
            if not o or o[1] ~= p.w - s[1] - 4 or o[2] ~= p.h - s[2] - 4 then table.insert(bad, "start " .. n .. " has no twin") end
        end
    end
    return #bad == 0, bad
end
