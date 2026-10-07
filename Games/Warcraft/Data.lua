-- Warcraft III (RTS): data only. Units, buildings, factions and the map.
-- Distances are in map tiles; speeds in tiles per second; times in seconds.
--
-- A unit type: name, hp, armor, damage, cooldown, range, speed, cost = { gold, lumber },
--   time (to train), food, worker = true (gathers and builds), icon, npc (the WoW
--   creature drawn for it), hotkey (as in Warcraft III).
-- A building type: name, hp, armor, size (tiles, square), cost, time (to build),
--   food (supply it gives), trains = { unit types }, dropoff = true (gold and lumber
--   are brought here; "lumber": only lumber), hall = true, icon.
-- A faction: name, hall, worker, farm, barracks (keys into Units/Buildings), color.
local ADDON, ns = ...

ns.WC = ns.WC or {}
local I = "Interface\\Icons\\"

local U = {}
ns.WC.Units = U
U.peasant = { npc = 351, hotkey = "P", name = "Peasant", hp = 220, armor = 0, damage = 6, cooldown = 2, range = 1, speed = 2.6,
    cost = { 75, 0 }, time = 10, food = 1, worker = true, icon = I .. "INV_Hammer_20" }
U.footman = { npc = 68, hotkey = "F", name = "Footman", hp = 420, armor = 2, damage = 12, cooldown = 1.35, range = 1, speed = 2.7,
    cost = { 135, 0 }, time = 14, food = 2, icon = I .. "INV_Shield_06" }
U.rifleman = { npc = 727, hotkey = "R", name = "Rifleman", hp = 505, armor = 0, damage = 21, cooldown = 1.5, range = 4.5, speed = 2.7,
    cost = { 205, 30 }, time = 18, food = 3, icon = I .. "INV_Weapon_Rifle_01" }
-- Peasants called to arms (Town Hall: Call to Arms) for MILITIA_TIME seconds.
U.militia = { npc = 10037, name = "Militia", hp = 220, armor = 4, damage = 12, cooldown = 1.2, range = 1, speed = 2.9,
    cost = { 0, 0 }, time = 0, food = 1, icon = I .. "INV_Sword_04" }
U.peon = { npc = 14901, hotkey = "P", name = "Peon", hp = 250, armor = 0, damage = 7, cooldown = 2, range = 1, speed = 2.6,
    cost = { 75, 0 }, time = 10, food = 1, worker = true, icon = I .. "INV_Pick_02" }
U.grunt = { npc = 3296, hotkey = "G", name = "Grunt", hp = 700, armor = 1, damage = 19, cooldown = 1.6, range = 1, speed = 2.7,
    cost = { 200, 0 }, time = 18, food = 3, icon = I .. "INV_Axe_02" }
U.headhunter = { npc = 671, hotkey = "T", name = "Troll Headhunter", hp = 350, armor = 0, damage = 23, cooldown = 2.3, range = 4.5,
    speed = 2.7, cost = { 135, 20 }, time = 14, food = 2, icon = I .. "INV_Spear_04" }

local B = {}
ns.WC.Buildings = B
B.town_hall = { hotkey = "H", name = "Town Hall", hp = 1500, armor = 5, size = 4, cost = { 385, 205 }, time = 60, food = 12,
    trains = { "peasant" }, dropoff = true, hall = true, icon = I .. "INV_BannerPVP_02" }
B.farm = { hotkey = "F", name = "Farm", hp = 500, armor = 5, size = 2, cost = { 80, 20 }, time = 18, food = 6,
    icon = I .. "INV_Misc_Food_02" }
B.barracks = { hotkey = "B", name = "Barracks", hp = 1000, armor = 5, size = 3, cost = { 160, 60 }, time = 30, food = 0,
    trains = { "footman", "rifleman" }, icon = I .. "INV_Sword_27" }
B.lumber_mill = { hotkey = "L", name = "Lumber Mill", hp = 900, armor = 5, size = 3, cost = { 120, 0 }, time = 30, food = 0,
    dropoff = "lumber", icon = I .. "INV_Axe_10" }
