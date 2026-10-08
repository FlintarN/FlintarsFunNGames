-- Warcraft III step 3: the rest of the armies, air, splash, casters, shops, upkeep.
local WC = ns.WC
local E = WC.Engine

local function Game(f1, f2)
    local st = E.New({ factions = { f1 or "human", f2 or "orc" }, seed = 44 })
    for p = 1, 2 do st.players[p].gold, st.players[p].lumber = 99999, 99999 end
    return st
end
local function Run(st, seconds)
    for _ = 1, math.floor(seconds / 0.05 + 0.5) do E.Step(st, 0.05) end
end
local function Done(st, p, btype, dx, dy)
    local hall = E.Hall(st, p)
    local hx, hy = E.Center(hall)
    local x, y = WC.AI.FindSpot(st, hx + dx, hy + dy, WC.Buildings[btype].size)
    return E.SpawnBuilding(st, p, btype, x, y, true)
end
local function Hold(u) u.order = { type = "hold" } return u end

function WcArmyTests()
    local st = Game()
    local hall = E.Hall(st, 1)
    -- Requirements: a Workshop needs a Keep and a Blacksmith; Knights need a Castle too.
    local w
    for _, id in ipairs(st.list) do if st.ents[id].owner == 1 and st.ents[id].kind == "unit" then w = st.ents[id] break end end
    local hx, hy = E.Center(hall)
    local x, y = WC.AI.FindSpot(st, hx + 7, hy, 3)
    local ok, why = E.Command(st, 1, { type = "build", unit = w.id, btype = "workshop", x = x, y = y })
    check(not ok and why == "requires Keep", "wc army: a Workshop needs a Keep (" .. tostring(why) .. ")")
    local rax = Done(st, 1, "barracks", 7, 6)
    ok, why = E.Command(st, 1, { type = "train", building = rax.id, utype = "knight" })
    check(not ok and why == "requires Castle", "wc army: Knights need a Castle (" .. tostring(why) .. ")")

    -- Air: flies straight over trees; footmen can't hit it, riflemen can.
    local fm = Hold(E.Spawn(st, 1, "footman", 30, 20))
    local rifle = Hold(E.Spawn(st, 1, "rifleman", 30, 21))
    local wind = E.Spawn(st, 2, "wind_rider", 31, 20)
    check(not E.CanHit(st, fm, wind) and E.CanHit(st, rifle, wind), "wc army: only ranged units hit flyers")
    local fly = E.Spawn(st, 1, "flying_machine", 4, 4)
    check(not E.CanHit(st, fly, E.Spawn(st, 2, "grunt", 5, 4)), "wc army: Flying Machines only hit flyers")
    E.Command(st, 1, { type = "move", units = { fly.id }, x = 4, y = 30 })
    E.Step(st, 0.05)
    check(fly.path and #fly.path == 1, "wc army: flyers go in a straight line")
    Run(st, 8)
    check(math.abs(fly.y - 30) < 0.5, "wc army: over the trees and there")
    -- Siege Engines only hit buildings.
    local siege = E.Spawn(st, 1, "siege_engine", 40, 30)
    check(not E.CanHit(st, siege, E.Spawn(st, 2, "grunt", 41, 30)) and E.CanHit(st, siege, E.Hall(st, 2)),
        "wc army: Siege Engines attack buildings only")
    -- Splash: a Mortar Team hits a group.
    local mortar = E.Spawn(st, 1, "mortar_team", 20, 30)
    local g1 = Hold(E.Spawn(st, 2, "grunt", 26, 30))
    local g2 = Hold(E.Spawn(st, 2, "grunt", 26.6, 30))
    E.Command(st, 1, { type = "attack", units = { mortar.id }, target = g1.id })
    Run(st, 2)
    check(g1.hp < g1.maxHp and g2.hp < g2.maxHp, "wc army: Mortar splash hits both")

    -- Casters.
    local priest = E.Spawn(st, 1, "priest", 50, 10)
    local hurt = Hold(E.Spawn(st, 1, "footman", 51, 10))
    hurt.hp = 100
    Run(st, 2.5)
    check(hurt.hp > 100 and priest.mana < priest.maxMana, "wc army: the Priest heals by itself")
    local sorc = E.Spawn(st, 1, "sorceress", 50, 14)
    local foe = Hold(E.Spawn(st, 2, "grunt", 53, 14))
    Run(st, 1.5)
    check(foe.buffs and foe.buffs.slow, "wc army: the Sorceress slows enemies")
    local shaman = E.Spawn(st, 2, "shaman", 55, 20)
    local grunt = Hold(E.Spawn(st, 2, "grunt", 56, 20))
    Hold(E.Spawn(st, 1, "footman", 60, 20))
    Run(st, 1.5)
    check(grunt.buffs and grunt.buffs.bloodlust and E.Cooldown(st, grunt) < WC.Units.grunt.cooldown,
        "wc army: the Shaman casts Bloodlust: faster attacks")
    local wd = E.Spawn(st, 2, "witch_doctor", 55, 30)
    for i = 1, 2 do
        local g = Hold(E.Spawn(st, 2, "grunt", 55 + i, 31))
        g.hp = 100
    end
    Run(st, 1.5)
    local ward
    for _, id in ipairs(st.list) do if st.ents[id].type == "healing_ward" then ward = st.ents[id] end end
    check(ward and ward.expire, "wc army: the Witch Doctor drops a Healing Ward")
    -- Kodo drums.
    local g = E.Spawn(st, 2, "grunt", 40, 10)
    local before = E.Damage(st, g)
    E.Spawn(st, 2, "kodo", 41, 10)
    check(E.Damage(st, g) > before, "wc army: War Drums: more damage near a Kodo")

    -- Shops and items.
    local vault = Done(st, 1, "arcane_vault", -6, 6)
    local vx, vy = E.Center(vault)
    local pal = E.Spawn(st, 1, "paladin", vx + 2, vy)
    ok = E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "healing_potion" })
    check(ok and pal.items[1] == "healing_potion", "wc army: a hero buys a potion")
    pal.hp = 100
    E.Command(st, 1, { type = "useItem", unit = pal.id, slot = 1 })
    check(pal.hp == 350 and #pal.items == 0, "wc army: the potion heals 250")
    local speed = E.Speed(st, pal)
    E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "boots" })
    E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "ring" })
    check(E.Speed(st, pal) > speed and E.ArmorOf(st, pal) >= E.HeroArmor(pal), "wc army: boots and a ring")
    for _ = 1, 4 do E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "healing_potion" }) end
    ok, why = E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "healing_potion" })
    check(not ok and why == "the hero's bag is full", "wc army: six items at most (" .. tostring(why) .. ")")
    pal.x, pal.y = 50, 35
    ok, why = E.Command(st, 1, { type = "buy", building = vault.id, unit = pal.id, item = "claws" })
    check(not ok and why == "bring a hero next to the shop", "wc army: the hero must be at the shop")
    pal.items = { "town_portal" }
    E.Command(st, 1, { type = "useItem", unit = pal.id, slot = 1 })
    check((pal.x - hx) ^ 2 + (pal.y - hy) ^ 2 < 50, "wc army: Town Portal takes him home")

    -- Upkeep.
    st.players[1].food = 60
    check(E.Upkeep(st, 1) == 0.7, "wc army: upkeep above 50 food")
    st.players[1].food = 90
    check(select(2, E.Upkeep(st, 1)) == "high", "wc army: high upkeep above 80 food")
