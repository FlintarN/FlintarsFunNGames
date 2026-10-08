-- Warcraft 4: the WoW classes (Classes.lua) and loot (Loot.lua), in Hero Defense.
local WC = ns.WC
local E = WC.Engine
local HD = WC.Modes.hd
local C = WC.Classes
local A = WC.Abilities

local function Run(st, seconds)
    local t = 0
    while t < seconds and not st.over do
        E.Step(st, 0.1)
        t = t + 0.1
    end
end

-- A game alone with a hero of class `cls`, at level `lv` with every spell
-- learned as far as it goes.
local function Game(cls, lv, factions)
    local st = E.New({ factions = factions or { "human" }, map = "hd_castle", mode = "hd", seed = 4 })
    st.hd.nextWave = 1e9 -- (no waves: the test makes its own creeps)
    E.Command(st, 1, { type = "train", building = HD.Altar(st, 1).id, utype = "cls_" .. cls })
    Run(st, 4)
    local h = HD.Hero(st, 1)
    if lv and h then
        E.GiveXp(st, h, WC.XP_LEVELS[lv - 1] - h.xp)
        for _, key in ipairs(WC.Units[h.type].abilities) do
            local a = A[key]
            local n = 0
            for i, need in ipairs(a.needs) do if h.level >= need then n = i end end
            h.skills[key] = n
        end
        h.points = 0
    end
    return st, h
end

local function Creep(st, utype, x, y, hp)
    local u = E.Spawn(st, st.hd.creeps, utype or "hd_ogre", x, y)
    u.maxHp, u.hp = hp or 3000, hp or 3000
    return u
end

