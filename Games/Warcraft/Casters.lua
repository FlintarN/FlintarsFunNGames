-- Warcraft 4 casters: the spells of the Priest, Sorceress, Shaman, Witch
-- Doctor, Raider and Footman, as in Warcraft III. You cast them yourself (the
-- command card; they walk into range like heroes do), and spells with
-- autocast cast themselves while it's on (right-click the button to switch).
-- The computer's casters use every spell they know by themselves.
--
-- A caster's spells are its unit's `spells` list; it knows them all at
-- level 1 (E.Skill), so casting goes through the heroes' path (HeroRules:
-- the cast command, CastStep, E.CAST).
local ADDON, ns = ...

local WC = ns.WC
local E = WC.Engine
local U, A = WC.Units, WC.Abilities
local I = "Interface\\Icons\\"
local CAST = E.CAST

---------------------------------------------------------------------------
-- The spells (Warcraft III numbers; our ranges are in tiles)
---------------------------------------------------------------------------
A.heal = { name = "Heal", hotkey = "E", icon = I .. "Spell_Holy_Heal", target = "ally", range = 6, mana = { 5 }, cd = { 1 },
    amount = { 25 }, autocast = true, text = "Heals a friendly unit for 25. Autocast: right-click." }
A.dispel = { name = "Dispel Magic", hotkey = "D", icon = I .. "Spell_Holy_DispelMagic", target = "point", range = 7,
    radius = 2.5, mana = { 75 }, cd = { 1 }, text = "Removes all spells from units in an area; summoned units take 200 damage." }
A.inner_fire = { name = "Inner Fire", hotkey = "F", icon = I .. "Spell_Holy_InnerFire", target = "ally", range = 7,
    mana = { 35 }, cd = { 1 }, duration = { 60 }, autocast = true,
    text = "A friendly unit deals 10% more damage and gets 5 armour for 60 seconds." }
A.slow = { name = "Slow", hotkey = "W", icon = I .. "Spell_Nature_Slow", target = "enemy", range = 7, mana = { 50 }, cd = { 1 },
    duration = { 60 }, heroDuration = { 10 }, autocast = true, text = "An enemy moves and attacks more slowly (heroes for 10 seconds)." }
A.invisibility = { name = "Invisibility", hotkey = "V", icon = I .. "Ability_Mage_Invisibility", target = "ally", range = 7,
    mana = { 50 }, cd = { 1 }, duration = { 120 }, text = "A friendly unit can't be seen for 2 minutes, until it attacks." }
A.polymorph = { name = "Polymorph", hotkey = "O", icon = I .. "Spell_Nature_Polymorph", target = "enemy", range = 6,
    mana = { 200 }, cd = { 1 }, duration = { 60 }, notHero = true, text = "Turns an enemy (not a hero) into a sheep for 60 seconds." }
A.purge = { name = "Purge", hotkey = "G", icon = I .. "Spell_Nature_Purge", target = "unit", range = 6, mana = { 75 }, cd = { 5 },
    duration = { 5 }, text = "Removes all spells from a unit; an enemy is slowed a lot for a while. Destroys summoned units." }
A.lightning_shield = { name = "Lightning Shield", hotkey = "L", icon = I .. "Spell_Nature_LightningShield", target = "unit",
    range = 6, mana = { 100 }, cd = { 1 }, duration = { 20 },
    text = "Lightning round a unit for 20 seconds: 20 damage a second to everyone next to it." }
A.bloodlust = { name = "Bloodlust", hotkey = "B", icon = I .. "Spell_Nature_BloodLust", target = "ally", range = 7, mana = { 40 },
    cd = { 1 }, duration = { 60 }, autocast = true, text = "A friendly unit attacks 40% and moves 25% faster for 60 seconds." }
A.sentry_ward = { name = "Sentry Ward", hotkey = "W", icon = I .. "Spell_Nature_RemoveCurse", target = "point", range = 8,
    mana = { 50 }, cd = { 1 }, text = "An invisible ward that sees far, for 10 minutes." }
A.stasis_trap = { name = "Stasis Trap", hotkey = "T", icon = I .. "Spell_Nature_StrangleVines", target = "point", range = 4,
    mana = { 100 }, cd = { 12 }, text = "An invisible trap: when an enemy comes near, everyone round it is stunned (5 seconds, heroes 2)." }
A.healing_ward_spell = { name = "Healing Ward", hotkey = "E", icon = I .. "Spell_Nature_HealingWaveLesser", target = "point",
    range = 5, mana = { 100 }, cd = { 1 }, duration = { 45 }, autocast = true,
    text = "A ward that heals friendly units nearby 2% a second for 45 seconds." }
