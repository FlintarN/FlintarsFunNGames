-- Death Roll: take turns rolling. The first roll is 1 - start, every roll
-- after that is 1 - the last number rolled. Whoever rolls a 1 loses and pays
-- the wager to the player who rolled before them.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "deathroll",
    name = "Death Roll",
    icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    short = "Take turns rolling lower and lower. Roll a 1 and you lose.",
    rules = "Players take turns. The first roll is 1 - start, then each roll is 1 - the number before it. "
        .. "Whoever rolls a 1 loses and pays the wager to the player who rolled just before them.",
    minPlayers = 2,
    practiceBots = 1,
    fields = {
        { key = "wager", label = "Wager", money = true, default = 1000, min = 1, max = 100000000 },
        { key = "start", label = "Start roll", default = 1000, min = 2, max = 1000000 },
    },
}
ns.Games.deathroll = G

-- Seats still in the game (a player the host continued without is "out").
local function NextIn(s, i)
    local n = #s.players
    for _ = 1, n do
        i = i % n + 1
        if not s.players[i].out then return i end
    end
end

local function PrevIn(s, i)
    local n = #s.players
    for _ = 1, n do
        i = (i - 2) % n + 1
        if not s.players[i].out then return i end
    end
end

local function InCount(s)
    local n = 0
    for _, p in ipairs(s.players) do
        if not p.out then n = n + 1 end
    end
    return n
end

G.dropText = "They leave the turn order; the game goes on with the others."

function G:Setup(s, settings)
    s.wager = settings.wager
    s.start = settings.start
end

function G:Begin(s)
    s.cur = s.start
    s.turn = 1
    for _, p in ipairs(s.players) do p.roll = nil end
    s.banner = s.players[1].name .. " rolls first: 1 - " .. s.cur .. "."
end

function G:Current(s)
    if s.phase ~= "rolling" then return nil end
    return s.players[s.turn]
end

function G:Expect(s, name)
    local p = self:Current(s)
    if p and p.name == name then return 1, s.cur end
end

function G:Apply(s, name, roll)
    local p = s.players[s.turn]
    p.roll = roll
    if roll == 1 then
        local before = s.players[PrevIn(s, s.turn)]
        s.phase = "done"
        s.result = { payer = name, payee = before.name, amount = s.wager }
        s.banner = name .. " rolled a 1!"
        return
    end
    s.cur = roll
    s.turn = NextIn(s, s.turn)
    s.banner = name .. " rolled " .. roll .. ". " .. s.players[s.turn].name .. " rolls 1 - " .. roll .. " next."
end

-- Skipping this player would leave fewer than two.
function G:DropEnds(s, name)
    local n = 0
    for _, p in ipairs(s.players) do
        if not p.out and p.name ~= name then n = n + 1 end
    end
    return n < 2
end

-- Continue without a player: take them out of the turn order. (Bring back
-- just clears p.out: NextIn includes them again from the next turn.)
function G:Drop(s, name)
    if InCount(s) < 2 then
        s.phase = "cancelled"
        s.banner = "Not enough players left, so the game is off. No one pays."
        return
    end
    if s.players[s.turn].name == name then
        s.turn = NextIn(s, s.turn)
        s.banner = name .. " is out. " .. s.players[s.turn].name .. " rolls 1 - " .. s.cur .. "."
    end
end

function G:Status(s)
    if s.phase == "lobby" then
        return "Wager " .. ns.Money(s.wager) .. ", first roll 1 - " .. s.start
    end
    local p = self:Current(s)
    if p then return p.name .. "'s turn" end
end

function G:RangeText(s)
    if s.phase == "rolling" then return "1 - " .. s.cur end
    if s.phase == "lobby" then return "1 - " .. s.start end
end

function G:RollText(s, p)
    return p.roll and tostring(p.roll) or ""
end
