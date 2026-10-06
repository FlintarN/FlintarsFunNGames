-- Rules and helpers, no network.
local Ser = ns.Serialize

-- Serialize
local t = { a = 1, b = "x~y|z{}%25 é", c = { 1, 2, { d = true } }, e = false, _skip = 1, f = -3.5 }
local back = Ser.Decode(Ser.Encode(t))
check(back and back.a == 1 and back.b == t.b and back.c[3].d == true and back.e == false and back.f == -3.5, "serialize round trip")
check(back and back._skip == nil, "local-only keys are not sent")
check(Ser.Decode("{s1~") == nil and Ser.Decode("garbage") == nil, "broken messages decode to nil")
check(not Ser.Encode({ b = "a|b" }):find("|", 1, true), "no pipe characters on the wire")

-- Money
check(ns.Money(0) == "0" and ns.Money(12345) == "1g 23s 45c" and ns.Money(500) == "5s", "money text")
local mb = ns.Widgets.MoneyBox(UIParent, "Test")
mb:SetCopper(12345)
check(mb.fields[1]:GetText() == "1" and mb.fields[2]:GetText() == "23" and mb.fields[3]:GetText() == "45", "money box splits into g/s/c")
mb.fields[2]:SetText("150") -- silver above 99 counts as 99
check(mb:GetCopper() == 10000 + 9900 + 45, "money box reads back copper")

-- Roll messages
local n, r, lo, hi = ns.Rolls.Parse("Bob-Realm rolls 37 (1-100)")
check(n == "Bob" and r == 37 and lo == 1 and hi == 100, "parse a roll message")
check(ns.Rolls.Parse("Bob says hello") == nil, "only roll messages")
n, r, lo, hi = ns.Rolls.Parse("|cffffff00|Hplayer:Bob|h[Bob]|h rolls 5 (1-1000)|r")
check(n == "Bob" and r == 5 and hi == 1000, "parse a roll message with a link and colours")
n, r, lo, hi = ns.Rolls.Parse("Bob rolls 37 (1-100).")
check(n == "Bob" and r == 37, "parse a roll message with trailing text")
n, r, lo, hi = ns.Rolls.Parse("Bob Arer würfelt. Ergebnis: 37 (1-100)")
check(n == "Bob" and r == 37 and lo == 1 and hi == 100, "fallback: other wording, name is the first word")

-- High-Low
local HL = ns.Games.highlow
local function HLGame(names)
    local s = { phase = "rolling", max = 100, players = {} }
    for _, nm in ipairs(names) do table.insert(s.players, { name = nm }) end
    HL:Begin(s)
    return s
end
local function Rolls(G, s, list)
    for _, pair in ipairs(list) do
        local lo2, hi2 = G:Expect(s, pair[1])
        check(lo2 ~= nil, "expects " .. pair[1] .. " to roll")
        G:Apply(s, pair[1], pair[2])
    end
end

local s = HLGame({ "A", "B", "C" })
Rolls(HL, s, { { "A", 50 }, { "B", 90 }, { "C", 10 } })
check(s.phase == "done" and s.result.payer == "C" and s.result.payee == "B" and s.result.amount == 80, "high-low: lowest pays highest the difference")

s = HLGame({ "A", "B", "C" })
Rolls(HL, s, { { "A", 90 }, { "B", 90 }, { "C", 10 } })
check(s.phase == "rolling" and s.stage == "tb" and HL:Expect(s, "C") == nil, "high tie: only the tied players roll")
check(HL:Expect(s, "A") ~= nil, "high tie: A rolls again")
Rolls(HL, s, { { "A", 30 }, { "B", 30 } })
check(s.stage == "tb" and s.banner:find("again"), "tied again: another tiebreaker")
Rolls(HL, s, { { "A", 40 }, { "B", 20 } })
check(s.phase == "done" and s.result.payee == "A" and s.result.payer == "C" and s.result.amount == 80, "tiebreaker winner gets the first-roll difference")

s = HLGame({ "A", "B", "C", "D" })
Rolls(HL, s, { { "A", 90 }, { "B", 90 }, { "C", 5 }, { "D", 5 } })
Rolls(HL, s, { { "A", 10 }, { "B", 60 } })
check(s.phase == "rolling" and s.tb.side == "low", "after the high tie comes the low tie")
Rolls(HL, s, { { "C", 50 }, { "D", 60 } })
check(s.phase == "done" and s.result.payee == "B" and s.result.payer == "C" and s.result.amount == 85, "both ties settled")

s = HLGame({ "A", "B" })
Rolls(HL, s, { { "A", 7 }, { "B", 7 } })
check(s.phase == "rolling" and HL:Expect(s, "A") and HL:Expect(s, "B"), "everyone tied: everyone rolls again")
check(HL:Expect(s, "Z") == nil, "strangers never roll")

-- Death Roll
local DR = ns.Games.deathroll
local function DRGame(names)
    local d = { phase = "rolling", wager = 10, start = 100, players = {} }
    for _, nm in ipairs(names) do table.insert(d.players, { name = nm }) end
    DR:Begin(d)
    return d
end
local d = DRGame({ "A", "B" })
local elo, ehi = DR:Expect(d, "A")
check(elo == 1 and ehi == 100 and DR:Expect(d, "B") == nil, "death roll: A starts at 1-100, B waits")
DR:Apply(d, "A", 40)
elo, ehi = DR:Expect(d, "B")
check(elo == 1 and ehi == 40 and DR:Expect(d, "A") == nil, "death roll: B rolls 1-40 next")
DR:Apply(d, "B", 1)
check(d.phase == "done" and d.result.payer == "B" and d.result.payee == "A" and d.result.amount == 10, "rolling a 1 loses the wager")

d = DRGame({ "A", "B" })
DR:Apply(d, "A", 1)
check(d.result.payer == "A" and d.result.payee == "B", "a 1 on the first roll pays the other player")

d = DRGame({ "A", "B", "C" })
DR:Apply(d, "A", 50)
DR:Apply(d, "B", 20)
DR:Apply(d, "C", 1)
check(d.result.payer == "C" and d.result.payee == "B", "three players: pay the one who rolled before you")

-- Stats
local real = ns.Me
ns.Me = function() return "Me" end
local function Rec(id, kind, names, result)
    local ps = {}
    for _, n in ipairs(names) do table.insert(ps, { name = n }) end
    ns.Stats:Record({ id = id, kind = kind, players = ps, result = result })
end
ns.db.history = {}
Rec("1", "deathroll", { "Me", "Bob" }, { payer = "Bob", payee = "Me", amount = 10 })
Rec("2", "highlow", { "Me", "Bob", "Al" }, { payer = "Me", payee = "Al", amount = 30 })
Rec("3", "highlow", { "Me", "Bob", "Al" }, { payer = "Bob", payee = "Al", amount = 5 })
Rec("3", "highlow", { "Me", "Bob", "Al" }, { payer = "Bob", payee = "Al", amount = 5 })
check(#ns.db.history == 3, "a game is recorded once")
ns.Me = real
local all = ns.Stats:Summary()
check(all.played == 3 and all.won == 1 and all.lost == 1 and all.net == -20, "summary over all games")
local hl = ns.Stats:Summary("highlow")
check(hl.played == 2 and hl.net == -30 and hl.worst == -30, "summary for one game")
local ledger = ns.Stats:Ledger()
local byName = {}
for _, e in ipairs(ledger) do byName[e.name] = e end
check(byName.Bob.games == 3 and byName.Bob.net == 10 and byName.Al.games == 2 and byName.Al.net == -30, "ledger per player")
ns.db.history = {}