end

-- The computer builds the later buildings and trains new kinds of units.
function WcArmyAI()
    local st = E.New({ factions = { "human", "orc" }, seed = 9, difficulty = "normal" })
    st.players[1].gold, st.players[1].lumber = 4000, 4000 -- a head start: tech up quickly
    local h2 = E.Hall(st, 2)
    h2.maxHp, h2.hp = 1e9, 1e9 -- a passive opponent that lasts: only player 1 thinks
    local kinds = {}
    for _ = 1, 20 * 60 * 20 do -- 20 minutes
        E.Step(st, 0.05)
        if math.floor(st.time * 20 + 0.5) % 20 == 0 then
            WC.AI.Think(st, 1)
        end
        if math.floor(st.time * 20 + 0.5) % 200 == 0 then
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e.kind == "unit" then kinds[e.type] = true end
            end
        end
        if st.over then break end
    end
    local new = {}
    for _, k in ipairs({ "priest", "sorceress", "siege_engine", "flying_machine", "mortar_team", "gryphon_rider",
        "dragonhawk_rider", "knight", "catapult", "raider", "kodo", "wind_rider", "batrider", "shaman", "witch_doctor", "tauren" }) do
        if kinds[k] then table.insert(new, k) end
    end
    local c = E.Count(st, 1)
    local tech = (c.buildings.arcane_sanctum or 0) + (c.buildings.workshop or 0) + (c.buildings.gryphon_aviary or 0)
    check(tech >= 2 and #new >= 1, "wc army AI: the computer built later buildings (" .. tech .. ") and trained new kinds of units ("
        .. table.concat(new, ", ") .. ")")
    print("  wc army AI: " .. table.concat(new, ", "))
