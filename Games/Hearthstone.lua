-- Hearthstone: an Arcade card game, against the computer (solo) or another
-- player (PvP), on the rules engine in Games\Hearthstone\ (cards, heroes,
-- engine, AI) and the board in UI\HearthstonePage.lua.
--
-- PvP is a lobby like the other Arcade games (Session). The host runs the
-- engine (s._st, never sent). Everyone gets the public view (both hands
-- hidden, decks as counts) and the public events; each player gets their
-- own hand by whisper (like poker hole cards). Moves go to the host, which
-- checks them with the same rules as against the computer.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "hearthstone",
    arcade = true,
    section = "blizzard", -- the home page's Blizzard Games section
    solo = true,
    name = "Hearthstone 2",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconHearthstone",
    short = "The card game: pick a hero, play minions and spells, beat the computer or a friend.",
    how = "Click a card to play it, click a minion then a target to attack. Right-click cancels.",
    rules = "Bring the enemy hero from 30 Health to 0 with minions, spells and your hero power. "
        .. "Play the computer, or a friend from your group, guild or realm.",
    scoreLabel = "Wins",
    window = { 760, 560 }, -- the main window grows for this game
    fullscreen = true, -- offers a Fullscreen button
    fields = {},
    -- PvP lobbies
    minPlayers = 2,
    maxPlayers = 2,
    practiceBots = 1,
    afterGame = { rematch = true },
    dropText = "The game waits for them, or you can close the lobby.",
}
ns.Games.hearthstone = G

G.TURN_TIME = 75 -- seconds a turn may take in PvP (then it ends by itself)

local function E() return ns.HS.Engine end

---------------------------------------------------------------------------
-- Actions as text: "type,card,target,pos,attacker"
---------------------------------------------------------------------------
function G.EncodeAction(a)
    return table.concat({ a.type, a.card or "", a.target or "", a.pos or "", a.attacker or "" }, ",")
end

function G.DecodeAction(text)
    local t, card, target, pos, attacker = text:match("^(%a+),(%d*),(%d*),(%d*),(%d*)$")
    if not t then return nil end
    return { type = t, card = tonumber(card), target = tonumber(target), pos = tonumber(pos),
        attacker = tonumber(attacker) }
end

---------------------------------------------------------------------------
-- The host's side
---------------------------------------------------------------------------
function G:Setup(s) end

-- Your chair (1 or 2) in this game.
function G.Seat(s, name)
    return s.seat and s.seat[name]
end

-- Events everyone may see: the cards drawn are hidden.
local function Public(events)
    local out = {}
    for i, ev in ipairs(events or {}) do
        local c = {}
        for k, v in pairs(ev) do c[k] = v end
        if c.kind == "draw" then c.key = nil end
        out[i] = c
    end
    return out
end

local function Hand(st, i)
    local out = {}
    for j, c in ipairs(st.players[i].hand) do out[j] = { id = c.id, key = c.key } end
    return out
end

-- After every change: the public view, each player's hand, the turn timer,
-- and the result when it's over.
local function Publish(s, events)
    local st = s._st
    s.view = E().View(st, 0)
    s.events = Public(events)
    s.step = (s.step or 0) + 1
    if s.turnNo ~= st.turn then
        s.turnNo = st.turn
        s.turnStart = ns.Now()
        local no, kind = st.turn, s.kind
        ns.After(G.TURN_TIME + 0.5, function()
            local cur = ns.Session.Get(kind)
            if cur == s and s.phase == "rolling" and s.stage == "play" and s.turnNo == no then
                ns.Session.Act(kind, "timeout:" .. no)
            end
        end)
    end
    for _, p in ipairs(s.players) do
        if not p.bot then ns.Session.SendPrivate(s, p.name, Hand(st, s.seat[p.name])) end
    end
    if st.over then
        s.phase, s.stage = "done", "over"
        local winner = st.winner ~= 0 and s.players[st.winner] and s.players[st.winner].name or nil
        local loser = st.winner ~= 0 and s.players[3 - st.winner] and s.players[3 - st.winner].name or nil
        if winner then
            s.score[winner] = (s.score[winner] or 0) + 1
            s.result = { winner = winner, loser = loser, summary = "Hearthstone 2, " .. winner .. " won" }
            s.banner = winner .. " wins!"
        else
            s.result = { summary = "Hearthstone 2, a draw" }
            s.banner = "A draw."
        end
    end
end

local function NewGame(s)
    s.games = (s.games or 0) + 1
    s.recordId = s.id .. ":" .. s.games
    s.hand = s.recordId -- private hands are per game
    local d1, d2 = s._decks[s.players[1].name], s._decks[s.players[2].name]
    local st, events = E().New({ heroes = { d1.hero, d2.hero }, decks = { d1.cards or false, d2.cards or false },
        seed = math.random(1, 2000000000), mulligan = true })
    s._st = st
    s.stage = "play"
    s.result = nil
    s.turnNo = nil
    s.missed = { 0, 0 }
    Publish(s, events)
    s.banner = s.players[st.active].name .. " goes first."
end

