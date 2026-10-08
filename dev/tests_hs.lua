-- Hearthstone: the rules engine and the AI, without any UI.
local HS = ns.HS
local E = HS.Engine

-- A fresh game, player 1 to act, with empty boards and hands.
local function Fresh(seed)
    local st = E.New({ heroes = { "jaina", "thrall" }, seed = seed or 7, first = 1 })
    for _, p in ipairs(st.players) do
        p.hand, p.board = {}, {}
        p.mana, p.maxMana = 10, 10
    end
    return st
end

local function Put(st, owner, key, awake)
    E.Run(st, { owner = owner }, { { op = "summon", card = key } })
    local p = st.players[owner]
    local m = p.board[#p.board]
    if awake then m.sleeping = nil end
    return m
end

local function Give(st, owner, key)
    st.nextId = st.nextId + 1
    local c = { id = st.nextId, key = key }
    table.insert(st.players[owner].hand, c)
    return c
end

local function Has(list, pred)
    for _, x in ipairs(list) do if pred(x) then return true end end
    return false
end

function HsDataTests()
    local missing = {}
    for key, c in pairs(HS.Cards) do
        if c.npc ~= nil and type(c.npc) ~= "number" then check(false, "hs: " .. key .. " has a number for npc") end
        if c.type == "minion" and not c.npc then table.insert(missing, key) end
    end
    check(#missing <= 1, "hs: minions have a WoW creature (" .. table.concat(missing, ", ") .. ")")
    for hk, h in pairs(HS.Heroes) do check(type(h.npc) == "number", "hs: hero " .. hk .. " has a creature") end
    for key, c in pairs(HS.Cards) do
        if not (c.name and c.cost and c.type and c.art) then check(false, "hs: card " .. key .. " is complete") end
        if c.type == "minion" and not (c.attack and c.health) then check(false, "hs: minion " .. key .. " has stats") end
    end
    for hk, h in pairs(HS.Heroes) do
        local list = HS.DeckList(h.deck)
        check(#list == 30, "hs: " .. hk .. "'s deck has 30 cards (" .. #list .. ")")
        local counts = {}
        for _, key in ipairs(list) do
            check(HS.Cards[key] ~= nil and not HS.Cards[key].token, "hs: deck card " .. key .. " exists")
            counts[key] = (counts[key] or 0) + 1
        end
        for key, n in pairs(counts) do check(n <= 2, "hs: at most two " .. key) end
    end
end

function HsRuleTests()
    -- Opening: 3 + draw for the first player, 4 + The Coin for the second.
    local st = E.New({ heroes = { "jaina", "thrall" }, seed = 99, first = 1 })
    check(#st.players[1].hand == 4 and #st.players[2].hand == 5, "hs: opening hands 4 and 5")
    check(Has(st.players[2].hand, function(c) return c.key == "coin" end), "hs: the second player gets The Coin")
    check(st.players[1].mana == 1 and st.players[1].maxMana == 1, "hs: one mana on turn one")
    check(#st.players[1].deck == 26 and #st.players[2].deck == 26, "hs: decks after the opening draw")
    E.Apply(st, { type = "end" })
    check(st.active == 2 and st.players[2].mana == 1 and #st.players[2].hand == 6, "hs: turn passes, draw, mana")
    local coin
    for _, c in ipairs(st.players[2].hand) do if c.key == "coin" then coin = c end end
    E.Apply(st, { type = "play", card = coin.id })
    check(st.players[2].mana == 2 and st.players[2].maxMana == 1, "hs: The Coin gives one mana this turn")

    -- Summoning sickness, Charge, Taunt.
    st = Fresh()
    local yeti = Put(st, 1, "chillwind_yeti")
    check(not E.CanAttack(st, yeti), "hs: a new minion can't attack")
    local boar = Put(st, 1, "stonetusk_boar")
    check(E.CanAttack(st, boar), "hs: Charge attacks at once")
    yeti.sleeping = nil
    local grunt = Put(st, 2, "frostwolf_grunt")
    local t = E.AttackTargets(st, 1)
    check(#t == 1 and t[1] == grunt.id, "hs: Taunt must be attacked first")
    local ok = E.Apply(st, { type = "attack", attacker = yeti.id, target = 2 })
    check(not ok, "hs: can't go past a Taunt to the hero")
    E.Apply(st, { type = "attack", attacker = yeti.id, target = grunt.id })
    check(#st.players[2].board == 0 and yeti.health == 3, "hs: Yeti kills the Grunt and takes 2")
    check(not E.CanAttack(st, yeti), "hs: one attack per turn")
    E.Apply(st, { type = "attack", attacker = boar.id, target = 2 })
    check(st.players[2].hero.health == 29, "hs: the Boar hits face")

    -- Divine Shield and Windfury.
    st = Fresh()
    local squire = Put(st, 2, "argent_squire")
    local a = Put(st, 1, "bloodfen_raptor", true)
    E.Apply(st, { type = "attack", attacker = a.id, target = squire.id })
    check(squire.health == 1 and not squire.divineShield and a.health == 1, "hs: Divine Shield soaks the first hit")
    st = Fresh()
    local w = Put(st, 1, "river_crocolisk", true)
    w.windfury = true
    E.Apply(st, { type = "attack", attacker = w.id, target = 2 })
    E.Apply(st, { type = "attack", attacker = w.id, target = 2 })
    check(st.players[2].hero.health == 26 and not E.CanAttack(st, w), "hs: Windfury attacks twice")

    -- Spells and Spell Damage.
    st = Fresh()
    local fb = Give(st, 1, "fireball")
    E.Apply(st, { type = "play", card = fb.id, target = 2 })
    check(st.players[2].hero.health == 24 and st.players[1].mana == 6, "hs: Fireball for 6, costs 4")
    Put(st, 1, "archmage")
    fb = Give(st, 1, "fireball")
    E.Apply(st, { type = "play", card = fb.id, target = 2 })
    check(st.players[2].hero.health == 17, "hs: Archmage makes it 7")
    st.players[1].mana = 10
    local ok2, why = E.Apply(st, { type = "play", card = Give(st, 1, "fireball").id })
    check(not ok2 and why == "pick a target", "hs: Fireball needs a target")
    st = Fresh()
    local m1, m2 = Put(st, 2, "boulderfist_ogre"), Put(st, 2, "murloc_raider")
    E.Apply(st, { type = "play", card = Give(st, 1, "flamestrike").id })
    check(m1.health == 3 and #st.players[2].board == 1, "hs: Flamestrike hits every enemy minion")
    st.players[1].mana = 10
    E.Apply(st, { type = "play", card = Give(st, 1, "polymorph").id, target = m1.id })
    check(st.players[2].board[1].key == "sheep" and st.players[2].board[1].id == m1.id, "hs: Polymorph makes a Sheep in place")
    local hp = st.players[2].hero.health
    E.Apply(st, { type = "play", card = Give(st, 1, "arcane_missiles").id })
    check(hp - st.players[2].hero.health + (st.players[2].board[1] and 0 or 1) >= 2, "hs: Arcane Missiles hit enemies")

    -- Freeze: a frozen minion skips its next attack and thaws after.
    st = Fresh()
    local victim = Put(st, 2, "chillwind_yeti", true)
    E.Apply(st, { type = "play", card = Give(st, 1, "frostbolt").id, target = victim.id })
    check(victim.frozen and victim.health == 2, "hs: Frostbolt damages and freezes")
    E.Apply(st, { type = "end" })
    check(not E.CanAttack(st, victim), "hs: frozen on its turn")
    E.Apply(st, { type = "end" })
    check(not victim.frozen, "hs: it thaws at the end of its turn")
    E.Apply(st, { type = "end" })
    check(E.CanAttack(st, victim), "hs: and attacks the turn after")
    -- Water Elemental freezes what it hits.
    st = Fresh()
    local we = Put(st, 1, "water_elemental", true)
    E.Apply(st, { type = "attack", attacker = we.id, target = 2 })
    check(st.players[2].hero.frozen and st.players[2].hero.health == 27, "hs: Water Elemental freezes the hero")

    -- Auras: Stormwind Champion and Flametongue Totem.
    st = Fresh()
    local raptor = Put(st, 1, "bloodfen_raptor")
    local champ = Put(st, 1, "stormwind_champion")
    check(E.Attack(raptor) == 4 and raptor.health == 3, "hs: Champion gives +1/+1")
    E.Damage(st, nil, raptor, 2)
    E.Damage(st, nil, champ, 6)
    E.Deaths(st)
    check(#st.players[1].board == 1 and raptor.health == 1 and E.Attack(raptor) == 3, "hs: a hurt minion survives losing the aura")
    st = Fresh()
    local l, totem, r = Put(st, 1, "murloc_raider"), Put(st, 1, "flametongue_totem"), Put(st, 1, "river_crocolisk")
    local far = Put(st, 1, "bloodfen_raptor")
    check(E.Attack(l) == 4 and E.Attack(r) == 4 and E.Attack(far) == 3 and E.Attack(totem) == 0, "hs: Flametongue only buffs neighbours")

    -- Battlecries: target, no target, tokens next to the minion.
    st = Fresh()
    local tide = Give(st, 1, "murloc_tidehunter")
    E.Apply(st, { type = "play", card = tide.id })
    check(#st.players[1].board == 2 and st.players[1].board[2].key == "murloc_scout", "hs: Tidehunter brings a Scout")
    local fe = Give(st, 1, "fire_elemental")
    local targets = E.PlayTargets(st, 1, fe)
    check(targets and #targets >= 4, "hs: Fire Elemental's battlecry can hit anything")
    E.Apply(st, { type = "play", card = fe.id, target = 2 })
    check(st.players[2].hero.health == 27, "hs: Fire Elemental deals 3")
    st = Fresh()
    local cleric = Give(st, 1, "shattered_sun_cleric")
    check(E.PlayTargets(st, 1, cleric) == nil, "hs: with no friendly minion the battlecry just fizzles")
    check(E.Apply(st, { type = "play", card = cleric.id }), "hs: and the minion can still be played")

    -- Damage triggers.
    st = Fresh()
    local guru = Put(st, 2, "gurubashi_berserker")
    local att = Put(st, 1, "murloc_raider", true)
    E.Apply(st, { type = "attack", attacker = att.id, target = guru.id })
    check(E.Attack(guru) == 5, "hs: Gurubashi gains 3 Attack when hit")

    -- Hero powers.
    st = Fresh()
    E.Apply(st, { type = "power", target = 2 })
    check(st.players[2].hero.health == 29 and st.players[1].mana == 8, "hs: Fireblast")
    check(not E.Apply(st, { type = "power", target = 2 }), "hs: once a turn")
    E.Apply(st, { type = "end" })
    for _ = 1, 4 do
        E.Apply(st, { type = "power" })
        st.players[2].powerUsed = false
        st.players[2].mana = 10
    end
    local keys = {}
    for _, m in ipairs(st.players[2].board) do keys[m.key] = true end
    check(#st.players[2].board == 4 and keys.healing_totem and keys.searing_totem and keys.stoneclaw_totem
        and keys.wrath_of_air_totem, "hs: Totemic Call makes each totem once")
    check(E.PowerTargets(st, 2) == false, "hs: no fifth totem")
    -- Healing Totem heals at the end of the turn.
    local hurt = Put(st, 2, "chillwind_yeti")
    hurt.health = 2
    E.Apply(st, { type = "end" })
    check(hurt.health == 3, "hs: Healing Totem heals at the end of the turn")

    -- Hand limit and fatigue.
    st = Fresh()
    for _ = 1, 10 do Give(st, 1, "murloc_raider") end
    local deck = #st.players[1].deck
    E.Draw(st, 1, 1)
    check(#st.players[1].hand == 10 and #st.players[1].deck == deck - 1, "hs: a full hand burns the draw")
    st.players[1].deck = {}
    E.Draw(st, 1, 2)
    check(st.players[1].hero.health == 27 and st.players[1].fatigue == 2, "hs: fatigue 1, then 2")

    -- Lethal ends it.
    st = Fresh()
    st.players[2].hero.health = 3
    E.Apply(st, { type = "play", card = Give(st, 1, "fireball").id, target = 2 })
    check(st.over and st.winner == 1, "hs: the game ends at 0 health")
    check(not E.Apply(st, { type = "end" }), "hs: nothing after the end")

    -- The view for player 1 hides player 2's hand and both decks.
    st = E.New({ heroes = { "jaina", "thrall" }, seed = 3, first = 1 })
    local v = E.View(st, 1)
    check(v.players[1].hand[1].key ~= nil and v.players[2].hand[1].key == nil and #v.players[1].deck == 0
        and v.players[1].deckCount == 26, "hs: views hide what you can't see")
end

-- Whole games, AI against AI.
function HsBotGames()
    local wins, turns = { 0, 0, [0] = 0 }, 0
    for seed = 1, 24 do
        local st = E.New({ heroes = { "jaina", "thrall" }, seed = seed * 7919 })
        for _ = 1, 120 do
            if st.over then break end
            HS.AI.PlayTurn(st)
        end
        check(st.over, "hs: game " .. seed .. " finishes (turn " .. st.turn .. ")")
        wins[st.winner or 0] = (wins[st.winner or 0] or 0) + 1
        turns = turns + st.turn
    end
    check(wins[1] >= 2 and wins[2] >= 2, "hs: both heroes win some (" .. wins[1] .. " / " .. wins[2] .. ")")
    print(string.format("  hs: Jaina %d, Thrall %d, draws %d; %.1f turns a game", wins[1], wins[2], wins[0], turns / 24))
    -- Same seed, same game.
    local function Run(seed)
        local st = E.New({ heroes = { "jaina", "thrall" }, seed = seed })
        for _ = 1, 120 do if st.over then break end HS.AI.PlayTurn(st) end
        return st.winner .. ":" .. st.turn .. ":" .. st.players[1].hero.health .. ":" .. st.players[2].hero.health
    end
    check(Run(4242) == Run(4242), "hs: the same seed plays out the same")
    -- The AI takes lethal.
    local st = Fresh()
    Put(st, 1, "boulderfist_ogre", true)
    st.players[2].hero.health = 6
    local a = HS.AI.Choose(st)
    check(a.type == "attack" and a.target == 2, "hs: the AI sees lethal")
    -- And trades into a Taunt it must get past.
    st = Fresh()
    Put(st, 1, "chillwind_yeti", true)
    local g = Put(st, 2, "frostwolf_grunt")
    a = HS.AI.Choose(st)
    check(a.type == "attack" and a.target == g.id, "hs: the AI attacks the Taunt")
end


-- The board page: start a game, play cards by clicking, let the AI move,
-- play a whole game to the end.
function HsPageTests()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("hearthstone")
    Advance(0)
    local view = ns.UI.pages.hearthstone.view
    local function Settle()
        for _ = 1, 3 do
            ns.Cards.Tick(true)
            Advance(1)
            view:Tick()
        end
        ns.Cards.Tick(true)
    end
    check(view.overlay:IsShown() and #view.pick == 9, "hs page: choose a hero (" .. #view.pick .. ")")
    ns.Cards.Tick(true)
    check(math.floor(ns.UI.frame:GetWidth() + 0.5) == 760 and math.floor(ns.UI.frame:GetHeight() + 0.5) == 560,
        "hs page: the window grows for Hearthstone (" .. tostring(ns.UI.frame:GetWidth()) .. ")")
    local jaina
    for _, b in ipairs(view.pick) do if b.key == "jaina" then jaina = b end end
    jaina._scripts.OnClick()
    check(view.deckRows[1]:IsShown() and view.deckRows[1].play:IsEnabled(), "hs page: the basic deck is ready to play")
    view.deckRows[1].play._scripts.OnClick()
    local st = view.st
    check(st and st.players[1].heroKey == "jaina" and not view.overlay:IsShown(), "hs page: a game as Jaina")
    check(ns.Solo.Running("hearthstone"), "hs page: the tab stays while a game is on")
    check(ns.db.hearthstone.game == st, "hs page: the game is saved")
    -- The mulligan: our opening cards, big; swap the first one.
    check(view.mull:IsShown() and view.mull.cards[1]:IsShown(), "hs page: the mulligan shows our opening cards")
    local first = st.players[1].hand[1].id
    view.mull.cards[1]._scripts.OnClick()
    check(view.mull.cards[1].cross:IsShown(), "hs page: a card marked to swap")
    view.mull.confirm._scripts.OnClick()
    for _ = 1, 3 do Settle() end
    local still = false
    for _, c in ipairs(st.players[1].hand) do if c.id == first then still = true end end
    check(not still and not ns.HS.Engine.Mulliganing(st), "hs page: the card was swapped and the game starts")
    -- Wait for our turn.
    for _ = 1, 40 do
        if st.active == 1 then break end
        Settle()
    end
    check(st.active == 1, "hs page: our turn comes")
    Settle()
    check(view.endButton:IsEnabled(), "hs page: End turn is clickable at the start of our turn")
    -- Fireball the enemy hero by clicking.
    local me = st.players[1]
    me.mana, me.maxMana = 10, 10
    st.nextId = st.nextId + 1
    local fb = { id = st.nextId, key = "fireball" }
    table.insert(me.hand, fb)
    view:Draw()
    local f = view.handCards[fb.id]
    check(f and f:IsShown(), "hs page: the card shows in the hand")
    f._scripts.OnClick(f, "LeftButton")
    check(view.sel and view.sel.kind == "card", "hs page: clicking a targeted spell asks for a target")
    local function Life() return st.players[2].hero.health + st.players[2].hero.armor end
    local hp = Life()
    view.heroes[2]._scripts.OnClick()
    Settle()
    check(Life() == hp - 6, "hs page: Fireball hits the enemy hero")
    check(#view.fxFree >= 5, "hs page: Fireball flies as a bolt and bursts (" .. #view.fxFree .. " effect pieces)")
    -- A minion with no target goes straight to the board.
    st.nextId = st.nextId + 1
    local yeti = { id = st.nextId, key = "chillwind_yeti" }
    table.insert(me.hand, yeti)
    view:Draw()
    view.handCards[yeti.id]._scripts.OnClick(view.handCards[yeti.id], "LeftButton")
    Settle()
    local onBoard
    for _, m in ipairs(me.board) do if m.id == yeti.id then onBoard = m end end
    check(onBoard and view.minions[yeti.id] and view.minions[yeti.id]:IsShown(), "hs page: the Yeti is on the board")
    check(view.minions[yeti.id].model and view.minions[yeti.id].model.npc == 7458, "hs page: the Yeti shows its WoW creature")
    check(view.heroes[1].model and view.heroes[1].model.npc == 4968, "hs page: Jaina shows Jaina")
    -- The 3D model is cropped to its window and the border stays above it,
    -- also after the card moves up (an attack) and back down.
    local mf = view.minions[yeti.id]
    check(mf.model.clip and mf.model:GetParent() == mf.model.clip, "hs page: the model sits in a cropping frame")
    for _, level in ipairs({ 40, 10 }) do
        view.Lift(mf, level)
        check(mf.top:GetFrameLevel() > mf.model:GetFrameLevel() and mf.model:GetFrameLevel() > level - 1,
            "hs page: the border is above the model at level " .. level)
    end
    view.minions[yeti.id]._scripts.OnClick(view.minions[yeti.id], "LeftButton")
    check(view.sel == nil and view.status:GetText():find("next turn") ~= nil, "hs page: a new minion can't attack yet")
    -- Not enough mana.
    me.mana = 0
    st.nextId = st.nextId + 1
    local ogre = { id = st.nextId, key = "boulderfist_ogre" }
    table.insert(me.hand, ogre)
    view:Draw()
    view.handCards[ogre.id]._scripts.OnClick(view.handCards[ogre.id], "LeftButton")
    check(view.status:GetText() == "Not enough mana", "hs page: not enough mana")
    Settle()
    check(view.endButton:IsEnabled(), "hs page: End turn is clickable again after playing cards")
    -- Dragging cards.
    me.mana = 10
    local function NewCard(key)
        st.nextId = st.nextId + 1
        local c = { id = st.nextId, key = key }
        table.insert(me.hand, c)
        view:Draw()
        return c, view.handCards[c.id]
    end
    local function Drag(f, x, y)
        CURSOR_X, CURSOR_Y = f.x, -f.y
        view:DragStart(f)
        view:DragMove(x, y)
        view:DragEnd(x, y)
        f._scripts.OnClick(f, "LeftButton") -- the click that follows the mouse-up is ignored
        Settle()
    end
    local raptor, rf = NewCard("bloodfen_raptor")
    Drag(rf, 20, 192)
    check(me.board[1] and me.board[1].id == raptor.id, "hs page: a minion dragged to the left lands on the left")
    local fb2, ff = NewCard("fireball")
    local life = Life()
    Drag(ff, view.heroes[2].x, view.heroes[2].y)
    check(Life() == life - 6, "hs page: Fireball dragged onto the enemy hero")
    local back, bf = NewCard("river_crocolisk")
    Drag(bf, bf.x + 30, 400)
    local inHand = false
    for _, c in ipairs(me.hand) do if c.id == back.id then inHand = true end end
    check(inHand and view.sel == nil, "hs page: dropping back on the hand cancels")
    me.mana = 10
    local archer, af = NewCard("elven_archer")
    Drag(af, 640, 222)
    check(view.sel and view.sel.kind == "card" and view.sel.pos ~= nil, "hs page: a battlecry asks for a target after the drop")
    life = Life()
    view.heroes[2]._scripts.OnClick()
    Settle()
    local last = me.board[#me.board]
    check(Life() == life - 1 and last and last.id == archer.id, "hs page: then the archer lands and shoots")
    -- End the turn; the AI moves; back to us.
    view.endButton._scripts.OnClick()
    for _ = 1, 60 do
        Settle()
        if st.active == 1 or st.over then break end
    end
    check(st.active == 1 or st.over, "hs page: the AI plays its turn and hands it back")
    -- Play the rest of the game (our side picks the AI's move too).
    for _ = 1, 400 do
        if st.over then break end
        if st.active == 1 and view:MyTurn() then
            view:Do(ns.HS.AI.Choose(st))
        end
        Settle()
    end
    Settle()
    check(st.over, "hs page: the game ends (turn " .. st.turn .. ")")
    local rec = ns.db.hearthstone
    check(view.overlay:IsShown() and (view.overTitle:GetText() == "Victory!" or view.overTitle:GetText() == "Defeat"
        or view.overTitle:GetText() == "Draw"), "hs page: the result shows (" .. tostring(view.overTitle:GetText()) .. ")")
    check(rec.wins + rec.losses == 1 and rec.game == nil, "hs page: the result is counted once")
    check(not ns.Solo.Running("hearthstone"), "hs page: the tab can go now")
    -- A new game, then close it from the tab.
    view.againButton._scripts.OnClick()
    jaina._scripts.OnClick()
    view.deckRows[1].play._scripts.OnClick()
    check(view.st and view.st ~= st and ns.Solo.Running("hearthstone"), "hs page: another game")
    view:Quit()
    ns.UI:SelectTab("home")
    ns.Cards.Tick(true)
    check(math.floor(ns.UI.frame:GetWidth() + 0.5) == 560, "hs page: and shrinks back for other tabs")
    check(view.st == nil and ns.db.hearthstone.game == nil and not ns.Solo.Running("hearthstone"), "hs page: quitting ends it")
end

-- Deck building.
function HsDeckTests()
    local HS = ns.HS
    check(HS.CheckDeck("jaina", HS.DeckList("basic_mage")), "decks: the basic mage deck is valid")
    local bad = HS.DeckList("basic_mage")
    bad[1] = "hex"
    local ok, why = HS.CheckDeck("jaina", bad)
    check(not ok and why:find("not a mage") ~= nil, "decks: no shaman cards for Jaina (" .. tostring(why) .. ")")
    bad = HS.DeckList("basic_mage")
    bad[2] = bad[1]
    bad[3] = bad[1]
    ok, why = HS.CheckDeck("jaina", bad)
    check(not ok and why:find("too many") ~= nil, "decks: at most two copies")
    local col = HS.Collection("thrall")
    local hasShaman, hasMage = false, false
    for _, k in ipairs(col) do
        if HS.Cards[k].class == "shaman" then hasShaman = true end
        if HS.Cards[k].class == "mage" then hasMage = true end
        if HS.Cards[k].token then check(false, "decks: no tokens in the collection") end
    end
    check(hasShaman and not hasMage, "decks: Thrall sees shaman and neutral cards only")

    -- The builder, through the page.
    local view = ns.UI.pages.hearthstone.view
    ns.db.hearthstone.decks = {}
    view:ShowDecks("jaina")
    view.newDeckButton._scripts.OnClick()
    local f = view.deckBuilder
    check(f and f:IsShown() and f.cards[1]:IsShown(), "decks: the builder opens with cards")
    check(HS.Cards[f.cards[1].key].class == "mage", "decks: class cards first")
    local key = f.cards[1].key
    f.cards[1]._scripts.OnClick()
    f.cards[1]._scripts.OnClick()
    f.cards[1]._scripts.OnClick()
    check(#f.deck == 2, "decks: two copies, then no more")
    f.rows = nil
    f.list.rows[1]:GetScript("OnMouseUp")(f.list.rows[1])
    check(#f.deck == 1, "decks: clicking the deck list takes one out")
    f.costs[9]._scripts.OnClick()
    local allSeven = true
    for _, c in ipairs(f.cards) do if c:IsShown() and HS.Cards[c.key].cost < 7 then allSeven = false end end
    check(allSeven, "decks: the 7+ filter")
    -- "All": selected (greyed) at the start; after a filter, it shows every card again.
    f.costs[1]._scripts.OnClick()
    ns.HearthstoneDecks.Refresh(f)
    check(f.filterCost == nil and f.costs[1]._enabled == false, "decks: All is the selected filter")
    local shownAll = #ns.HearthstoneDecks.Shown(f)
    f.costs[9]._scripts.OnClick()
    check(#ns.HearthstoneDecks.Shown(f) < shownAll and f.costs[1]._enabled ~= false, "decks: a cost filter, All clickable again")
    f.costs[1]._scripts.OnClick()
    check(#ns.HearthstoneDecks.Shown(f) == shownAll and shownAll > 0, "decks: All shows every card again")
    f.tabs[2]._scripts.OnClick()
    check(HS.Cards[f.cards[1].key].class == "neutral", "decks: the neutral tab")
    f.fill._scripts.OnClick()
    check(#f.deck == 30 and HS.CheckDeck("jaina", f.deck), "decks: auto-fill makes a valid 30")
    f.name:SetText("Big Fireball")
    f.save._scripts.OnClick()
    local saved = ns.db.hearthstone.decks
    check(#saved == 1 and saved[1].name == "Big Fireball" and #saved[1].cards == 30, "decks: saved")
    check(not f:IsShown() and view.deckRows[2]:IsShown() and view.deckRows[2].play:IsEnabled(), "decks: it shows up, ready to play")
    -- Play it: every card in the game comes from it.
    view.deckRows[2].play._scripts.OnClick()
    local st = view.st
    local allowed = {}
    for _, k in ipairs(saved[1].cards) do allowed[k] = true end
    local okCards = true
    for _, c in ipairs(st.players[1].hand) do if c.key ~= "coin" and not allowed[c.key] then okCards = false end end
    for _, k in ipairs(st.players[1].deck) do if not allowed[k] then okCards = false end end
    check(okCards, "decks: the game uses your deck")
    view:Quit()
    -- Edit and delete.
    view:ShowDecks("jaina")
    view.deckRows[2].edit._scripts.OnClick()
    check(f:IsShown() and #f.deck == 30 and f.name:GetText() == "Big Fireball", "decks: edit opens the saved deck")
    f.clear._scripts.OnClick()
    f.save._scripts.OnClick()
    check(#ns.db.hearthstone.decks[1].cards == 0, "decks: saved empty")
    check(not view.deckRows[2].play:IsEnabled(), "decks: an unfinished deck can't be played")
    view.deckRows[2].delete._scripts.OnClick()
    AnswerPopup()
    check(#ns.db.hearthstone.decks == 0 and not view.deckRows[2]:IsShown(), "decks: deleted")
end

-- Preloading creatures.
function HsPreloadTests()
    local P = ns.HearthstonePage
    local list = P.CreaturesFor({ "murloc_tidehunter", "polymorph", "fireball" }, { "thrall" })
    local has = {}
    for _, npc in ipairs(list) do has[npc] = true end
    check(has[127] and has[578] and has[1933], "preload: a card, its token and a transform target (Tidehunter, Scout, Sheep)")
    check(has[4949] and has[3527] and has[2523], "preload: the hero and its totems")
    check(not has[0] and #list == 8, "preload: nothing twice, spells without creatures add none (" .. #list .. ")")
    -- The page queued everything; a game moves its creatures to the front.
    local view = ns.UI.pages.hearthstone.view
    view:NewGame("jaina", 5)
    local first = P.preloadQueue[1]
    local inGame = {}
    for _, npc in ipairs(P.CreaturesFor((function()
        local keys = {}
        for i = 1, 2 do
            for _, k in ipairs(view.st.players[i].deck) do table.insert(keys, k) end
            for _, c in ipairs(view.st.players[i].hand) do table.insert(keys, c.key) end
        end
        return keys
    end)(), { "jaina", view.st.players[2].heroKey })) do inGame[npc] = true end
    check(first == nil or inGame[first], "preload: this game's creatures go first")
    -- Loaders work through the queue and remember looks.
    view:PreloadTick()
    for _, x in ipairs(view.loaders or {}) do x.npc = nil end
    P.Preload({ 999001 }, true)
    local before = #P.preloadQueue
    view:PreloadTick()
    local l = view.loaders and view.loaders[1]
    check(l and l.npc == 999001 and #P.preloadQueue < before, "preload: a loader takes the next creature")
    l.GetDisplayInfo = function() return 4242 end
    local npc = l.npc
    l._scripts.OnModelLoaded(l)
    check(ns.db.hearthstone.looks[npc] == 4242 and l.npc == nil, "preload: the look is saved and the loader is free")
    view:Quit()
end


-- The other classes: weapons, filters, new effects, triggers, heroes.
function HsClassTests()
    local HS = ns.HS
    local E = HS.Engine
    local function Fresh(h1, h2)
        local st = E.New({ heroes = { h1 or "valeera", h2 or "garrosh" }, seed = 11, first = 1 })
        for _, p in ipairs(st.players) do
            p.hand, p.board = {}, {}
            p.mana, p.maxMana = 10, 10
        end
        return st
    end
    local function Put(st, owner, key, awake)
        E.Run(st, { owner = owner }, { { op = "summon", card = key } })
        local p = st.players[owner]
        local m = p.board[#p.board]
        if awake then m.sleeping = nil end
        return m
    end
    local function Give(st, owner, key)
        st.nextId = st.nextId + 1
        local c = { id = st.nextId, key = key }
        table.insert(st.players[owner].hand, c)
        return c
    end
    local function Play(st, key, target) return E.Apply(st, { type = "play", card = Give(st, st.active, key).id, target = target }) end

    -- Every hero has a 30-card deck that passes the rules.
    local n = 0
    for hk, h in pairs(HS.Heroes) do
        n = n + 1
        check(HS.CheckDeck(hk, HS.DeckList(h.deck)), "classes: " .. hk .. "'s basic deck is legal")
    end
    check(n == 9, "classes: nine heroes (" .. n .. ")")

    -- Weapons: Dagger Mastery, attacking uses durability, Deadly Poison.
    local st = Fresh("valeera")
    E.Apply(st, { type = "power" })
    local hero = st.players[1].hero
    check(hero.weapon and hero.weapon.key == "wicked_knife" and E.Attack(hero) == 1, "classes: Dagger Mastery equips a 1/2")
    Play(st, "deadly_poison")
    check(hero.weapon.attack == 3, "classes: Deadly Poison +2 Attack")
    E.Apply(st, { type = "attack", attacker = 1, target = 2 })
    check(st.players[2].hero.health == 27 and hero.weapon.durability == 1, "classes: the hero swings, durability drops")
    hero.attacks = 0
    E.Apply(st, { type = "attack", attacker = 1, target = 2 })
    check(hero.weapon == nil and st.players[2].hero.health == 24, "classes: the weapon breaks at 0")
    local c = Give(st, 1, "deadly_poison")
    check(E.PlayTargets(st, 1, c) == false, "classes: no Deadly Poison without a weapon")
    -- Truesilver heals when the hero attacks.
    st = Fresh("uther")
    st.players[1].hero.health = 20
    Play(st, "truesilver_champion")
    E.Apply(st, { type = "attack", attacker = 1, target = 2 })
    check(st.players[1].hero.health == 22 and st.players[2].hero.health == 26, "classes: Truesilver heals 2 on each swing")

    -- Target filters.
    st = Fresh("anduin")
    local small, big = Put(st, 2, "bloodfen_raptor"), Put(st, 2, "boulderfist_ogre")
    local pain = E.PlayTargets(st, 1, Give(st, 1, "shadow_word_pain"))
    local death = E.PlayTargets(st, 1, Give(st, 1, "shadow_word_death"))
    local function Has(list, id) for _, x in ipairs(list or {}) do if x == id then return true end end return false end
    check(Has(pain, small.id) and not Has(pain, big.id), "classes: Shadow Word: Pain only on 3 Attack or less")
    check(Has(death, big.id) and not Has(death, small.id), "classes: Shadow Word: Death only on 5 Attack or more")
    st = Fresh("garrosh")
    local y = Put(st, 2, "chillwind_yeti")
    check(E.PlayTargets(st, 1, Give(st, 1, "execute")) == false, "classes: Execute needs a damaged minion")
    E.Damage(st, nil, y, 1)
    Play(st, "execute", y.id)
    check(#st.players[2].board == 0, "classes: Execute destroys a damaged one")

    -- Return, steal, set, double, doom.
    st = Fresh("valeera")
    local r = Put(st, 2, "river_crocolisk")
    Play(st, "sap", r.id)
    check(#st.players[2].board == 0 and st.players[2].hand[1] and st.players[2].hand[1].key == "river_crocolisk", "classes: Sap returns it to their hand")
    st = Fresh("anduin")
    local ogre = Put(st, 2, "boulderfist_ogre")
    Play(st, "mind_control", ogre.id)
    check(#st.players[1].board == 1 and st.players[1].board[1].owner == 1 and not E.CanAttack(st, ogre), "classes: Mind Control takes it, sleepy")
    st = Fresh("rexxar")
    local yeti = Put(st, 2, "chillwind_yeti")
    Play(st, "hunters_mark", yeti.id)
    check(yeti.health == 1 and yeti.maxHealth == 1, "classes: Hunter's Mark sets Health to 1")
    st = Fresh("uther")
    yeti = Put(st, 2, "chillwind_yeti")
    Play(st, "humility", yeti.id)
    check(E.Attack(yeti) == 1, "classes: Humility sets Attack to 1")
    st = Fresh("anduin")
    yeti = Put(st, 1, "chillwind_yeti")
    Play(st, "divine_spirit", yeti.id)
    check(yeti.health == 10, "classes: Divine Spirit doubles Health")
    st = Fresh("guldan")
    yeti = Put(st, 2, "chillwind_yeti")
    Play(st, "corruption", yeti.id)
    check(yeti.doomedBy == 1 and #st.players[2].board == 1, "classes: Corruption marks it")
    E.Apply(st, { type = "end" })
    check(#st.players[2].board == 1, "classes: it lives through their turn")
    E.Apply(st, { type = "end" })
    check(#st.players[2].board == 0, "classes: and dies at the start of yours")

    -- Random damage, conditional damage, kill-then-draw, discard, copy.
    st = Fresh("garrosh")
    check(E.PlayTargets(st, 1, Give(st, 1, "cleave")) == false, "classes: Cleave needs two enemy minions")
    local a1, a2 = Put(st, 2, "river_crocolisk"), Put(st, 2, "chillwind_yeti")
    Play(st, "cleave")
    check(a1.health == 1 and a2.health == 3, "classes: Cleave hits both for 2")
    st = Fresh("rexxar")
    Play(st, "kill_command", 2)
    check(st.players[2].hero.health == 27, "classes: Kill Command 3 without a Beast")
    Put(st, 1, "river_crocolisk")
    Play(st, "kill_command", 2)
    check(st.players[2].hero.health == 22, "classes: 5 with a Beast")
    st = Fresh("guldan")
    local wisp = Put(st, 2, "murloc_scout")
    local hand = #st.players[1].hand
    Play(st, "mortal_coil", wisp.id)
    check(#st.players[1].hand == hand + 1, "classes: Mortal Coil draws when it kills")
    Give(st, 1, "fireball")
    Give(st, 1, "frostbolt")
    hand = #st.players[1].hand
    Play(st, "soulfire", 2)
    check(#st.players[1].hand == hand - 1 and st.players[2].hero.health == 26, "classes: Soulfire hits 4 and discards one")
    st = Fresh("anduin")
    Give(st, 2, "fireball")
    Play(st, "mind_vision")
    check(st.players[1].hand[#st.players[1].hand].key == "fireball", "classes: Mind Vision copies their card")

    -- Triggers and auras.
    st = Fresh("garrosh")
    Put(st, 1, "warsong_commander")
    Play(st, "murloc_raider")
    local raider = st.players[1].board[2]
    check(raider.charge and E.CanAttack(st, raider), "classes: Warsong Commander gives Charge")
    st = Fresh("rexxar")
    Put(st, 1, "starving_buzzard")
    hand = #st.players[1].hand
    Play(st, "river_crocolisk")
    check(#st.players[1].hand == hand + 1, "classes: Starving Buzzard draws for a Beast")
    st = Fresh("rexxar")
    Put(st, 1, "tundra_rhino")
    Play(st, "bloodfen_raptor")
    check(E.CanAttack(st, st.players[1].board[2]), "classes: Tundra Rhino gives Beasts Charge")
    st = Fresh("rexxar")
    local wolf = Put(st, 1, "timber_wolf")
    local croc, yeti2 = Put(st, 1, "river_crocolisk"), Put(st, 1, "chillwind_yeti")
    check(E.Attack(croc) == 3 and E.Attack(yeti2) == 4 and E.Attack(wolf) == 1, "classes: Timber Wolf only buffs other Beasts")
    st = Fresh("anduin")
    Put(st, 1, "northshire_cleric")
    local hurt = Put(st, 1, "chillwind_yeti")
    hurt.health = 2
    hand = #st.players[1].hand
    E.Apply(st, { type = "power", target = hurt.id })
    check(hurt.health == 4 and #st.players[1].hand == hand + 1, "classes: Lesser Heal + Northshire Cleric draws")

    -- Hero powers.
    st = Fresh("malfurion")
    E.Apply(st, { type = "power" })
    check(E.Attack(st.players[1].hero) == 1 and st.players[1].hero.armor == 1, "classes: Shapeshift")
    st = Fresh("rexxar")
    E.Apply(st, { type = "power" })
    check(st.players[2].hero.health == 28, "classes: Steady Shot")
    st = Fresh("uther")
    E.Apply(st, { type = "power" })
    check(st.players[1].board[1] and st.players[1].board[1].key == "silver_hand_recruit", "classes: Reinforce")
    st = Fresh("guldan")
    hand = #st.players[1].hand
    E.Apply(st, { type = "power" })
    check(#st.players[1].hand == hand + 1 and st.players[1].hero.health == 28, "classes: Life Tap")
    st = Fresh("malfurion")
    local max = st.players[1].maxMana
    st.players[1].maxMana, st.players[1].mana = 5, 5
    Play(st, "wild_growth")
    check(st.players[1].maxMana == 6 and st.players[1].mana == 3, "classes: Wild Growth adds an empty crystal")
    st = Fresh("guldan")
    Put(st, 1, "river_crocolisk")
    Put(st, 2, "chillwind_yeti")
    Play(st, "hellfire")
    check(st.players[1].hero.health == 27 and st.players[2].hero.health == 27 and #st.players[1].board == 0, "classes: Hellfire hits everything")

    -- Every hero plays whole games.
    local keys = {}
    for k in pairs(HS.Heroes) do table.insert(keys, k) end
    table.sort(keys)
    local wins, games = {}, 0
    for i, a in ipairs(keys) do
        local b = keys[(i % #keys) + 1]
        for seed = 1, 2 do
            local g = E.New({ heroes = { a, b }, seed = i * 101 + seed })
            for _ = 1, 120 do if g.over then break end HS.AI.PlayTurn(g) end
            check(g.over, "classes: " .. a .. " vs " .. b .. " finishes")
            games = games + 1
            if g.winner == 1 then wins[a] = (wins[a] or 0) + 1 elseif g.winner == 2 then wins[b] = (wins[b] or 0) + 1 end
        end
    end
    local line = {}
    for _, k in ipairs(keys) do table.insert(line, k .. " " .. (wins[k] or 0)) end
    print("  classes: " .. games .. " games: " .. table.concat(line, ", "))
end

-- Sound: every minion and hero has a voice; playing, summoning, hitting
-- and dying make their sounds when the animation gets there.
function HsSoundTests()
    local S = ns.HS.Sounds
    local quiet = {}
    for key, c in pairs(ns.HS.Cards) do
        if c.type == "minion" and not (S.Minions[key] and S.Minions[key].play) and c.race ~= "totem" then
            table.insert(quiet, key)
        end
    end
    table.sort(quiet)
    check(#quiet == 0, "hs sound: every minion has a voice (" .. table.concat(quiet, ", ") .. ")")
    local noHero = {}
    for key in pairs(ns.HS.Heroes) do if not (S.Heroes[key] and S.Heroes[key].play) then table.insert(noHero, key) end end
    check(#noHero == 0, "hs sound: every hero has a greeting (" .. table.concat(noHero, ", ") .. ")")
    local view = ns.UI.pages.hearthstone.view
    local function Has(list, id)
        if type(list) ~= "table" then return list == id end
        for _, x in ipairs(list) do if x == id then return true end end
    end
    local function Played(list)
        for _, id in ipairs(SOUND_FILES) do if Has(list, id) then return true end end
    end
    SOUND_FILES = {}
    view:EventSounds({ { kind = "play", owner = 1, key = "chillwind_yeti" }, { kind = "summon", owner = 1, key = "chillwind_yeti" },
        { kind = "play", owner = 1, key = "fireball" }, { kind = "death", key = "murloc_raider" } }, {}, 0.5, 0)
    for _ = 1, 3 do ns.Cards.Tick(true) Advance(1) end
    ns.Cards.Tick(true)
    check(Played(S.Play) and Played(S.Minions.chillwind_yeti.play) and Played(S.School.fire) and Played(S.Minions.murloc_raider.death),
        "hs sound: card, the Yeti's roar, Fireball, the murloc's death (" .. #SOUND_FILES .. " sounds)")
    ns.db.sound = false
    SOUND_FILES = {}
    view:EventSounds({ { kind = "play", owner = 1, key = "fireball" } }, {}, 0, 0)
    check(#SOUND_FILES == 0, "hs sound: Game sounds off: quiet")
    ns.db.sound = true
end

-- Classic: Stealth, Enrage, Combo, Secrets, more Deathrattles.
function HsClassicTests()
    -- Stealth: can't be targeted or attacked until it attacks.
    local st = Fresh()
    local wolf = Put(st, 2, "worgen_infiltrator", true)
    local yeti = Put(st, 1, "chillwind_yeti", true)
    check(not Has(E.AttackTargets(st, 1), function(id) return id == wolf.id end), "hs classic: a stealthed minion can't be attacked")
    check(not Has(E.Targets(st, 1, "any"), function(id) return id == wolf.id end), "hs classic: or targeted by the enemy")
    st.active = 2
    E.Apply(st, { type = "attack", attacker = wolf.id, target = 1 })
    check(not wolf.stealth, "hs classic: attacking shows it")
    -- Enrage: Amani Berserker hits harder when hurt.
    st = Fresh()
    local amani = Put(st, 1, "amani_berserker", true)
    local atk = E.Attack(amani)
    E.Damage(st, nil, amani, 1)
    check(E.Attack(amani) == atk + 3, "hs classic: Enrage: +3 Attack when damaged")
    -- Combo: Eviscerate deals 4 after another card.
    st = E.New({ heroes = { "valeera", "jaina" }, seed = 5, first = 1 })
    for _, p in ipairs(st.players) do p.hand, p.board, p.mana, p.maxMana = {}, {}, 10, 10 end
    local ev1 = Give(st, 1, "eviscerate")
    E.Apply(st, { type = "play", card = ev1.id, target = 2 })
    local hp1 = st.players[2].hero.health
    check(hp1 == 28, "hs classic: Eviscerate alone: 2 damage")
    local coin = Give(st, 1, "coin")
    local ev2 = Give(st, 1, "eviscerate")
    E.Apply(st, { type = "play", card = coin.id })
    E.Apply(st, { type = "play", card = ev2.id, target = 2 })
    check(st.players[2].hero.health == hp1 - 4, "hs classic: Combo: 4 damage after The Coin")
    -- Secrets.
    st = Fresh()
    local trap = Give(st, 1, "explosive_trap")
    E.Apply(st, { type = "play", card = trap.id })
    check(#st.players[1].secrets == 1, "hs classic: a secret is set")
    local again = Give(st, 1, "explosive_trap")
    check(E.PlayTargets(st, 1, again) == false, "hs classic: not the same secret twice")
    E.Apply(st, { type = "end" })
    local raider = Put(st, 2, "bloodfen_raptor", true)
    local hpRaptor = raider.health
    E.Apply(st, { type = "attack", attacker = raider.id, target = 1 })
    check(#st.players[1].secrets == 0 and raider.health == hpRaptor - 2 and st.players[2].hero.health == 28,
        "hs classic: Explosive Trap: 2 damage to all enemies when the hero is attacked")
    st = Fresh()
    local cs = Give(st, 2, "counterspell")
    st.active = 2
    E.Apply(st, { type = "play", card = cs.id })
    st.active = 1
    local fb = Give(st, 1, "fireball")
    E.Apply(st, { type = "play", card = fb.id, target = 2 })
    check(st.players[2].hero.health == 30 and #st.players[2].secrets == 0, "hs classic: Counterspell stops the Fireball")
    st = Fresh()
    local me = Give(st, 2, "mirror_entity")
    st.active = 2
    E.Apply(st, { type = "play", card = me.id })
    st.active = 1
    local y2 = Give(st, 1, "chillwind_yeti")
    E.Apply(st, { type = "play", card = y2.id })
    check(#st.players[2].board == 1 and st.players[2].board[1].key == "chillwind_yeti", "hs classic: Mirror Entity copies the Yeti")
    st = Fresh()
    local ns2 = Give(st, 2, "noble_sacrifice")
    st.active = 2
    E.Apply(st, { type = "play", card = ns2.id })
    st.active = 1
    local att = Put(st, 1, "chillwind_yeti", true)
    E.Apply(st, { type = "attack", attacker = att.id, target = 2 })
    check(st.players[2].hero.health == 30 and att.health < att.maxHealth, "hs classic: Noble Sacrifice: the Defender takes the hit")
    -- Deathrattles: Harvest Golem leaves a Damaged Golem.
    st = Fresh()
    local hg = Put(st, 1, "harvest_golem")
    E.Damage(st, nil, hg, 5)
    E.Deaths(st)
    check(#st.players[1].board == 1 and st.players[1].board[1].key == "damaged_golem", "hs classic: Harvest Golem: a Damaged Golem")
end