end

-- On the page: the 12-slot card, buying at a shop, the hero's bag.
function WcArmyPage()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    Advance(0)
    local view = ns.UI.pages.warcraft.view
    view:NewGame("human", 23)
    local st = view.st
    st.players[1].gold = 5000
    check(#view.cmds == 12, "wc army page: a 4 x 3 command card")
    local vault = Done(st, 1, "arcane_vault", -6, 6)
    local vx, vy = E.Center(vault)
    local pal = E.Spawn(st, 1, "paladin", vx + 2, vy)
    view.sel = { vault.id }
    view:Draw()
    local buy
    for _, c in ipairs(view.cmds) do if c:IsShown() and c.title == "Buy Potion of Healing (H)" then buy = c end end
    check(buy and buy:IsEnabled(), "wc army page: the shop sells to the hero next to it")
    buy.action()
    check(pal.items and pal.items[1] == "healing_potion", "wc army page: bought")
    view.sel = { pal.id }
    view:Draw()
    check(view.itemButtons[1]:IsShown() and view.itemButtons[1].item == "healing_potion", "wc army page: in the hero's bag")
    pal.hp = 100
    view.itemButtons[1]._scripts.OnClick()
    check(pal.hp == 350 and #pal.items == 0, "wc army page: click the potion to drink it")
    local holy
    for i = 9, 12 do if view.cmds[i]:IsShown() and view.cmds[i].title:find("Holy Light", 1, true) then holy = i end end
    check(holy == 9, "wc army page: the hero's abilities on the bottom row")
    -- Every building can be placed (its ghost has art): the Arcane Vault once broke this.
    local peasant
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e.owner == 1 and e.type == "peasant" then peasant = e break end
    end
    st.players[1].gold, st.players[1].lumber = 99999, 99999
    local keys = {}
    for k in pairs(WC.Buildings) do if k ~= "gold_mine" then table.insert(keys, k) end end
    table.sort(keys)
    local bad = {}
    for _, k in ipairs(keys) do
        view.sel = { peasant.id }
        local ok = pcall(view.StartPlace, view, k)
        if not ok then table.insert(bad, k) end
        view.place = nil
    end
    check(#bad == 0, "wc army page: every building can be placed (" .. table.concat(bad, ", ") .. ")")

    -- Cancel: a building going up (75% back), the last unit in training.
    st.players[1].gold, st.players[1].lumber = 1000, 1000
    local hall = E.Hall(st, 1)
    local hx, hy = E.Center(hall)
    local fx, fy = WC.AI.FindSpot(st, hx - 8, hy + 4, 2)
    E.Command(st, 1, { type = "build", unit = peasant.id, btype = "farm", x = fx, y = fy })
    local farm
    for _ = 1, 400 do
        E.Step(st, 0.05)
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e.type == "farm" and e.owner == 1 and e.progress < 1 then farm = e end
        end
        if farm then break end
    end
    check(farm ~= nil, "wc cancel: a farm going up")
    view.sel = { farm.id }
    view:Draw()
    check(view.cmds[12]:IsShown() and view.cmds[12].title == "Cancel", "wc cancel: a Cancel button on a building going up")
    local gold = st.players[1].gold
    view.cmds[12].action()
    check(not st.ents[farm.id] and st.players[1].gold == gold + math.floor(WC.Buildings.farm.cost[1] * 0.75)
        and not peasant.order, "wc cancel: gone, 75% back, the worker is free")
    local barracks = Done(st, 1, "barracks", 8, -6)
    E.Command(st, 1, { type = "train", building = barracks.id, utype = "footman" })
    view.sel = { barracks.id }
    view:Draw()
    check(view.cmds[11]:IsShown() and view.cmds[11].title == "Cancel", "wc cancel: Cancel while training")
    gold = st.players[1].gold
    view.cmds[11].action()
    check(#barracks.queue == 0 and st.players[1].gold == gold + WC.Units.footman.cost[1], "wc cancel: the footman is cancelled, gold back")

    -- Each creature its own look, even when the model frame is slow to switch.
    local fake = { cur = nil }
    function fake:SetCreature(n) self.pending = n end
    function fake:GetDisplayInfo() return self.cur or 0 end
    view.prober = fake
    ns.db.warcraft.looks = {}
    view:Probe(12126)
    fake.cur = 501 -- the paladin loaded
    view:Probe(2543)
    view:Probe(2543) -- still showing the paladin
    check(ns.db.warcraft.looks[12126] == 501 and ns.db.warcraft.looks[2543] == nil, "wc looks: a stale look isn't taken for the next creature")
    fake.cur = 777
    view:Probe(2543)
    check(ns.db.warcraft.looks[2543] == 777, "wc looks: the archmage gets its own look")
    view.prober = nil

    -- Spell effects: area spells, buffs on units, auras under heroes.
    local am = E.Spawn(st, 1, "archmage", hx + 3, hy + 3)
    am.skills.brilliance = 1
    view:Events({ { kind = "cast", id = am.id, owner = 1, ability = "blizzard", x = hx + 4, y = hy + 3, lv = 1 } })
    view:Draw()
    local area, aura = false, false
    for key, f in pairs(view.fx) do
        if f.file == ns.UI.pages.warcraft.view.SPELL_FX.blizzard[1] then area = true end
        if key == "a" .. am.id .. "brilliance" then aura = true end
    end
    check(area and aura, "wc fx: Blizzard on the ground, Brilliance Aura under the Archmage")
    local foot = E.Spawn(st, 1, "footman", hx + 2, hy + 4)
    E.AddBuff(foot, "stun", 2)
    view:Draw()
    check(view.fx["b" .. foot.id .. "stun"] ~= nil, "wc fx: a stunned unit shows the swirl")
    foot.buffs = nil
    view:Draw()
    check(view.fx["b" .. foot.id .. "stun"] == nil, "wc fx: gone when the stun ends")
end

-- The showcase: everything on one map, heroes cast their spells in turn.
function WcDemo()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    local saved = ns.db.warcraft.game
    view.demoButton._scripts.OnClick()
    local st = view.st
    check(st and st.demo and not view.overlay:IsShown(), "wc demo: the showcase starts from the menu")
    local types = {}
    for _, id in ipairs(st.list) do if st.ents[id] then types[st.ents[id].type] = true end end
    local missing = {}
    for k, b in pairs(WC.Buildings) do if not types[k] and not rawget(b, "base") then table.insert(missing, k) end end
    for _, k in ipairs({ "footman", "knight", "gryphon_rider", "tauren", "wind_rider", "paladin", "shadow_hunter" }) do
        if not types[k] then table.insert(missing, k) end
    end
    table.sort(missing)
    check(#missing == 0, "wc demo: every building and the units are there (" .. table.concat(missing, ", ") .. ")")
    local real = ns.UI.pages.warcraft.view.SpellEvents
    local casts, fights = 0, 0
    view.SpellEvents = function(self, events)
        for _, ev in ipairs(events) do
            if ev.kind == "cast" then casts = casts + 1 end
            if ev.kind == "hit" then fights = fights + 1 end
        end
        return real(self, events)
    end
    local where = {}
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.kind == "unit" then where[id] = e.x + e.y end end
    for _ = 1, 30 * 20 do view:Tick(0.05) end
    view.SpellEvents = nil
    local moved = 0
    for id, p in pairs(where) do local e = st.ents[id] if e and math.abs(e.x + e.y - p) > 0.01 then moved = moved + 1 end end
    check(not st.over and casts == 0 and fights == 0 and moved == 0,
        "wc demo: nothing happens by itself (" .. casts .. " casts, " .. fights .. " hits, " .. moved .. " moved)")
    check(ns.db.warcraft.game == nil, "wc demo: the Showcase replaces your game (nothing left running)")
    check(view.demoText[1] and view.demoText[1]:IsShown(), "wc demo: names under everything")
    -- You cast: every ability is known, mana and cooldowns refill.
    local am
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "archmage" then am = e end end
    local d0
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "target_dummy" then d0 = e break end end
    for round = 1, 2 do
        local ok, why = E.Command(st, 1, { type = "cast", unit = am.id, ability = "blizzard", x = am.x + 2, y = am.y + 2 })
        check(ok, "wc demo: Blizzard, round " .. round .. " (" .. tostring(why) .. ")")
        for _ = 1, 3 * 20 do view:Tick(0.05) end
    end
    -- Attack a Target Dummy on purpose.
    local dummy, knight
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.type == "target_dummy" and not dummy then dummy = e end
        if e and e.type == "knight" then knight = e end
    end
    E.Command(st, 1, { type = "attack", units = { knight.id }, target = dummy.id })
    local before = dummy.hp
    for _ = 1, 15 * 20 do view:Tick(0.05) end
    local hits = 0
    view.SpellEvents = function(self, events)
        for _, ev in ipairs(events) do if ev.kind == "hit" and ev.id == knight.id and ev.target == dummy.id then hits = hits + 1 end end
        return real(self, events)
    end
    for _ = 1, 5 * 20 do view:Tick(0.05) end
    view.SpellEvents = nil
    check(hits > 0, "wc demo: a knight attacks the Target Dummy when told (" .. hits .. " hits)")
    check(knight.order and knight.order.type == "attack", "wc demo: still on it")
    -- Looks: Avatar makes a hero bigger and grey; Bladestorm spins; the
    -- Catapult is a model file; flyers have a shadow.
    local mk, bm, cat, hawk
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.type == "mountain_king" then mk = e end
        if e and e.type == "blademaster" then bm = e end
        if e and e.type == "catapult" then cat = e end
        if e and e.type == "dragonhawk_rider" then hawk = e end
    end
    view.camX, view.camY = 0, mk.y * 20 - 150
    view:Draw()
    local m = view.unitFrames[mk.id].model
    -- Team colour in the unit's light: player 1 blue, player 2 red.
    local a = m._ambient
    if mk.owner == 1 then
        check(a and a[3] > a[1], "wc looks: player 1's units are lit blue")
    else
        check(a and a[1] > a[3], "wc looks: player 2's units are lit red")
    end
    local before = m.k
    E.AddBuff(mk, "avatar", 10)
    view:Draw()
    check(m.k > before and m.desat > 0.5, "wc looks: Avatar, bigger and grey (" .. before .. " > " .. m.k .. ")")
    E.AddBuff(bm, "bladestorm", 10, { dps = 0 })
    view:Draw()
    check(view.unitFrames[bm.id].model.anim == 17, "wc looks: Bladestorm swings round")
    view.camX, view.camY = cat.x * 20 - 300, cat.y * 20 - 150
    view:Draw()
    check(view.unitFrames[cat.id].model.disp == "f" .. WC.Units.catapult.file, "wc looks: the Catapult's own model")
    check(view.unitFrames[hawk.id].shadow ~= nil, "wc looks: a flyer's shadow")

    -- Sound: a voice when selected or ordered, annoyed when clicked a lot;
    -- the Game sounds switch mutes it.
    local S = WC.Sounds
    local function Has(list, id) for _, x in ipairs(list) do if x == id then return true end end end
    local foot
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "footman" then foot = e end end
    view.camX, view.camY = foot.x * 20 - 300, foot.y * 20 - 150
    SOUND_FILES = {}
    view:SelectAt(foot.x, foot.y)
    check(#SOUND_FILES == 1 and Has(S.Voices.footman.what, SOUND_FILES[1]), "wc sound: the Footman answers when selected")
    for _ = 1, 4 do view:SelectAt(foot.x, foot.y) end
    check(Has(S.Voices.footman.pissed, SOUND_FILES[#SOUND_FILES]), "wc sound: annoyed after clicking it a lot")
    SOUND_FILES = {}
    view.lastAck = nil
    view:Smart(foot.x + 2, foot.y)
    check(#SOUND_FILES == 1 and Has(S.Voices.footman.yes, SOUND_FILES[1]), "wc sound: yes, on the move")
    SOUND_FILES = {}
    view:Say("Not enough gold or lumber")
    check(#SOUND_FILES == 1 and SOUND_FILES[1] == S.Error, "wc sound: the warning sound")
    ns.db.sound = false
    SOUND_FILES = {}
    view:SelectAt(foot.x, foot.y)
    view:Say("Not enough gold or lumber")
    check(#SOUND_FILES == 0, "wc sound: Game sounds off: quiet, warnings too")
    ns.db.sound = true
    -- A building of yours makes its sound when clicked; buying rings a coin.
    local farm
    for _, id in ipairs(st.list) do local e = st.ents[id] if e and e.type == "farm" and e.owner == 1 then farm = e end end
    view.camX, view.camY = farm.x * 20 - 300, farm.y * 20 - 150
    SOUND_FILES = {}
    view:SelectAt(farm.x + 1, farm.y + 1)
    check(SOUND_FILES[1] == S.Buildings.farm, "wc sound: a farm sounds like a farm")
    SOUND_FILES = {}
    view:Acknowledge({ type = "buy" })
    check(SOUND_FILES[1] == S.Buy, "wc sound: a coin when you buy")
    -- Every unit has a voice, every hero ability a sound.
    local mute = {}
    for k, u in pairs(WC.Units) do
        if not u.summon and not u.creep and not rawget(u, "base") and k ~= "catapult" and k ~= "target_dummy" and k ~= "sheep" and not k:find("%d$")
            and not (S.Voices[k] and S.Voices[k].what) then table.insert(mute, k) end
    end
    for k, a in pairs(WC.Abilities) do
        if not a.passive and not S.Spells[k] then table.insert(mute, k) end
    end
    table.sort(mute)
    check(#mute == 0, "wc sound: every unit has a voice and every spell a sound (" .. table.concat(mute, ", ") .. ")")
    view:ShowMenu()
end

-- Casters: every spell by hand, autocast on and off, Defend.
function WcCasterTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 12 })
    local function Hold(u) u.order = { type = "hold" } return u end
    local function Cast(u, key, t, x, y)
        u.mana, u.cds = u.maxMana, nil
        local ok, why = E.Command(st, u.owner, { type = "cast", unit = u.id, ability = key, target = t and t.id, x = x, y = y })
        for _ = 1, 30 do E.Step(st, 0.05) end
        return ok, why
    end
    local sorc = Hold(E.Spawn(st, 1, "sorceress", 30, 20))
    local grunt = Hold(E.Spawn(st, 2, "grunt", 33, 20))
    check(Cast(sorc, "polymorph", grunt) and grunt.buffs and grunt.buffs.hex, "casters: Polymorph turns a grunt into a sheep")
    local bm = Hold(E.Spawn(st, 2, "blademaster", 33, 22))
    sorc.mana, sorc.cds = sorc.maxMana, nil
    local ok, why = E.Command(st, 1, { type = "cast", unit = sorc.id, ability = "polymorph", target = bm.id })
    check(not ok and why == "not on a hero", "casters: Polymorph doesn't work on heroes (" .. tostring(why) .. ")")
    local foot = Hold(E.Spawn(st, 1, "footman", 30, 24))
    check(Cast(sorc, "invisibility", foot) and E.Hidden(foot), "casters: Invisibility hides a footman")
    E.Strike(st, foot, grunt, 5, false, "normal")
    check(not E.Hidden(foot), "casters: attacking shows it again")
    -- Shaman: Purge destroys a summon; Lightning Shield burns neighbours.
    local sham = Hold(E.Spawn(st, 2, "shaman", 40, 30))
    local wolf = E.Spawn(st, 1, "spirit_wolf1", 42, 30)
    wolf.summon, wolf.expire = true, st.time + 60
    Cast(sham, "purge", wolf)
    check(not st.ents[wolf.id], "casters: Purge destroys a summoned wolf")
    local g2 = Hold(E.Spawn(st, 2, "grunt", 44, 34))
    local near = Hold(E.Spawn(st, 1, "footman", 44.8, 34))
    local hp = near.hp
    sham.mana = sham.maxMana
    Cast(sham, "lightning_shield", g2)
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(g2.buffs and g2.buffs.lshield and near.hp < hp, "casters: Lightning Shield burns the footman next to it")
    -- Raider: Ensnare roots and pulls a flyer down so melee can hit it.
    local raider = Hold(E.Spawn(st, 2, "raider", 50, 10))
    local gry = Hold(E.Spawn(st, 1, "gryphon_rider", 53, 10))
    local fm = E.Spawn(st, 1, "footman", 51, 12)
    local g3 = E.Spawn(st, 2, "grunt", 52, 12)
    check(not E.CanHit(st, g3, gry), "casters: a grunt can't hit a gryphon")
    Cast(raider, "ensnare", gry)
    check(gry.buffs and gry.buffs.ensnare and E.CanHit(st, g3, gry) and E.Speed(st, gry) == 0,
        "casters: Ensnare: it can't move, and melee can hit it")
    -- Footman: Defend halves pierce damage and slows it.
    local d1 = Hold(E.Spawn(st, 1, "footman", 10, 30))
    local speed = E.Speed(st, d1)
    check(E.Command(st, 1, { type = "defend", units = { d1.id }, on = true }) and d1.defend and E.Speed(st, d1) < speed,
        "casters: Defend on: slower")
    local rifle = E.Spawn(st, 2, "headhunter", 12, 30)
    local before = d1.hp
    E.Strike(st, rifle, d1, 20, true, "pierce")
    local withDefend = before - d1.hp
    d1.defend = nil
    before = d1.hp
    E.Strike(st, rifle, d1, 20, true, "pierce")
    check(withDefend < before - d1.hp, "casters: Defend: less damage from spears (" .. withDefend .. " vs " .. (before - d1.hp) .. ")")
    -- Witch Doctor: a Stasis Trap stuns enemies that come near.
    local wd = Hold(E.Spawn(st, 2, "witch_doctor", 20, 10))
    Cast(wd, "stasis_trap", nil, 22, 10)
    local trap
    for _, id in ipairs(st.list) do if st.ents[id] and st.ents[id].type == "stasis_trap" then trap = st.ents[id] end end
    check(trap and E.Hidden(trap), "casters: an invisible Stasis Trap")
    local walker = E.Spawn(st, 1, "footman", trap.x + 1, trap.y)
    for _ = 1, 10 do E.Step(st, 0.05) end
    check(walker.buffs and walker.buffs.stun and not st.ents[trap.id], "casters: it springs: the footman is stunned")
    -- Priest: Dispel Magic takes spells off units in an area.
    local pr = Hold(E.Spawn(st, 1, "priest", 30, 34))
    local lusted = Hold(E.Spawn(st, 2, "grunt", 32, 34))
    E.AddBuff(lusted, "bloodlust", 60)
    Cast(pr, "dispel", nil, 32, 34)
    check(not (lusted.buffs and lusted.buffs.bloodlust), "casters: Dispel Magic takes Bloodlust off")
    -- Autocast: off by command, then no heal.
    local pr2 = Hold(E.Spawn(st, 1, "priest", 5, 36))
    local hurt = Hold(E.Spawn(st, 1, "footman", 6, 36))
    hurt.hp = 100
    E.Command(st, 1, { type = "autocast", units = { pr2.id }, ability = "heal", on = false })
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(hurt.hp == 100, "casters: autocast off: no heal")
    E.Command(st, 1, { type = "autocast", units = { pr2.id }, ability = "heal", on = true })
    for _ = 1, 40 do E.Step(st, 0.05) end
    check(hurt.hp > 100, "casters: autocast on: it heals")

    -- The command card: a priest's spells; right-click switches autocast.
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    view:NewGame("human", 5)
    local s2 = view.st
    local p3 = E.Spawn(s2, 1, "priest", 20, 20)
    view.sel = { p3.id }
    view:Draw()
    local heal
    for _, c in ipairs(view.cmds) do if c:IsShown() and c.title == "Heal (E)" then heal = c end end
    check(heal and heal.auto:GetText() == "auto", "casters card: Heal, autocast on")
    heal._scripts.OnClick(heal, "RightButton")
    view:Draw()
    check(p3.auto and p3.auto.heal == false and heal.auto:GetText() == "", "casters card: right-click: autocast off")
    local disp
    for _, c in ipairs(view.cmds) do if c:IsShown() and c.title == "Dispel Magic (D)" then disp = c end end
    disp._scripts.OnClick(disp, "LeftButton")
    check(view.targeting == "cast" and view.castKey == "dispel", "casters card: Dispel Magic asks where")
    view:Draw()
    check(view.aoeTex and view.aoeTex:IsShown(), "casters card: a ring under the cursor shows where it lands")
    view.targeting = nil
    view:Draw()
    check(not view.aoeTex:IsShown(), "casters card: gone when not aiming")
    -- Projectiles: a rifleman's shot flies as a bullet, a mortar's in an arc.
    local rf = E.Spawn(s2, 1, "rifleman", 21, 22)
    local mt = E.Spawn(s2, 1, "mortar_team", 21, 24)
    local tg = E.Spawn(s2, 2, "grunt", 25, 22)
    view.camX, view.camY = 21 * 20 - 300, 22 * 20 - 150
    view:Events({ { kind = "hit", id = rf.id, target = tg.id, ranged = true }, { kind = "hit", id = mt.id, target = tg.id, ranged = true } })
    local bullet, boulder
    for _, fx in pairs(view.fx or {}) do
        if fx.move and fx.file == view.MISSILE.rifleman then bullet = fx end
        if fx.move and fx.file == view.MISSILE.mortar_team and fx.move[7] > 0 then boulder = fx end
    end
    check(bullet and boulder, "projectiles: a bullet, and a boulder in an arc")
    view:Quit()
end

-- Towers: Cannon (area, ground only), Arcane (mana burn, sees invisible),
-- each Scout Tower upgrades on its own; Spiked Barricades.
function WcTowerTests()
    local st = E.New({ factions = { "human", "orc" }, seed = 15 })
    for p = 1, 2 do st.players[p].gold, st.players[p].lumber = 99999, 99999 end
    local function Tower(x, y) return E.SpawnBuilding(st, 1, "scout_tower", x, y, true) end
    local t1, t2 = Tower(20, 20), Tower(26, 20)
    E.SpawnBuilding(st, 1, "lumber_mill", 20, 26, true)
    check(E.Command(st, 1, { type = "research", building = t1.id, key = "guard_tower" }), "towers: upgrade one Scout Tower")
    check(E.Command(st, 1, { type = "research", building = t2.id, key = "guard_tower" }), "towers: and another one too")
    local ok, why = E.Command(st, 1, { type = "research", building = t1.id, key = "cannon_tower" })
    check(not ok, "towers: one upgrade at a time per tower (" .. tostring(why) .. ")")
    for _ = 1, 35 * 20 do E.Step(st, 0.05) end
    check(t1.type == "guard_tower" and t2.type == "guard_tower", "towers: both became Guard Towers")
    local t3 = Tower(32, 20)
    ok, why = E.Command(st, 1, { type = "research", building = t3.id, key = "cannon_tower" })
    check(not ok and why == "requires Workshop", "towers: a Cannon Tower needs a Workshop (" .. tostring(why) .. ")")
    E.SpawnBuilding(st, 1, "workshop", 32, 26, true)
    check(E.Command(st, 1, { type = "research", building = t3.id, key = "cannon_tower" }), "towers: with a Workshop it can")
    for _ = 1, 50 * 20 do E.Step(st, 0.05) end
    check(t3.type == "cannon_tower", "towers: a Cannon Tower")
    -- It shells a group on the ground, and leaves a flyer alone.
    local g1 = E.Spawn(st, 2, "grunt", 36, 21)
    local g2 = E.Spawn(st, 2, "grunt", 36.6, 21)
    g1.order, g2.order = { type = "hold" }, { type = "hold" }
    for _ = 1, 3 * 20 do E.Step(st, 0.05) end
    check(g1.hp < g1.maxHp and g2.hp < g2.maxHp, "towers: the Cannon Tower hits both grunts")
    local wr = E.Spawn(st, 2, "wind_rider", 36, 24)
    wr.order = { type = "hold" }
    g1.hp, g2.hp = 0, 0
    st.ents[g1.id], st.ents[g2.id] = nil, nil
    for _ = 1, 3 * 20 do E.Step(st, 0.05) end
    check(wr.hp == wr.maxHp, "towers: it doesn't shoot the Wind Rider (flyers)")
    -- Arcane Tower: burns a shaman's mana; sees an invisible unit.
    E.SpawnBuilding(st, 1, "arcane_sanctum", 40, 26, true)
    local t4 = Tower(44, 30)
    E.Command(st, 1, { type = "research", building = t4.id, key = "arcane_tower" })
    for _ = 1, 40 * 20 do E.Step(st, 0.05) end
    local sh = E.Spawn(st, 2, "shaman", 47, 31)
    sh.order = { type = "hold" }
    local mana = sh.mana
    for _ = 1, 2 * 20 do E.Step(st, 0.05) end
    check(t4.type == "arcane_tower" and sh.mana < mana, "towers: the Arcane Tower burns the Shaman's mana")
    E.AddBuff(sh, "invis", 60)
    sh.hp = sh.maxHp
    local before = sh.hp
    for _ = 1, 3 * 20 do E.Step(st, 0.05) end
    check(sh.hp < before, "towers: it sees and shoots an invisible unit")
    -- Spiked Barricades: a grunt hitting an Orc building... (here: Human attacker on an Orc building)
    local wm = E.SpawnBuilding(st, 2, "war_mill", 10, 30, true)
    E.Command(st, 2, { type = "research", building = wm.id, key = "spikes" })
    for _ = 1, 25 * 20 do E.Step(st, 0.05) end
    check(E.Level(st, 2, "spikes") == 1, "towers: Spiked Barricades researched")
    local fm = E.Spawn(st, 1, "footman", 13.6, 31)
    local hp = fm.hp
    E.Command(st, 1, { type = "attack", units = { fm.id }, target = wm.id })
    for _ = 1, 3 * 20 do E.Step(st, 0.05) end
    check(fm.hp < hp, "towers: the footman hitting the War Mill gets spiked")
end
