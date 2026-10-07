-- Hearthstone rules engine. Pure logic: no frames, no globals beyond ns.HS.
--
-- The whole game is one plain table (`st`) with no functions in it, so it
-- can be saved, copied (the AI tries moves on copies) or sent over the
-- network later (a host runs the engine for PvP, like poker). Randomness
-- comes from a seeded generator inside the state.
--
--   local st = E.New({ heroes = { "jaina", "thrall" }, seed = 12345 })
--   E.Legal(st)                 -> every action the active player can take
--   E.Apply(st, action)         -> ok, events (or false, reason)
--
-- Actions:
--   { type = "play",   card = handCardId, target = id or nil, pos = n or nil }
--   { type = "attack", attacker = id, target = id }
--   { type = "power",  target = id or nil }
--   { type = "end" }
-- With opts.mulligan, both players first see their opening hand and may
-- swap cards with E.Mulligan(st, i, ids); the coin and the first turn come
-- when both have. Until then E.Legal is empty and E.Apply refuses.
-- Events (for the UI to animate), each { kind, ... }:
--   draw, burn, fatigue, play, summon, damage, heal, shield, freeze,
--   transform, buff, death, attack, power, mana, armor, turn, over,
--   equip, weaponBreak, bounce, discard, steal, doom
--
-- Ids: hero 1 and hero 2 are ids 1 and 2; every card instance gets a new id.
local ADDON, ns = ...

ns.HS = ns.HS or {}
local E = {}
ns.HS.Engine = E

local MAX_HAND, MAX_BOARD, MAX_MANA = 10, 7, 10

local function Card(key) return ns.HS.Cards[key] end
E.Card = Card

local EV -- the event list of the action being applied

local function Emit(kind, a)
    if EV then
        a = a or {}
        a.kind = kind
        table.insert(EV, a)
    end
end

---------------------------------------------------------------------------
-- Random numbers (Park-Miller; fits in a double exactly)
---------------------------------------------------------------------------
local function Rand(st, n)
    st.rng = (st.rng * 16807) % 2147483647
    return math.floor(st.rng / 2147483647 * n) + 1
end
E.Rand = Rand

local function Shuffle(st, list)
    for i = #list, 2, -1 do
        local j = Rand(st, i)
        list[i], list[j] = list[j], list[i]
    end
end

---------------------------------------------------------------------------
-- Looking things up
---------------------------------------------------------------------------
function E.Player(st, i) return st.players[i] end
function E.Other(i) return 3 - i end

-- An entity by id: the thing, its owner's index, and where it is.
function E.Find(st, id)
    for i, p in ipairs(st.players) do
        if p.hero.id == id then return p.hero, i, "hero" end
        for _, m in ipairs(p.board) do if m.id == id then return m, i, "board" end end
        for _, c in ipairs(p.hand) do if c.id == id then return c, i, "hand" end end
    end
end

local function BoardIndex(p, m)
    for i, x in ipairs(p.board) do if x == m then return i end end
end

-- Enrage: while damaged, a minion has more attack (and maybe Windfury).
local function Enraged(ent)
    local en = ent.key and Card(ent.key).enrage
    return en and ent.health < ent.maxHealth and en or nil
end
E.Enraged = Enraged

function E.Attack(ent)
    local weapon = ent.weapon and ent.weapon.attack or 0
    local en = Enraged(ent)
    return math.max(0, (ent.attack or 0) + (ent.tempAttack or 0) + (ent.auraAttack or 0) + weapon + (en and en.attack or 0))
end

local function SpellDamage(p)
    local n = 0
    for _, m in ipairs(p.board) do n = n + (Card(m.key).spellDamage or 0) end
    return n
end
E.SpellDamage = SpellDamage

---------------------------------------------------------------------------
-- Auras: recomputed after every change. Health auras move max and current
-- health together; losing one only lowers current health down to the new
-- max (a damaged minion survives losing Stormwind Champion).
---------------------------------------------------------------------------
local function Refresh(st)
    for _, p in ipairs(st.players) do
        for i, m in ipairs(p.board) do
            local atk, hp, charge = 0, 0, nil
            local race = Card(m.key).race
            for j, s in ipairs(p.board) do
                local aura = Card(s.key).aura
                local reaches = aura and (aura.scope == "all" or (s ~= m and (aura.scope == "others"
                    or (aura.scope == "adjacent" and math.abs(i - j) == 1))))
                if reaches and (not aura.race or aura.race == race) then
                    atk, hp = atk + (aura.attack or 0), hp + (aura.health or 0)
                    if aura.charge then charge = true end
                end
            end
            m.auraAttack = atk
            m.auraCharge = charge
            local delta = hp - (m.auraHealth or 0)
            if delta ~= 0 then
                m.maxHealth = m.maxHealth + delta
                if delta > 0 then m.health = m.health + delta else m.health = math.min(m.health, m.maxHealth) end
                m.auraHealth = hp
            end
        end
    end
