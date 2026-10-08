-- Raffle: numbering, payouts, a practice raffle through the page.
local RF = ns.Games.raffle
local S = ns.Session

do
    local s = { phase = "rolling", host = "H", players = { { name = "H" }, { name = "A" }, { name = "B" } } }
    RF:Setup(s, { price = 100, maxTickets = 10, cut = 10 })
    RF:Begin(s)
    check(not RF.CanDraw(s), "no draw without tickets")
    RF:Act(s, "A", "buy:3")
    check(not RF.CanDraw(s), "one buyer isn't a raffle")
    RF:Act(s, "B", "buy:5")
    RF:Act(s, "H", "buy:2")
    check(RF:Act(s, "A", "buy:11") == false, "the ticket limit holds")
    local ranges, n = RF.Ranges(s)
    check(n == 10 and ranges[1].name == "H" and ranges[1].from == 1 and ranges[1].to == 2, "the organizer's tickets are #1-2 (seat order)")
    check(ranges[2].name == "A" and ranges[2].from == 3 and ranges[3].to == 10, "A holds #3-5, B #6-10")
    check(RF.Owner(s, 5) == "A" and RF.Owner(s, 6) == "B", "ticket owners")
    check(RF:Expect(s, "H") == nil, "no roll until sales close")
    check(RF:Act(s, "A", "close") == false, "only the organizer closes sales")
    RF:Act(s, "H", "close")
    check(RF:Act(s, "A", "buy:4") == false, "no buying after sales close")
    local lo, hi = RF:Expect(s, "H")
    check(lo == 1 and hi == 10 and RF:Expect(s, "A") == nil, "the organizer rolls 1-10")
    RF:Apply(s, "H", 7)
    local net = {}
    for _, p in ipairs(s.players) do net[p.name] = p.net end
    -- Pot 1000, cut 100: B wins 900 and paid 500; A paid 300; H paid 200, gets 100.
    check(s.phase == "done" and s.draw.winner == "B", "ticket #7 is B's")
    check(net.B == 400 and net.A == -300 and net.H == -100, "payouts with a 10% cut")
    check(net.A + net.B + net.H == 0, "the raffle adds up to zero")
end

---------------------------------------------------------------------------
-- Practice through the page
---------------------------------------------------------------------------
function RaffleStart()
    SlashCmdList.FUNNGAMES("")
    ns.UI:SelectTab("raffle")
    Advance(0)
    local view = ns.UI.pages.raffle.view
    check(#view.fields == 3, "raffle: price, limit and cut")
    view.practiceButton._scripts.OnClick()
    Advance(2)
    local s = S.Get("raffle")
    check(s.host == "Flintar" and #s.players == 4, "raffle: you organize, three bots")
    view.buttons.start._scripts.OnClick()
    Advance(3) -- bots buy
    local bought = 0
    for who, n in pairs(s.tickets) do if who ~= "Flintar" then bought = bought + n end end
    check(bought >= 3, "raffle: the bots bought tickets")
    -- Buy four.
    for _ = 1, 3 do view.plus._scripts.OnClick() end
    Advance(0)
    check(view.mine:GetText() == "4" and view.buy._enabled ~= false, "raffle: four tickets ready to buy")
    view.buy._scripts.OnClick()
    Advance(1)
    check(s.tickets.Flintar == 4, "raffle: bought")
    check(view.buttons.draw._enabled ~= false, "raffle: you can draw")
    view.buttons.draw._scripts.OnClick()
    check(s.stage == "closed" and view.spin ~= nil, "raffle: sales close, the ticket starts spinning")
end

function RaffleAfterDraw()
    local s = S.Get("raffle")
    local view = ns.UI.pages.raffle.view
    Advance(0)
    check(s.phase == "done" and s.draw, "raffle: drawn")
    -- While the ticket spins, nothing on the page gives the winner away.
    ns.UI:SelectTab("raffle")
    Advance(0)
    local told = view.winner:GetText() ~= "" or view.banner:GetText():find(s.draw.winner, 1, true) ~= nil
    for i = 1, #s.players do
        if (view.list:Row(i).chance:GetText() or ""):find("Winner", 1, true) then told = true end
    end
    check(view.spin ~= nil and not told, "raffle: the winner stays secret while the ticket spins")
    for _ = 1, 100 do
        if not view.spin then break end
        Advance(0.1)
        view:Animate(GetTime())
    end
    check(view.number:GetText() == "#" .. s.draw.ticket, "raffle: the ticket stops on the drawn number")
    check(view.winner:GetText() == s.draw.winner .. " wins!" and view.winnerPortrait:IsShown(), "raffle: the winner is shown")
    Advance(0)
    check(view.banner:GetText():find(s.draw.winner, 1, true) ~= nil, "raffle: then the banner tells")
    check(RF.Owner(s, s.draw.ticket) == s.draw.winner, "raffle: the winner holds the ticket")
    local sum = 0
    for _, p in ipairs(s.players) do sum = sum + p.net end
    check(sum == 0, "raffle: adds up to zero")
    check(#ns.db.history == 0, "raffle: practice stays out of the stats")
    view.buttons.close._scripts.OnClick()
end
