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
    for k in pairs(WC.Buildings) do if not types[k] then table.insert(missing, k) end end
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
    check(ns.db.warcraft.game == saved, "wc demo: your saved game is left alone")
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
    view:ShowMenu()
end
