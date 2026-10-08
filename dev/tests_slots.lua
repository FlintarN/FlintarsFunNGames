-- Slot machine: reels from the roll, the paytable, practice and the page.
local SL = ns.Games.slots
local S = ns.Session

local r = SL.Reels(512)
check(r[1] == "seven" and r[2] == "seven" and r[3] == "seven", "roll 512 is 7 7 7")
r = SL.Reels(1)
check(r[1] == "cherry" and r[2] == "cherry" and r[3] == "cherry", "roll 1 is three cherries")
r = SL.Reels(1 + 64 * 7 + 8 * 2 + 5)
check(r[1] == "seven" and r[2] == "lemon" and r[3] == "bar", "reels read from the roll's digits")
check(SL.Payout({ "cherry", "cherry", "cherry" }) == 10, "three cherries pay 10, not 4")
check(SL.Payout({ "cherry", "cherry", "gem" }) == 4 and SL.Payout({ "cherry", "gem", "cherry" }) == 1, "cherries count from the left")
check(SL.Payout({ "gem", "cherry", "cherry" }) == 0, "cherries not on the left pay nothing")

-- Payback over every possible roll.
local total = 0
for roll = 1, SL.ROLL do total = total + SL.Payout(SL.Reels(roll)) end
local rtp = total / SL.ROLL
check(rtp > 0.95 and rtp < 0.97, string.format("payback is about 96%% (%.3f)", rtp))

---------------------------------------------------------------------------
-- Practice through the page
---------------------------------------------------------------------------
local function Finish(view)
    for _ = 1, 400 do
        if not view:IsSpinning() then return end
        Advance(0.05)
        view:Animate(GetTime(), 0.05)
    end
end

