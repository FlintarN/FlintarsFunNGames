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
F.human = { name = "Human", hall = "town_hall", worker = "peasant", farm = "farm", barracks = "barracks", tower = "scout_tower",
    smith = "blacksmith", mill = "lumber_mill", altar = "altar_kings", alarm = "callToArms",
    melee = "footman", ranged = "rifleman",
    builds = { "farm", "barracks", "lumber_mill", "blacksmith", "scout_tower", "altar_kings", "town_hall" } }
F.orc = { name = "Orc", buildInside = true, hall = "great_hall", worker = "peon", farm = "orc_burrow", barracks = "orc_barracks",
    tower = "watch_tower", smith = "war_mill", mill = "war_mill", altar = "altar_storms", alarm = "battleStations",
    melee = "grunt", ranged = "headhunter",
    builds = { "orc_burrow", "orc_barracks", "war_mill", "watch_tower", "altar_storms", "great_hall" } }

---------------------------------------------------------------------------
-- Tech (Warcraft III): tiers, requirements, research, damage and armour
---------------------------------------------------------------------------
-- Hall tiers: a Keep counts as a Town Hall, a Castle as both (counts).
B.keep = { name = "Keep", hp = 2000, armor = 5, size = 4, cost = { 0, 0 }, time = 0, food = 12,
    trains = { "peasant" }, dropoff = true, hall = true, counts = { "town_hall" }, icon = I .. "INV_BannerPVP_02" }
B.castle = { name = "Castle", hp = 2500, armor = 5, size = 4, cost = { 0, 0 }, time = 0, food = 12,
    trains = { "peasant" }, dropoff = true, hall = true, counts = { "town_hall", "keep" }, icon = I .. "INV_BannerPVP_02" }
B.stronghold = { name = "Stronghold", hp = 2000, armor = 5, size = 4, cost = { 0, 0 }, time = 0, food = 12,
    trains = { "peon" }, dropoff = true, hall = true, counts = { "great_hall" }, icon = I .. "INV_BannerPVP_01" }
B.fortress = { name = "Fortress", hp = 2500, armor = 5, size = 4, cost = { 0, 0 }, time = 0, food = 12,
    trains = { "peon" }, dropoff = true, hall = true, counts = { "great_hall", "stronghold" }, icon = I .. "INV_BannerPVP_01" }
-- Upgrade buildings.
B.blacksmith = { hotkey = "S", name = "Blacksmith", hp = 1200, armor = 5, size = 3, cost = { 140, 60 }, time = 40, food = 0,
    requires = { "town_hall" }, icon = I .. "Trade_BlackSmithing" }
B.war_mill = { hotkey = "M", name = "War Mill", hp = 1000, armor = 5, size = 3, cost = { 205, 0 }, time = 40, food = 0,
    dropoff = "lumber", requires = { "great_hall" }, icon = I .. "INV_Hammer_05" }
-- Scout Tower: sees far, no attack; upgrades to a Guard Tower (needs a Lumber Mill).
B.scout_tower = { hotkey = "T", name = "Scout Tower", hp = 300, armor = 0, size = 2, cost = { 30, 20 }, time = 25, food = 0,
    icon = I .. "INV_Misc_Spyglass_02" }
B.guard_tower.cost = { 100, 70 } -- (as the Scout Tower plus its upgrade)
B.watch_tower.requires = { "war_mill" }

-- Units: who needs what.
U.rifleman.requires = { "blacksmith" }
U.headhunter.requires = { "war_mill" }

-- Damage and armour types, and the Warcraft III table.
for _, x in ipairs({ { "peasant", "normal", "medium" }, { "footman", "normal", "heavy" }, { "rifleman", "pierce", "medium" },
    { "militia", "normal", "heavy" }, { "peon", "normal", "medium" }, { "grunt", "normal", "heavy" },
    { "headhunter", "pierce", "medium" } }) do
    U[x[1]].attackType, U[x[1]].armorType = x[2], x[3]
