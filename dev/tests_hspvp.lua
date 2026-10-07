-- Hearthstone PvP: the mirrored view, a practice game against a bot, and a
-- real game between two players over a code lobby (host and guest).
local HS = ns.HS
local E = HS.Engine
local S = ns.Session
local G = ns.Games.hearthstone

local function Same(a, b, path)
    if type(a) ~= type(b) then return false, path end
    if type(a) ~= "table" then return a == b, path end
    for k, v in pairs(a) do
        local ok, where = Same(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, where end
    end
    for k in pairs(b) do
        if a[k] == nil then return false, path .. "." .. tostring(k) end
    end
    return true
end

-- Mirroring twice gives the game back, and a move made on the mirrored game
-- (mirrored too) ends in the mirror of the real one: nothing is left out.
function HsMirrorTests()
    for seed = 1, 6 do
        local st = E.New({ heroes = { "jaina", "garrosh" }, seed = seed * 97 })
        check(Same(E.Mirror(E.Mirror(st)), st, "st"), "hs mirror: twice is the same game")
        local broken
        for _ = 1, 200 do
            if st.over then break end
            local a = HS.AI.Choose(st)
            local m = E.Mirror(st)
            local ok1, ev1 = E.Apply(st, a)
            local ok2, ev2 = E.Apply(m, E.Mirror(a))
            local same, where = Same(E.Mirror(m), st, "st")
            -- Events in any order (deaths at the same moment come player by player).
            local function Bag(list)
                local out = {}
                for _, ev in ipairs(list or {}) do
                    local keys = {}
                    for k, v in pairs(ev) do table.insert(keys, k .. "=" .. tostring(v)) end
                    table.sort(keys)
                    table.insert(out, table.concat(keys, ","))
                end
                table.sort(out)
                return out
            end
            local evSame, evWhere = Same(Bag(E.Mirror(ev2)), Bag(ev1), "ev")
            if ok1 ~= ok2 or not same or not evSame then
                broken = where or evWhere
                break
            end
        end
        check(not broken, "hs mirror: a whole game plays the same from chair 2 (seed " .. seed .. ", " .. tostring(broken) .. ")")
    end
    -- Actions as text.
    local a = { type = "play", card = 12, target = 2, pos = 3 }
    check(Same(G.DecodeAction(G.EncodeAction(a)), a, "a"), "hs pvp: actions go over the wire and back")
    check(G.DecodeAction("play,x,,,") == nil, "hs pvp: nonsense isn't an action")
end

local function View() return ns.UI.pages.hearthstone.view end

local function Open()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("hearthstone")
    Advance(0)
end

-- Play my moves (the computer's choice) whenever it's my turn.
local function PlayMine(s, me)
    local v = View()
    v:Refresh()
    if s.phase ~= "rolling" or s.stage ~= "play" or not v.st or v.st.over then return end
    if v.st.players[1].mulligan then
        -- Swap the first opening card.
        v.mullMarked = { [v.st.players[1].hand[1].id] = true }
        v:ConfirmMulligan()
        return
    end
    if E.Mulliganing(v.st) or v.st.active ~= 1 then return end
    v.busyUntil = 0
    local seat = G.Seat(s, me)
    -- Choose with the real game on the host; a guest only has its view, so it
    -- just ends the turn or plays its first legal card.
    local a
    if s._st then
        local mine = HS.AI.Choose(s._st)
        a = seat == 2 and E.Mirror(mine) or mine
    else
        a = { type = "end" }
        for _, l in ipairs(E.Legal(v.st)) do
            if l.type == "play" then a = l break end
        end
    end
    v:Do(a)
end

function HsPvpPractice()
    Open()
    local v = View()
    v.friendButton._scripts.OnClick()
    check(v.setup:IsShown(), "hs pvp: Play a friend opens the lobby panel")
    v.practiceButton._scripts.OnClick()
    Advance(1)
    local s = S.Get("hearthstone")
    check(s and s.test and #s.players == 2, "hs pvp: a practice lobby with a bot")
    v:Refresh()
    check(v.pvpButtons.start:IsShown() and v.pvpButtons.start:IsEnabled(), "hs pvp: the host can start")
    v.pvpButtons.start._scripts.OnClick()
    v:Refresh()
    check(v.pick[1]:IsShown(), "hs pvp: pick a hero")
    local jaina
    for _, b in ipairs(v.pick) do if b.key == "jaina" then jaina = b end end
    jaina._scripts.OnClick()
    v.deckRows[1].play._scripts.OnClick()
    for _ = 1, 10 do Advance(1) if s.stage == "play" then break end end
    check(s.stage == "play" and s.view, "hs pvp: both decks chosen, the game is on")
    -- Nobody's hand shows in the public view; mine comes privately.
    local hidden = true
    for _, p in ipairs(s.view.players) do
        for _, c in ipairs(p.hand) do if c.key then hidden = false end end
    end
    check(hidden, "hs pvp: hands are hidden in the shared game")
    v:Refresh()
    check(#v.st.players[1].hand == #s._st.players[1].hand and v.st.players[1].hand[1].key ~= nil,
        "hs pvp: my own hand, with its cards")
    for _ = 1, 400 do
        PlayMine(s, ns.Me())
        Advance(2)
        if s.phase == "done" then break end
    end
    check(s.phase == "done" and s.result, "hs pvp: the practice game ends (" .. tostring(s.phase) .. ")")
    v:Refresh()
    v.busyUntil = 0
    v:Tick()
    check(v.overlay:IsShown() and v.pvpButtons.rematch:IsShown(), "hs pvp: game over, rematch offered")
    v.pvpButtons.close._scripts.OnClick()
    Advance(1)
    v:Refresh()
    check(not v.pvp and S.Get("hearthstone") == nil, "hs pvp: closing the lobby goes back to the start")
    -- The leaderboards on the start screen.
    ns.Scores.Submit("hearthstonepvp", 3)
    v.boardButton._scripts.OnClick()
    check(v.boardPanel:IsShown() and v.boardPanel.lists[2].rows[1].name:GetText() == "1. " .. ns.Me()
        and v.boardPanel.lists[2].rows[1].score:GetText() == "3", "hs pvp: PvP wins on the leaderboard")
    v.boardButton._scripts.OnClick()
    check(not v.boardPanel:IsShown(), "hs pvp: the leaderboard closes")
end

-- Two players over a private code.
function HsPvpHost()
    Open()
    local v = View()
    v.friendButton._scripts.OnClick()
    ns.db.arcadeScope = "code"
    Advance(0)
    v.createButton._scripts.OnClick()
    return S.Get("hearthstone").code
end

function HsPvpJoin(code)
    Open()
    local v = View()
    v.friendButton._scripts.OnClick()
    v.codeBox:SetText(code)
    v.codeBox._scripts.OnEnterPressed(v.codeBox)
end

function HsPvpStart()
    local v = View()
    v:Refresh()
    check(#S.Get("hearthstone").players == 2, "hs pvp: Bob is in the lobby")
    v.pvpButtons.start._scripts.OnClick()
end

function HsPvpDeck(hero)
    local v = View()
    v:Refresh()
    for _, b in ipairs(v.pick) do if b.key == hero then b._scripts.OnClick() end end
    v.deckRows[1].play._scripts.OnClick()
end

function HsPvpMove()
    local s = S.Get("hearthstone")
    if s then PlayMine(s, PLAYER_NAME) end
end

function HsPvpDone()
    local s = S.Get("hearthstone")
    return s ~= nil and s.phase == "done"
end

function HsPvpCheck()
    local s = S.Get("hearthstone")
    local v = View()
    v:Refresh()
    check(s and s.stage == "play" or (s and s.phase == "done"), "hs pvp: " .. PLAYER_NAME .. " is in the game")
    check(v.st and v.st.players[1].heroKey == (PLAYER_NAME == "Flintar" and "jaina" or "thrall"),
        "hs pvp: " .. PLAYER_NAME .. " sees their own hero at the bottom")
    local hand = v.st and v.st.players[1].hand or {}
    check(#hand > 0 and hand[1].key ~= nil, "hs pvp: " .. PLAYER_NAME .. " sees their own cards")
    local theirs = v.st and v.st.players[2].hand or {}
    local secret = true
    for _, c in ipairs(theirs) do if c.key then secret = false end end
    check(#theirs > 0 and secret, "hs pvp: " .. PLAYER_NAME .. " can't see the other hand")
end

function HsPvpEnd()
    local s = S.Get("hearthstone")
    check(s and s.phase == "done" and s.result, "hs pvp: " .. PLAYER_NAME .. " sees the game end")
end

function HsMulliganTests()
    local st = E.New({ heroes = { "jaina", "thrall" }, seed = 5, first = 1, mulligan = true })
    check(E.Mulliganing(st) and #st.players[1].hand == 3 and #st.players[2].hand == 4,
        "hs mulligan: 3 and 4 opening cards, no coin yet")
    check(#E.Legal(st) == 0 and not E.Apply(st, { type = "end" }), "hs mulligan: nothing else until both have chosen")
    local swap = { st.players[1].hand[1].id, st.players[1].hand[2].id }
    local deck = #st.players[1].deck
    local ok = E.Mulligan(st, 1, swap)
    check(ok and #st.players[1].hand == 3 and #st.players[1].deck == deck, "hs mulligan: two swapped, still 3 cards")
    local kept = 0
    for _, c in ipairs(st.players[1].hand) do if c.id == swap[1] or c.id == swap[2] then kept = kept + 1 end end
    check(kept == 0, "hs mulligan: never the same cards back")
    check(not E.Mulligan(st, 1, {}), "hs mulligan: only once")
    E.Mulligan(st, 2, {})
    local coin = false
    for _, c in ipairs(st.players[2].hand) do if c.key == "coin" then coin = true end end
    check(not E.Mulliganing(st) and coin and st.turn == 1 and #st.players[1].hand == 4,
        "hs mulligan: then the coin and the first turn (with its draw)")
end

function HsMenuTests()
    Open()
    local v = View()
    v:ShowMenu()
    check(v.menu:IsShown() and v.queueButton:IsShown() and not v.pick[1]:IsShown(), "hs menu: the main menu first")
    v.soloButton._scripts.OnClick()
    check(v.pick[1]:IsShown() and v.backButton:IsShown() and not v.menu:IsShown(), "hs menu: Solo Adventures picks a hero")
    v.backButton._scripts.OnClick()
    check(v.menu:IsShown(), "hs menu: Back goes to the menu")
    v.collectionButton._scripts.OnClick()
    v.pick[1]._scripts.OnClick()
    check(v.deckRows[1]:IsShown() and not v.deckRows[1].play:IsShown(), "hs menu: My Collection shows decks to edit, not to play")
    v:ShowMenu()
end

function HsQueueJoin(hero)
    Open()
    local v = View()
    v:ShowMenu()
    v.queueButton._scripts.OnClick()
    for _, b in ipairs(v.pick) do if b.key == hero then b._scripts.OnClick() end end
    v.deckRows[1].play._scripts.OnClick()
    check(ns.Queue.IsQueued("hearthstone") and v.queueFrame:IsShown(), "hs queue: " .. PLAYER_NAME .. " is looking")
end

function HsQueueStage()
    local s = S.Get("hearthstone")
    View():Refresh()
    return s and s.stage or "none"
end

function HsQueueCheck(hero)
    local v = View()
    v:Refresh()
    local s = S.Get("hearthstone")
    check(s and s.stage == "play" and #s.players == 2, "hs queue: " .. PLAYER_NAME .. " matched and playing ("
        .. tostring(s and s.stage) .. ")")
    check(not ns.Queue.IsQueued("hearthstone"), "hs queue: " .. PLAYER_NAME .. " is out of the queue")
    check(v.st and v.st.players[1].heroKey == hero, "hs queue: " .. PLAYER_NAME .. " plays the hero picked before queueing")
end

-- Alone in the queue: never "found", and Play a Friend is still on the menu after.
function HsQueueAlone()
    Open()
    local v = View()
    HsQueueJoin("jaina")
    for _ = 1, 5 do Advance(4) v:Refresh() v:Tick() end
    check(ns.Queue.IsQueued("hearthstone") and v.queueFrame:IsShown() and S.Get("hearthstone") == nil,
        "hs queue: alone, still looking (no lobby, nobody found)")
    v.queueFrame.cancel._scripts.OnClick()
    check(not ns.Queue.IsQueued("hearthstone") and v.menu:IsShown() and v.friendButton:IsShown()
        and v.queueButton:IsShown() and v.soloButton:IsShown(), "hs queue: Cancel goes back to the full menu")
    -- After a deck screen and a lobby, the menu still has every button.
    v.friendButton._scripts.OnClick()
    v.practiceButton._scripts.OnClick()
    Advance(1)
    v:Refresh()
    v.pvpButtons.close._scripts.OnClick()
    Advance(1)
    v:Refresh()
    check(v.menu:IsShown() and v.friendButton:IsShown(), "hs menu: Play a Friend is back after a lobby")
end