end

---------------------------------------------------------------------------
-- Making things
---------------------------------------------------------------------------
local function NewId(st)
    st.nextId = st.nextId + 1
    return st.nextId
end

local function NewMinion(st, owner, key)
    local c = Card(key)
    return {
        id = NewId(st), key = key, owner = owner,
        attack = c.attack or 0, tempAttack = 0, auraAttack = 0,
        health = c.health or 1, maxHealth = c.health or 1, auraHealth = 0,
        taunt = c.taunt or nil, charge = c.charge or nil, divineShield = c.divineShield or nil,
        windfury = c.windfury or nil, stealth = c.stealth or nil, sleeping = true, attacks = 0,
    }
end

-- `id`: keep the hand card's id when a card is played (the UI follows it).
local function Summon(st, owner, key, pos, id)
    local p = st.players[owner]
    if #p.board >= MAX_BOARD then return nil end
    local m = NewMinion(st, owner, key)
    if id then m.id = id end
    pos = math.max(1, math.min(pos or (#p.board + 1), #p.board + 1))
    table.insert(p.board, pos, m)
    Emit("summon", { id = m.id, owner = owner, key = key, pos = pos })
    Refresh(st)
    E.OnSummon(st, owner, m)
    return m
end

local Damage

local function Draw(st, owner, n)
    local p = st.players[owner]
    for _ = 1, n or 1 do
        if #p.deck == 0 then
            p.fatigue = p.fatigue + 1
            Emit("fatigue", { owner = owner, amount = p.fatigue })
            Damage(st, nil, p.hero, p.fatigue)
        else
            local key = table.remove(p.deck, 1)
            if #p.hand >= MAX_HAND then
                Emit("burn", { owner = owner, key = key })
            else
                local c = { id = NewId(st), key = key }
                table.insert(p.hand, c)
                Emit("draw", { owner = owner, id = c.id, key = key })
            end
        end
    end
end
E.Draw = Draw

---------------------------------------------------------------------------
-- Damage, healing, freezing
---------------------------------------------------------------------------
local Run, Equip, Bounce, Steal

local function Freeze(st, t)
    t.frozen = true
    t.frozenOn = st.turn
    Emit("freeze", { id = t.id })
end

Damage = function(st, src, t, amount)
    if not t or amount <= 0 or t.health <= 0 then return 0 end
    if t.divineShield then
        t.divineShield = nil
        Emit("shield", { id = t.id })
        return 0
    end
    local left = amount
    if t.armor and t.armor > 0 then
        local soak = math.min(t.armor, left)
        t.armor = t.armor - soak
        left = left - soak
    end
    t.health = t.health - left
    Emit("damage", { id = t.id, amount = amount, source = src and src.id })
    if src and src.key and Card(src.key).freezeOnHit then Freeze(st, t) end
    if t.key and t.health > 0 then
        local trig = Card(t.key).damaged
        if trig then Run(st, { owner = t.owner, source = t }, trig.effects) end
    end
    return amount
end
E.Damage = Damage

local function Heal(st, t, amount)
    if not t or t.health <= 0 then return end
    local before = t.health
    t.health = math.min(t.maxHealth, t.health + amount)
    if t.health > before then
        Emit("heal", { id = t.id, amount = t.health - before })
        if t.key then
            for i, p in ipairs(st.players) do
                for _, m in ipairs(p.board) do
                    local trig = Card(m.key).minionHealed
                    if trig and m.health > 0 then Run(st, { owner = i, source = m }, trig.effects) end
                end
            end
        end
    end
end

-- Remove the dead (deathrattles can kill more, so loop) and check heroes.
local function Deaths(st)
    for _ = 1, 20 do
        local dead = {}
        for i, p in ipairs(st.players) do
            for j = #p.board, 1, -1 do
                local m = p.board[j]
                if m.health <= 0 then
                    table.remove(p.board, j)
                    table.insert(dead, { m = m, owner = i, pos = j })
                end
            end
        end
        if #dead == 0 then break end
        for _, d in ipairs(dead) do Emit("death", { id = d.m.id, owner = d.owner, key = d.m.key, pos = d.pos }) end
        E.SecretDied(st, dead)
        Refresh(st)
        for _, d in ipairs(dead) do
            local dr = Card(d.m.key).deathrattle
            if dr then Run(st, { owner = d.owner, source = d.m, pos = d.pos }, dr.effects) end
        end
    end
    if not st.over then
        local a, b = st.players[1].hero.health <= 0, st.players[2].hero.health <= 0
        if a or b then
            st.over = true
            st.winner = (a and b) and 0 or (a and 2 or 1)
            Emit("over", { winner = st.winner })
        end
    end
end
E.Deaths = Deaths

---------------------------------------------------------------------------
-- Targets
---------------------------------------------------------------------------
local function Alive(list)
    local out = {}
    for _, x in ipairs(list) do if x.health > 0 then table.insert(out, x) end end
    return out
end

local function Chars(p)
    local out = { p.hero }
    for _, m in ipairs(p.board) do table.insert(out, m) end
    return out
end

-- Who an effect's "to" means.
local function Who(st, ctx, to)
    local me, them = st.players[ctx.owner], st.players[3 - ctx.owner]
    if to == "target" then return { ctx.target } end
    if to == "self" then return { ctx.source } end
    if to == "myHero" then return { me.hero } end
    if to == "enemyHero" then return { them.hero } end
    if to == "myMinions" then return Alive(me.board) end
    if to == "enemyMinions" then return Alive(them.board) end
    if to == "otherMyMinions" then
        local out = {}
        for _, m in ipairs(Alive(me.board)) do if m ~= ctx.source then table.insert(out, m) end end
        return out
    end
    if to == "enemies" then return Alive(Chars(them)) end
    if to == "myChars" then return Alive(Chars(me)) end
    if to == "allMinions" then
        local out = Alive(me.board)
        for _, m in ipairs(Alive(them.board)) do table.insert(out, m) end
        return out
    end
    if to == "allChars" then
        local out = Alive(Chars(me))
        for _, m in ipairs(Alive(Chars(them))) do table.insert(out, m) end
        return out
    end
    if to == "allOthers" then -- every character but the source
        local out = {}
        for _, c in ipairs(Alive(Chars(me))) do if c ~= ctx.source then table.insert(out, c) end end
        for _, c in ipairs(Alive(Chars(them))) do if c ~= ctx.source then table.insert(out, c) end end
        return out
    end
    if to == "otherEnemies" then -- enemies but the target
        local out = {}
        for _, c in ipairs(Alive(Chars(them))) do if c ~= ctx.target then table.insert(out, c) end end
        return out
    end
    if to == "summoned" then return { ctx.summoned } end
    return {}
end

-- Does a character pass a target filter? { maxAttack, minAttack, damaged, undamaged, race }
local function Passes(x, f)
    if not f then return true end
    local atk = E.Attack(x)
    if f.maxAttack and atk > f.maxAttack then return false end
    if f.minAttack and atk < f.minAttack then return false end
    if f.damaged and x.health >= x.maxHealth then return false end
    if f.undamaged and x.health < x.maxHealth then return false end
    if f.race and not (x.key and Card(x.key).race == f.race) then return false end
    return true
end
E.Passes = Passes

-- Ids a target spec allows for player `owner` (`except` = the minion being
-- played, `filter` = see Passes).
function E.Targets(st, owner, spec, except, filter)
    local me, them = st.players[owner], st.players[3 - owner]
    local out = {}
    local function Add(list)
        for _, x in ipairs(list) do
            local hidden = x.stealth and x.owner ~= owner
            if x.health > 0 and x.id ~= except and Passes(x, filter) and not hidden then table.insert(out, x.id) end
        end
    end
    if spec == "any" then Add(Chars(me)) Add(Chars(them))
    elseif spec == "minion" then Add(me.board) Add(them.board)
    elseif spec == "enemyChar" then Add(Chars(them))
    elseif spec == "enemyMinion" then Add(them.board)
    elseif spec == "friendlyMinion" then Add(me.board)
    elseif spec == "friendlyChar" then Add(Chars(me))
    end
    return out
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
local function Transform(st, t, into)
    local p = st.players[t.owner]
    local i = BoardIndex(p, t)
    if not i then return end
    local m = NewMinion(st, t.owner, into)
    m.id = t.id -- same spot, same id: the UI turns it into the new minion
    p.board[i] = m
    Emit("transform", { id = t.id, key = into })
    Refresh(st)
end

-- Weapons: the hero's attack and durability.
Equip = function(st, owner, key)
    local c = Card(key)
    local hero = st.players[owner].hero
    if hero.weapon then Emit("weaponBreak", { id = hero.id, key = hero.weapon.key }) end
    hero.weapon = { key = key, attack = c.attack, durability = c.durability }
    Emit("equip", { id = hero.id, key = key })
end

-- Back to its owner's hand (destroyed if the hand is full).
Bounce = function(st, t)
    local p = st.players[t.owner]
    local i = BoardIndex(p, t)
    if not i then return end
    table.remove(p.board, i)
    if #p.hand < MAX_HAND then
        table.insert(p.hand, { id = t.id, key = t.key })
        Emit("bounce", { id = t.id, owner = t.owner, key = t.key })
    else
        Emit("death", { id = t.id, owner = t.owner, key = t.key, pos = i })
    end
    Refresh(st)
end

-- Take control of an enemy minion (it can't attack this turn).
Steal = function(st, t, owner)
    local from = st.players[t.owner]
    local to = st.players[owner]
    local i = BoardIndex(from, t)
    if not i or #to.board >= MAX_BOARD then return end
    table.remove(from.board, i)
    t.owner, t.sleeping, t.attacks, t.doomedBy = owner, true, 0, nil
    table.insert(to.board, t)
    Emit("steal", { id = t.id, owner = owner })
    Refresh(st)
end

Run = function(st, ctx, effects)
    local me = st.players[ctx.owner]
    for _, e in ipairs(effects or {}) do
        local op = e.op
        if op == "damage" then
            local amount = e.amount
            if e.ifRace then
                for _, m in ipairs(me.board) do
                    if Card(m.key).race == e.ifRace.race then amount = e.ifRace.amount break end
                end
            end
            amount = amount + ((ctx.spell and e.spell) and SpellDamage(me) or 0)
            for _, t in ipairs(Who(st, ctx, e.to)) do
                Damage(st, ctx.source, t, amount)
                if e.onKill and t.health <= 0 then Run(st, ctx, e.onKill) end
            end
        elseif op == "missiles" then
            for _ = 1, e.n + (ctx.spell and SpellDamage(me) or 0) do
                local pool = Alive(Chars(st.players[3 - ctx.owner]))
                if #pool == 0 then break end
                Damage(st, nil, pool[Rand(st, #pool)], 1)
            end
        elseif op == "heal" then
            for _, t in ipairs(Who(st, ctx, e.to)) do Heal(st, t, e.amount) end
        elseif op == "draw" then
            Draw(st, ctx.owner, e.n or 1)
        elseif op == "summon" then
            for _ = 1, e.n or 1 do
                -- Battlecry tokens go to the right of the minion that made them.
                local pos = ctx.source and ctx.source.key and BoardIndex(me, ctx.source)
                Summon(st, ctx.owner, e.card, pos and pos + 1 or nil)
            end
        elseif op == "summonRandom" then
            local pool = {}
            for _, key in ipairs(e.pool) do
                local taken = false
                if e.unique then for _, m in ipairs(me.board) do if m.key == key then taken = true end end end
                if not taken then table.insert(pool, key) end
            end
            if #pool > 0 then Summon(st, ctx.owner, pool[Rand(st, #pool)]) end
        elseif op == "freeze" then
            for _, t in ipairs(Who(st, ctx, e.to)) do Freeze(st, t) end
        elseif op == "transform" then
            for _, t in ipairs(Who(st, ctx, e.to)) do Transform(st, t, e.into) end
        elseif op == "buff" then
            for _, t in ipairs(Who(st, ctx, e.to)) do
                if e.temp then t.tempAttack = (t.tempAttack or 0) + (e.attack or 0)
                else t.attack = (t.attack or 0) + (e.attack or 0) end
                if e.health then
                    t.maxHealth = t.maxHealth + e.health
                    t.health = t.health + e.health
                end
                if e.taunt then t.taunt = true end
                if e.windfury then t.windfury = true end
                if e.divineShield then t.divineShield = true end
                if e.charge then t.charge = true end
                Emit("buff", { id = t.id })
            end
        elseif op == "mana" then
            me.mana = math.min(MAX_MANA, me.mana + e.n)
            Emit("mana", { owner = ctx.owner })
        elseif op == "armor" then
            me.hero.armor = me.hero.armor + e.n
            Emit("armor", { id = me.hero.id, amount = e.n })
        elseif op == "destroy" then
            for _, t in ipairs(Who(st, ctx, e.to)) do t.health = 0 end
        elseif op == "damageRandom" then
            -- `n` different random enemy minions.
            local amount = e.amount + ((ctx.spell and e.spell) and SpellDamage(me) or 0)
            local pool = Alive(st.players[3 - ctx.owner].board)
            for _ = 1, e.n do
                if #pool == 0 then break end
                Damage(st, ctx.source, table.remove(pool, Rand(st, #pool)), amount)
            end
        elseif op == "equip" then
            Equip(st, ctx.owner, e.card)
        elseif op == "weaponBuff" then
            if me.hero.weapon then
                me.hero.weapon.attack = me.hero.weapon.attack + (e.attack or 0)
                Emit("buff", { id = me.hero.id })
            end
        elseif op == "returnToHand" then
            for _, t in ipairs(Who(st, ctx, e.to)) do Bounce(st, t) end
        elseif op == "control" then
            for _, t in ipairs(Who(st, ctx, e.to)) do Steal(st, t, ctx.owner) end
        elseif op == "setHealth" then
            for _, t in ipairs(Who(st, ctx, e.to)) do
                t.health, t.maxHealth, t.auraHealth = e.n, e.n, 0
                Emit("buff", { id = t.id })
            end
        elseif op == "setAttack" then
            for _, t in ipairs(Who(st, ctx, e.to)) do
                t.attack, t.tempAttack = e.n, 0
                Emit("buff", { id = t.id })
            end
        elseif op == "doubleHealth" then
            for _, t in ipairs(Who(st, ctx, e.to)) do
                t.maxHealth = t.maxHealth + t.health
                t.health = t.health * 2
                Emit("buff", { id = t.id })
            end
        elseif op == "discard" then
            for _ = 1, e.n or 1 do
                if #me.hand == 0 then break end
                local c = table.remove(me.hand, Rand(st, #me.hand))
                Emit("discard", { owner = ctx.owner, id = c.id, key = c.key })
            end
        elseif op == "copyEnemyHand" then
            local them = st.players[3 - ctx.owner]
            if #them.hand > 0 and #me.hand < MAX_HAND then
                local src = them.hand[Rand(st, #them.hand)]
                local c = { id = NewId(st), key = src.key }
                table.insert(me.hand, c)
                Emit("draw", { owner = ctx.owner, id = c.id, key = c.key })
            end
        elseif op == "manaCrystal" then
            if me.maxMana < MAX_MANA then
                me.maxMana = me.maxMana + 1 -- an empty one
                Emit("mana", { owner = ctx.owner })
            else
                Draw(st, ctx.owner, 1)
            end
        elseif op == "doom" then
            for _, t in ipairs(Who(st, ctx, e.to)) do
                t.doomedBy = ctx.owner
                Emit("doom", { id = t.id })
            end
        end
        Refresh(st)
    end
end
E.Run = Run

-- A minion was summoned: friendly "whenever you summon" minions react.
function E.OnSummon(st, owner, m)
    local p = st.players[owner]
    for _, other in ipairs(p.board) do
        local trig = Card(other.key).onSummon
        if trig and other ~= m and other.health > 0 then
            local f = trig.filter or {}
            local c = Card(m.key)
            local ok = (not f.maxAttack or E.Attack(m) <= f.maxAttack) and (not f.race or c.race == f.race)
            if ok then Run(st, { owner = owner, source = other, summoned = m }, trig.effects) end
        end
    end
end

---------------------------------------------------------------------------
-- A new game
---------------------------------------------------------------------------
-- opts: heroes = { key1, key2 }, decks = { list1, list2 } (optional: the
-- heroes' default decks), seed, first (1 or 2; random if not given).
function E.New(opts)
    local seed = math.floor(opts.seed or 1) % 2147483646 + 1
    local st = { rng = seed, turn = 0, nextId = 2, over = false, players = {} }
    for i = 1, 2 do
        local h = ns.HS.Heroes[opts.heroes[i]]
        local deck = {}
        for j, key in ipairs((opts.decks and opts.decks[i]) or ns.HS.DeckList(h.deck)) do deck[j] = key end
        st.players[i] = {
            index = i, heroKey = h.key,
            hero = { id = i, owner = i, health = h.health, maxHealth = h.health, armor = 0, attack = 0,
                tempAttack = 0, attacks = 0 },
            deck = deck, hand = {}, board = {},
            mana = 0, maxMana = 0, overload = 0, locked = 0, powerUsed = false, fatigue = 0,
        }
    end
    for i = 1, 2 do Shuffle(st, st.players[i].deck) end
    st.active = opts.first or Rand(st, 2)
    local events = {}
    EV = events
    -- First player draws 3, the second 4 and gets The Coin.
    Draw(st, st.active, 3)
    Draw(st, 3 - st.active, 4)
    if opts.mulligan then
        st.players[1].mulligan, st.players[2].mulligan = true, true
    else
        E.FirstTurn(st)
    end
    EV = nil
    st.startEvents = nil
    return st, events
end

-- The second player's coin, then the first turn.
function E.FirstTurn(st)
    local second = 3 - st.active
    table.insert(st.players[second].hand, { id = NewId(st), key = "coin" })
    Emit("draw", { owner = second, id = st.nextId, key = "coin" })
    E.StartTurn(st)
end

-- Is someone still choosing which opening cards to swap?
function E.Mulliganing(st)
    return st.players[1].mulligan == true or st.players[2].mulligan == true
end

-- Player i swaps these opening cards (ids; none: keep them all): new cards
-- are drawn first (so never the same ones back), then the old ones are
-- shuffled into the deck. Returns ok, events.
function E.Mulligan(st, i, ids)
    local p = st.players[i]
    if not p or not p.mulligan then return false, "nothing to swap now" end
    local events = {}
    EV = events
    local back = {}
    for _, id in ipairs(ids or {}) do
        for j, c in ipairs(p.hand) do
            if c.id == id then
                table.insert(back, table.remove(p.hand, j))
                break
            end
        end
    end
    Draw(st, i, #back)
    for _, c in ipairs(back) do table.insert(p.deck, c.key) end
    Shuffle(st, p.deck)
    p.mulligan = nil
    Emit("mulligan", { owner = i, n = #back })
    if not E.Mulliganing(st) then E.FirstTurn(st) end
    EV = nil
    return true, events
end

function E.StartTurn(st)
    local p = st.players[st.active]
    st.turn = st.turn + 1
    p.maxMana = math.min(MAX_MANA, p.maxMana + 1)
    p.locked, p.overload = p.overload, 0
    p.mana = math.max(0, p.maxMana - p.locked)
    p.powerUsed = false
    p.played = 0 -- cards played this turn (Combo)
    p.hero.attacks = 0
    for _, m in ipairs(p.board) do
        m.sleeping = nil
        m.attacks = 0
    end
    Emit("turn", { owner = st.active, turn = st.turn })
    -- Corruption: minions this player doomed die now.
    for _, q in ipairs(st.players) do
        for _, m in ipairs(q.board) do
            if m.doomedBy == st.active and m.health > 0 then m.health = 0 end
        end
    end
    Deaths(st)
    if st.over then return end
    Draw(st, st.active, 1)
    Deaths(st)
end

local function EndTurn(st)
    local i = st.active
    local p = st.players[i]
    for _, m in ipairs(p.board) do
        local trig = Card(m.key).endTurn
        if trig and m.health > 0 then Run(st, { owner = i, source = m }, trig.effects) end
    end
    Deaths(st)
    -- "This turn" buffs end; characters that were frozen before this turn thaw.
    for _, q in ipairs(st.players) do
        q.hero.tempAttack = 0
        for _, m in ipairs(q.board) do m.tempAttack = 0 end
    end
    for _, c in ipairs(Chars(p)) do
        if c.frozen and (c.frozenOn or 0) < st.turn then c.frozen = nil end
    end
    if st.over then return end
    st.active = 3 - i
    E.StartTurn(st)
end

---------------------------------------------------------------------------
-- What's allowed
---------------------------------------------------------------------------
local function CanAttack(st, ent)
    if ent.frozen or E.Attack(ent) <= 0 then return false end
    if ent.key then
        if ent.sleeping and not (ent.charge or ent.auraCharge) then return false end
        local en = Enraged(ent)
        return ent.attacks < ((ent.windfury or (en and en.windfury)) and 2 or 1)
    end
    return ent.attacks < 1
end
E.CanAttack = CanAttack

-- Enemy characters `owner` may attack (Taunt first).
function E.AttackTargets(st, owner)
    local them = st.players[3 - owner]
    local taunts = {}
    for _, m in ipairs(them.board) do if m.taunt and not m.stealth and m.health > 0 then table.insert(taunts, m.id) end end
    if #taunts > 0 then return taunts end
    return E.Targets(st, owner, "enemyChar")
end

-- Would these effects do anything? (A summon needs room, a unique random
-- summon needs something left in its pool.)
local function Useful(st, owner, effects, requires)
    local p = st.players[owner]
    if requires then
        if requires.weapon and not p.hero.weapon then return false end
        if requires.boardRoom and #p.board >= MAX_BOARD then return false end
        if requires.enemyMinions and #Alive(st.players[3 - owner].board) < requires.enemyMinions then return false end
    end
    for _, e in ipairs(effects or {}) do
        if e.op == "summon" and not e.free and #p.board >= MAX_BOARD then return false end
        if e.op == "summonRandom" then
            if #p.board >= MAX_BOARD then return false end
            local free = false
            for _, key in ipairs(e.pool) do
                local taken = false
                for _, m in ipairs(p.board) do if m.key == key then taken = true end end
                if not taken then free = true end
            end
            if not free then return false end
        end
    end
    return true
end

-- Target ids for playing hand card `c`; nil when it needs none; false when it can't be played.
-- Combo (Rogue): another card played before this one this turn.
local function ComboOn(p) return (p.played or 0) > 0 end
E.ComboOn = ComboOn

function E.PlayTargets(st, owner, c)
    local p = st.players[owner]
    local card = Card(c.key)
    if card.cost > p.mana then return false end
    if card.secret then
        for _, k in ipairs(p.secrets or {}) do if k == c.key then return false end end
        return nil
    end
    if card.type == "minion" then
        if #p.board >= MAX_BOARD then return false end
        local bc = (ComboOn(p) and card.combo) or card.battlecry
        if bc and bc.target then
            local t = E.Targets(st, owner, bc.target, nil, bc.filter)
            return #t > 0 and t or nil -- no one to hit: the battlecry just does nothing
        end
        return nil
    end
    if card.type == "weapon" then return nil end
    local sp = (ComboOn(p) and card.comboSpell) or card.spell or {}
    if not Useful(st, owner, sp.effects, sp.requires) then return false end
    if sp.target then
        local t = E.Targets(st, owner, sp.target, nil, sp.filter)
        if #t == 0 then return false end
        return t
    end
    return nil
end

function E.PowerTargets(st, owner)
    local p = st.players[owner]
    local pw = ns.HS.Heroes[p.heroKey].power
    if p.powerUsed or pw.cost > p.mana or not Useful(st, owner, pw.effects) then return false end
    if pw.target then return E.Targets(st, owner, pw.target) end
    return nil
end

-- Every action the active player can take now.
function E.Legal(st)
    local out = {}
    if st.over or E.Mulliganing(st) then return out end
    local i = st.active
    local p = st.players[i]
    for _, c in ipairs(p.hand) do
        local t = E.PlayTargets(st, i, c)
        if t then
            for _, id in ipairs(t) do table.insert(out, { type = "play", card = c.id, target = id }) end
        elseif t == nil then
            table.insert(out, { type = "play", card = c.id })
        end
    end
    local targets = E.AttackTargets(st, i)
    for _, ent in ipairs(Chars(p)) do
        if CanAttack(st, ent) then
            for _, id in ipairs(targets) do table.insert(out, { type = "attack", attacker = ent.id, target = id }) end
        end
    end
    local pt = E.PowerTargets(st, i)
    if pt then
        for _, id in ipairs(pt) do table.insert(out, { type = "power", target = id }) end
    elseif pt == nil then
        table.insert(out, { type = "power" })
    end
    table.insert(out, { type = "end" })
    return out
end

local function Contains(list, id)
    for _, x in ipairs(list or {}) do if x == id then return true end end
    return false
end

---------------------------------------------------------------------------
-- Secrets: hidden until the other player sets them off on their turn.
---------------------------------------------------------------------------
local function TakeSecret(st, owner, key)
    local p = st.players[owner]
    for i, k in ipairs(p.secrets or {}) do
        if k == key and st.active ~= owner then
            table.remove(p.secrets, i)
            Emit("secret", { owner = owner, key = key })
            return true
        end
    end
    return false
end
E.TakeSecret = TakeSecret

-- Something attacks `def`: returns who's really hit, and true to stop it.
function E.SecretAttacked(st, att, def)
    local owner = def.owner or def.id
    local me = st.players[owner]
    if not me or not me.secrets or #me.secrets == 0 then return def end
    if att.key and TakeSecret(st, owner, "freezing_trap") then
        Bounce(st, att)
        return def, true
    end
    if TakeSecret(st, owner, "noble_sacrifice") then
        local d = Summon(st, owner, "defender")
        if d then def = d end
    end
    if not def.key then
        if TakeSecret(st, owner, "explosive_trap") then
            for _, t in ipairs(Alive(Chars(st.players[3 - owner]))) do Damage(st, me.hero, t, 2) end
        end
        if TakeSecret(st, owner, "ice_barrier") then
            me.hero.armor = (me.hero.armor or 0) + 8
            Emit("armor", { id = me.hero.id, amount = 8 })
        end
    elseif TakeSecret(st, owner, "snake_trap") then
        for _ = 1, 3 do Summon(st, owner, "snake") end
    end
    return def
end

-- A spell is cast: Counterspell stops it (true).
function E.SecretSpellCast(st, caster, key)
    return TakeSecret(st, 3 - caster, "counterspell")
end

-- A minion is played: Mirror Entity copies it; Repentance cuts it to 1 Health.
function E.SecretMinionPlayed(st, owner, m)
    local other = 3 - owner
    if TakeSecret(st, other, "mirror_entity") then Summon(st, other, m.key) end
    if TakeSecret(st, other, "repentance") then
        m.maxHealth, m.health = 1, math.min(m.health, 1)
    end
end

-- Minions died: Redemption brings the first friendly one back with 1 Health.
function E.SecretDied(st, dead)
    for _, d in ipairs(dead) do
        if TakeSecret(st, d.owner, "redemption") then
            local m = Summon(st, d.owner, d.m.key)
            if m then m.health = 1 end
            break
        end
    end
end

---------------------------------------------------------------------------
-- Doing it
---------------------------------------------------------------------------
local function Play(st, a)
    local i = st.active
    local p = st.players[i]
    local c, owner, where = E.Find(st, a.card)
    if not c or owner ~= i or where ~= "hand" then return false, "not in your hand" end
    local t = E.PlayTargets(st, i, c)
    if t == false then return false, "can't play that now" end
    if t and not Contains(t, a.target) then return false, "pick a target" end
    local card = Card(c.key)
    for j, x in ipairs(p.hand) do if x == c then table.remove(p.hand, j) break end end
    p.mana = p.mana - card.cost
    if card.overload then p.overload = p.overload + card.overload end
    Emit("play", { owner = i, id = c.id, key = c.key, target = a.target })
    local target = a.target and E.Find(st, a.target)
    local combo = ComboOn(p)
    p.played = (p.played or 0) + 1
    if card.secret then
        p.secrets = p.secrets or {}
        table.insert(p.secrets, c.key)
        Emit("secretSet", { owner = i })
    elseif card.type == "minion" then
        local m = Summon(st, i, c.key, a.pos, c.id)
        local bc = (combo and card.combo) or card.battlecry
        if m and bc then
            Run(st, { owner = i, source = m, target = target }, bc.effects)
        end
        if m then E.SecretMinionPlayed(st, i, m) end
    elseif card.type == "weapon" then
        Equip(st, i, c.key)
    elseif not E.SecretSpellCast(st, i, c.key) then
        Run(st, { owner = i, target = target, spell = true }, ((combo and card.comboSpell) or card.spell).effects)
    end
    Deaths(st)
    return true
end

local function Fight(st, a)
    local i = st.active
    local att, ao = E.Find(st, a.attacker)
    local def = E.Find(st, a.target)
    if not att or ao ~= i or not CanAttack(st, att) then return false, "can't attack" end
    if not Contains(E.AttackTargets(st, i), a.target) then return false, "must attack a Taunt minion" end
    att.attacks = att.attacks + 1
    att.stealth = nil -- attacking shows you
    -- The defender's secrets (Noble Sacrifice can change who's hit; Freezing
    -- Trap can stop the attack).
    local stop
    def, stop = E.SecretAttacked(st, att, def)
    if stop then
        Deaths(st)
        return true
    end
    Emit("attack", { attacker = att.id, target = def.id })
    local weapon = not att.key and att.weapon
    if weapon then
        local trig = Card(weapon.key).onAttack
        if trig then Run(st, { owner = i, source = att }, trig.effects) end
    end
    -- Both hit at once; heroes only hit back when they're the attacker.
    local dealt, back = E.Attack(att), def.key and E.Attack(def) or 0
    Damage(st, att, def, dealt)
    if back > 0 then Damage(st, def, att, back) end
    if weapon and att.weapon == weapon then
        weapon.durability = weapon.durability - 1
        if weapon.durability <= 0 then
            att.weapon = nil
            Emit("weaponBreak", { id = att.id, key = weapon.key })
        end
    end
    Deaths(st)
    return true
end

local function Power(st, a)
    local i = st.active
    local p = st.players[i]
    local pw = ns.HS.Heroes[p.heroKey].power
    local t = E.PowerTargets(st, i)
    if t == false then return false, "can't use the hero power now" end
    if t and not Contains(t, a.target) then return false, "pick a target" end
    p.powerUsed = true
    p.mana = p.mana - pw.cost
    Emit("power", { owner = i, target = a.target })
    Run(st, { owner = i, source = p.hero, target = a.target and E.Find(st, a.target) }, pw.effects)
    Deaths(st)
    return true
end

function E.Apply(st, a)
    if st.over then return false, "the game is over" end
    if E.Mulliganing(st) then return false, "choose your opening cards first" end
    local events = {}
    EV = events
    local ok, why
    if a.type == "play" then ok, why = Play(st, a)
    elseif a.type == "attack" then ok, why = Fight(st, a)
    elseif a.type == "power" then ok, why = Power(st, a)
    elseif a.type == "end" then EndTurn(st) ok = true
    else ok, why = false, "unknown action" end
    EV = nil
    if not ok then return false, why end
    return true, events
end

---------------------------------------------------------------------------
-- Copies and views
---------------------------------------------------------------------------
local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end
E.Copy = Copy

-- The same game from the other chair: players swapped (and every player
-- index and hero id with them), so player 2 can be shown by board code that
-- always puts "you" at index 1. Works on states, events and actions; card ids
-- start at 3, so only the heroes' ids 1 and 2 change.
local SWAP = { owner = true, active = true, winner = true, doomedBy = true, index = true,
    id = true, target = true, attacker = true, source = true }
function E.Mirror(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        if SWAP[k] and (v == 1 or v == 2) then out[k] = 3 - v else out[k] = E.Mirror(v) end
    end
    if type(t.players) == "table" and #t.players == 2 then out.players = { out.players[2], out.players[1] } end
    return out
end

-- What player `i` may see (for PvP): the other hand's cards and both decks
-- are hidden (i = 0: both hands).
function E.View(st, i)
    local v = Copy(st)
    for j, p in ipairs(v.players) do
        if j ~= i then
            for _, c in ipairs(p.hand) do c.key = nil end
            -- Their secrets: how many, not which.
            for k in ipairs(p.secrets or {}) do p.secrets[k] = "?" end
        end
        p.deckCount = #p.deck
        p.deck = {}
    end
    v.rng = nil
    return v
end
