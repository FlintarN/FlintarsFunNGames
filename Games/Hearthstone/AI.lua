-- Hearthstone AI. It knows no cards: it tries every legal action on a copy
-- of the game and keeps the one that leaves the best-looking board, so new
-- cards and heroes need no AI changes. Actions that look like nothing on
-- their own (The Coin, Bloodlust, Rockbiter) get one more step of lookahead.
local ADDON, ns = ...

ns.HS = ns.HS or {}
local AI = {}
ns.HS.AI = AI

local function E() return ns.HS.Engine end

local function HeroValue(h)
    local hp = h.health + (h.armor or 0)
    -- Low health matters more.
    return hp + math.max(0, 12 - hp) * 0.8
end

local function MinionValue(m)
    local c = E().Card(m.key)
    local atk = (m.attack or 0) + (m.auraAttack or 0) -- not "this turn" buffs
    local v = atk + m.health + 0.5
    if m.taunt then v = v + 1.5 end
    if m.divineShield then v = v + atk * 0.8 + 0.5 end
    if m.windfury then v = v + atk * 0.5 end
    if c.spellDamage then v = v + 1.5 * c.spellDamage end
    if c.aura then v = v + 2 end
    if c.endTurn then v = v + 1.5 end
    if m.frozen then v = v - atk * 0.4 end
    return v
end

-- How good `st` looks for player `me` (higher is better).
function AI.Score(st, me)
    if st.over then
        if st.winner == me then return 1e6 end
        if st.winner == 0 then return -1e5 end
        return -1e6
    end
    local p, o = st.players[me], st.players[3 - me]
    local s = HeroValue(p.hero) - HeroValue(o.hero) * 1.1
    local function Value(m) return MinionValue(m) * (m.doomedBy and 0.15 or 1) end
    local function Weapon(h) return h.weapon and (h.weapon.attack * h.weapon.durability * 0.6 + 0.5) or 0 end
    for _, m in ipairs(p.board) do s = s + Value(m) end
    for _, m in ipairs(o.board) do s = s - Value(m) * 1.05 end
    s = s + Weapon(p.hero) - Weapon(o.hero)
    s = s + #p.hand * 1.2 - #o.hand * 1.2
    return s
end

local function Try(st, action)
    local copy = E().Copy(st)
    local ok = E().Apply(copy, action)
    if not ok then return nil end
    return copy
end

-- The best action for the active player (an "end" when nothing helps).
function AI.Choose(st)
    local me = st.active
    local base = AI.Score(st, me)
    local best, bestScore = { type = "end" }, base + 0.01
    for _, a in ipairs(E().Legal(st)) do
        if a.type ~= "end" then
            local after = Try(st, a)
            if after then
                local score = AI.Score(after, me)
                -- Nothing gained yet: is there a good follow-up this turn?
                if score <= base and after.active == me and not after.over then
                    for _, b in ipairs(E().Legal(after)) do
                        if b.type ~= "end" then
                            local after2 = Try(after, b)
                            if after2 then
                                local s2 = AI.Score(after2, me) - 0.05
                                if s2 > score then score = s2 end
                            end
                        end
                    end
                end
                if score > bestScore then best, bestScore = a, score end
            end
        end
    end
    return best
end

-- Which opening cards to swap: the expensive ones (more than 3 mana), like
-- a player looking for an early curve.
function AI.Mulligan(st, i)
    local ids = {}
    for _, c in ipairs(st.players[i].hand) do
        local card = E().Card(c.key)
        if card and card.cost > 3 then table.insert(ids, c.id) end
    end
    return ids
end

-- Play a whole turn (tests and bot-vs-bot): returns every event.
function AI.PlayTurn(st, limit)
    local me = st.active
    local all = {}
    for _ = 1, limit or 40 do
        if st.over or st.active ~= me then break end
        local a = AI.Choose(st)
        local ok, events = E().Apply(st, a)
        if not ok then E().Apply(st, { type = "end" }) break end
        for _, ev in ipairs(events) do table.insert(all, ev) end
        if a.type == "end" then break end
    end
    if not st.over and st.active == me then E().Apply(st, { type = "end" }) end
    return all
end