A.ensnare = { name = "Ensnare", hotkey = "E", icon = I .. "Spell_Nature_Web", target = "enemy", range = 5, mana = { 0 },
    cd = { 16 }, duration = { 12 }, heroDuration = { 3.5 },
    text = "Nets an enemy: it can't move, and a flyer is pulled down (melee can hit it). 12 seconds, heroes 3.5." }
A.defend = { name = "Defend", hotkey = "D", icon = I .. "Ability_Defend", target = "toggle",
    text = "Half damage from piercing attacks (arrows, guns), but 30% slower. Click again to stop." }

U.priest.spells = { "heal", "dispel", "inner_fire" }
U.sorceress.spells = { "slow", "invisibility", "polymorph" }
U.shaman.spells = { "purge", "lightning_shield", "bloodlust" }
U.witch_doctor.spells = { "sentry_ward", "stasis_trap", "healing_ward_spell" }
U.raider.spells = { "ensnare" }
U.footman.spells = { "defend" }
for _, k in ipairs({ "priest", "sorceress", "shaman", "witch_doctor" }) do U[k].autocast = nil end

-- Wards: they don't move or fight; enemies can't see them.
U.sentry_ward = { name = "Sentry Ward", npc = 3968, hp = 50, armor = 0, damage = 0, cooldown = 1, range = 0, speed = 0,
    cost = { 0, 0 }, time = 0, food = 0, summon = true, noAttack = true, invisible = true, sight = 10,
    attackType = "normal", armorType = "medium", icon = I .. "Spell_Nature_RemoveCurse" }
U.stasis_trap = { name = "Stasis Trap", npc = 2630, hp = 100, armor = 0, damage = 0, cooldown = 1, range = 0, speed = 0,
    cost = { 0, 0 }, time = 0, food = 0, summon = true, noAttack = true, invisible = true, sight = 3,
    attackType = "normal", armorType = "medium", icon = I .. "Spell_Nature_StrangleVines" }

-- A caster knows its spells (at level 1); heroes learn theirs.
local Skill = E.Skill
function E.Skill(u, key)
    local n = Skill(u, key)
    if n > 0 then return n end
    local d = U[u.type]
    for _, k in ipairs(d and d.spells or {}) do
        if k == key then return 1 end
    end
    return 0
end

-- Buffs that a dispel or purge takes away (not death's or invulnerability's).
local KEEP = { reinc = true, invuln = true, stun = true }
local function Strip(t)
    if not t.buffs then return end
    for k in pairs(t.buffs) do
        if not KEEP[k] then t.buffs[k] = nil end
    end
    if not next(t.buffs) then t.buffs = nil end
end

local function Summon(st, u, utype, x, y, life)
    local fx, fy = E.NearestFree(st, math.floor(x), math.floor(y))
    if not fx then return end
    local w = E.Spawn(st, u.owner, utype, fx + 0.5, fy + 0.5)
    w.summon = true
    if life then w.expire = st.time + life end
    return w
end

---------------------------------------------------------------------------
-- What each spell does (lv is 1 for casters)
---------------------------------------------------------------------------
CAST.heal = function(st, u, lv, a, t)
    t.hp = math.min(t.maxHp, t.hp + a.amount[1])
    E.Emit("heal", { id = u.id, target = t.id, amount = a.amount[1] })
end
CAST.dispel = function(st, u, lv, a, t, x, y)
    local hit = {}
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and (e.x - x) ^ 2 + (e.y - y) ^ 2 <= a.radius * a.radius then
            table.insert(hit, e)
        end
    end
    for _, e in ipairs(hit) do
        Strip(e)
        if e.summon and e.expire and E.Foe(st, e.owner, u.owner) then E.Strike(st, u, e, 200, false, "spell") end
    end
end
CAST.inner_fire = function(st, u, lv, a, t) E.AddBuff(t, "innerFire", a.duration[1]) end
CAST.slow = function(st, u, lv, a, t) E.AddBuff(t, "slow", E.IsHero(t) and a.heroDuration[1] or a.duration[1]) end
CAST.invisibility = function(st, u, lv, a, t) E.AddBuff(t, "invis", a.duration[1]) end
CAST.polymorph = function(st, u, lv, a, t) E.AddBuff(t, "hex", a.duration[1]) end
CAST.purge = function(st, u, lv, a, t)
    Strip(t)
    if t.summon and t.expire then
        E.Strike(st, u, t, t.hp + 1, false, "spell")
    elseif E.Foe(st, t.owner, u.owner) then
        E.AddBuff(t, "purged", a.duration[1])
    end
