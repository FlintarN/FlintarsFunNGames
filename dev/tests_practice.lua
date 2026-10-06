-- Practice games through the window, alone with bots.
local S = ns.Session

SlashCmdList.FUNNGAMES("")
local UI = ns.UI
check(UI.frame:IsShown() and UI.tab == "home", "/fng opens on the game picker")
Advance(0)
check(ns.HomePage.cards[1].button:GetText() == "Play", "home card says Play")

function PracticeStart(kind)
    ns.HomePage.cards[kind == "deathroll" and 1 or 2].button._scripts.OnClick()
    check(UI.tab == kind, kind .. ": Play opens the game tab")
    local view = UI.pages[kind].view
    Advance(0)
    check(view.setup:IsShown() and not view.game:IsShown(), kind .. ": setup shows with no game")
    check(view.groupButton._enabled == false, kind .. ": group game needs a group")
    view.practiceButton._scripts.OnClick()
    local s = S.Get(kind)
    check(s and s.test and s.phase == "lobby", kind .. ": practice game opened")
end

function PracticeAfterJoin(kind)
    local s = S.Get(kind)
    local view = UI.pages[kind].view
    check(#s.players == 1 + ns.Games[kind].practiceBots, kind .. ": bots joined by themselves")
    check(view.buttons.bot:IsShown(), kind .. ": + Bot is offered")
    view.buttons.bot._scripts.OnClick()
    check(#s.players == 2 + ns.Games[kind].practiceBots, kind .. ": + Bot adds one more")

    -- Switching tabs keeps the game.
    UI:SelectTab("stats")
    UI:SelectTab("home")
    Advance(0)
    check(ns.HomePage.cards[kind == "deathroll" and 1 or 2].button:GetText() == "Resume", kind .. ": home offers Resume")
    UI:SelectTab(kind)
    check(S.Get(kind) == s, kind .. ": tab switching keeps the game")

    view.buttons.start._scripts.OnClick()
    check(s.phase == "rolling", kind .. ": started")
    check(#OUTBOX == 0, kind .. ": practice sends nothing to the group")
end

function ClickRollIfMyTurn(kind)
    local s = S.Get(kind)
    if not s then return "none" end
    Advance(0)
    local view = UI.pages[kind] and UI.pages[kind].view
    if s.phase == "rolling" and S.MyTurn(s) then
        check(view.buttons.roll._enabled ~= false, kind .. ": Roll! enabled on my turn")
        view.buttons.roll._scripts.OnClick()
        check(view.spin ~= nil, kind .. ": the die starts spinning")
    end
    return s.phase
end

function PracticeEnd(kind)
    local s = S.Get(kind)
    Advance(5)
    check(s.phase == "done" and s.result and s.result.amount > 0, kind .. ": practice game finished")
    check(#ns.db.history == 0, kind .. ": practice is not in the stats")
    local view = UI.pages[kind].view
    check(view.result:GetText() ~= "", kind .. ": result shown")
    check(view.buttons.again:IsShown() and view.buttons.close:IsShown(), kind .. ": Play again / Close offered")
    view.buttons.close._scripts.OnClick()
    Advance(0)
    check(S.Get(kind) == nil and view.setup:IsShown(), kind .. ": Close returns to setup")
end
