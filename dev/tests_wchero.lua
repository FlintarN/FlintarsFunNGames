-- Warcraft III heroes: training, levels, skills, every ability, death and revival.
local WC = ns.WC
local E = WC.Engine

local function Game(f1, f2)
    local st = E.New({ factions = { f1 or "human", f2 or "orc" }, seed = 33 })
    for p = 1, 2 do st.players[p].gold, st.players[p].lumber = 99999, 99999 end
    return st
end

local function Run(st, seconds)
    for _ = 1, math.floor(seconds / 0.05 + 0.5) do E.Step(st, 0.05) end
end

-- A hero ready to go: spawned at (x, y), at a level, with skills.
local function Hero(st, p, utype, x, y, level, skills)
    local h = E.Spawn(st, p, utype, x, y)
    if level and level > 1 then E.GiveXp(st, h, WC.XP_LEVELS[level - 1]) end
    for key, lv in pairs(skills or {}) do h.skills[key] = lv end
    h.mana = h.maxMana
    return h
end

local function Cast(st, h, ability, target, x, y)
    return E.Command(st, h.owner, { type = "cast", unit = h.id, ability = ability, target = target and target.id, x = x, y = y })
end

function WcHeroTests()
    local st = Game()
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    -- Training at the altar: needs the altar; one of each; the 2nd needs a Keep.
    local ax, ay = WC.AI.FindSpot(st, hx + 6, hy + 6, 3)
    local altar = E.SpawnBuilding(st, 1, "altar_kings", ax, ay, true)
    check(E.Command(st, 1, { type = "train", building = altar.id, utype = "paladin" }), "wc hero: train a Paladin")
    local ok, why = E.Command(st, 1, { type = "train", building = altar.id, utype = "paladin" })
    check(not ok and why == "already training", "wc hero: one of each (" .. tostring(why) .. ")")
    ok, why = E.Command(st, 1, { type = "train", building = altar.id, utype = "archmage" })
    check(not ok and why == "requires Keep", "wc hero: the second hero needs a Keep (" .. tostring(why) .. ")")
    Run(st, 60)
    local pal
    for _, id in ipairs(st.list) do if st.ents[id].type == "paladin" then pal = st.ents[id] end end
    check(pal and pal.level == 1 and pal.points == 1 and pal.maxHp == 100 + 25 * 22, "wc hero: a level 1 Paladin, 650 health")
    check(pal.maxMana == 15 * 17 and pal.mana == pal.maxMana, "wc hero: mana from intelligence")
    -- Learning: level 1 abilities; the ultimate needs level 6.
    ok, why = E.Command(st, 1, { type = "learn", unit = pal.id, ability = "resurrection" })
    check(not ok and why == "needs hero level 6", "wc hero: no ultimate before level 6 (" .. tostring(why) .. ")")
    check(E.Command(st, 1, { type = "learn", unit = pal.id, ability = "holy_light" }), "wc hero: learn Holy Light")
    check(pal.skills.holy_light == 1 and pal.points == 0, "wc hero: a skill point spent")
    -- Experience from kills nearby.
    local grunt = E.Spawn(st, 2, "grunt", pal.x + 1, pal.y)
    grunt.hp = 1
    pal.order = { type = "attack", target = grunt.id }
    Run(st, 4)
    check(grunt.dead and pal.xp == 3 * 25, "wc hero: experience for a kill (" .. tostring(pal.xp) .. ")")
    E.GiveXp(st, pal, 500)
    check(pal.level == 3 and pal.points == 2 and pal.maxHp > 650, "wc hero: levels up, more health, skill points")

    -- Holy Light heals a friend.
    local fm = E.Spawn(st, 1, "footman", pal.x + 2, pal.y)
    fm.hp = 50
    check(Cast(st, pal, "holy_light", fm), "wc hero: cast Holy Light")
    Run(st, 1)
    check(fm.hp == 250 and pal.mana < pal.maxMana and pal.cds.holy_light, "wc hero: healed 200, mana spent, cooldown")
    ok, why = Cast(st, pal, "holy_light", fm)
    check(not ok and why == "not ready yet", "wc hero: not again before the cooldown")
