-- Roulette: the rules, the house edge, a practice table, and the page.
local RL = ns.Games.roulette
local S = ns.Session

-- Spots and payouts.
local _, pays, wins = RL.Spot("n17")
check(pays == 35 and wins(17) and not wins(16), "a single number pays 35")
_, pays, wins = RL.Spot("red")
check(pays == 1 and wins(1) and not wins(2) and not wins(0), "red pays 1, loses on 0")
check(RL.Spot("d3") and select(3, RL.Spot("d3"))(36) and not select(3, RL.Spot("d3"))(24), "third dozen")
check(select(3, RL.Spot("c1"))(34) and not select(3, RL.Spot("c1"))(36), "column 1 is 1, 4 ... 34")
check(RL.Spot("n37") == nil and RL.Spot("purple") == nil, "no such spots")
check(#RL.WHEEL == 37 and RL.POCKET[0] == 1 and RL.POCKET[26] == 37, "European wheel order")

-- Every kind of bet loses 1/37 on average: the house edge.
for _, spot in ipairs({ "n0", "n17", "red", "black", "odd", "even", "low", "high", "d1", "d2", "d3", "c1", "c2", "c3" }) do
    local total = 0
    for n = 0, 36 do total = total + RL.SlipResult({ [spot] = 1 }, n, 37) end
    check(total == -37, "house edge on " .. spot .. " is 1/37 (" .. total .. ")")
end

-- Slips on the wire.
local slip = RL.DecodeSlip(RL.EncodeSlip({ n17 = 2, red = 1 }))
check(slip and slip.n17 == 2 and slip.red == 1, "slip round trip")
check(RL.DecodeSlip("n99=1") == nil and RL.DecodeSlip("red=500") == nil, "bad slips are refused")
check(RL.SlipResult({ n17 = 2, red = 1 }, 17, 100) == 2 * 3500 - 100, "17 black: the number wins, red loses")

-- Caps.
do
    local t = { phase = "rolling", host = "H", players = { { name = "H" }, { name = "P" } } }
    RL:Setup(t, { chip = 100, playerCap = 300, houseCap = 0 })
    RL:Begin(t)
    check(t.thrower == "P", "the player throws, never the house")
    check(RL:Act(t, "P", "slip:red=3") == true, "3 chips under a 300 cap")
    check(RL:Act(t, "P", "slip:red=4") == false, "4 chips is over the cap")
    check(RL:Act(t, "H", "slip:red=1") == false, "the house can't bet")
end

---------------------------------------------------------------------------
-- Practice through the page
---------------------------------------------------------------------------
local function Finish(view)
    for _ = 1, 200 do
        Advance(0.05)
        view:Animate(GetTime(), 0.05)
        if view.mode ~= "land" and view.mode ~= "spin" and not view.sendAt then return end
    end
end

ROUND_NETS = nil
function RoulettePracticeStart()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("roulette")
    local view = ns.UI.pages.roulette.view
    Advance(0)
    check(view.setup:IsShown() and #view.fields == 3, "roulette: setup with chip value and two caps")
    view.practiceButton._scripts.OnClick()
    Advance(2)
    local s = S.Get("roulette")
    check(s.house == "Gazlowe" and #s.players == 4, "roulette: Gazlowe and two bots")
    view.buttons.start._scripts.OnClick()
    check(s.phase == "rolling" and s.thrower == "Flintar", "roulette: you throw in practice")
    check(view.cells.n17 and view.cells.red and view.cells.c3 and view.cells.d2, "roulette: the table has its spots")
end

function RoulettePlaceBets()
    local view = ns.UI.pages.roulette.view
    local s = S.Get("roulette")
    view.cells.n17._scripts.OnClick(view.cells.n17, "LeftButton")
    view.cells.n17._scripts.OnClick(view.cells.n17, "LeftButton")
    view.cells.red._scripts.OnClick(view.cells.red, "LeftButton")
    view.cells.black._scripts.OnClick(view.cells.black, "LeftButton")
    view.cells.black._scripts.OnClick(view.cells.black, "RightButton")
    check(view.slip.n17 == 2 and view.slip.red == 1 and view.slip.black == nil, "roulette: chips on, one taken back")
    check(view.cells.n17.count:GetText() == "2", "roulette: the chip count shows")
    Finish(view)
    Advance(3) -- the bots put chips down too
    local mine = s.bets.Flintar
    check(mine and mine.n17 == 2 and mine.red == 1, "roulette: your slip reached the host")
    local botsBet = 0
    for who in pairs(s.bets) do if who ~= "Flintar" then botsBet = botsBet + 1 end end
    check(botsBet == 2, "roulette: both bots bet")
    ROUND_NETS = {}
    for _, p in ipairs(s.players) do ROUND_NETS[p.name] = p.net end
    ROUND_BETS = {}
    for who, slip in pairs(s.bets) do ROUND_BETS[who] = slip end
    check(view.buttons.throw._enabled ~= false, "roulette: Throw the ball is ready")
    view.buttons.throw._scripts.OnClick()
    check(view.mode == "spin", "roulette: the ball starts spinning")
end

function RouletteAfterThrow()
    local view = ns.UI.pages.roulette.view
    local s = S.Get("roulette")
    Advance(0)
    check(s.last and s.last.round == 1, "roulette: the ball landed (round 1)")
    check(view.mode == "land", "roulette: the ball is on its way in")
    Finish(view)
    local n = s.last.number
    check(view.mode == "rest" and view.restN == n and view.shownN == n, "roulette: ball at rest in pocket " .. n)
    check(math.abs(view.ballAngle - (RL.POCKET[n] - 1) * (math.pi * 2 / 37)) < 1e-6, "roulette: the ball is exactly on its pocket")
    -- Everyone's total moved by exactly their slip's result; the house took the other side.
    local sum = 0
    for _, p in ipairs(s.players) do
        sum = sum + p.net
        local bet = ROUND_BETS[p.name]
        if bet then
            check(p.net - ROUND_NETS[p.name] == RL.SlipResult(bet, n, s.chip), "roulette: " .. p.name .. " paid right")
        end
    end
    check(sum == 0, "roulette: the table adds up to zero")
    check(s.round == 2 and s.bets.Flintar == nil and s.thrower == "Flintar", "roulette: next round, your bets cleared")
    check(s.history[1] == n, "roulette: number in the history")
    Advance(0)
    check(next(view.slip) == nil, "roulette: your slip starts empty")
end

function RouletteClose()
    local view = ns.UI.pages.roulette.view
    local s = S.Get("roulette")
    view.buttons.endTable._scripts.OnClick()
    AnswerPopup()
    check(s.phase == "done" and s.result.transfers, "roulette: table closed with a settlement")
    check(#ns.db.history == 0, "roulette: practice stays out of the stats")
    Advance(0)
    view.buttons.close._scripts.OnClick()
    check(S.Get("roulette") == nil, "roulette: closed")
end
