-- Disconnects in practice: /gamble dc switches a bot off and on.
DIRECT_ROLLS = true
local S = ns.Session

local function Popup() return POPUP and POPUP.which end
local function ChatHas(text)
    for _, line in ipairs(CHAT) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

-- The host's switch on the row of `name` in a dice game.
local function RowSwitch(kind, name)
    local s = S.Get(kind)
    local view = ns.UI.pages[kind].view
    ns.UI:SelectTab(kind)
    Advance(0)
    local i = S.Find(s, name)
    return view.list.rows[i].skip
end

SlashCmdList.FUNNGAMES("")

-- Death Roll, three players. Ragnar drops, the host waits, then skips him.
function DcDeathRollStart()
    ns.UI:SelectTab("deathroll")
    Advance(0)
    local view = ns.UI.pages.deathroll.view
    view.practiceButton._scripts.OnClick()
    Advance(2) -- Ragnar joins
    S.AddBot("deathroll") -- Jaina
    view.buttons.start._scripts.OnClick()
    local s = S.Get("deathroll")
    check(s.phase == "rolling" and #s.players == 3, "dc: death roll with three")

    SlashCmdList.FUNNGAMES("dc ragnar")
    local _, rag = S.Find(s, "Ragnar")
    check(rag.offline and Popup() == nil, "dc: no pop-up when Ragnar goes offline")
    check(ChatHas("Ragnar went offline"), "dc: the host is told in chat")
    check(not rag.out, "dc: the game waits for Ragnar by default")

    -- The switch: Skip, Bring back, Skip again (three players, so no confirm).
    local b = RowSwitch("deathroll", "Ragnar")
    check(b:IsShown() and b:GetText() == "Skip", "dc: Skip next to offline Ragnar")
    b._scripts.OnClick()
    check(rag.out and Popup() == nil, "dc: Skip takes Ragnar out at once")
    b = RowSwitch("deathroll", "Ragnar")
    check(b:IsShown() and b:GetText() == "Bring back", "dc: the switch now says Bring back")
    b._scripts.OnClick()
    check(not rag.out, "dc: Bring back puts Ragnar in again")
    b = RowSwitch("deathroll", "Ragnar")
    check(b:GetText() == "Skip", "dc: and it can be flipped again")
end

-- Play until the game is stuck on Ragnar.
function DcDeathRollStep()
    local s = S.Get("deathroll")
    local view = ns.UI.pages.deathroll.view
    ns.UI:SelectTab("deathroll")
    Advance(2)
    if s.phase ~= "rolling" then return "over" end
    if S.MyTurn(s) then view.buttons.roll._scripts.OnClick() end
    if S.IsTurn(s, "Ragnar") then return "stuck" end
    return "going"
end

function DcDeathRollSkip()
    local s = S.Get("deathroll")
    local view = ns.UI.pages.deathroll.view
    if s.phase ~= "rolling" then return end -- someone rolled a 1 before Ragnar's turn
    Advance(10)
    check(S.IsTurn(s, "Ragnar"), "dc: the game waits on offline Ragnar")
    ns.UI:SelectTab("deathroll")
    Advance(0)
    local i = S.Find(s, "Ragnar")
    local row = view.list.rows[i]
    check(row.skip:IsShown() and row.skip:GetText() == "Skip", "dc: Skip shows next to offline Ragnar")
    row.skip._scripts.OnClick()
    local _, rag = S.Find(s, "Ragnar")
    check(rag.out and not S.IsTurn(s, "Ragnar"), "dc: skipped, the turn moves on")
    check(s.phase == "rolling", "dc: the game goes on with two")
    SlashCmdList.FUNNGAMES("dc ragnar") -- back
    Advance(0)
    check(not rag.offline and rag.out, "dc: Ragnar is back but sits out the rest of this game")
end

function DcDeathRollFinish()
    local s = S.Get("deathroll")
    for _ = 1, 400 do
        if s.phase ~= "rolling" then break end
        DcDeathRollStep()
    end
    check(s.phase == "done" or s.phase == "cancelled", "dc: death roll finished")
    if s.result then
        check(s.result.payer ~= "Ragnar" and s.result.payee ~= "Ragnar" or false, "dc: Ragnar isn't in the result")
    end
    ns.UI.pages.deathroll.view.buttons.close._scripts.OnClick()
end

-- Two players: continuing without one cancels the game.
function DcTwoPlayers()
    ns.UI:SelectTab("deathroll")
    Advance(0)
    local view = ns.UI.pages.deathroll.view
    view.practiceButton._scripts.OnClick()
    Advance(2)
    view.buttons.start._scripts.OnClick()
    local s = S.Get("deathroll")
    SlashCmdList.FUNNGAMES("dc ragnar")
    RowSwitch("deathroll", "Ragnar")._scripts.OnClick()
    check(Popup() == "FUNNGAMES_CONFIRM" and s.phase == "rolling", "dc: skipping the last other player asks first")
    AnswerPopup()
    check(s.phase == "cancelled", "dc: with one player left the game is off")
    SlashCmdList.FUNNGAMES("dc ragnar")
    view.buttons.close._scripts.OnClick()
end

-- High-Low: Jaina drops before rolling; the others settle it.
function DcHighLow()
    ns.UI:SelectTab("highlow")
    Advance(0)
    local view = ns.UI.pages.highlow.view
    view.practiceButton._scripts.OnClick()
    Advance(3)
    view.buttons.start._scripts.OnClick()
    local s = S.Get("highlow")
    SlashCmdList.FUNNGAMES("dc jaina")
    RowSwitch("highlow", "Jaina")._scripts.OnClick()
    local _, jaina = S.Find(s, "Jaina")
    check(jaina.out, "dc: Jaina skipped")
    RowSwitch("highlow", "Jaina")._scripts.OnClick()
    check(not jaina.out and S.Game(s):Expect(s, "Jaina"), "dc: brought back, Jaina has to roll again")
    RowSwitch("highlow", "Jaina")._scripts.OnClick()
    view.buttons.roll._scripts.OnClick()
    for _ = 1, 100 do
        if s.phase ~= "rolling" then break end
        Advance(2)
        if S.MyTurn(s) then view.buttons.roll._scripts.OnClick() end
    end
    check(s.phase == "done" and s.result.payer ~= "Jaina" and s.result.payee ~= "Jaina", "dc: high-low settled without Jaina")
    SlashCmdList.FUNNGAMES("dc jaina")
    view.buttons.close._scripts.OnClick()
end

-- Poker: Thrall drops, folds and sits out; back, he's dealt in again.
function DcPoker()
    ns.UI:SelectTab("poker")
    Advance(0)
    local view = ns.UI.pages.poker.view
    view.practiceButton._scripts.OnClick()
    Advance(3)
    view.buttons.start._scripts.OnClick()
    local s = S.Get("poker")
    local function Play()
        for _ = 1, 200 do
            Advance(2)
            if s.stage == "over" then return end
            if S.MyTurn(s) then view.buttons.call._scripts.OnClick() end
        end
    end
    -- Wait for the deal, then drop Thrall.
    for _ = 1, 20 do
        if s.stage ~= "cut" then break end
        Advance(2)
    end
    SlashCmdList.FUNNGAMES("dc thrall")
    ns.UI:SelectTab("poker")
    Advance(0)
    local seatSwitch
    for _, seat in ipairs(view.seats) do
        if seat:IsShown() and (seat.name:GetText() or ""):find("Thrall", 1, true) then seatSwitch = seat.skip end
    end
    check(seatSwitch and seatSwitch:IsShown() and seatSwitch:GetText() == "Skip", "dc: Skip on Thrall's seat")
    seatSwitch._scripts.OnClick()
    local _, thrall = S.Find(s, "Thrall")
    check(thrall.out and thrall.folded, "dc: Thrall folds and sits out")
    Play()
    check(s.stage == "over", "dc: the hand finishes without Thrall")
    view.buttons.deal._scripts.OnClick()
    for _ = 1, 20 do
        if s.stage ~= "cut" then break end
        Advance(2)
    end
    check(s._hole.Thrall == nil and thrall.folded, "dc: Thrall gets no cards while out")
    SlashCmdList.FUNNGAMES("dc thrall")
    check(not thrall.out, "dc: Thrall is back")
    Play()
    view.buttons.deal._scripts.OnClick()
    for _ = 1, 20 do
        if s.stage ~= "cut" then break end
        Advance(2)
    end
    check(s._hole.Thrall ~= nil and not thrall.folded, "dc: Thrall is dealt in again")
    Play()
    view.buttons.endTable._scripts.OnClick()
    AnswerPopup()
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + p.net end
    check(s.phase == "done" and sum == 0, "dc: poker still adds up")
    view.buttons.close._scripts.OnClick()
end

-- Right-click on a game's tab closes that game.
function CloseTabTests()
    local function Tab(key)
        for _, t in ipairs(ns.UI.tabs) do if t.key == key then return t end end
    end
    local function RightClick(key) Tab(key)._scripts.OnClick(Tab(key), "RightButton") end
    -- A practice lobby with bots: asks, then it's gone and the tab with it.
    ns.UI:SelectTab("deathroll")
    Advance(0)
    local view = ns.UI.pages.deathroll.view
    view.practiceButton._scripts.OnClick()
    Advance(3)
    check(S.Get("deathroll") ~= nil and Tab("deathroll"):IsShown(), "close: a game with its tab")
    RightClick("deathroll")
    check(Popup() == "FUNNGAMES_CONFIRM" and S.Get("deathroll") ~= nil, "close: closing a table with others asks first")
    AnswerPopup()
    Advance(0)
    check(S.Get("deathroll") == nil and ns.UI.tab == "home" and not Tab("deathroll"):IsShown(), "close: the game and its tab are gone")
    -- A solo run: asks, then stops without a score.
    ns.UI:SelectTab("snake")
    Advance(0)
    local sn = ns.UI.pages.snake.view
    sn.newButton._scripts.OnClick()
    ns.UI:SelectTab("home")
    Advance(0)
    check(Tab("snake"):IsShown(), "close: a running solo game keeps its tab")
    RightClick("snake")
    check(Popup() == "FUNNGAMES_CONFIRM", "close: quitting a run asks first")
    AnswerPopup()
    Advance(0)
    check(not ns.Solo.Running("snake") and not sn.running and not Tab("snake"):IsShown(), "close: the run stops and the tab goes")
    -- Nothing going on: just closes.
    ns.UI:SelectTab("tetris")
    Advance(0)
    RightClick("tetris")
    check(POPUP == nil and ns.UI.tab == "home", "close: an idle game closes without asking")
    -- Left-click still selects.
    Tab("stats")._scripts.OnClick(Tab("stats"), "LeftButton")
    check(ns.UI.tab == "stats", "close: left-click still opens a tab")
end
