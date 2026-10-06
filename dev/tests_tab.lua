-- The running tab and trade watching.
local T = ns.Tab
T.Reset()
local real = ns.Me
ns.Me = function() return "Flintar" end
T.AddGame("highlow", { { payer = "Bob", payee = "Flintar", amount = 5000 } }, "Flintar")
T.AddGame("deathroll", { { payer = "Bob", payee = "Flintar", amount = 1000 } }, "Flintar")
T.AddGame("poker", { { payer = "Flintar", payee = "Alice", amount = 2550 }, { payer = "Bob", payee = "Alice", amount = 100 } }, "Flintar")
check(T.Balance("Bob") == 6000 and T.Balance("Alice") == -2550, "tab adds up across games")
local owed, owe = T.Totals()
check(owed == 6000 and owe == 2550, "tab totals")
check(T.List()[1].name == "Bob", "biggest balance first")

local function Trade(partner, mine, theirs)
    TRADE_PARTNER, TRADE_MINE, TRADE_THEIRS = partner, 0, 0
    Fire("TRADE_SHOW")
    TRADE_MINE, TRADE_THEIRS = mine, theirs
    Fire("TRADE_MONEY_CHANGED")
    Fire("TRADE_ACCEPT_UPDATE", 1, 1)
    TRADE_MINE, TRADE_THEIRS = 0, 0 -- the window clears as it closes
    Fire("TRADE_CLOSED")
    Fire("UI_INFO_MESSAGE", 0, "Trade complete.")
    Advance(2)
end

Trade("Bob", 0, 4000)
check(T.Balance("Bob") == 2000, "Bob paying 40s in a trade counts")
Trade("Bob", 0, 50000)
check(T.Balance("Bob") == 0, "overpaying only clears the debt, the rest is just a trade")
Trade("Alice", 2550, 0)
check(T.Balance("Alice") == 0, "paying Alice in a trade counts")
T.AddGame("highlow", { { payer = "Bob", payee = "Flintar", amount = 300 } }, "Flintar")
Trade("Bob", 10000, 0)
check(T.Balance("Bob") == 300, "giving gold to someone who owes you is not a payment")
TRADE_PARTNER = "Bob"
Fire("TRADE_SHOW")
TRADE_THEIRS = 300
Fire("TRADE_MONEY_CHANGED")
Fire("TRADE_CLOSED") -- cancelled: no "Trade complete."
Advance(2)
check(T.Balance("Bob") == 300, "a cancelled trade changes nothing")

Trade("Bob", 0, 300)
check(T.Balance("Bob") == 0, "paid")
T.Undo(T.Log()[1])
check(T.Balance("Bob") == 300 and T.Log()[2].undone, "undo a trade that wasn't a payment")

T.Remind("Bob")
check(WHISPERS[1] and WHISPERS[1][3] == "Bob" and WHISPERS[1][1]:find("3s", 1, true) and not WHISPERS[1][1]:find("|", 1, true),
    "remind whispers the amount as plain text")