end

-- Every ability does what it says.
function WcHeroAbilities()
    local st = Game()
    local X, Y = 32, 20
    local function Clear()
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.kind == "unit" then E.Remove(st, e) end
        end
        Run(st, 0.05)
    end
    local function Enemies(n, utype, x, y)
        local out = {}
        for i = 1, n do
            local e = E.Spawn(st, 2, utype or "grunt", (x or X + 2) + (i - 1) * 0.5, y or Y)
            e.order = { type = "hold" }
            table.insert(out, e)
        end
        return out
    end

    -- Paladin
    Clear()
    local pal = Hero(st, 1, "paladin", X, Y, 6, { divine_shield = 1, devotion = 3, resurrection = 1 })
    Cast(st, pal, "divine_shield")
    Run(st, 0.1)
    local hp = pal.hp
    E.Strike(st, { id = 0 }, pal, 100, false, "normal")
    check(pal.hp == hp and pal.buffs.invuln, "wc ability: Divine Shield, no damage")
    local fm = E.Spawn(st, 1, "footman", X + 1, Y)
    check(E.ArmorOf(st, fm) >= WC.Units.footman.armor + 4.5, "wc ability: Devotion Aura armour")
    fm.hp = 1
    E.Strike(st, { id = 0, owner = 2 }, fm, 100, false, "normal")
    check(fm.dead and st.corpses and #st.corpses >= 1, "wc ability: a corpse left behind")
    Cast(st, pal, "resurrection")
    Run(st, 0.1)
    local back = 0
    for _, id in ipairs(st.list) do if st.ents[id].type == "footman" then back = back + 1 end end
    check(back == 1, "wc ability: Resurrection brings the footman back")

    -- Archmage
    Clear()
    local am = Hero(st, 1, "archmage", X, Y, 6, { blizzard = 1, water_elemental = 1, brilliance = 1, mass_teleport = 1 })
    local foes = Enemies(3, "grunt", X + 4, Y)
    local before = foes[1].hp
    Cast(st, am, "blizzard", nil, X + 4.5, Y)
    Run(st, 3)
    check(foes[1].hp < before, "wc ability: Blizzard hurts in the area")
    Cast(st, am, "water_elemental")
    Run(st, 0.1)
    local elem
    for _, id in ipairs(st.list) do if st.ents[id].type == "water_elemental1" then elem = st.ents[id] end end
    check(elem and elem.summon and elem.expire, "wc ability: a Water Elemental appears")
    Run(st, 61)
    check(elem.dead, "wc ability: and goes after 60 seconds")
    am.mana = 10
    Run(st, 2)
    check(am.mana > 10 + 2 * 0.05 * E.Stat(am, "int"), "wc ability: Brilliance Aura gives mana")
    local hall = E.Hall(st, 1)
    am.mana = am.maxMana
    Cast(st, am, "mass_teleport", hall)
    Run(st, 0.1)
    local hx, hy = E.Center(hall)
    check(math.abs(am.x - hx) < 6 and math.abs(am.y - hy) < 6, "wc ability: Mass Teleport to the hall")

    -- Mountain King
    Clear()
    local mk = Hero(st, 1, "mountain_king", X, Y, 6, { storm_bolt = 1, thunder_clap = 1, bash = 3, avatar = 1 })
    foes = Enemies(2, "grunt", X + 1.5, Y)
    before = foes[1].hp
    Cast(st, mk, "storm_bolt", foes[1])
    Run(st, 0.1)
    check(foes[1].hp < before and foes[1].buffs and foes[1].buffs.stun, "wc ability: Storm Bolt damages and stuns")
    Cast(st, mk, "thunder_clap")
    Run(st, 0.1)
    check(foes[2].buffs and foes[2].buffs.slow, "wc ability: Thunder Clap slows")
    local hpMax = mk.maxHp
    Cast(st, mk, "avatar")
    Run(st, 0.1)
    check(mk.maxHp == hpMax + 500 and E.HeroDamage(st, mk) >= 20, "wc ability: Avatar +500 health")
    local bashed = false
    for _ = 1, 40 do
        if E.OnHit(st, mk, foes[2], 10) > 10 then bashed = true break end
    end
    check(bashed, "wc ability: Bash happens sometimes")

    -- Blood Mage
    Clear()
    local bm = Hero(st, 1, "blood_mage", X, Y, 6, { flame_strike = 1, banish = 1, siphon_mana = 1, phoenix = 1 })
    foes = Enemies(1, "grunt", X + 3, Y)
    before = foes[1].hp
    Cast(st, bm, "flame_strike", nil, X + 3, Y)
    Run(st, 2)
    check(foes[1].hp < before, "wc ability: Flame Strike burns")
    Cast(st, bm, "banish", foes[1])
    Run(st, 0.1)
    check(E.CantAttack(foes[1]), "wc ability: Banish: can't attack")
    local seer = Hero(st, 2, "far_seer", X + 2, Y + 1, 1, {})
    bm.mana = 0
    Cast(st, bm, "siphon_mana", seer)
    Run(st, 0.1)
    check(bm.mana > 100 and seer.mana < seer.maxMana, "wc ability: Siphon Mana steals mana")
    bm.mana = bm.maxMana
    Cast(st, bm, "phoenix")
    Run(st, 0.1)
    local ph = false
    for _, id in ipairs(st.list) do if st.ents[id].type == "phoenix1" then ph = true end end
    check(ph, "wc ability: a Phoenix appears")

    -- Blademaster
    Clear()
    local bl = Hero(st, 2, "blademaster", X, Y, 6, { wind_walk = 1, mirror_image = 2, critical_strike = 3, bladestorm = 1 })
    Cast(st, bl, "wind_walk")
    Run(st, 0.1)
    local fm2 = E.Spawn(st, 1, "footman", X + 1, Y)
    check(E.Hidden(bl) and E.Nearest(st, fm2, 5) ~= bl, "wc ability: Wind Walk hides the hero")
    check(E.OnHit(st, bl, fm2, 10) >= 50 and not E.Hidden(bl), "wc ability: the next hit is stronger and shows him")
    Cast(st, bl, "mirror_image")
    Run(st, 0.1)
    local images = 0
    for _, id in ipairs(st.list) do if st.ents[id].illusion then images = images + 1 end end
    check(images == 2, "wc ability: Mirror Image: two copies")
    local crit = false
    for _ = 1, 60 do
        if E.OnHit(st, bl, fm2, 10) >= 40 then crit = true break end
    end
    check(crit, "wc ability: Critical Strike happens sometimes (x4)")
    before = fm2.hp
    Cast(st, bl, "bladestorm")
    Run(st, 1.1)
    check(fm2.hp < before and E.Untouchable(bl), "wc ability: Bladestorm hurts all around, untouchable")

    -- Far Seer
    Clear()
    local fs = Hero(st, 2, "far_seer", X, Y, 6, { chain_lightning = 1, far_sight = 1, feral_spirit = 1, earthquake = 1 })
    local men = {}
    for i = 1, 3 do
        local f = E.Spawn(st, 1, "footman", X + 2 + i, Y)
        f.order = { type = "hold" }
        table.insert(men, f)
    end
    Cast(st, fs, "chain_lightning", men[1])
    Run(st, 0.2)
    check(men[1].hp < men[1].maxHp and men[3].hp < men[3].maxHp, "wc ability: Chain Lightning jumps")
    Cast(st, fs, "far_sight", nil, 50, 30)
    Run(st, 0.1)
    check(st.reveals and st.reveals[1].owner == 2, "wc ability: Far Sight reveals")
    Cast(st, fs, "feral_spirit")
    Run(st, 0.1)
    local wolves = 0
    for _, id in ipairs(st.list) do if st.ents[id].type == "spirit_wolf1" then wolves = wolves + 1 end end
    check(wolves == 2, "wc ability: two Spirit Wolves")
    local farm = E.SpawnBuilding(st, 1, "farm", X + 4, Y + 3, true)
    fs.mana = fs.maxMana
    Cast(st, fs, "earthquake", nil, X + 5, Y + 4)
    Run(st, 3)
    check(farm.hp < farm.maxHp, "wc ability: Earthquake breaks buildings")

    -- Tauren Chieftain
    Clear()
    local tc = Hero(st, 2, "tauren_chieftain", X, Y, 6, { shockwave = 1, war_stomp = 1, endurance = 1, reincarnation = 1 })
    men = {}
    for i = 1, 2 do
        local f = E.Spawn(st, 1, "footman", X + 1 + i, Y)
        f.order = { type = "hold" }
        table.insert(men, f)
    end
    Cast(st, tc, "shockwave", nil, X + 6, Y)
    Run(st, 0.1)
    check(men[2].hp < men[2].maxHp, "wc ability: Shockwave hits along the line")
    Cast(st, tc, "war_stomp")
    Run(st, 0.1)
    check(men[1].buffs and men[1].buffs.stun, "wc ability: War Stomp stuns")
    local grunt = E.Spawn(st, 2, "grunt", X - 1, Y)
    check(E.Speed(st, grunt) > WC.Units.grunt.speed, "wc ability: Endurance Aura: faster")
    E.Strike(st, { id = 0, owner = 1 }, tc, 99999, false, "normal")
    check(not tc.dead and tc.buffs.reinc, "wc ability: Reincarnation: not dead yet")
    Run(st, 7.5)
    check(tc.hp == tc.maxHp and not tc.buffs, "wc ability: and back at full health")

    -- Shadow Hunter
    Clear()
    local sh = Hero(st, 2, "shadow_hunter", X, Y, 6, { healing_wave = 1, hex = 1, serpent_ward = 1, big_bad_voodoo = 1 })
    local g1 = E.Spawn(st, 2, "grunt", X + 1, Y)
    local g2 = E.Spawn(st, 2, "grunt", X + 2, Y)
    g1.hp, g2.hp = 100, 100
    Cast(st, sh, "healing_wave", g1)
    Run(st, 0.1)
    check(g1.hp > 100 and g2.hp > 100, "wc ability: Healing Wave heals and jumps")
    local foe = E.Spawn(st, 1, "footman", X + 3, Y)
    Cast(st, sh, "hex", foe)
    Run(st, 0.1)
    check(foe.buffs and foe.buffs.hex and E.CantAttack(foe), "wc ability: Hex: a sheep")
    Cast(st, sh, "serpent_ward", nil, X + 2, Y + 2)
    Run(st, 0.1)
    local ward = false
    for _, id in ipairs(st.list) do if st.ents[id].type == "serpent_ward1" then ward = true end end
    check(ward, "wc ability: a Serpent Ward")
    Cast(st, sh, "big_bad_voodoo")
    Run(st, 0.1)
    check(E.Untouchable(g1) and not E.Untouchable(sh), "wc ability: Big Bad Voodoo: friends invulnerable, not the hero")
end

-- A hero dies: experience for the killer's heroes, revive at the altar.
function WcHeroRevive()
    local st = Game()
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local ax, ay = WC.AI.FindSpot(st, hx + 6, hy + 6, 3)
    local altar = E.SpawnBuilding(st, 1, "altar_kings", ax, ay, true)
    local mk = Hero(st, 1, "mountain_king", 30, 20, 3, { storm_bolt = 2 })
    local bm = Hero(st, 2, "blademaster", 31, 20, 1, {})
    local xp = bm.xp
    E.Strike(st, { id = 0, owner = 2 }, mk, 99999, false, "normal")
    Run(st, 0.1)
    check(mk.dead and st.players[1].fallen.mountain_king.level == 3, "wc hero: the fallen hero is remembered")
    check(bm.xp > xp, "wc hero: the other side's hero gets the experience")
    local ok, why = E.Command(st, 1, { type = "train", building = altar.id, utype = "mountain_king" })
    check(not ok and why == "revive that hero instead", "wc hero: revive, don't train again (" .. tostring(why) .. ")")
    check(E.Command(st, 1, { type = "revive", building = altar.id, utype = "mountain_king" }), "wc hero: revive at the altar")
    Run(st, E.ReviveTime(st, 1, "mountain_king") + 1)
    local back
    for _, id in ipairs(st.list) do if st.ents[id].type == "mountain_king" then back = st.ents[id] end end
    check(back and back.level == 3 and back.skills.storm_bolt == 2 and back.hp == back.maxHp,
        "wc hero: back at level 3 with his skills, full health")
end

-- The computer trains heroes and casts their spells.
function WcHeroAI()
    local st = E.New({ factions = { "human", "orc" }, seed = 12, difficulty = "normal" })
    local casts, heroes = 0, {}
    for _ = 1, 20 * 60 * 16 do -- 16 minutes
        local events = E.Step(st, 0.05)
        for _, ev in ipairs(events) do
            if ev.kind == "cast" then casts = casts + 1 end
        end
        if math.floor(st.time * 20 + 0.5) % 20 == 0 then
            WC.AI.Think(st, 1)
            WC.AI.Think(st, 2)
        end
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and E.IsHero(e) then heroes[e.type] = math.max(heroes[e.type] or 0, e.level) end
        end
        if st.over then break end
    end
    local names = {}
    for k, v in pairs(heroes) do table.insert(names, k .. " " .. v) end
    table.sort(names)
    local info = {}
    for p = 1, 2 do
        local c = E.Count(st, p)
        local b = {}
        for k, n in pairs(c.buildings) do table.insert(b, k .. "=" .. n) end
        table.sort(b)
        table.insert(info, "p" .. p .. ": " .. table.concat(b, ","))
    end
    check(#names >= 2, "wc hero AI: both sides got heroes (" .. table.concat(names, ", ") .. "; " .. table.concat(info, "; ") .. ")")
    -- The computer's hero casts when enemies are near (a set scene).
    local sc = E.New({ factions = { "human", "orc" }, seed = 3 })
    local mk = E.Spawn(sc, 1, "mountain_king", 30, 20)
    mk.skills.storm_bolt = 1
    for i = 1, 3 do E.Spawn(sc, 2, "grunt", 32 + i * 0.5, 20) end
    local cast = 0
    for _ = 1, 3 * 20 do
        for _, ev in ipairs(E.Step(sc, 0.05)) do if ev.kind == "cast" then cast = cast + 1 end end
        if math.floor(sc.time * 20 + 0.5) % 20 == 0 then WC.AI.Think(sc, 1) end
    end
    check(cast > 0, "wc hero AI: a hero next to enemies casts (" .. cast .. "; whole game: " .. casts .. ")")
    print("  wc hero AI: " .. table.concat(names, ", ") .. "; " .. casts .. " spells")
end

-- On the page: select a hero, learn a skill on the command card, cast it.
function WcHeroPage()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    Advance(0)
    local view = ns.UI.pages.warcraft.view
    view:NewGame("human", 21)
    local st = view.st
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local pal = E.Spawn(st, 1, "paladin", hx, hy + 4)
    view.sel = { pal.id }
    view:Draw()
    local function Button(title)
        for _, c in ipairs(view.cmds) do
            if c:IsShown() and c.title and c.title:find(title, 1, true) then return c end
        end
    end
    local plus = Button("Hero Abilities")
    check(plus and plus:IsEnabled(), "wc hero page: a skill point shows Hero Abilities (O)")
    plus.action()
    view:Draw()
    local learn = Button("Learn Holy Light")
    check(learn and learn:IsEnabled() and not Button("Learn Resurrection"):IsEnabled(), "wc hero page: learn Holy Light, not the ultimate")
    learn.action()
    view:Draw()
    check(pal.skills.holy_light == 1 and Button("Holy Light (T)") ~= nil, "wc hero page: Holy Light on the card")
    local fm = E.Spawn(st, 1, "footman", hx + 2, hy + 4)
    fm.hp = 100
    Button("Holy Light (T)").action()
    check(view.targeting == "cast", "wc hero page: click a target")
    view:TargetAt(fm.x, fm.y)
    for _ = 1, 20 do E.Step(st, 0.05) end
    check(fm.hp == 300, "wc hero page: the footman was healed (" .. fm.hp .. ")")
    view:Draw()
    check(view.selHp:GetText():find("Mana") ~= nil, "wc hero page: mana in the selection panel")
end