function WcClassTests()
    -- Ten classes, each with four spells, an ultimate and Attributes.
    check(#C.ORDER == 10, "classes: ten")
    for _, k in ipairs(C.ORDER) do
        local d, dh = WC.Units["cls_" .. k], WC.Units["cls_" .. k .. "_h"]
        check(d and dh and d.maxLevel == 25 and d.hero and #d.abilities == 6 and d.abilities[6] == "attributes",
            "class " .. k .. ": a hero to level 25 with six skills")
        check(dh.npc == C.LOOKS[k][2] and d.npc == C.LOOKS[k][1], "class " .. k .. ": Alliance and Horde looks")
        local ults = 0
        for _, key in ipairs(d.abilities) do
            local a = A[key]
            check(a and a.needs, "class " .. k .. ": " .. key .. " has its ranks")
            if a.ult then ults = ults + 1 end
            if not a.passive then check(E.CAST[key] ~= nil, "class " .. k .. ": " .. key .. " can be cast") end
        end
        check(ults == 1, "class " .. k .. ": one ultimate")
    end
    check(#WC.Buildings.hd_altar.trains == 10 and WC.Buildings.hd_altar_orc.trains[1] == "cls_warrior_h", "classes: the altars offer them")

    -- Levels past 10, a point each; ranks open at their levels.
    local st, h = Game("paladin")
    check(h and h.level == 1 and h.points == 1, "classes: a level-1 hero with a point")
    check(E.Command(st, 1, { type = "learn", unit = h.id, ability = "holy_light_p" }), "classes: learn Holy Light")
    E.GiveXp(st, h, WC.XP_LEVELS[2] - h.xp) -- level 3
    local ok, why = E.Command(st, 1, { type = "learn", unit = h.id, ability = "holy_light_p" })
    check(not ok and why == "needs hero level 4", "classes: rank 2 opens at level 4 (" .. tostring(why) .. ")")
    check(not E.Command(st, 1, { type = "learn", unit = h.id, ability = "divine_shield_p" }), "classes: the ultimate waits for level 6")
    E.GiveXp(st, h, 1e6)
    check(h.level == 25, "classes: up to level 25 (" .. h.level .. ")")
    local hp25 = h.maxHp

    -- Every spell of every class, cast for real at level 25.
    for _, k in ipairs(C.ORDER) do
        local gs, hero = Game(k, 25)
        local cx, cy = 32, 26
        hero.x, hero.y = cx, cy
        local foes = { Creep(gs, "hd_ogre", cx + 1.2, cy), Creep(gs, "hd_ogre", cx + 1.5, cy + 0.8), Creep(gs, "hd_thug", cx + 2, cy - 0.6) }
        local cast, hurt = 0, 0
        for _, key in ipairs(WC.Units[hero.type].abilities) do
            local a = A[key]
            if not a.passive then
                hero.mana, hero.cds = 100000, {}
                local f = foes[1].dead and foes[2] or foes[1]
                if f.dead then f = foes[3] end
                local cmd = { type = "cast", unit = hero.id, ability = key }
                if a.target == "enemy" then cmd.target = f.id
                elseif a.target == "ally" then hero.hp = hero.maxHp / 2 cmd.target = hero.id
                elseif a.target == "point" then cmd.x, cmd.y = f.x, f.y end
                local before = 0
                for _, e in ipairs(foes) do before = before + math.max(0, e.hp) end
                local okc, whyc = E.Command(gs, 1, cmd)
                check(okc, k .. ": cast " .. key .. " (" .. tostring(whyc) .. ")")
                local pass, t = false, 0
                while t < 6 and not pass do
                    E.Step(gs, 0.1)
                    t = t + 0.1
                    if hero.cds and hero.cds[key] then pass = true end
                end
                check(pass, k .. ": " .. key .. " went off")
                Run(gs, 2)
                local after = 0
                for _, e in ipairs(foes) do after = after + math.max(0, e.dead and 0 or e.hp) end
                if after < before then hurt = hurt + 1 end
                cast = cast + 1
            end
        end
        check(hurt >= 2, k .. ": its spells hurt the creeps (" .. hurt .. " of " .. cast .. ")")
    end

    -- Rage builds in a fight; energy comes back by itself; combo points.
    local ws, w = Game("warrior", 5)
    check(w.mana == 0 and w.maxMana == 100, "warrior: rage starts empty")
    w.x, w.y = 32, 26
    local dummy = Creep(ws, "hd_ogre", 33, 26, 99999)
    E.Command(ws, 1, { type = "attack", units = { w.id }, target = dummy.id })
    Run(ws, 6)
    check(w.mana > 10, "warrior: hitting builds rage (" .. math.floor(w.mana) .. ")")
    local rs, r = Game("rogue", 9)
    r.mana = 0
    Run(rs, 2)
    check(r.mana >= 18 and r.mana <= 22, "rogue: energy comes back, 10 a second (" .. math.floor(r.mana) .. ")")
    r.x, r.y = 32, 26
    local mark = Creep(rs, "hd_ogre", 33, 26, 99999)
    for _ = 1, 3 do
        r.mana, r.cds = 100, {}
        E.Command(rs, 1, { type = "cast", unit = r.id, ability = "sinister_strike", target = mark.id })
        Run(rs, 1.2)
    end
    check(r.combo == 3 and r.comboOn == mark.id, "rogue: three combo points (" .. tostring(r.combo) .. ")")
    local hp0 = mark.hp
    r.mana, r.cds = 100, {}
    E.Command(rs, 1, { type = "cast", unit = r.id, ability = "eviscerate", target = mark.id })
    Run(rs, 1.2)
    check((r.combo or 0) == 0 and hp0 - mark.hp >= 3 * WC.Abilities.eviscerate.fx[1][2][3], "rogue: Eviscerate spends them (" .. math.floor(hp0 - mark.hp) .. ")")

    -- A Hunter's pet: comes, follows, comes back.
    local hs, hu = Game("hunter", 12)
    E.Command(hs, 1, { type = "cast", unit = hu.id, ability = "call_pet" })
    Run(hs, 1)
    local pet = hs.ents[hu.pet or 0]
    check(pet and pet.master == hu.id and pet.type == "pet_wolf4", "hunter: a wolf (" .. tostring(pet and pet.type) .. ")")
    E.Command(hs, 1, { type = "move", units = { hu.id }, x = 22, y = 40 })
    Run(hs, 8)
    check((pet.x - hu.x) ^ 2 + (pet.y - hu.y) ^ 2 < 50, "hunter: the pet keeps up")
end

function WcLootTests()
    local L = WC.Loot
    local it = WC.Items["g:1:3:1:10"]
    check(it and it.name == "Shortsword of the Bear" and it.damage > 0 and it.str > 0 and it.hp > 0 and it.quality == 3,
        "loot: a green Shortsword of the Bear (" .. tostring(it and it.name) .. ")")
    local grey = WC.Items["g:7:1:1:3"]
    check(grey and grey.name:find("Leather Tunic", 1, true) and not grey.str and grey.armor >= 1, "loot: grey items have no suffix")
    local epic = WC.Items["n:cruel_barb"]
    check(epic and epic.name == "Cruel Barb" and epic.quality == 5, "loot: VanCleef's Cruel Barb")

    -- Stats count: an item of the Bear makes the hero stronger.
    local st = E.New({ factions = { "human", "orc" }, map = "hd_castle", mode = "hd", seed = 4 })
    st.hd.nextWave = 1e9
    E.Command(st, 1, { type = "train", building = HD.Altar(st, 1).id, utype = "cls_warrior" })
    E.Command(st, 2, { type = "train", building = HD.Altar(st, 2).id, utype = "cls_priest_h" })
    Run(st, 4)
    local a, b = HD.Hero(st, 1), HD.Hero(st, 2)
    local str, hp = E.Stat(a, "str"), a.maxHp
    a.x, a.y, b.x, b.y = 30, 24, 36, 24
    L.Drop(st, { "g:1:3:1:10" }, a.x, a.y)
    Run(st, 0.5)
    check(a.gear and a.gear[1] == "g:1:3:1:10" and #(a.items or {}) == 0, "loot: walking over a weapon puts it on")
    check(E.Stat(a, "str") == str + it.str and a.maxHp > hp, "loot: its strength and stamina count")

    -- Gear and bag: six of each. Potions go in the bag, gear on the hero.
    a.items = {}
    local L = WC.Loot
    check(L.Give(st, a, "healing_potion") and a.items[1] == "healing_potion", "gear: a potion goes in the bag")
    check(L.Give(st, a, "g:14:3:8:6") and a.gear[5] == "g:14:3:8:6", "gear: a ring goes on (an accessory slot)")
    -- A second weapon: in the bag (the weapon slot is taken); equip it to swap.
    local axe = "g:2:4:8:15"
    check(L.Give(st, a, axe) and a.items[2] == axe, "gear: a second weapon waits in the bag")
    local before = E.Stat(a, "str")
    check(E.Command(st, 1, { type = "equip", unit = a.id, slot = 2 }) and a.gear[1] == axe and a.items[2] == "g:1:3:1:10",
        "gear: equip it - the old one goes to the bag")
    check(E.Stat(a, "str") ~= before, "gear: the stats change with it")
    -- Only worn gear counts: what's in the bag does nothing.
    local worn = E.ItemBonus(a, "str")
    a.items[3] = "n:dragonslayers_signet"
    check(E.ItemBonus(a, "str") == worn, "gear: things in the bag don't count")
    a.items[3] = nil
    check(E.Command(st, 1, { type = "unequip", unit = a.id, gear = 5 }) and not a.gear[5] and a.items[3] == "g:14:3:8:6",
        "gear: take it off - into the bag")
    -- A revived hero comes back wearing its gear.
    local gearBefore = a.gear[1]
    E.Strike(st, b, a, 1e6, false, "spell")
    Run(st, 120)
    local back = HD.Hero(st, 1)
    check(back and back.gear and back.gear[1] == gearBefore, "gear: still worn after a revive")
    a = back
    a.x, a.y = 30, 24
    a.items = { "g:1:3:1:10" }

    -- Trading: drop it, a friend picks it up.
    check(E.Command(st, 1, { type = "dropItem", unit = a.id, slot = 1 }) and #a.items == 0, "loot: drop it")
    Run(st, 1)
    check(#a.items == 0, "loot: not straight back into your own bag")
    local item = st.items[#st.items]
    E.Command(st, 2, { type = "move", units = { b.id }, x = item.x, y = item.y })
    Run(st, 5)
    check(b.gear and b.gear[1] == "g:1:3:1:10", "loot: a friend picks it up (and wears it)")
    E.Command(st, 2, { type = "unequip", unit = b.id, gear = 1 })

    -- Selling at the merchant.
    local shop = st.ents[st.hd.shop]
    local sx, sy = E.Center(shop)
    b.x, b.y, b.order, b.path = sx + 1, sy + 2, nil, nil
    local gold = st.players[2].gold
    check(E.Command(st, 2, { type = "sellItem", unit = b.id, slot = 1, building = shop.id }), "loot: sell it")
    check(st.players[2].gold == gold + math.floor(it.cost * 0.5) and #b.items == 0, "loot: half its worth in gold")

    -- A boss drops its own.
    local boss = E.Spawn(st, st.hd.creeps, "hd_vancleef", 30, 30)
    boss.hdBounty, boss.hdBoss, boss.hp = 100, true, 1
    local n = #(st.items or {})
    E.Strike(st, a, boss, 50, false, "normal")
    local own = false
    for i = n + 1, #st.items do
        if st.items[i].key == "n:cruel_barb" or st.items[i].key == "n:cape_brotherhood" then own = true end
    end
    check(#st.items >= n + 3 and own, "loot: Edwin VanCleef drops his own, and more")
end

-- The screen: the altar's classes; drop from the bag with a right-click.
function WcClassPageTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("warcraft")
    local view = ns.UI.pages.warcraft.view
    ns.db.warcraft.lobby = nil
    view:ShowLobby()
    local f = view.lobbyFrame
    for _, b in ipairs(f.modes) do if b.key == "hd" then b._scripts.OnClick() end end
    f.start._scripts.OnClick()
    local st = view.st
    view.sel = { HD.Altar(st, 1).id }
    view:Draw()
    local t = {}
    for _, c in ipairs(view.cmds) do if c:IsShown() then t[#t + 1] = c.title end end
    local all = table.concat(t, " | ")
    check(all:find("Train Warrior", 1, true) and all:find("Train Death Knight", 1, true) and all:find("Train Priest", 1, true),
        "class page: the altar offers the classes (" .. all .. ")")
    for _, c in ipairs(view.cmds) do if c:IsShown() and c.title:find("Train Rogue", 1, true) then c.action() end end
    Run(st, 4)
    local h = HD.Hero(st, 1)
    check(h and h.type == "cls_rogue", "class page: a Rogue")
    h.items = { "g:3:4:2:12" }
    view.sel = { h.id }
    view:Draw()
    view:Draw()
    local slot = view.itemButtons[1]
    check(slot:IsShown() and slot.item == "g:3:4:2:12" and slot.edge:IsShown(), "class page: the blue item in the bag, framed")
    check(view.selHp:GetText():find("Energy", 1, true), "class page: the Rogue's energy shows")
    check(view.gearButtons[1]:IsShown() and view.gearButtons[1].empty:IsShown(), "class page: the gear slots, empty")
    -- Left-click: wear it. Right-click the worn one: back into the bag.
    slot._scripts.OnClick(slot, "LeftButton")
    view:Draw()
    check(h.gear and h.gear[1] == "g:3:4:2:12" and #h.items == 0 and view.gearButtons[1].item == "g:3:4:2:12",
        "class page: click a weapon in the bag to wear it")
    view.gearButtons[1]._scripts.OnClick(view.gearButtons[1], "RightButton")
    view:Draw()
    check(not h.gear[1] and h.items[1] == "g:3:4:2:12", "class page: right-click it to take it off")
    slot._scripts.OnClick(slot, "RightButton")
    check(#h.items == 0 and st.items[#st.items].key == "g:3:4:2:12", "class page: right-click in the bag drops it")
    ns.db.warcraft.lobby = nil
    view:Quit()
end