T.Settle("Bob")
check(T.Balance("Bob") == 0 and #T.List() == 0, "marked as paid")

-- The page draws.
SlashCmdList.FUNNGAMES("")
T.AddGame("highlow", { { payer = "Bob", payee = "Flintar", amount = 300 } }, "Flintar")
ns.UI:SelectTab("settle")
Advance(0)
local page = ns.SettlePage
check(page.oweList.rows[1]:IsShown() and page.oweList.rows[1].name:GetText() == "Bob", "settle up lists Bob")
page.oweList.rows[1].paid._scripts.OnClick()
AnswerPopup()
check(T.Balance("Bob") == 0, "Paid button settles")
T.Reset()
ns.Me = real

-- Settings tab.
do
    local UI = ns.UI
    UI:SelectTab("settings")
    Advance(0)
    local page = ns.SettingsPage
    check(UI.pages.settings.frame:IsShown(), "settings: the tab opens")
    -- A real checkbox flips its tick before OnClick runs.
    local function Click(cb)
        Advance(0)
        cb:SetChecked(not cb:GetChecked())
        cb._scripts.OnClick(cb)
    end

    -- Mute: no sounds, but alerts still play.
    SOUNDS = {}
    Click(page.checks[1]) -- Sounds was on: click turns it off
    check(ns.db.sound == false, "settings: Sounds off")
    ns.Widgets.PlaySound("LOOTWINDOW_COIN_SOUND")
    ns.Widgets.PlaySound("READY_CHECK", true)
    check(#SOUNDS == 1 and SOUNDS[1] == "READY_CHECK", "settings: muted, only the turn alert plays")
    Click(page.checks[2])
    ns.Widgets.PlaySound("READY_CHECK", true)
    check(#SOUNDS == 1, "settings: alerts off too")
    SlashCmdList.FUNNGAMES("mute")
    check(ns.db.sound == true, "settings: /gamble mute turns sounds back on")
    ns.db.alertSound = true

    -- Minimap button.
    Click(page.checks[5])
    check(ns.db.minimap == false and not ns.Minimap.button:IsShown(), "settings: minimap button hidden")
    Click(page.checks[5])
    check(ns.Minimap.button:IsShown(), "settings: and back")

    -- Window size.
    page.bigger._scripts.OnClick()
    check(math.abs(ns.db.scale - 1.1) < 0.001, "settings: window 110%")
    for _ = 1, 10 do page.smaller._scripts.OnClick() end
    check(math.abs(ns.db.scale - 0.7) < 0.001, "settings: no smaller than 70%")
    Advance(0)
    check(page.smaller._enabled == false, "settings: - greys out at 70%")
    ns.db.scale = 1

    -- Clearing data asks first.
    ns.Tab.AddGame("highlow", { { payer = "Bob", payee = ns.Me(), amount = 300 } }, ns.Me())
    Advance(0)
    page.rows[2].button._scripts.OnClick()
    check(POPUP ~= nil and #ns.Tab.List() == 1, "settings: Clear Settle up asks first")
    AnswerPopup()
    check(#ns.Tab.List() == 0, "settings: Settle up cleared")

    ns.db.settings.poker = { bet = 5 }
    ns.db.active.poker = { kept = true }
    ns.db.sound = false
    page.rows[5].button._scripts.OnClick()
    AnswerPopup()
    check(ns.db.sound == true and next(ns.db.settings) == nil, "settings: Reset all brings back the defaults")
    check(ns.db.active.poker and ns.db.active.poker.kept, "settings: games in progress survive Reset all")
    ns.db.active.poker = nil

    -- After a reset, every game still opens (bug: Practice crashed after Reset game settings).
    for _, kind in ipairs(ns.GAME_ORDER) do
      if #ns.Games[kind].fields > 0 then -- Arcade games have no settings to reset
        ns.db.settings[kind] = nil
        UI:SelectTab(kind)
        Advance(0)
        local view = UI.pages[kind].view
        local f = view.fields[1]
        local shown = f.field.money and f:GetCopper() or tonumber(f:GetText())
        check(shown == f.field.default, kind .. ": setup shows the default after a reset")
        local ok, err = pcall(view.practiceButton._scripts.OnClick)
        check(ok and ns.Session.Get(kind) ~= nil, kind .. ": practice opens after a reset " .. tostring(err))
        check(ns.db.settings[kind] and ns.db.settings[kind][f.field.key] == f.field.default, kind .. ": settings remembered again")
        local s = ns.Session.Get(kind)
        if s then
            s.phase = "done"
            ns.Session.Dismiss(kind)
        end
      end
    end
    wipe(ns.db.settings)
    Advance(0)
    UI:SelectTab("poker")
    Advance(0)
    check(pcall(UI.pages.poker.view.practiceButton._scripts.OnClick), "poker: practice opens after Reset game settings")
end
