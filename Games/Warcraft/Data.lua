-- Warcraft III (RTS): data only. Units, buildings, factions and the map.
-- Distances are in map tiles; speeds in tiles per second; times in seconds.
--
-- A unit type: name, hp, armor, damage, cooldown, range, speed, cost = { gold, lumber },
--   time (to train), food, worker = true (gathers and builds), icon.
-- A building type: name, hp, armor, size (tiles, square), cost, time (to build),
--   food (supply it gives), trains = { unit types }, dropoff = true (gold and lumber
--   are brought here), hall = true, icon.
-- A faction: name, hall, worker, farm, barracks (keys into Units/Buildings), color.
local ADDON, ns = ...

ns.WC = ns.WC or {}
local I = "Interface\\Icons\\"

local U = {}
ns.WC.Units = U
U.peasant = { name = "Peasant", hp = 220, armor = 0, damage = 6, cooldown = 2, range = 1, speed = 2.6,
    cost = { 75, 0 }, time = 10, food = 1, worker = true, icon = I .. "INV_Hammer_20" }
U.footman = { name = "Footman", hp = 420, armor = 2, damage = 12, cooldown = 1.35, range = 1, speed = 2.7,
    cost = { 135, 0 }, time = 14, food = 2, icon = I .. "INV_Shield_06" }
U.rifleman = { name = "Rifleman", hp = 505, armor = 0, damage = 21, cooldown = 1.5, range = 4.5, speed = 2.7,
    cost = { 205, 30 }, time = 18, food = 3, icon = I .. "INV_Weapon_Rifle_01" }
U.peon = { name = "Peon", hp = 250, armor = 0, damage = 7, cooldown = 2, range = 1, speed = 2.6,
    cost = { 75, 0 }, time = 10, food = 1, worker = true, icon = I .. "INV_Pick_02" }
U.grunt = { name = "Grunt", hp = 700, armor = 1, damage = 19, cooldown = 1.6, range = 1, speed = 2.7,
    cost = { 200, 0 }, time = 18, food = 3, icon = I .. "INV_Axe_02" }
U.headhunter = { name = "Troll Headhunter", hp = 350, armor = 0, damage = 23, cooldown = 2.3, range = 4.5,
    speed = 2.7, cost = { 135, 20 }, time = 14, food = 2, icon = I .. "INV_Spear_04" }

local B = {}
ns.WC.Buildings = B
B.town_hall = { name = "Town Hall", hp = 1500, armor = 5, size = 4, cost = { 385, 205 }, time = 60, food = 12,
    trains = { "peasant" }, dropoff = true, hall = true, icon = I .. "INV_Misc_Flag_01" }
B.farm = { name = "Farm", hp = 500, armor = 5, size = 2, cost = { 80, 20 }, time = 18, food = 6,
    icon = I .. "INV_Misc_Food_02" }
B.barracks = { name = "Barracks", hp = 1000, armor = 5, size = 3, cost = { 160, 60 }, time = 30, food = 0,
    trains = { "footman", "rifleman" }, icon = I .. "INV_Sword_27" }
B.great_hall = { name = "Great Hall", hp = 1500, armor = 5, size = 4, cost = { 385, 185 }, time = 60, food = 12,
    trains = { "peon" }, dropoff = true, hall = true, icon = I .. "INV_Misc_Flag_02" }
B.orc_burrow = { name = "Orc Burrow", hp = 600, armor = 5, size = 2, cost = { 80, 40 }, time = 18, food = 6,
    icon = I .. "INV_Misc_Bone_01" }
B.orc_barracks = { name = "Orc Barracks", hp = 1200, armor = 5, size = 3, cost = { 180, 50 }, time = 30, food = 0,
    trains = { "grunt", "headhunter" }, icon = I .. "INV_Axe_02" }
B.gold_mine = { name = "Gold Mine", hp = 1, armor = 0, size = 3, neutral = true, icon = I .. "INV_Misc_Coin_02" }

local F = {}
ns.WC.Factions = F
F.human = { name = "Human", hall = "town_hall", worker = "peasant", farm = "farm", barracks = "barracks",
    melee = "footman", ranged = "rifleman", builds = { "farm", "barracks", "town_hall" } }
F.orc = { name = "Orc", hall = "great_hall", worker = "peon", farm = "orc_burrow", barracks = "orc_barracks",
    melee = "grunt", ranged = "headhunter", builds = { "orc_burrow", "orc_barracks", "great_hall" } }

ns.WC.START = { gold = 500, lumber = 150, workers = 5 }
ns.WC.MINE_GOLD = 12500
ns.WC.TREE_LUMBER = 50
ns.WC.CARRY = 10          -- gold or lumber per trip
ns.WC.MINE_TIME = 1.0     -- seconds inside the mine
ns.WC.CHOP_TIME = 4.0     -- seconds to chop a load of lumber
ns.WC.FOOD_MAX = 100
ns.WC.SIGHT = 7           -- how far units notice enemies

-- The map: 64 x 40 tiles. Player 1 top left, player 2 bottom right (the
-- map is mirrored so both sides are the same).
ns.WC.MAP = {
    w = 64, h = 40,
    halls = { { 6, 6 }, nil },            -- player 2's is mirrored
    mines = { { 14, 4 } },                 -- per side, mirrored for the other
    -- Forest rectangles per side { x, y, w, h }, mirrored for the other side.
    forests = {
        { 0, 0, 64, 2 }, { 0, 0, 2, 40 },  -- the map edge (both halves come from mirroring)
        { 2, 12, 8, 4 }, { 18, 2, 4, 6 }, { 10, 16, 3, 3 },
        { 26, 10, 3, 5 }, { 30, 18, 4, 2 },
    },
}