function G:Begin(s)
    s.score = s.score or {}
    s.seat = {}
    for i, p in ipairs(s.players) do
        s.seat[p.name] = i
        s.score[p.name] = s.score[p.name] or 0
    end
    s.stage = "decks"
    s.chosen = {}
    s._decks = {}
    s.view, s.events, s.result = nil, nil, nil
    s.banner = "Choose your hero and deck."
end

function G:Expect() return nil end

function G:IsTurn(s, name)
    if s.phase ~= "rolling" then return false end
    if s.stage == "decks" then return s.chosen ~= nil and not s.chosen[name] end
    if s.stage ~= "play" or not s.view or s.view.over then return false end
    local seat = G.Seat(s, name)
    if E().Mulliganing(s.view) then return seat ~= nil and s.view.players[seat].mulligan == true end
    return s.view.active == seat
end

function G:Act(s, name, action)
    local verb, arg = action:match("^(%a+):?(.*)$")
    if verb == "rematch" then
        if name ~= s.host or s.phase ~= "done" then return false end
        s.phase = "rolling"
        self:Begin(s)
        return true
    end
    local seat = G.Seat(s, name)
    if not seat or s.phase ~= "rolling" then return false end
    if verb == "deck" then
        if s.stage ~= "decks" or s.chosen[name] then return false end
        local hero, list = arg:match("^(%a+):?(.*)$")
        if not hero or not ns.HS.Heroes[hero] then return false end
        local cards
        if list ~= "" then
            cards = {}
            for key in list:gmatch("[^,]+") do table.insert(cards, key) end
            if not ns.HS.CheckDeck(hero, cards) then return false, "that deck isn't allowed" end
        end
        s.chosen[name] = hero
        s._decks[name] = { hero = hero, cards = cards }
        s.banner = name .. " is ready."
        for _, p in ipairs(s.players) do
            if not s.chosen[p.name] then return true end
        end
        NewGame(s)
        return true
    elseif verb == "mull" then
        if s.stage ~= "play" then return false end
        local ids = {}
        for id in arg:gmatch("%d+") do table.insert(ids, tonumber(id)) end
        local ok, events = E().Mulligan(s._st, seat, ids)
        if not ok then return false, events end
        Publish(s, events)
        return true
    elseif verb == "do" then
        if s.stage ~= "play" or s._st.active ~= seat then return false end
        local a = G.DecodeAction(arg)
        if not a then return false end
        local ok, events = E().Apply(s._st, a)
        if not ok then return false, events end
        s.missed[seat] = 0
        Publish(s, events)
        return true
    elseif verb == "timeout" then
        -- The host's clock: the turn took too long, it ends. Choosing opening
        -- cards too long keeps them. Two missed turns in a row lose the game
        -- (someone who went away or lost their connection).
        if name ~= s.host or s.stage ~= "play" or tonumber(arg) ~= s.turnNo then return false end
        local st, events = s._st, {}
        if E().Mulliganing(st) then
            for i = 1, 2 do
                if st.players[i].mulligan then
                    local _, ev = E().Mulligan(st, i, {})
                    for _, e in ipairs(ev or {}) do table.insert(events, e) end
                end
            end
        else
            local idle = st.active
            s.missed[idle] = (s.missed[idle] or 0) + 1
            if s.missed[idle] >= 2 then
                st.over, st.winner = true, 3 - idle
                Publish(s, { { kind = "over", winner = 3 - idle } })
                s.banner = s.players[idle].name .. " missed two turns and loses."
                return true
            end
            local ok
            ok, events = E().Apply(st, { type = "end" })
            if not ok then return false end
        end
        Publish(s, events)
        return true
    elseif verb == "concede" then
        if s.stage ~= "play" then return false end
        s._st.over, s._st.winner = true, 3 - seat
        Publish(s, { { kind = "over", winner = 3 - seat } })
        s.banner = name .. " conceded."
        return true
    end
    return false
end

-- The host skipped a player who went offline (group lobbies): they lose.
function G:Drop(s, name)
    local seat = G.Seat(s, name)
    if s.stage ~= "play" or not seat or not s._st or s._st.over then return end
    s._st.over, s._st.winner = true, 3 - seat
    Publish(s, { { kind = "over", winner = 3 - seat } })
    s.banner = name .. " left; the game is over."
end

-- Practice bot: a random hero with its basic deck, then the computer's moves.
function G:BotAct(s, name)
    local seat = G.Seat(s, name)
    if s.stage == "play" and s._st and s._st.players[seat].mulligan then
        return "mull:" .. table.concat(ns.HS.AI.Mulligan(s._st, seat), ",")
    end
    if s.stage == "decks" then
        local heroes = {}
        for key in pairs(ns.HS.Heroes) do table.insert(heroes, key) end
        table.sort(heroes)
        return "deck:" .. heroes[math.random(#heroes)]
    end
    return "do:" .. G.EncodeAction(ns.HS.AI.Choose(s._st))
end

function G:Status(s)
    if s.phase == "lobby" then return #s.players < 2 and "Waiting for an opponent" or "Ready to start" end
    if s.stage == "decks" then return "Choosing decks" end
    if s.stage == "play" and s.view then
        local p = s.players[s.view.active]
        return p and (p.name .. "'s turn") or nil
    end
end

function G:RangeText() return nil end
function G:RollText() return "" end