function SlotsPracticeStart()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("slots")
    local view = ns.UI.pages.slots.view
    Advance(0)
    check(view.setup:IsShown() and view.fields[1].GetCopper, "slots: setup with a money box")
    view.practiceButton._scripts.OnClick()
    local s = S.Get("slots")
    check(s and s.test and s.house == "Gazlowe" and s.players[1].house, "slots: Gazlowe runs the practice machine")
    Advance(0)
    check(view.buttons.start:IsShown() and view.buttons.start._enabled ~= false, "slots: can open right away")
    view.buttons.start._scripts.OnClick()
    check(s.phase == "rolling", "slots: machine open")
    view.buttons.bot._scripts.OnClick()
    check(#s.players == 3 and s.players[3].net == 0, "slots: a bot steps up while it's open")
end

SLOT_PULLS = 0
function SlotsStep()
    local s = S.Get("slots")
    local view = ns.UI.pages.slots.view
    ns.UI:SelectTab("slots")
    Advance(0)
    Finish(view)
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + (p.net or 0) end
    check(sum == 0, "slots: house and players always add up to zero")
    if SLOT_PULLS < 25 and view.buttons.spin._enabled ~= false then
        SLOT_PULLS = SLOT_PULLS + 1
        local before = s.spins or 0
        view.buttons.spin._scripts.OnClick()
        check(view:IsSpinning(), "slots: reels spin on the pull")
        return "pulled"
    end
    return SLOT_PULLS >= 25 and "done" or "wait"
end

function SlotsCheckSpin()
    local s = S.Get("slots")
    local view = ns.UI.pages.slots.view
    Advance(0)
    Finish(view)
    -- (Your machine shows your own spins; bots pull at their own.)
    local spin
    for _, p in ipairs(s.players) do if p.name == PLAYER_NAME then spin = p.last end end
    if spin then
        for i = 1, 3 do
            check(view.reels[i].keys[2] == spin.reels[i] or view.pending ~= nil, "slots: reel " .. i .. " stopped on the rolled symbol")
        end
    end
end

function SlotsPracticeEnd()
    local s = S.Get("slots")
    local view = ns.UI.pages.slots.view
    check((s.spins or 0) >= 25, "slots: spins counted (" .. tostring(s.spins) .. ")")
    local bot = s.players[3]
    check(bot.spins == 8, "slots: the bot pulled 8 times and stopped")
    view.buttons.endTable._scripts.OnClick()
    AnswerPopup()
    check(s.phase == "done" and s.result.transfers, "slots: machine closed with a settlement")
    check(#ns.db.history == 0 and #ns.Tab.List() == 0, "slots: practice stays out of stats and the tab")
    Advance(0)
    view.buttons.close._scripts.OnClick()
    check(S.Get("slots") == nil, "slots: closed")
end

-- Optional caps.
do
    local function Machine(caps)
        local m = { phase = "rolling", host = "H", house = "H", players = { { name = "H", house = true, net = 0 }, { name = "P", net = 0 } } }
        SL:Setup(m, caps)
        m.house = "H"
        return m
    end
    local LOSE = 2 * 64 + 4 * 8 + 5 + 1 -- lemon, bell, BAR
    check(SL.Payout(SL.Reels(LOSE)) == 0, "a losing roll for the cap tests")

    local m = Machine({ bet = 100, playerCap = 300, houseCap = 0 })
    check(m.houseCap == nil and m.playerCap == 300, "0 means no cap")
    for _ = 1, 3 do
        check(SL:Expect(m, "P") ~= nil, "may spin under the cap")
        SL:Apply(m, "P", LOSE)
    end
    check(m.players[2].net == -300 and SL:Expect(m, "P") == nil, "max loss reached: no more spins")

    m = Machine({ bet = 100, playerCap = 0, houseCap = 5000 })
    SL:Apply(m, "P", 512) -- 7 7 7 pays 75 x 100
    check(m.players[2].net == 7400 and m.players[1].net == -7400, "a jackpot past the bankroll still pays in full")
    check(m.phase == "done" and m.result.transfers[1].amount == 7400, "the machine closes when the bankroll is gone")

    m = Machine({ bet = 100, playerCap = 0, houseCap = 0 })
    SL:Apply(m, "P", 512)
    check(m.phase == "rolling", "no bankroll: the machine stays open")
end

-- Players list: the scroll bar only shows when the rows don't fit.
do
    local list = ns.Widgets.ScrollList(UIParent, 20, function(row) row.name = row:CreateFontString() end)
    list.frame.GetHeight = function() return 100 end
    list:Inset(6, -26, 6, 6)
    list:SetCount(3)
    check(not list.frame.ScrollBar:IsShown(), "lists: no scroll bar for 3 rows")
    check(list.frame._point and list.frame._point[2] == -6, "lists: rows use the scroll bar's room")
    list:SetCount(8)
    check(list.frame.ScrollBar:IsShown() and list.frame._point[2] == -26, "lists: scroll bar when 8 rows don't fit")
end

-- Side tabs: game tabs only while that game has a table (or is open).
function TabsCheck()
    local UI = ns.UI
    local function Shown()
        local keys = {}
        for _, tab in ipairs(UI.tabs) do if tab:IsShown() then table.insert(keys, tab.key) end end
        return table.concat(keys, ",")
    end
    for _, kind in ipairs(ns.GAME_ORDER) do
        if S.Get(kind) then S.Get(kind).phase = "done" S.Dismiss(kind) end
    end
    UI:SelectTab("home")
    Advance(0)
    check(Shown() == "home,settle,stats,settings", "tabs: only Games, Settle up, Statistics, Settings when nothing runs (" .. Shown() .. ")")
    UI:SelectTab("roulette")
    Advance(0)
    check(Shown() == "home,roulette,settle,stats,settings", "tabs: the game you look at gets a tab (" .. Shown() .. ")")
    UI.pages.roulette.view.practiceButton._scripts.OnClick()
    UI:SelectTab("stats")
    Advance(0)
    check(Shown() == "home,roulette,settle,stats,settings", "tabs: a game with a table keeps its tab (" .. Shown() .. ")")
    S.Get("roulette").phase = "done"
    S.Dismiss("roulette")
    Advance(0)
    check(Shown() == "home,settle,stats,settings", "tabs: closed and looked away, the tab goes (" .. Shown() .. ")")
end