end
B.guard_tower.attack.type = "pierce"
B.watch_tower.attack.type = "pierce"
B.orc_burrow.attack.type = "pierce"
ns.WC.DAMAGE = {
    normal = { light = 1, medium = 1.5, heavy = 1, fortified = 0.7, unarmored = 1 },
    pierce = { light = 2, medium = 0.75, heavy = 1, fortified = 0.35, unarmored = 1.5 },
    siege = { light = 1, medium = 0.5, heavy = 1, fortified = 1.5, unarmored = 1.5 },
}

-- Research, done in a building like training (one at a time per building).
-- Per level: cost, time, requires (buildings). upgrade = the building it turns
-- into. effect per level: melee/ranged (+share of damage), armor (units),
-- buildingArmor, lumber (per trip), rifleRange, gruntHp, gruntDamage,
-- trollRegen (health per second).
local R = {}
ns.WC.Research = R
R.keep = { name = "Upgrade to Keep", building = "town_hall", upgrade = "keep", hotkey = "U", levels = 1,
    cost = { { 320, 210 } }, time = { 60 }, icon = I .. "INV_BannerPVP_02",
    text = "More health; Steel and Advanced upgrades." }
R.castle = { name = "Upgrade to Castle", building = "keep", upgrade = "castle", hotkey = "U", levels = 1,
    cost = { { 360, 210 } }, time = { 70 }, requires = { { "altar_kings" } }, icon = I .. "INV_BannerPVP_02",
    text = "More health; Mithril and Imbued upgrades." }
R.stronghold = { name = "Upgrade to Stronghold", building = "great_hall", upgrade = "stronghold", hotkey = "U", levels = 1,
    cost = { { 315, 190 } }, time = { 60 }, icon = I .. "INV_BannerPVP_01", text = "More health; Thorium upgrades." }
R.fortress = { name = "Upgrade to Fortress", building = "stronghold", upgrade = "fortress", hotkey = "U", levels = 1,
    cost = { { 325, 190 } }, time = { 70 }, requires = { { "altar_storms" } }, icon = I .. "INV_BannerPVP_01",
    text = "More health; Arcanite upgrades." }
R.guard_tower = { name = "Upgrade to Guard Tower", building = "scout_tower", upgrade = "guard_tower", hotkey = "G", levels = 1,
    cost = { { 70, 50 } }, time = { 30 }, requires = { { "lumber_mill" } }, icon = I .. "INV_Misc_Spyglass_03",
    text = "A tower that shoots enemies in range." }
R.swords = { names = { "Iron Forged Swords", "Steel Forged Swords", "Mithril Forged Swords" }, building = "blacksmith",
    hotkey = "S", levels = 3, cost = { { 100, 50 }, { 175, 175 }, { 250, 300 } }, time = { 45, 55, 65 },
    requires = { nil, { "keep" }, { "castle" } }, effect = { melee = 0.15 }, icon = I .. "INV_Sword_04",
    text = "Melee units deal 15% more damage." }
R.gunpowder = { names = { "Black Gunpowder", "Refined Gunpowder", "Imbued Gunpowder" }, building = "blacksmith",
    hotkey = "G", levels = 3, cost = { { 100, 50 }, { 175, 175 }, { 250, 300 } }, time = { 45, 55, 65 },
    requires = { nil, { "keep" }, { "castle" } }, effect = { ranged = 0.15 }, icon = I .. "INV_Misc_Ammo_Gunpowder_01",
    text = "Ranged units deal 15% more damage." }
R.plating = { names = { "Iron Plating", "Steel Plating", "Mithril Plating" }, building = "blacksmith",
    hotkey = "A", levels = 3, cost = { { 125, 75 }, { 150, 175 }, { 175, 275 } }, time = { 45, 55, 65 },
    requires = { nil, { "keep" }, { "castle" } }, effect = { armor = 2 }, icon = I .. "INV_Chest_Plate06",
    text = "Your army's armour +2." }
R.harvest = { names = { "Improved Lumber Harvesting", "Advanced Lumber Harvesting" }, building = "lumber_mill",
    hotkey = "L", levels = 2, cost = { { 100, 50 }, { 175, 100 } }, time = { 40, 50 }, requires = { nil, { "keep" } },
    effect = { lumber = 5 }, icon = I .. "INV_Axe_02", text = "Workers carry 5 more lumber a trip." }
