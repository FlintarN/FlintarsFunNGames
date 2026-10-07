-- Warcraft III: a real-time strategy game, against the computer (solo) or
-- another player (PvP), on the engine in Games\Warcraft\ (data, engine, AI)
-- and the page in UI\WarcraftPage.lua.
--
-- PvP is a lobby like the other Arcade games (Session) for the setup: both
-- pick a race, the host deals a seed. Then both clients run the same
-- deterministic engine in lockstep (Core\Lockstep.lua): only commands
-- travel, whispered between the two players. The session only hears about
-- the end (who won, or that the games drifted apart).
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "warcraft",
    arcade = true,
    solo = true,
    name = "Warcraft III",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconWarcraft",
    short = "Real-time strategy: gather gold and lumber, build a base, crush the enemy.",
    how = "Left-click or drag to select, right-click to move, attack or gather. A attacks, S stops.",
    rules = "Gather gold and lumber, build farms and barracks, train an army and destroy every enemy building. "
        .. "Play the computer, or a friend from your group, guild or realm.",
    scoreLabel = "Wins",
    window = { 760, 560 },
    fullscreen = true, -- offers a Fullscreen button
    fields = {},
    -- PvP lobbies
    minPlayers = 2,
    maxPlayers = 2,
    practiceBots = 1,
    afterGame = { rematch = true },
    dropText = "The game waits for them, or you can close the lobby.",
}
ns.Games.warcraft = G

function G:Setup(s) end

function G.Seat(s, name)
    for i, p in ipairs(s.players) do
        if p.name == name then return i end
    end
end

function G:Begin(s)
    s.score = s.score or {}
    for _, p in ipairs(s.players) do s.score[p.name] = s.score[p.name] or 0 end
    s.stage = "races"
    s.races = {}
    s.result = nil
    s.banner = "Choose your race."
end

function G:Expect() return nil end

function G:IsTurn(s, name)
    return s.phase == "rolling" and s.stage == "races" and s.races ~= nil and not s.races[name]
end

local function Finish(s, winner, loser, summary)
    s.phase, s.stage = "done", "over"
    if winner then
        s.score[winner] = (s.score[winner] or 0) + 1
        s.result = { winner = winner, loser = loser, summary = summary or ("Warcraft III, " .. winner .. " won") }
        s.banner = winner .. " wins!"
    else
        s.result = { summary = summary or "Warcraft III, no winner" }
        s.banner = summary or "No winner."
    end
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
    if verb == "race" then
        if s.stage ~= "races" or s.races[name] or not ns.WC.Factions[arg] then return false end
        s.races[name] = arg
        s.banner = name .. " plays " .. ns.WC.Factions[arg].name .. "."
        for _, p in ipairs(s.players) do
            if not s.races[p.name] then return true end
        end
        s.stage = "play"
        s.games = (s.games or 0) + 1
        s.recordId = s.id .. ":" .. s.games
        s.seed = math.random(1, 2000000000)
        s.banner = "The battle begins."
        return true
    elseif verb == "won" then
        -- Either player's game says who won (both see the same thing).
        local w = tonumber(arg)
        if s.stage ~= "play" or not s.players[w or 0] then return false end
        Finish(s, s.players[w].name, s.players[3 - w] and s.players[3 - w].name)
        return true
    elseif verb == "surrender" then
        if s.stage ~= "play" then return false end
        local other = s.players[3 - seat]
        Finish(s, other and other.name, name, "Warcraft III, " .. name .. " surrendered")
        return true
    elseif verb == "desync" then
        if s.stage ~= "play" then return false end
        Finish(s, nil, nil, "The two games drifted apart (out of sync). No winner.")
        return true
    end
    return false
end

-- The host skipped a player who went offline (group lobbies): they lose.
function G:Drop(s, name)
    if s.stage ~= "play" then return end
    local seat = G.Seat(s, name)
    local other = seat and s.players[3 - seat]
    Finish(s, other and other.name, name, "Warcraft III, " .. name .. " left")
end

-- Practice bot: picks a race at once (the game itself is played by the
-- computer on your side, like a solo game).
function G:BotAct(s, name)
    if s.stage == "races" then return "race:" .. (math.random() < 0.5 and "human" or "orc") end
end

function G:Status(s)
    if s.phase == "lobby" then return #s.players < 2 and "Waiting for an opponent" or "Ready to start" end
    if s.stage == "races" then return "Choosing races" end
    if s.stage == "play" then return "Battle" end
end

function G:RangeText() return nil end
function G:RollText() return "" end
