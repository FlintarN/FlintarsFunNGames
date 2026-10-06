-- Battleship: an Arcade game for two. 8x8 waters, four ships (4, 3, 3, 2).
--
-- Your board never leaves your client during the game. When you're ready
-- you send only a sealed fingerprint of it (SHA-256 of board + secret).
-- A shot goes to the host; the defender's addon answers by itself (hit,
-- miss, sunk). When the game ends both boards are shown, and every addon
-- checks each board against its fingerprint and against every answer it
-- gave, so lying about a hit would be caught.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "battleship",
    arcade = true,
    name = "Battleship",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconBattleship",
    short = "Hide your fleet, then take turns firing. Sink all four ships to win.",
    rules = "Place your four ships on your side, then take turns firing at the other side. "
        .. "Each shot is a hit or a miss; sink every ship to win.",
    minPlayers = 2,
    maxPlayers = 2,
    practiceBots = 1,
    fields = {},
    afterGame = { rematch = true, reveal = true },
}
ns.Games.battleship = G

G.SIZE = 8
G.SHIPS = {
    { name = "Carrier", size = 4 },
    { name = "Cruiser", size = 3 },
    { name = "Submarine", size = 3 },
    { name = "Destroyer", size = 2 },
}

---------------------------------------------------------------------------
-- Boards: a 64-character string, "0" water or "1"-"4" a ship.
---------------------------------------------------------------------------
local N = G.SIZE

function G.Index(r, c) return (r - 1) * N + c end
function G.Key(r, c) return r .. "," .. c end

function G.Empty()
    return string.rep("0", N * N)
end

function G.Cell(board, r, c)
    return tonumber(board:sub(G.Index(r, c), G.Index(r, c))) or 0
end

-- The cells a ship would cover, or nil if it doesn't fit.
function G.Cells(board, r, c, size, horiz)
    local cells = {}
    for k = 0, size - 1 do
        local rr, cc = horiz and r or r + k, horiz and c + k or c
        if rr < 1 or rr > N or cc < 1 or cc > N or G.Cell(board, rr, cc) ~= 0 then return nil end
        table.insert(cells, { rr, cc })
    end
    return cells
end

function G.Put(board, cells, ship)
    local chars = {}
    for i = 1, N * N do chars[i] = board:sub(i, i) end
    for _, rc in ipairs(cells) do chars[G.Index(rc[1], rc[2])] = tostring(ship) end
    return table.concat(chars)
end

function G.Remove(board, ship)
    return (board:gsub(tostring(ship), "0"))
end

function G.Random()
    local board = G.Empty()
    for i, ship in ipairs(G.SHIPS) do
        for _ = 1, 500 do
            local horiz = math.random() < 0.5
            local cells = G.Cells(board, math.random(1, N), math.random(1, N), ship.size, horiz)
            if cells then
                board = G.Put(board, cells, i)
                break
            end
        end
    end
    return board
end

function G.Complete(board)
    for i, ship in ipairs(G.SHIPS) do
        local _, count = board:gsub(tostring(i), "")
        if count ~= ship.size then return false end
    end
    return true
end

function G.Seal(board, salt)
    return ns.Fair.Hash(board .. ":" .. salt)
end

-- Is that shot a hit, and did it sink a ship? (from the defender's board
-- and the shots it has already taken)
function G.Answer(board, shotsOnMe, r, c)
    local ship = G.Cell(board, r, c)
    if ship == 0 then return "miss" end
    for i = 1, N * N do
        if board:sub(i, i) == tostring(ship) then
            local rr, cc = math.floor((i - 1) / N) + 1, (i - 1) % N + 1
            if not (rr == r and cc == c) and shotsOnMe[G.Key(rr, cc)] ~= "hit" then return "hit" end
        end
    end
    return "sunk:" .. ship
end

---------------------------------------------------------------------------
-- Your own board (never in the shared game): game id -> { board, salt }
---------------------------------------------------------------------------
G.mine = {}

function G.Mine(s, name)
    if s._boards and s._boards[name] then return s._boards[name] end -- practice bot (host only)
    return G.mine[s.id]
