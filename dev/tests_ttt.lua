-- Tic-Tac-Toe and Arcade lobbies. Runs in every player's VM; run.mjs calls
-- the functions on the right player.
local TT = ns.Games.tictactoe
local S = ns.Session

-- Rules
do
    local b = { "X", "X", "X", "", "", "", "", "", "" }
    check(TT.Winner(b) == "X", "three across wins")
    b = { "O", "", "", "", "O", "", "", "", "O" }
    check(TT.Winner(b) == "O", "a diagonal wins")
    b = { "X", "O", "X", "X", "O", "O", "O", "X", "X" }
    check(TT.Winner(b) == "draw", "a full board without a line is a draw")
    check(TT.Winner({ "X", "", "", "", "", "", "", "", "" }) == nil, "not over yet")
end

local function View() return ns.UI.pages.tictactoe.view end

-- Click the first free square on my turn.
function TttMove()
    local s = S.Get("tictactoe")
    if not (s and s.phase == "rolling" and S.MyTurn(s)) then return false end
    ns.UI:SelectTab("tictactoe")
    Advance(0)
    for i = 1, 9 do
        if s.board[i] == "" then
            check(View().cells[i]._enabled ~= false, "tictactoe: a free square is clickable on your turn")
            View().cells[i]._scripts.OnClick()
            return true
        end
    end
end

---------------------------------------------------------------------------
-- Practice
---------------------------------------------------------------------------
function TttPractice()
    SlashCmdList.FUNNGAMES("")
    -- The home page: Casino and Arcade.
    ns.UI:SelectTab("home")
    Advance(0)
    local home = ns.HomePage
    home.sectionButtons[2]._scripts.OnClick()
    Advance(0)
    local shown = {}
    for _, c in ipairs(home.cards) do if c:IsShown() then table.insert(shown, c.kind) end end
    local arcade = {}
    for _, kind in ipairs(ns.GAME_ORDER) do if ns.Games[kind].arcade then table.insert(arcade, kind) end end
    check(#shown == #arcade and shown[1] == arcade[1], "home: the Arcade shows only arcade games (" .. table.concat(shown, ",") .. ")")
    home.sectionButtons[1]._scripts.OnClick()
    Advance(0)
    local casino = 0
    for _, c in ipairs(home.cards) do if c:IsShown() then casino = casino + 1 end end
    check(casino == 7, "home: the Casino shows the seven money games")

    ns.UI:SelectTab("tictactoe")
    Advance(0)
    View().practiceButton._scripts.OnClick()
    Advance(2)
    local s = S.Get("tictactoe")
    check(s and s.test and #s.players == 2, "tictactoe: a bot joins the practice")
    View().buttons.start._scripts.OnClick()
    check(s.phase == "rolling" and s.marks.Flintar == "X", "tictactoe: you are X and start")
    for _ = 1, 20 do
        if s.phase ~= "rolling" then break end
        TttMove()
        Advance(2)
    end
    check(s.phase == "done", "tictactoe: the game ends")
    check(View().buttons.rematch:IsShown() and View().buttons.rematch._enabled ~= false, "tictactoe: rematch offered")
    View().buttons.rematch._scripts.OnClick()
    check(s.phase == "rolling" and s.games == 2 and s.toMove == "O", "tictactoe: rematch, the other player starts")
    Advance(3) -- the bot moves first
    check(#ns.db.history == 0, "tictactoe: practice stays out of the stats")
    View():CloseLobby()
    check(S.Get("tictactoe") == nil, "tictactoe: lobby closed")
end

---------------------------------------------------------------------------
-- Lobbies with real players
---------------------------------------------------------------------------
function TttOpenSetup()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("tictactoe")
    Advance(0)
end

function TttHost(scope)
    TttOpenSetup()
    ns.db.arcadeScope = scope
    Advance(0)
    View().createButton._scripts.OnClick()
    local s = S.Get("tictactoe")
    check(s and s.scope == (scope ~= "group" and scope or nil) and s.phase == "lobby", "lobby: " .. scope .. " lobby opened")
    if scope == "code" then check(s.code and #s.code == 5, "lobby: a five-letter code") end
    return scope == "code" and s.code or ""
end

function TttSeesLobby(expect)
    TttOpenSetup()
    local list = S.Lobbies("tictactoe")
    check((#list > 0) == expect, "lobby: " .. PLAYER_NAME .. (expect and " sees" or " doesn't see") .. " the lobby")
    if expect then
        check(View().lobbyList.rows[1] and View().lobbyList.rows[1]:IsShown(), "lobby: it's in " .. PLAYER_NAME .. "'s Open lobbies list")
    end
    check(S.Get("tictactoe") == nil, "lobby: nothing popped up for " .. PLAYER_NAME)
end

function TttJoinFromList()
    TttOpenSetup()
    View().lobbyList.rows[1].join._scripts.OnClick()
end

function TttJoinCode(code)
    TttOpenSetup()
    View().codeBox:SetText(code:lower())
    View().codeBox._scripts.OnEnterPressed(View().codeBox)
end

function TttSeated(expect)
    local s = S.Get("tictactoe")
    check(s and S.Find(s, PLAYER_NAME) ~= nil, "lobby: " .. PLAYER_NAME .. " is in the lobby")
    check(ns.UI.tab == "tictactoe", "lobby: " .. PLAYER_NAME .. "'s window shows the game")
end

function TttStart()
    View().buttons.start._scripts.OnClick()
end

function TttDone()
    local s = S.Get("tictactoe")
    return s and s.phase == "done"
end

function TttCheckEnd(opponent)
    local s = S.Get("tictactoe")
    check(s.phase == "done" and s.result, "lobby: " .. PLAYER_NAME .. " sees the game over")
    local h = ns.db.history[1]
    check(h and h.kind == "tictactoe", "lobby: " .. PLAYER_NAME .. " recorded the game")
    if s.result.winner then
        check(h.won == (s.result.winner == PLAYER_NAME) or h.lost == (s.result.winner ~= PLAYER_NAME), "lobby: win or loss recorded")
    end
end

function TttClose()
    local s = S.Get("tictactoe")
    if not s then return end
    if S.IsHost(s) then View():CloseLobby() else
        if S.IsActive(s) then s.phase = "cancelled" end
        S.Dismiss("tictactoe")
    end
end

-- Settle up and the /roll line only on the casino side.
function SideCheck()
    local UI = ns.UI
    local function Shown()
        local keys = {}
        for _, tab in ipairs(UI.tabs) do if tab:IsShown() then table.insert(keys, tab.key) end end
        return table.concat(keys, ",")
    end
    ns.db.homeSection = "casino"
    UI:SelectTab("home")
    Advance(0)
    check(Shown() == "home,settle,stats,settings", "side: casino shows Settle up (" .. Shown() .. ")")
    check(UI.footer:GetText():find("/roll", 1, true), "side: casino footer")
    ns.HomePage.sectionButtons[2]._scripts.OnClick()
    Advance(0)
    check(Shown() == "home,stats,settings", "side: arcade hides Settle up (" .. Shown() .. ")")
    check(UI.footer:GetText():find("just for fun", 1, true), "side: arcade footer")
    UI:SelectTab("stats")
    Advance(0)
    check(Shown() == "home,stats,settings", "side: Statistics keeps the arcade side")
    UI:SelectTab("deathroll")
    Advance(0)
    check(Shown():find("settle", 1, true) and UI.footer:GetText():find("/roll", 1, true), "side: opening a casino game brings the casino side")
    UI:SelectTab("tictactoe")
    Advance(0)
    check(not Shown():find("settle", 1, true), "side: opening an arcade game hides Settle up")
end
