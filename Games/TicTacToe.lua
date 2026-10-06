-- Tic-Tac-Toe: the first Arcade game. Two players, X and O, no money.
-- The host is X and the first player to join is O; whoever starts swaps
-- every game. The host can call a rematch in the same lobby, and the
-- lobby keeps the score.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "tictactoe",
    arcade = true,
    name = "Tic-Tac-Toe",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconTicTacToe",
    short = "Three in a row wins. Play your group, your guild, the realm, or a friend with a code.",
    rules = "Take turns putting your mark in an empty square. Three in a row, across, down or diagonally, wins. "
        .. "A full board with no three in a row is a draw.",
    minPlayers = 2,
    maxPlayers = 2,
    practiceBots = 1,
    fields = {},
    afterGame = { rematch = true }, -- allowed once a game is over
}
ns.Games.tictactoe = G

G.LINES = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 }, { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 }, { 1, 5, 9 }, { 3, 5, 7 } }

-- "X", "O", "draw" or nil, and the winning line.
function G.Winner(board)
    for _, line in ipairs(G.LINES) do
        local a = board[line[1]]
        if a ~= "" and a == board[line[2]] and a == board[line[3]] then return a, line end
    end
    for i = 1, 9 do
        if board[i] == "" then return nil end
    end
    return "draw"
end

local function NewBoard(s)
    s.board = { "", "", "", "", "", "", "", "", "" }
    s.line = nil
    s.games = (s.games or 0) + 1
    s.recordId = s.id .. ":" .. s.games
    -- X starts the first game, then the starter swaps.
    s.toMove = (s.games % 2 == 1) and "X" or "O"
end

function G:Setup(s) end

function G:Begin(s)
    s.marks = { [s.players[1].name] = "X", [s.players[2].name] = "O" }
    s.score = { [s.players[1].name] = 0, [s.players[2].name] = 0 }
    s.draws = 0
    NewBoard(s)
    s.banner = "Game " .. s.games .. ": " .. self:Mover(s) .. " (" .. s.toMove .. ") starts."
end

function G:Mover(s)
    for name, mark in pairs(s.marks or {}) do
        if mark == s.toMove then return name end
    end
end

function G:Expect() return nil end

function G:IsTurn(s, name)
    return s.phase == "rolling" and s.marks ~= nil and s.marks[name] == s.toMove
end

function G:Act(s, name, action)
    if action == "rematch" then
        if name ~= s.host or s.phase ~= "done" then return false end
        s.phase = "rolling"
        s.result = nil
        NewBoard(s)
        s.banner = "Game " .. s.games .. ": " .. self:Mover(s) .. " (" .. s.toMove .. ") starts."
        return true
    end
    local i = tonumber(action:match("^mark:(%d)$") or "")
    if not i or not self:IsTurn(s, name) or s.board[i] ~= "" then return false end
    s.board[i] = s.toMove
    local winner, line = G.Winner(s.board)
    if winner == "draw" then
        s.draws = s.draws + 1
        s.phase = "done"
        s.result = { summary = "Tic-Tac-Toe, draw" }
        s.banner = "A draw!"
    elseif winner then
        s.line = line
        s.score[name] = s.score[name] + 1
        s.phase = "done"
        local other
        for n in pairs(s.marks) do if n ~= name then other = n end end
        s.result = { winner = name, loser = other, summary = "Tic-Tac-Toe, " .. name .. " won" }
        s.banner = name .. " wins with three " .. winner .. "s!"
    else
        s.toMove = s.toMove == "X" and "O" or "X"
        s.banner = self:Mover(s) .. "'s turn (" .. s.toMove .. ")."
    end
    return true
end

-- The bot: win if it can, block if it must, else centre, corner, anything.
function G:BotAct(s, name)
    local me = s.marks[name]
    local them = me == "X" and "O" or "X"
    local function Finish(mark)
        for _, line in ipairs(G.LINES) do
            local count, empty = 0, nil
            for _, i in ipairs(line) do
                if s.board[i] == mark then count = count + 1 elseif s.board[i] == "" then empty = i end
            end
            if count == 2 and empty then return empty end
        end
    end
    local pick = Finish(me) or Finish(them)
    if not pick and s.board[5] == "" and math.random() < 0.8 then pick = 5 end
    if not pick then
        local free = {}
        for i = 1, 9 do if s.board[i] == "" then table.insert(free, i) end end
        pick = free[math.random(#free)]
    end
    return "mark:" .. pick
end

G.dropText = "The game waits for them to come back, or you can close the lobby."

function G:Status(s)
    if s.phase == "lobby" then return #s.players < 2 and "Waiting for an opponent" or "Ready to start" end
    if s.phase == "rolling" then return self:Mover(s) .. "'s turn (" .. s.toMove .. ")" end
end

function G:RangeText() return nil end
function G:RollText() return "" end
