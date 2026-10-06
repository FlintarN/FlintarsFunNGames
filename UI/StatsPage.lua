-- Stats tab: a summary table (each game and all games), the players you
-- have played with, and your recent games.
local ADDON, ns = ...

local W = ns.Widgets
local P = {}
ns.StatsPage = P

local ROW_H = 18
local COLUMNS = { { "played", "Played", 230 }, { "won", "Won", 290 }, { "lost", "Lost", 350 },
    { "best", "Best", 420 }, { "net", "Net", -12 } }

-- One line of the summary table: icon, game, then the numbers.
local function SummaryRow(parent, y, title, icon, font)
    local row = {}
    if icon then
        row.icon = parent:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("TOPLEFT", 10, y)
        row.icon:SetTexture(icon)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    row.name = W.Label(parent, title, font or "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 30, y)
    for _, col in ipairs(COLUMNS) do
        local fs = W.Label(parent, "", font or "GameFontHighlight")
        if col[3] > 0 then
            fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", col[3], y)
        else
            fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", col[3], y)
        end
        row[col[1]] = fs
    end
    return row
end

local function BuildLedgerRow(row)
    row.name = W.Label(row, "", "GameFontHighlight")
    row.name:SetPoint("LEFT", 6, 0)
    row.net = W.Label(row, "", "GameFontHighlight")
    row.net:SetPoint("RIGHT", -6, 0)
    row.games = W.Label(row, "", "GameFontDisableSmall")
    row.games:SetPoint("RIGHT", -70, 0)
    row.name:SetPoint("RIGHT", row.games, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

local function BuildRecentRow(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = W.Label(row, "", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -60, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.net = W.Label(row, "", "GameFontHighlightSmall")
    row.net:SetPoint("RIGHT", -6, 0)
end

function P:Build(page)
    local entries = {}
    for _, kind in ipairs(ns.GAME_ORDER) do
        -- Solo games keep their scores on their own leaderboards.
        if not ns.Games[kind].solo then
            table.insert(entries, { kind = kind, title = ns.Games[kind].name, icon = ns.Games[kind].icon })
        end
    end
    local height = 30 + (#entries + 2) * ROW_H + 8
    local summary = W.Panel(page, "Your results")
    summary:SetPoint("TOPLEFT")
    summary:SetPoint("TOPRIGHT")
    summary:SetHeight(height)

    local head = SummaryRow(summary, -30, "", nil, "GameFontNormalSmall")
    for _, col in ipairs(COLUMNS) do head[col[1]]:SetText(col[2]) end
    self.rows = {}
    for i, e in ipairs(entries) do
        local row = SummaryRow(summary, -30 - i * ROW_H, e.title, e.icon)
        row.kind = e.kind
        table.insert(self.rows, row)
    end
    local line = W.Divider(summary)
    line:SetPoint("TOPLEFT", 10, -30 - (#entries + 1) * ROW_H + 3)
    line:SetPoint("TOPRIGHT", -10, -30 - (#entries + 1) * ROW_H + 3)
    local total = SummaryRow(summary, -30 - (#entries + 1) * ROW_H, "All games", ns.ICON, "GameFontNormal")
    table.insert(self.rows, total)

        local ledger = W.Panel(page, "Players")
    ledger:SetPoint("TOPLEFT", 0, -(height + 8))
    ledger:SetPoint("BOTTOMLEFT", 0, 32)
    ledger:SetWidth(220)
    self.ledgerList = W.ScrollList(ledger, 20, BuildLedgerRow)
    self.ledgerList:Inset(6, -28, 6, 6)
    self.ledgerEmpty = W.Label(ledger, "No one yet.", "GameFontDisable")
    self.ledgerEmpty:SetPoint("CENTER")

    local recent = W.Panel(page, "Recent games")
    recent:SetPoint("TOPLEFT", ledger, "TOPRIGHT", 8, 0)
    recent:SetPoint("BOTTOMRIGHT", 0, 32)
    self.recentList = W.ScrollList(recent, 20, BuildRecentRow)
    self.recentList:Inset(6, -28, 6, 6)
    self.recentEmpty = W.Label(recent, "Finished games show up here.", "GameFontDisable")
    self.recentEmpty:SetPoint("CENTER")

    local reset = W.Button(page, "Reset stats", 110, function()
        W.Confirm("Forget all your games and stats? This cannot be undone.", function() ns.Stats:Reset() end)
    end, 24)
    reset:SetPoint("BOTTOMRIGHT", 0, 2)
    self.resetButton = reset
    local note = W.Label(page, "Practice and cancelled games are not counted.", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 4, 8)
end

function P:Refresh()
    for _, row in ipairs(self.rows) do
        local sum = ns.Stats:Summary(row.kind)
        row.played:SetText(sum.played)
        row.won:SetText(sum.won)
        row.lost:SetText(sum.lost)
        row.best:SetText(sum.best > 0 and ns.Signed(sum.best) or "-")
        row.net:SetText(ns.Signed(sum.net))
    end

    local ledger = ns.Stats:Ledger()
    for i, e in ipairs(ledger) do
        local row = self.ledgerList:Row(i)
        row.name:SetText(e.name)
        row.games:SetText(e.games .. (e.games == 1 and " game" or " games"))
        row.net:SetText(ns.Signed(e.net))
    end
    self.ledgerList:SetCount(#ledger)
    self.ledgerEmpty:SetShown(#ledger == 0)

    local history = ns.db.history
    for i, h in ipairs(history) do
        local row = self.recentList:Row(i)
        local G = ns.Games[h.kind]
        row.icon:SetTexture(G and G.icon or ns.ICON)
        local when = date and date("%d %b %H:%M", h.t) or ""
        row.text:SetText("|cffaaaaaa" .. when .. "|r  " .. ns.Stats.Describe(h))
        row.net:SetText(ns.Signed(ns.Stats.Net(h)))
    end
    self.recentList:SetCount(#history)
    self.resetButton:SetEnabled(#history > 0)
    self.recentEmpty:SetShown(#history == 0)
end