-- Towers shoot enemy units in range on their own.
B.guard_tower = { hotkey = "T", name = "Guard Tower", hp = 500, armor = 5, size = 2, cost = { 100, 70 }, time = 30, food = 0,
    attack = { damage = 13, cooldown = 0.9, range = 7 }, icon = I .. "INV_Misc_Spyglass_03" }
-- The altar: heroes come later.
B.altar_kings = { hotkey = "A", name = "Altar of Kings", hp = 900, armor = 5, size = 3, cost = { 180, 50 }, time = 40, food = 0,
    icon = I .. "Spell_Holy_SealOfMight" }
B.great_hall = { hotkey = "H", name = "Great Hall", hp = 1500, armor = 5, size = 4, cost = { 385, 185 }, time = 60, food = 12,
    trains = { "peon" }, dropoff = true, hall = true, icon = I .. "INV_BannerPVP_01" }
B.orc_burrow = { hotkey = "O", name = "Orc Burrow", hp = 600, armor = 5, size = 2, cost = { 80, 40 }, time = 18, food = 6,
    garrison = 4, attack = { damage = 25, cooldown = 2.4, range = 7 }, -- Battle Stations: peons inside, it shoots
    icon = I .. "INV_Misc_Bone_01" }
B.orc_barracks = { hotkey = "B", name = "Orc Barracks", hp = 1200, armor = 5, size = 3, cost = { 180, 50 }, time = 30, food = 0,
    trains = { "grunt", "headhunter" }, icon = I .. "INV_Axe_02" }
B.watch_tower = { hotkey = "T", name = "Watch Tower", hp = 500, armor = 5, size = 2, cost = { 110, 80 }, time = 30, food = 0,
    attack = { damage = 16, cooldown = 1.0, range = 8 }, icon = I .. "INV_Spear_02" }
B.altar_storms = { hotkey = "A", name = "Altar of Storms", hp = 900, armor = 5, size = 3, cost = { 180, 50 }, time = 40, food = 0,
    icon = I .. "Spell_Nature_Lightning" }
B.gold_mine = { name = "Gold Mine", hp = 1, armor = 0, size = 3, neutral = true, icon = I .. "INV_Misc_Coin_02" }

local F = {}
ns.WC.Factions = F
F.human = { name = "Human", hall = "town_hall", worker = "peasant", farm = "farm", barracks = "barracks", tower = "guard_tower", alarm = "callToArms",
    melee = "footman", ranged = "rifleman", builds = { "farm", "barracks", "lumber_mill", "guard_tower", "altar_kings", "town_hall" } }
F.orc = { name = "Orc", buildInside = true, hall = "great_hall", worker = "peon", farm = "orc_burrow", barracks = "orc_barracks", tower = "watch_tower", alarm = "battleStations",
    melee = "grunt", ranged = "headhunter", builds = { "orc_burrow", "orc_barracks", "watch_tower", "altar_storms", "great_hall" } }

