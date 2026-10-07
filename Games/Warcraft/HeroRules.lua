-- Warcraft III: the rules for heroes (the data is in Heroes.lua): levels
-- and experience, skill points, mana, casting, effects (stun, invulnerable,
-- invisible, slow, can't attack), auras, area spells, summons that expire,
-- revival. The engine calls in at a few points (E.UnitTick, E.OnHit,
-- E.OnTaken, E.OnDying, E.OnDeath, E.CastStep, E.WorldTick, E.HeroCommand);
-- everything stays plain data in the game state, deterministic, so lockstep
-- PvP keeps working.
local _, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, B = WC.Units, WC.Buildings

-- Damage of spells: armour doesn't count; heroes take less, buildings half.
WC.DAMAGE.spell = { light = 1, medium = 1, heavy = 1, fortified = 0.5, unarmored = 1, hero = 0.75 }
WC.DAMAGE.hero = { light = 1, medium = 1, heavy = 1, fortified = 0.5, unarmored = 1, hero = 1 }
WC.DAMAGE.normal.hero, WC.DAMAGE.pierce.hero, WC.DAMAGE.siege.hero = 1, 0.5, 0.5

local function At(t, lv) if type(t) ~= "table" then return t end return t[lv] or t[#t] end
local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end
local ATAN2 = math.atan2 or math.atan

function E.IsHero(u) return u ~= nil and u.kind == "unit" and U[u.type] ~= nil and U[u.type].hero == true end
function E.Skill(u, key) return u.skills and u.skills[key] or 0 end
local Skill = E.Skill

-- A hero's attribute at its level.
function E.Stat(u, stat)
    local s = U[u.type][stat]
    return s[1] + s[2] * ((u.level or 1) - 1)
end

local function HeroMaxHp(u)
    return math.floor(100 + 25 * E.Stat(u, "str") + (u.buffs and u.buffs.avatar and 500 or 0))
end
local function HeroMaxMana(u) return math.floor(15 * E.Stat(u, "int")) end

function E.InitHero(st, u, saved)
    u.level, u.xp, u.skills, u.points, u.cds = 1, 0, {}, 1, {}
    if saved then
        u.level, u.xp, u.skills, u.points = saved.level, saved.xp, Copy(saved.skills), saved.points
        u.items = Copy(saved.items)
    end
    u.maxHp = HeroMaxHp(u)
    u.hp = u.maxHp
    u.maxMana = HeroMaxMana(u)
    u.mana = u.maxMana
end

function E.HeroDamage(st, u)
    if u.illusion then return 0 end
    local d = U[u.type]
    local items = E.ItemBonus and E.ItemBonus(u, "damage") or 0
    local dmg = d.baseDamage + E.Stat(u, d.primary) + (u.buffs and u.buffs.avatar and 20 or 0) + items
    if E.Drums then dmg = dmg * (1 + E.Drums(st, u)) end
    if u.buffs and u.buffs.innerFire then dmg = dmg * 1.1 end
    return dmg
end

function E.HeroArmor(u)
    local items = E.ItemBonus and E.ItemBonus(u, "armor") or 0
    return U[u.type].baseArmor + E.Stat(u, "agi") * 0.3 + (u.buffs and u.buffs.avatar and 5 or 0) + items
end

-- Heroes of player p (not copies), cached for one step.
local function Heroes(st, p)
    local c = st.heroCache
    if not c or c.time ~= st.time then
        c = { time = st.time }
        for p2 = 1, #st.players do c[p2] = {} end
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and E.IsHero(e) and not e.illusion and e.owner > 0 and not (e.buffs and e.buffs.reinc) then
                c[e.owner] = c[e.owner] or {}
                table.insert(c[e.owner], e)
            end
        end
        st.heroCache = c
    end
    return c[p] or {}
end
E.HeroesOf = Heroes

-- The strongest aura of this kind from u's own heroes in range (0: none).
function E.Aura(st, u, key, field)
    if not u.owner or u.owner < 1 then return 0 end
    local best = 0
    local x, y = u.x + (u.size or 0) / 2, u.y + (u.size or 0) / 2
    for q = 1, #st.players do
        if E.Ally(st, q, u.owner) then
            for _, h in ipairs(Heroes(st, q)) do
                local lv = Skill(h, key)
                if lv > 0 then
                    local a = WC.Abilities[key]
                    local dx, dy = h.x - x, h.y - y
                    if dx * dx + dy * dy <= a.radius * a.radius then best = math.max(best, At(a[field or "amount"], lv)) end
                end
            end
        end
    end
    return best
end

function E.Speed(st, u)
    local s = U[u.type].speed
    local b = u.buffs
    if b then
        if b.slow or b.hex then s = s * 0.5 end
        if b.windwalk then s = s * (1 + b.windwalk.speed) end
        if b.bloodlust then s = s * 1.25 end
    end
    if u.items and E.ItemBonus then s = s * (1 + E.ItemBonus(u, "speed")) end
    return s * (1 + E.Aura(st, u, "endurance"))
end

function E.Cooldown(st, u)
    local cd = U[u.type].cooldown / (1 + E.Aura(st, u, "endurance", "attack"))
    local b = u.buffs
    if b and b.bloodlust then cd = cd / 1.4 end
    if b and b.slow then cd = cd * 1.25 end
    return cd
end

-- Can't fight right now (hexed, banished, spinning, stunned)?
function E.CantAttack(u)
    if U[u.type] and U[u.type].noAttack then return true end
    local b = u.buffs
    return b ~= nil and (b.noAttack ~= nil or b.hex ~= nil or b.bladestorm ~= nil or b.reinc ~= nil or b.stun ~= nil)
end

-- Can't be targeted or hurt by enemies?
function E.Untouchable(e)
    local b = e.buffs
    return b ~= nil and (b.invuln ~= nil or b.reinc ~= nil or b.bladestorm ~= nil)
end

-- Invisible (Wind Walk): enemies don't notice it.
function E.Hidden(e)
    return e.buffs ~= nil and e.buffs.windwalk ~= nil
end

function E.AddBuff(u, name, t, extra)
    u.buffs = u.buffs or {}
    local b = extra or {}
    b.t = math.max(t, u.buffs[name] and u.buffs[name].t or 0)
    u.buffs[name] = b
end

-- Experience: a level up gives a skill point and more health and mana.
function E.GiveXp(st, u, n)
    u.xp = u.xp + n
    while u.level < 10 and u.xp >= WC.XP_LEVELS[u.level] do
        u.level = u.level + 1
        u.points = u.points + 1
        local hp, mana = u.maxHp, u.maxMana
        u.maxHp, u.maxMana = HeroMaxHp(u), HeroMaxMana(u)
        u.hp = u.hp + (u.maxHp - hp)
        u.mana = u.mana + (u.maxMana - mana)
        E.Emit("levelUp", { id = u.id, owner = u.owner, level = u.level, type = u.type })
    end
end

-- Damage an attacker deals (crits, bash, the Wind Walk hit).
function E.OnHit(st, u, t, dmg)
    local b = u.buffs
    if b and b.windwalk then
        dmg = dmg + b.windwalk.bonus
        b.windwalk = nil
    end
    if not E.IsHero(u) or u.illusion then return dmg end
    local cs = Skill(u, "critical_strike")
    if cs > 0 and E.Rand(st, 100) <= 15 then
        dmg = dmg * At(WC.Abilities.critical_strike.mult, cs)
        E.Emit("crit", { id = u.id, target = t.id, amount = math.floor(dmg) })
    end
    local bash = Skill(u, "bash")
    if bash > 0 and t.kind == "unit" and E.Rand(st, 100) <= At(WC.Abilities.bash.chance, bash) then
        dmg = dmg + 25
        E.AddBuff(t, "stun", E.IsHero(t) and 1 or 2)
        E.Emit("bash", { id = u.id, target = t.id })
    end
    return dmg
end

-- Damage taken: nothing while untouchable, double for a mirror image.
function E.OnTaken(st, t, dmg)
    if E.Untouchable(t) then return 0 end
    if t.illusion then return dmg * 2 end
    return dmg
end

-- About to die: Reincarnation takes over (true: not dead).
function E.OnDying(st, t)
    if not E.IsHero(t) or t.illusion or Skill(t, "reincarnation") == 0 or (t.cds and t.cds.reincarnation) then
        return false
    end
    t.hp = 1
    t.cds = t.cds or {}
    t.cds.reincarnation = WC.Abilities.reincarnation.cd[1]
    t.order, t.path = nil, nil
    E.AddBuff(t, "reinc", WC.Abilities.reincarnation.delay[1])
    E.Emit("reincarnating", { id = t.id, owner = t.owner })
    return true
end

-- Somebody died: experience for the other side's heroes nearby, a corpse
-- for Resurrection, a fallen hero to revive.
function E.OnDeath(st, t)
    if t.kind ~= "unit" or t.summon or t.illusion then return end
    local d = U[t.type]
    local xp = d.hero and (80 + 60 * (t.level or 1)) or (d.food or 1) * 25
    local near = {}
    for p = 1, #st.players do
        if E.Foe(st, p, t.owner) then -- (heroes of the other side learn from it)
            for _, h in ipairs(Heroes(st, p)) do
                local dx, dy = h.x - t.x, h.y - t.y
                if h.level < 10 and dx * dx + dy * dy <= WC.XP_RANGE * WC.XP_RANGE then table.insert(near, h) end
            end
        end
    end
    for _, h in ipairs(near) do E.GiveXp(st, h, math.floor(xp / #near)) end
    if d.hero then
        local pl = st.players[t.owner]
        pl.fallen = pl.fallen or {}
        pl.fallen[t.type] = { level = t.level, xp = t.xp, skills = Copy(t.skills), points = t.points, items = Copy(t.items) }
        E.Emit("heroDied", { id = t.id, owner = t.owner, type = t.type })
    else
        st.corpses = st.corpses or {}
        table.insert(st.corpses, { owner = t.owner, type = t.type, x = t.x, y = t.y, t = st.time })
    end
end

-- Spell damage to everyone of the other side in a circle.
function E.AreaDamage(st, caster, x, y, r, amount, buildingsOnly)
    local hits = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and not e.dead and E.Foe(st, e.owner, caster.owner) and e.kind ~= "mine"
            and (not buildingsOnly or e.kind == "building") then
            local cx, cy = E.Center(e)
            local dx, dy = cx - x, cy - y
            local rr = r + (e.size or 0) / 2
            if dx * dx + dy * dy <= rr * rr then table.insert(hits, e) end
        end
    end
    for _, e in ipairs(hits) do
        if not e.dead then E.Strike(st, caster, e, amount, true, "spell") end
    end
    return hits
end

-- Every step for every unit (true: it does nothing else this step).
function E.UnitTick(st, u, dt)
    if u.expire and st.time >= u.expire then
        E.Emit("expired", { id = u.id, owner = u.owner })
        E.Remove(st, u)
        return true
    end
    local b = u.buffs
    if b then
        local ended = {}
        for name, x in pairs(b) do
            x.t = x.t - dt
            if x.t <= 0 then table.insert(ended, name) end
        end
        table.sort(ended)
        for _, name in ipairs(ended) do
            b[name] = nil
            if name == "avatar" then
                u.maxHp = HeroMaxHp(u)
                u.hp = math.min(u.hp, u.maxHp)
            elseif name == "reinc" then
                u.hp, u.mana = u.maxHp, u.maxMana
                E.Emit("reincarnated", { id = u.id, owner = u.owner })
            end
        end
        if next(b) == nil then u.buffs, b = nil, nil end
    end
    if E.IsHero(u) and not u.illusion then
        u.hp = math.min(u.maxHp, u.hp + (0.25 + 0.05 * E.Stat(u, "str")) * dt)
        u.mana = math.min(u.maxMana, u.mana + (0.05 * E.Stat(u, "int") + E.Aura(st, u, "brilliance")) * dt)
        if u.cds then
            local done = {}
            for k, v in pairs(u.cds) do
                if v - dt <= 0 then table.insert(done, k) else u.cds[k] = v - dt end
            end
            for _, k in ipairs(done) do u.cds[k] = nil end
        end
    end
    if b then
        if b.bladestorm then
            b.bladestorm.acc = (b.bladestorm.acc or 0) + dt
            if b.bladestorm.acc >= 0.5 then
                b.bladestorm.acc = b.bladestorm.acc - 0.5
                E.AreaDamage(st, u, u.x, u.y, WC.Abilities.bladestorm.radius, b.bladestorm.dps * 0.5, false)
            end
        end
        if b.reinc or b.stun then return true end
    end
    if E.ArmyTick and E.ArmyTick(st, u, dt) then return true end
    return false
end

-- Areas that hurt over time (Blizzard, Flame Strike, Earthquake), revealed
-- spots (Far Sight), and old corpses.
function E.WorldTick(st, dt)
    st.heroCache = nil
    if st.zones then
        local keep = {}
        for _, z in ipairs(st.zones) do
            z.acc = (z.acc or 0) + dt
            if z.acc >= 0.5 then
                z.acc = z.acc - 0.5
                local caster = st.ents[z.caster] or { owner = z.owner, id = z.caster, kind = "unit" }
                E.AreaDamage(st, caster, z.x, z.y, z.r, z.dps * 0.5, z.buildings)
                if z.slow then
                    for _, id in ipairs(st.list) do
                        local e = st.ents[id]
                        if e and e.kind == "unit" and E.Foe(st, e.owner, z.owner)
                            and (e.x - z.x) ^ 2 + (e.y - z.y) ^ 2 <= z.r * z.r then
                            E.AddBuff(e, "slow", 1)
                        end
                    end
                end
            end
            if st.time < z.stop then table.insert(keep, z) end
        end
        st.zones = #keep > 0 and keep or nil
    end
    if st.reveals then
        local keep = {}
        for _, r in ipairs(st.reveals) do
            if st.time < r.stop then table.insert(keep, r) end
        end
        st.reveals = #keep > 0 and keep or nil
    end
    if st.corpses then
        local keep = {}
        for _, c in ipairs(st.corpses) do
            if st.time - c.t < 90 then table.insert(keep, c) end
        end
        st.corpses = #keep > 0 and keep or nil
    end
end

local function Summon(st, u, base, lv, n, duration, x, y)
    local utype = U[base .. lv] and (base .. lv) or (base .. "1")
    for i = 1, n do
        local fx, fy = E.NearestFree(st, math.floor(x + (i - 1) * 0.6), math.floor(y + 1))
        if fx then
            local s = E.Spawn(st, u.owner, utype, fx + 0.5, fy + 0.5)
            s.summon = true
            s.expire = st.time + duration
        end
    end
end

-- The spells (range, mana and cooldown already checked).
local CAST = {}
E.CAST = CAST

CAST.holy_light = function(st, u, lv, a, t)
    t.hp = math.min(t.maxHp, t.hp + At(a.amount, lv))
    E.Emit("heal", { id = u.id, target = t.id, amount = At(a.amount, lv) })
end
CAST.divine_shield = function(st, u, lv, a) E.AddBuff(u, "invuln", At(a.duration, lv)) end
CAST.resurrection = function(st, u, lv, a)
    local n, keep = 0, {}
    for _, c in ipairs(st.corpses or {}) do
        local here = c.owner == u.owner and (c.x - u.x) ^ 2 + (c.y - u.y) ^ 2 <= a.radius * a.radius
        local fx, fy
        if here and n < At(a.amount, lv) then fx, fy = E.NearestFree(st, math.floor(c.x), math.floor(c.y)) end
        if fx then
            E.Spawn(st, u.owner, c.type, fx + 0.5, fy + 0.5)
            n = n + 1
        else
            table.insert(keep, c)
        end
    end
    st.corpses = #keep > 0 and keep or nil
end
CAST.blizzard = function(st, u, lv, a, t, x, y)
    st.zones = st.zones or {}
    table.insert(st.zones, { owner = u.owner, caster = u.id, x = x, y = y, r = a.radius, dps = At(a.amount, lv),
        stop = st.time + At(a.duration, lv) })
end
CAST.flame_strike = CAST.blizzard
CAST.earthquake = function(st, u, lv, a, t, x, y)
    st.zones = st.zones or {}
    table.insert(st.zones, { owner = u.owner, caster = u.id, x = x, y = y, r = a.radius, dps = At(a.amount, lv),
        stop = st.time + At(a.duration, lv), buildings = true, slow = true })
end
CAST.water_elemental = function(st, u, lv, a)
    Summon(st, u, a.summon, lv, At(a.count, lv), At(a.duration, lv), u.x, u.y)
end
CAST.feral_spirit = CAST.water_elemental
CAST.phoenix = CAST.water_elemental
CAST.serpent_ward = function(st, u, lv, a, t, x, y)
    Summon(st, u, a.summon, lv, At(a.count, lv), At(a.duration, lv), x, y)
end
CAST.mass_teleport = function(st, u, lv, a, t)
    local tx, ty = E.Center(t)
    local movers = { u }
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e ~= u and e.kind == "unit" and e.owner == u.owner and not e.inside and #movers <= At(a.amount, lv)
            and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= a.radius * a.radius then
            table.insert(movers, e)
        end
    end
    for i, e in ipairs(movers) do
        local fx, fy = E.NearestFree(st, math.floor(tx + (i % 5) - 2), math.floor(ty + (t.size or 1) / 2 + 1 + math.floor(i / 5)))
        if fx then
            e.x, e.y = fx + 0.5, fy + 0.5
            e.order, e.path = nil, nil
        end
    end
end
CAST.storm_bolt = function(st, u, lv, a, t)
    E.Strike(st, u, t, At(a.amount, lv), true, "spell")
    if not t.dead then E.AddBuff(t, "stun", E.IsHero(t) and At(a.heroStun, lv) or At(a.stun, lv)) end
end
CAST.thunder_clap = function(st, u, lv, a)
    for _, e in ipairs(E.AreaDamage(st, u, u.x, u.y, a.radius, At(a.amount, lv), false)) do
        if not e.dead and e.kind == "unit" then E.AddBuff(e, "slow", At(a.slow, lv)) end
    end
end
CAST.avatar = function(st, u, lv, a)
    E.AddBuff(u, "avatar", At(a.duration, lv))
    local before = u.maxHp
    u.maxHp = HeroMaxHp(u)
    u.hp = u.hp + (u.maxHp - before)
end
CAST.banish = function(st, u, lv, a, t)
    E.AddBuff(t, "noAttack", E.IsHero(t) and At(a.heroDuration, lv) or At(a.duration, lv))
end
CAST.siphon_mana = function(st, u, lv, a, t)
    local n = math.min(At(a.amount, lv), t.mana or 0)
    t.mana = (t.mana or 0) - n
    u.mana = math.min(u.maxMana, u.mana + n)
end
CAST.wind_walk = function(st, u, lv, a)
    E.AddBuff(u, "windwalk", At(a.duration, lv), { speed = At(a.speed, lv), bonus = At(a.amount, lv) })
    -- Enemies chasing it lose it.
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and E.Foe(st, e.owner, u.owner) and e.order and e.order.type == "attack" and e.order.target == u.id then
            e.order, e.path = nil, nil
        end
    end
end
CAST.mirror_image = function(st, u, lv, a)
    for i = 1, At(a.count, lv) do
        local fx, fy = E.NearestFree(st, math.floor(u.x + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2)), math.floor(u.y))
        if fx then
            local m = E.Spawn(st, u.owner, u.type, fx + 0.5, fy + 0.5)
            m.illusion, m.expire = true, st.time + At(a.duration, lv)
            m.level, m.skills, m.points, m.cds = u.level, {}, 0, {}
            m.maxHp, m.hp = u.maxHp, u.hp
            m.maxMana, m.mana = 0, 0
        end
    end
end
CAST.bladestorm = function(st, u, lv, a)
    E.AddBuff(u, "bladestorm", At(a.duration, lv), { dps = At(a.amount, lv) })
end
CAST.chain_lightning = function(st, u, lv, a, t)
    local amount, hit, cur = At(a.amount, lv), {}, t
    for _ = 1, At(a.jumps, lv) do
        if not cur then break end
        hit[cur.id] = true
        E.Emit("bolt", { id = u.id, target = cur.id })
        local cx, cy = cur.x, cur.y
        E.Strike(st, u, cur, amount, true, "spell")
        amount = amount * 0.85
        local nxt, nd
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and not e.dead and e.kind == "unit" and E.Foe(st, e.owner, u.owner) and not hit[e.id]
                and not E.Untouchable(e) then
                local d = (e.x - cx) ^ 2 + (e.y - cy) ^ 2
                if d <= 25 and (not nd or d < nd) then nxt, nd = e, d end
            end
        end
        cur = nxt
    end
end
CAST.healing_wave = function(st, u, lv, a, t)
    local amount, hit, cur = At(a.amount, lv), {}, t
    for _ = 1, At(a.jumps, lv) do
        if not cur then break end
        hit[cur.id] = true
        cur.hp = math.min(cur.maxHp, cur.hp + amount)
        E.Emit("heal", { id = u.id, target = cur.id, amount = math.floor(amount) })
        amount = amount * 0.75
        local nxt, worst
        for _, id in ipairs(st.list) do
            local e = st.ents[id]
            if e and e.kind == "unit" and E.Ally(st, e.owner, u.owner) and not hit[e.id] and e.hp < e.maxHp
                and (e.x - cur.x) ^ 2 + (e.y - cur.y) ^ 2 <= 25 then
                local missing = e.maxHp - e.hp
                if not worst or missing > worst then nxt, worst = e, missing end
            end
        end
        cur = nxt
    end
end
CAST.far_sight = function(st, u, lv, a, t, x, y)
    st.reveals = st.reveals or {}
    table.insert(st.reveals, { owner = u.owner, x = x, y = y, r = At(a.radius, lv), stop = st.time + At(a.duration, lv) })
end
CAST.shockwave = function(st, u, lv, a, t, x, y)
    local dx, dy = x - u.x, y - u.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then dx, dy, len = 1, 0, 1 end
    dx, dy = dx / len, dy / len
    local hits = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and E.Foe(st, e.owner, u.owner) then
            local px, py = e.x - u.x, e.y - u.y
            local along = px * dx + py * dy
            local side = math.abs(px * dy - py * dx)
            if along >= 0 and along <= a.length and side <= 1 then table.insert(hits, e) end
        end
    end
    for _, e in ipairs(hits) do E.Strike(st, u, e, At(a.amount, lv), true, "spell") end
end
CAST.war_stomp = function(st, u, lv, a)
    for _, e in ipairs(E.AreaDamage(st, u, u.x, u.y, a.radius, At(a.amount, lv), false)) do
        if not e.dead and e.kind == "unit" then E.AddBuff(e, "stun", E.IsHero(e) and At(a.heroStun, lv) or At(a.stun, lv)) end
    end
end
CAST.hex = function(st, u, lv, a, t)
    E.AddBuff(t, "hex", E.IsHero(t) and At(a.heroDuration, lv) or At(a.duration, lv))
    if t.order and t.order.type == "attack" then t.order, t.path = nil, nil end
end
CAST.big_bad_voodoo = function(st, u, lv, a)
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and E.Ally(st, e.owner, u.owner) and not E.IsHero(e)
            and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= a.radius * a.radius then
            E.AddBuff(e, "invuln", At(a.duration, lv))
        end
    end
end

-- Is this a good target for that ability? (true, or false and why)
function E.ValidTarget(st, u, a, t)
    if not t or t.dead then return false, "no target" end
    local k = a.target
    if k == "enemy" then
        if not E.Foe(st, t.owner, u.owner) or t.kind ~= "unit" then return false, "target an enemy unit" end
        if E.Untouchable(t) then return false, "it can't be touched now" end
        if a == WC.Abilities.siphon_mana and not E.IsHero(t) then return false, "target an enemy hero" end
    elseif k == "ally" then
        if not E.Ally(st, t.owner, u.owner) or t.kind ~= "unit" then return false, "target a friendly unit" end
    elseif k == "unit" then
        if t.kind ~= "unit" then return false, "target a unit" end
    elseif k == "friend" then
        if t.owner ~= u.owner or t.kind == "mine" then return false, "target your own unit or building" end
    end
    return true
end

-- The cast order: walk into range, then cast.
function E.CastStep(st, u, o, dt)
    local a = WC.Abilities[o.ability]
    local lv = Skill(u, o.ability)
    local t = o.target and st.ents[o.target]
    local needsUnit = a.target ~= "self" and a.target ~= "point"
    if lv == 0 or (needsUnit and not E.ValidTarget(st, u, a, t)) then
        u.order, u.path = nil, nil
        return
    end
    local x, y = o.x, o.y
    if t then x, y = E.Center(t) end
    if a.target ~= "self" then
        local gap = t and E.Gap(u, t) or math.sqrt((x - u.x) ^ 2 + (y - u.y) ^ 2)
        if gap > (a.range or 0) then
            if not u.path then
                if t then E.PathTo(st, u, nil, nil, t) else E.PathTo(st, u, x, y) end
            end
            if E.Follow(st, u, dt) then u.path = nil end
            return
        end
    end
    local mana = At(a.mana, lv) or 0
    if (u.mana or 0) < mana or (u.cds and u.cds[o.ability]) then
        u.order, u.path = nil, nil
        return
    end
    u.mana = u.mana - mana
    u.cds = u.cds or {}
    u.cds[o.ability] = At(a.cd, lv)
    u.order, u.path = nil, nil
    if x and (x ~= u.x or y ~= u.y) then u.facing = ATAN2(y - u.y, x - u.x) end
    E.Emit("cast", { id = u.id, owner = u.owner, ability = o.ability, target = t and t.id, x = x, y = y, lv = lv })
    CAST[o.ability](st, u, lv, a, t, x, y)
end

function E.ReviveCost(st, p, utype)
    local f = st.players[p].fallen and st.players[p].fallen[utype]
    local lv = f and f.level or 1
    -- (A mode's heroes can have their own price to come back: reviveCost.)
    return { math.floor((U[utype].reviveCost or U[utype].cost[1]) * math.min(1, 0.4 + 0.1 * lv)), 0 }
end

function E.ReviveTime(st, p, utype)
    local f = st.players[p].fallen and st.players[p].fallen[utype]
    return 15 + 5 * (f and f.level or 1)
end

-- Can player p train this hero now? (true, or false and why)
function E.CanTrainHero(st, p, utype)
    local pl = st.players[p]
    local have = 0
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.owner == p and E.IsHero(e) and not e.illusion then
            have = have + 1
            if e.type == utype then return false, "you have that hero already" end
        end
        if e and e.owner == p and e.kind == "building" then
            for _, q in ipairs(e.queue) do
                local ut = q:match("^v:(.+)$") or q
                if U[ut] and U[ut].hero then
                    have = have + 1
                    if ut == utype then return false, "already training" end
                end
            end
        end
    end
    for ut, f in pairs(pl.fallen or {}) do
        if not f.reviving then have = have + 1 end
        if ut == utype then return false, "revive that hero instead" end
    end
    if have >= WC.HERO_MAX then return false, "at most " .. WC.HERO_MAX .. " heroes" end
    local tier = WC.HERO_TIER[have + 1]
    local need = tier and tier[pl.faction]
    if need and not E.Has(st, p, need) then return false, "requires " .. B[need].name end
    return true
end

-- Hero commands: learn, cast, revive.
function E.HeroCommand(st, p, cmd, mode)
    local t = cmd.type
    if t == "learn" then
        local u = st.ents[cmd.unit]
        if not (u and u.owner == p and E.IsHero(u)) or u.illusion then return false, "not a hero" end
        local a = WC.Abilities[cmd.ability]
        local mine = false
        for _, k in ipairs(U[u.type].abilities) do if k == cmd.ability then mine = true end end
        if not a or not mine then return false, "not this hero's" end
        if (u.points or 0) < 1 then return false, "no skill points" end
        local lv = Skill(u, cmd.ability) + 1
        if a.ult then
            if lv > 1 then return false, "already learned" end
            if u.level < 6 then return false, "needs hero level 6" end
        else
            if lv > 3 then return false, "already at the top level" end
            if u.level < lv * 2 - 1 then return false, "needs hero level " .. (lv * 2 - 1) end
        end
        u.skills[cmd.ability] = lv
        u.points = u.points - 1
        return true
    elseif t == "cast" then
        local u = st.ents[cmd.unit]
        if not (u and u.owner == p and E.IsHero(u)) or u.illusion then return false, "not a hero" end
        local a = WC.Abilities[cmd.ability]
        local lv = a and Skill(u, cmd.ability) or 0
        if lv == 0 then return false, "not learned" end
        if a.passive then return false, "that works by itself" end
        if (u.mana or 0) < (At(a.mana, lv) or 0) then return false, "not enough mana" end
        if u.cds and u.cds[cmd.ability] then return false, "not ready yet" end
        local target = cmd.target and st.ents[cmd.target]
        if a.target == "point" then
            if not cmd.x then return false, "pick a spot" end
        elseif a.target ~= "self" then
            local ok, why = E.ValidTarget(st, u, a, target)
            if not ok then return false, why end
        end
        E.Order(st, u, { type = "cast", ability = cmd.ability, target = target and target.id, x = cmd.x, y = cmd.y }, mode)
        return true
    elseif t == "revive" then
        local b = st.ents[cmd.building]
        local pl = st.players[p]
        local f = pl.fallen and pl.fallen[cmd.utype]
        if not (b and b.owner == p and b.kind == "building" and b.progress >= 1) or not f or f.reviving then
            return false, "nobody to revive"
        end
        local ok = false
        for _, ut in ipairs(E.Def(b).trains or {}) do if ut == cmd.utype then ok = true end end
        if not ok then return false, "not at this altar" end
        if #b.queue >= 5 then return false, "the queue is full" end
        local cost = E.ReviveCost(st, p, cmd.utype)
        if not E.CanAfford(st, p, cost) then return false, "not enough gold or lumber" end
        pl.gold, pl.lumber = pl.gold - cost[1], pl.lumber - cost[2]
        f.reviving = true
        table.insert(b.queue, "v:" .. cmd.utype)
        return true
    end
    return false, "unknown command"
end