end
CAST.lightning_shield = function(st, u, lv, a, t) E.AddBuff(t, "lshield", a.duration[1], { by = u.id }) end
CAST.bloodlust = function(st, u, lv, a, t) E.AddBuff(t, "bloodlust", a.duration[1]) end
CAST.sentry_ward = function(st, u, lv, a, t, x, y) Summon(st, u, "sentry_ward", x, y, 600) end
CAST.stasis_trap = function(st, u, lv, a, t, x, y) Summon(st, u, "stasis_trap", x, y, 300) end
CAST.healing_ward_spell = function(st, u, lv, a, t, x, y) Summon(st, u, "healing_ward", x, y, a.duration[1]) end
CAST.ensnare = function(st, u, lv, a, t) E.AddBuff(t, "ensnare", E.IsHero(t) and a.heroDuration[1] or a.duration[1]) end

-- A spell that needs a target: the right kind? (adds Polymorph's "not a hero")
local Valid = E.ValidTarget
function E.ValidTarget(st, u, a, t)
    local ok, why = Valid(st, u, a, t)
    if not ok then return ok, why end
    if a.notHero and E.IsHero(t) then return false, "not on a hero" end
    return true
end

---------------------------------------------------------------------------
-- By themselves: who to cast on (nil: nobody good now)
---------------------------------------------------------------------------
-- The best unit within r by want(e) (nil: not wanted); the nearer one on a tie.
local function Near(st, u, r, want)
    local best, bv, bd
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        local d = e and e.kind == "unit" and not e.dead and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2
        if d and d <= r * r then
            local v = want(e)
            if v and (not bv or v > bv or (v == bv and d < bd)) then best, bv, bd = e, v, d end
        end
    end
    return best
end
local function Foe(st, u, e) return E.Foe(st, e.owner, u.owner) and not (E.Hidden(e) or E.Untouchable(e)) end
local function Fighting(st, u) return Near(st, u, 10, function(e) return Foe(st, u, e) and 1 or nil end) ~= nil end
local function Fighter(e) return not U[e.type].worker and not U[e.type].summon and U[e.type].damage > 0 end

local AUTO = {}
E.AUTO = AUTO
AUTO.heal = function(st, u, a)
    return Near(st, u, a.range, function(e)
        local miss = e.maxHp - e.hp
        return E.Ally(st, e.owner, u.owner) and miss >= 25 and not U[e.type].summon and miss or nil
    end)
end
AUTO.inner_fire = function(st, u, a)
    if not Fighting(st, u) then return end
    return Near(st, u, a.range, function(e)
        return E.Ally(st, e.owner, u.owner) and not (e.buffs and e.buffs.innerFire) and Fighter(e) and e.maxHp or nil
    end)
end
AUTO.slow = function(st, u, a)
    return Near(st, u, a.range, function(e)
        return Foe(st, u, e) and not (e.buffs and e.buffs.slow) and (E.IsHero(e) and 2 or 1) or nil
    end)
end
AUTO.bloodlust = function(st, u, a)
    if not Fighting(st, u) then return end
    return Near(st, u, a.range, function(e)
        return E.Ally(st, e.owner, u.owner) and not (e.buffs and e.buffs.bloodlust) and Fighter(e) and e.maxHp or nil
    end)
end
AUTO.healing_ward_spell = function(st, u, a)
    local hurt, ward = 0, false
    for _, id in ipairs(st.list) do
        local e = st.ents[id]
        if e and e.kind == "unit" and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 36 then
            if E.Ally(st, e.owner, u.owner) and e.hp < e.maxHp * 0.7 then hurt = hurt + 1 end
            if e.type == "healing_ward" and e.owner == u.owner then ward = true end
        end
    end
    if hurt >= 2 and not ward then return { x = u.x, y = u.y + 1 } end
end
-- (The computer's casters only: these are click-to-cast for you.)
AUTO.polymorph = function(st, u, a)
    return Near(st, u, a.range, function(e)
        return Foe(st, u, e) and not E.IsHero(e) and not U[e.type].summon and not (e.buffs and e.buffs.hex)
            and e.maxHp >= 500 and e.maxHp or nil
    end)
end
AUTO.purge = function(st, u, a)
    return Near(st, u, a.range, function(e)
        if not Foe(st, u, e) then return nil end
        if e.summon and e.expire then return 3 end
        return (e.buffs and (e.buffs.bloodlust or e.buffs.innerFire or e.buffs.avatar)) and 2 or nil
    end)
end
AUTO.lightning_shield = function(st, u, a)
    if not Fighting(st, u) then return end
    return Near(st, u, a.range, function(e)
        if not (E.Ally(st, e.owner, u.owner) and Fighter(e) and U[e.type].range <= 1.5) or (e.buffs and e.buffs.lshield) then
            return nil
        end
        return Near(st, e, 2, function(f) return Foe(st, u, f) and 1 or nil end) and e.maxHp or nil
    end)
end
AUTO.ensnare = function(st, u, a)
    return Near(st, u, a.range, function(e)
        return Foe(st, u, e) and not (e.buffs and e.buffs.ensnare) and (U[e.type].air and 3 or (E.IsHero(e) and 2 or nil))
    end)
end
AUTO.dispel = function(st, u, a)
    local s = Near(st, u, a.range, function(e) return Foe(st, u, e) and e.summon and e.expire and 1 or nil end)
    if s then return { x = s.x, y = s.y } end
end

-- Is autocast on for this unit's spell? (the computer: always, if it can)
function E.AutoOn(st, u, key)
    if not AUTO[key] then return false end
    if st.ai and st.ai[u.owner] then return true end
    local a = A[key]
    if u.auto and u.auto[key] ~= nil then return u.auto[key] end
    return a.autocast == true
end

-- Every step for a caster: cast what's on by itself (once a second), and
-- run its wards and traps; Lightning Shield burns its neighbours.
function E.CasterTick(st, u, dt)
    local d = U[u.type]
    if u.type == "stasis_trap" then
        u.checkT = (u.checkT or 0) + dt
        if u.checkT < 0.25 then return true end
        u.checkT = 0
        local near = Near(st, u, 2, function(e)
            return E.Foe(st, e.owner, u.owner) and not U[e.type].air and not U[e.type].summon and 1 or nil
        end)
        if near then
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e.kind == "unit" and E.Foe(st, e.owner, u.owner) and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 16 then
                    E.AddBuff(e, "stun", E.IsHero(e) and 2 or 5)
                end
            end
            E.Emit("cast", { id = u.id, owner = u.owner, ability = "stasis_trap", x = u.x, y = u.y })
            u.hp = 0
            E.Strike(st, u, u, 1, false, "spell")
        end
        return true
    end
    if u.buffs and u.buffs.lshield then
        u.shieldT = (u.shieldT or 0) + dt
        if u.shieldT >= 0.5 then
            u.shieldT = u.shieldT - 0.5
            local hit = {}
            for _, id in ipairs(st.list) do
                local e = st.ents[id]
                if e and e ~= u and e.kind == "unit" and not e.dead and (e.x - u.x) ^ 2 + (e.y - u.y) ^ 2 <= 1.6 * 1.6 then
                    table.insert(hit, e)
                end
            end
            for _, e in ipairs(hit) do E.Strike(st, u, e, 10, false, "spell") end
        end
    end
    if not d.spells or st.peace or E.CantAttack(u) or u.order and u.order.type == "cast" then return false end
    u.castT = (u.castT or 0) - dt
    if u.castT > 0 then return false end
    u.castT = 1
    for _, key in ipairs(d.spells) do
        local a = A[key]
        if E.AutoOn(st, u, key) and (u.mana or 0) >= ((a.mana and a.mana[1]) or 0) and not (u.cds and u.cds[key]) then
            local t = AUTO[key](st, u, a)
            if t then
                local cmd = { type = "cast", unit = u.id, ability = key }
                if t.id then cmd.target = t.id else cmd.x, cmd.y = t.x, t.y end
                if a.target == "point" and t.id then cmd.x, cmd.y, cmd.target = t.x, t.y, nil end
                if E.Command(st, u.owner, cmd) then return false end
            end
        end
    end
    return false
end

-- Commands: switch a spell's autocast; Defend on or off.
function E.CasterCommand(st, p, cmd)
    if cmd.type == "autocast" then
        local a = A[cmd.ability]
        if not (a and AUTO[cmd.ability]) then return false end
        local n = 0
        for _, id in ipairs(cmd.units or {}) do
            local u = st.ents[id]
            if u and u.owner == p and E.Skill(u, cmd.ability) > 0 then
                u.auto = u.auto or {}
                u.auto[cmd.ability] = cmd.on and true or false
                n = n + 1
            end
        end
        return n > 0
    elseif cmd.type == "defend" then
        local n = 0
        for _, id in ipairs(cmd.units or {}) do
            local u = st.ents[id]
            if u and u.owner == p and E.Skill(u, "defend") > 0 then
                u.defend = cmd.on and true or nil
                n = n + 1
            end
        end
        return n > 0
    end
end

do
    local Command = E.Command
    function E.Command(st, p, cmd)
        if type(cmd) == "table" and (cmd.type == "autocast" or cmd.type == "defend") then
            return E.CasterCommand(st, p, cmd)
        end
        return Command(st, p, cmd)
    end
end