-- Art from the WoW game files (file ids from the community listfile; M2
-- files only: WMO files crash the client in a model frame). World models are
-- shown in a ModelScene. Buildings stand on the ground at the centre of
-- their footprint and are scaled so their width fills it (fill, default 1),
-- but never taller than `tall` footprints (default view.tall); facing turns
-- them (radians). Trees and the /wcgallery are fitted whole (view.margin).
ns.WC.ART = {
    ground = 187126, -- tileset/elwynn/elwynngrassbase.blp
    groundRepeat = 4, -- tiles per texture repeat
    trees = { 189923, 189927, 189923, 189928 }, -- elwynnfirtree01, elwynntreecanopy01/02
    forestFloor = 187130, forestShade = 0.5, -- tileset/elwynn/elwynnleaf.blp, darkened under trees
    treeGrow = 1.6, treeY = 8,
    -- The camera: from yaw (around), pitch (down), with this field of view;
    -- margin > 1 leaves room around the model.
    -- bpitch: the buildings' camera, lower so walls show, not just roofs.
    view = { yaw = math.pi, pitch = 0.75, bpitch = 0.55, fov = 0.6, margin = 1.0, tall = 1.6 },
    models = {
        gold_mine = { file = 189620, fill = 1.1 },                -- elwynn/buildings/goldmine
        town_hall = { file = 190505 },                            -- westfall/buildings/westfallchurch (gallery 8)
        farm = { file = 242696 },                                 -- redridge_human_farm_closed (gallery 16)
        barracks = { file = 189445 },                             -- duskwood/duskwoodbarn
        lumber_mill = { file = 242697, fill = 0.95 },             -- redridge_lumbermill (gallery 44)
        guard_tower = { file = 2061082, tall = 2.0 },             -- 8hu_warfronts_magictower_v3 (gallery 112)
        altar_kings = { file = 197831, fill = 0.8 },              -- generic/human/altars/altar01 (gallery 52)
        great_hall = { file = 189200 },                           -- burningsteppes/orctents/orctent
        orc_burrow = { file = 199387 },                           -- generic/orc/tents/orctent01 (gallery 24)
        orc_barracks = { file = 1910329 },                        -- 8or_warfronts_barracks_v2 (gallery 114)
        watch_tower = { file = 2061081, tall = 2.0 },             -- 8or_warfronts_magictower_v3 (gallery 115)
        altar_storms = { file = 189141, fill = 0.8 },             -- lavaaltar (gallery 54)
    },
    -- Models whose bounding box is smaller than what is drawn: more room
    -- around them (margin) and the camera aimed higher (up, in radii).
    fit = {
        [2061082] = { margin = 1.6, up = 0.4 },
        [2061081] = { margin = 1.6, up = 0.4 },
    },
}

ns.WC.START = { gold = 500, lumber = 150, workers = 5 }
ns.WC.MINE_GOLD = 12500
ns.WC.TREE_LUMBER = 50
ns.WC.CARRY = 10          -- gold or lumber per trip
ns.WC.MINE_TIME = 1.0     -- seconds inside the mine
ns.WC.CHOP_TIME = 4.0     -- seconds to chop a load of lumber
ns.WC.FOOD_MAX = 100
ns.WC.SIGHT = 7           -- how far units notice enemies
-- Fog of war: how far you see around your things (tiles).
ns.WC.VIEW = { unit = 8, worker = 7, building = 7, hall = 9, tower = 10 }
-- Computer difficulty. think: seconds between decisions; workers: how many
-- it trains; secondRax: when it builds a second barracks (nil: never);
-- firstAttack: earliest attack (seconds); wave/waveGrow/waveMax: army size
-- per wave; alarm: uses Call to Arms; income: gold/lumber per trip multiplier.
ns.WC.DIFFICULTY = {
    easy = { name = "Easy", think = 2, workers = 7, firstAttack = 600, wave = 6, waveGrow = 1, waveMax = 8,
        alarm = false, income = 1 },
    normal = { name = "Normal", think = 1, workers = 10, secondRax = 420, firstAttack = 360, wave = 6, waveGrow = 2,
        waveMax = 12, alarm = true, income = 1 },
    hard = { name = "Hard", think = 1, workers = 12, secondRax = 200, firstAttack = 240, wave = 5, waveGrow = 2,
        waveMax = 16, alarm = true, income = 1.25 },
}
ns.WC.MILITIA_TIME = 45   -- Call to Arms lasts this long
ns.WC.ALARM_RADIUS = 22   -- workers this close to the hall answer the alarm

-- The map: 64 x 40 tiles. Player 1 top left, player 2 bottom right (the
-- map is mirrored so both sides are the same).
ns.WC.MAP = {
    w = 64, h = 40,
    halls = { { 6, 6 }, nil },            -- player 2's is mirrored
    mines = { { 14, 4 } },                 -- per side, mirrored for the other
    expansions = { { 12, 30 } },           -- extra mines in the open corners (mirrored too)
    -- Forest rectangles per side { x, y, w, h }, mirrored for the other side.
    forests = {
        { 0, 0, 64, 2 }, { 0, 0, 2, 40 },  -- the map edge (both halves come from mirroring)
        { 2, 12, 8, 4 }, { 18, 2, 4, 6 }, { 10, 16, 3, 3 },
        { 26, 10, 3, 5 }, { 30, 18, 4, 2 },
    },
}