R.masonry = { names = { "Improved Masonry", "Advanced Masonry", "Imbued Masonry" }, building = "lumber_mill",
    hotkey = "M", levels = 3, cost = { { 125, 25 }, { 150, 75 }, { 175, 125 } }, time = { 45, 55, 65 },
    requires = { nil, { "keep" }, { "castle" } }, effect = { buildingArmor = 2 }, icon = I .. "INV_Stone_15",
    text = "Buildings' armour +2." }
R.long_rifles = { name = "Long Rifles", building = "barracks", hotkey = "L", levels = 1, cost = { { 75, 125 } },
    time = { 40 }, requires = { { "blacksmith" } }, effect = { rifleRange = 1.5 }, icon = I .. "INV_Weapon_Rifle_07",
    text = "Riflemen shoot farther." }
R.melee_o = { names = { "Steel Melee Weapons", "Thorium Melee Weapons", "Arcanite Melee Weapons" }, building = "war_mill",
    hotkey = "W", levels = 3, cost = { { 100, 50 }, { 175, 175 }, { 250, 300 } }, time = { 45, 55, 65 },
    requires = { nil, { "stronghold" }, { "fortress" } }, effect = { melee = 0.15 }, icon = I .. "INV_Axe_09",
    text = "Melee units deal 15% more damage." }
R.ranged_o = { names = { "Steel Ranged Weapons", "Thorium Ranged Weapons", "Arcanite Ranged Weapons" }, building = "war_mill",
    hotkey = "R", levels = 3, cost = { { 100, 50 }, { 175, 175 }, { 250, 300 } }, time = { 45, 55, 65 },
    requires = { nil, { "stronghold" }, { "fortress" } }, effect = { ranged = 0.15 }, icon = I .. "INV_Spear_06",
    text = "Ranged units deal 15% more damage." }
R.armor_o = { names = { "Steel Armor", "Thorium Armor", "Arcanite Armor" }, building = "war_mill",
    hotkey = "A", levels = 3, cost = { { 150, 75 }, { 225, 175 }, { 300, 275 } }, time = { 45, 55, 65 },
    requires = { nil, { "stronghold" }, { "fortress" } }, effect = { armor = 2 }, icon = I .. "INV_Shield_05",
    text = "Your army's armour +2." }
R.defenses = { name = "Reinforced Defenses", building = "war_mill", hotkey = "D", levels = 1, cost = { { 125, 200 } },
    time = { 50 }, requires = { { "stronghold" } }, effect = { buildingArmor = 3 }, icon = I .. "INV_Shield_10",
    text = "Buildings' armour +3." }
R.berserker = { name = "Berserker Strength", building = "orc_barracks", hotkey = "B", levels = 1, cost = { { 100, 150 } },
    time = { 45 }, requires = { { "stronghold" } }, effect = { gruntHp = 100, gruntDamage = 3 }, icon = I .. "Ability_Racial_BloodRage",
    text = "Grunts +100 health and +3 damage." }
R.regeneration = { name = "Troll Regeneration", building = "orc_barracks", hotkey = "E", levels = 1, cost = { { 100, 100 } },
    time = { 40 }, requires = { { "stronghold" } }, effect = { trollRegen = 2 }, icon = I .. "Spell_Nature_Regenerate",
    text = "Troll Headhunters heal 2 health a second." }

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
        scout_tower = { file = 189632, tall = 2.0 },              -- elwynn/buildings/humanwatchtower (gallery 3)
        keep = { file = 190505, fill = 1.08 },                    -- (the Town Hall's, bigger)
        castle = { file = 190505, fill = 1.15 },
        blacksmith = { file = 189601 },                           -- elwynn/buildings/blacksmith (gallery 5)
        war_mill = { file = 199384 },                             -- generic/orc/tents/durotarorctent01 (gallery 22)
        stronghold = { file = 189200, fill = 1.08 },              -- (the Great Hall's, bigger)
        fortress = { file = 189200, fill = 1.15 },
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
        alarm = false, income = 1, research = false },
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