end

local function Player(s, name)
    for _, p in ipairs(s.players) do
        if p.name == name then return p end
    end
end

local function Other(s, name)
    for _, p in ipairs(s.players) do
        if p.name ~= name then return p.name end
    end
end

---------------------------------------------------------------------------
-- A game
---------------------------------------------------------------------------
local function NewGame(s)
    s.games = (s.games or 0) + 1
    s.recordId = s.id .. ":" .. s.games
    s.stage = "placing"
    s.ready, s.commits, s.reveals = {}, {}, {}
    s.shots, s.sunk = {}, {}
    for _, p in ipairs(s.players) do
        s.shots[p.name], s.sunk[p.name] = {}, {}
    end
    s.pending, s.shooter = nil, nil
    s.result = nil
    s.banner = "Place your ships, then click Ready."
    -- Practice bots place at once.
    s._boards = s._boards or {}
    for _, p in ipairs(s.players) do
        if p.bot then
            local board, salt = G.Random(), ns.Fair.NewSecret()
            s._boards[p.name] = { board = board, salt = salt }
            s.ready[p.name] = true
            s.commits[p.name] = G.Seal(board, salt)
        end
    end
end

function G:Setup(s) end

function G:Begin(s)
    s.score = {}
    for _, p in ipairs(s.players) do s.score[p.name] = 0 end
    NewGame(s)
end

function G:Expect() return nil end

function G:IsTurn(s, name)
    if s.phase ~= "rolling" then return false end
    if s.stage == "placing" then return not s.ready[name] end
    return s.stage == "battle" and s.shooter == name and s.pending == nil
end

-- Record the defender's answer; next player's turn, or game over.
local function Resolve(s, answer)
    local shot = s.pending
    s.pending = nil
    local target = shot.target
    local result, ship = answer:match("^(%a+):?(%d*)$")
    s.shots[target][G.Key(shot.r, shot.c)] = (result == "miss") and "miss" or "hit"
    if result == "sunk" then
        table.insert(s.sunk[target], tonumber(ship))
        s.banner = shot.shooter .. " sank " .. target .. "'s " .. G.SHIPS[tonumber(ship)].name .. "!"
    elseif result == "hit" then
        s.banner = shot.shooter .. " hits!"
    else
        s.banner = shot.shooter .. " misses."
    end
    if #s.sunk[target] >= #G.SHIPS then
        s.phase = "done"
        s.stage = "over"
        s.score[shot.shooter] = (s.score[shot.shooter] or 0) + 1
        s.result = { winner = shot.shooter, loser = target, summary = "Battleship, " .. shot.shooter .. " won" }
        s.banner = shot.shooter .. " sank the whole fleet and wins!"
        -- The host (and practice bots) show their boards at once; players' addons follow.
        for name, b in pairs(s._boards or {}) do s.reveals[name] = { board = b.board, salt = b.salt } end
        local mine = G.mine[s.id]
        if mine and Player(s, s.host) then s.reveals[s.host] = { board = mine.board, salt = mine.salt } end
        return
    end
    s.shooter = target
end

-- The defender is here (the host, or a practice bot): answer at once.
local function AnswerHere(s)
    local shot = s.pending
    local b = G.Mine(s, shot.target)
    if shot.target == s.host or (s._boards and s._boards[shot.target]) then
        if b then Resolve(s, G.Answer(b.board, s.shots[shot.target], shot.r, shot.c)) end
    end
end

function G:Act(s, name, action)
    local verb, arg = action:match("^(%a+):?(.*)$")
    if verb == "rematch" then
        if name ~= s.host or s.phase ~= "done" then return false end
        s.phase = "rolling"
        NewGame(s)
        return true
    elseif verb == "reveal" then
        local board, salt = arg:match("^(%d+):(%w+)$")
        if not board or #board ~= N * N then return false end
        s.reveals[name] = { board = board, salt = salt }
        return true
    elseif verb == "ready" then
        if s.stage ~= "placing" or s.ready[name] or #arg ~= 64 then return false end
        s.ready[name], s.commits[name] = true, arg
        s.banner = name .. " is ready."
        for _, p in ipairs(s.players) do
            if not s.ready[p.name] then return true end
        end
        s.stage = "battle"
        -- The host fires first in odd games, the other player in even ones.
        s.shooter = (s.games % 2 == 1) and s.host or Other(s, s.host)
        s.banner = "All ships placed. " .. s.shooter .. " fires first."
        return true
    elseif verb == "shot" then
        if not self:IsTurn(s, name) then return false end
        local r, c = arg:match("^(%d+),(%d+)$")
        r, c = tonumber(r), tonumber(c)
        local target = Other(s, name)
        if not r or r < 1 or r > N or c < 1 or c > N or s.shots[target][G.Key(r, c)] then return false end
        s.pending = { shooter = name, target = target, r = r, c = c }
        s.banner = name .. " fires at " .. string.char(64 + c) .. r .. "..."
        AnswerHere(s)
        return true
    elseif verb == "answer" then
        if not s.pending or s.pending.target ~= name then return false end
        Resolve(s, arg)
        return true
    end
    return false
end

-- A player's addon: answer shots at you and show your board at the end.
function G:OnState(s)
    local me = ns.Me()
    local mine = G.mine[s.id]
    if not mine then return end
    local shot = s.pending
    if shot and shot.target == me and s.host ~= me then
        local key = s.id .. ":" .. s.games .. ":" .. shot.r .. "," .. shot.c
        if G.answered ~= key then
            G.answered = key
            ns.Session.Act(s.kind, "answer:" .. G.Answer(mine.board, s.shots[me], shot.r, shot.c))
        end
    end
    if s.phase == "done" and not s.reveals[me] and G.revealed ~= s.recordId then
        G.revealed = s.recordId
        ns.Session.Act(s.kind, "reveal:" .. mine.board .. ":" .. mine.salt)
    end
end

-- After a game: does this player's board match their seal and every answer?
-- true, false, or nil (not shown yet)
function G.Check(s, name)
    local r = s.reveals and s.reveals[name]
    if not r then return nil end
    if G.Seal(r.board, r.salt) ~= s.commits[name] or not G.Complete(r.board) then return false end
    for key, res in pairs(s.shots[name] or {}) do
        local rr, cc = key:match("^(%d+),(%d+)$")
        local isShip = G.Cell(r.board, tonumber(rr), tonumber(cc)) ~= 0
        if isShip ~= (res == "hit") then return false end
    end
    return true
end

-- Practice bot: hunt at random, then work along a hit.
function G:BotAct(s, name)
    if s.stage == "placing" then return nil end
    local target = Other(s, name)
    local shots = s.shots[target]
    local function Free(r, c) return r >= 1 and r <= N and c >= 1 and c <= N and not shots[G.Key(r, c)] end
    -- Next to a hit that isn't part of a sunk ship yet.
    for key, res in pairs(shots) do
        if res == "hit" then
            local r, c = key:match("^(%d+),(%d+)$")
            r, c = tonumber(r), tonumber(c)
            for _, d in ipairs({ { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }) do
                if Free(r + d[1], c + d[2]) and math.random() < 0.85 then
                    return "shot:" .. (r + d[1]) .. "," .. (c + d[2])
                end
            end
        end
    end
    for _ = 1, 200 do
        local r, c = math.random(1, N), math.random(1, N)
        if Free(r, c) and (r + c) % 2 == 0 then return "shot:" .. r .. "," .. c end
    end
    for r = 1, N do for c = 1, N do if Free(r, c) then return "shot:" .. r .. "," .. c end end end
end

G.dropText = "The game waits for them, or you can close the lobby."

function G:Status(s)
    if s.phase == "lobby" then return #s.players < 2 and "Waiting for an opponent" or "Ready to start" end
    if s.stage == "placing" then return "Placing ships" end
    if s.stage == "battle" then return tostring(s.shooter) .. " fires" end
end

function G:RangeText() return nil end
function G:RollText() return "" end
