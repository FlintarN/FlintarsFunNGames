-- Settle up tab: who owes whom across games, and what has been paid.
local ADDON, ns = ...

local W = ns.Widgets
local P = {}
ns.SettlePage = P

local function Total(parent, title, x)
    local label = W.Label(parent, title, "GameFontNormal")
    label:SetPoint("TOPLEFT", x, -12)
    local value = W.BigLabel(parent, 20)
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    return value
end

local function BuildOweRow(row)
    row.name = W.Label(row, "", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 6, -3)
    row.what = W.Label(row, "", "GameFontHighlightSmall")
    row.what:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.paid = W.Button(row, "Paid", 50, nil, 20)
    row.paid:SetPoint("RIGHT", -4, 0)
    W.Tooltip(row.paid, "Paid", "Mark everything between you as paid.")
    row.remind = W.Button(row, "Remind", 62, nil, 20)
    row.remind:SetPoint("RIGHT", row.paid, "LEFT", -2, 0)
    W.Tooltip(row.remind, "Remind", "Whisper them how much they owe you.")
end

local function BuildLogRow(row)
    row.text = W.Label(row, "", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetPoint("RIGHT", -54, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.undo = W.Button(row, "Undo", 48, nil, 18)
    row.undo:SetPoint("RIGHT", -2, 0)
    W.Tooltip(row.undo, "Undo", "Take this change back (for a trade that wasn't a payment, say).")
end

function P:Build(page)
    local top = W.Panel(page)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(64)
    self.owed = Total(top, "Owed to you", 14)
    self.owe = Total(top, "You owe", 190)
    local note = W.Label(top, "Finished trades are watched: gold that pays off a debt here is counted "
        .. "by itself. The trade itself is never touched.", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 340, -12)
    note:SetPoint("RIGHT", -12, 0)
    note:SetJustifyH("LEFT")

    local owes = W.Panel(page, "Who owes who")
    owes:SetPoint("TOPLEFT", 0, -72)
    owes:SetPoint("BOTTOMLEFT", 0, 32)
    owes:SetWidth(270)
    self.oweList = W.ScrollList(owes, 34, BuildOweRow)
    self.oweList:Inset(6, -28, 6, 6)
    self.oweEmpty = W.Label(owes, "All square with everyone.", "GameFontDisable")
    self.oweEmpty:SetPoint("CENTER")

    local log = W.Panel(page, "Recent changes")
    log:SetPoint("TOPLEFT", owes, "TOPRIGHT", 8, 0)
    log:SetPoint("BOTTOMRIGHT", 0, 32)
    self.logList = W.ScrollList(log, 22, BuildLogRow)
    self.logList:Inset(6, -28, 6, 6)
    self.logEmpty = W.Label(log, "Game results and payments show up here.", "GameFontDisable")
    self.logEmpty:SetPoint("CENTER")

    local clear
    clear = W.Button(page, "Clear tab", 100, function()
        W.Confirm("Forget who owes whom? This cannot be undone.", function() ns.Tab.Reset() end)
    end, 24)
    clear:SetPoint("BOTTOMRIGHT", 0, 2)
    self.clearButton = clear
    local hint = W.Label(page, "Practice games are never added here.", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 4, 8)
end

function P:Refresh()
    local owed, owe = ns.Tab.Totals()
    self.owed:SetText(owed > 0 and ("|cff40ff40" .. ns.Money(owed) .. "|r") or "|cffaaaaaanothing|r")
    self.owe:SetText(owe > 0 and ("|cffff5050" .. ns.Money(owe) .. "|r") or "|cffaaaaaanothing|r")

    local list = ns.Tab.List()
    for i, e in ipairs(list) do
        local row = self.oweList:Row(i)
        row.name:SetText(e.name)
        if e.balance > 0 then
            row.what:SetText("|cff40ff40owes you|r " .. ns.Money(e.balance))
        else
            row.what:SetText("|cffff5050you owe|r " .. ns.Money(-e.balance))
        end
        row.remind:SetShown(e.balance > 0)
        row.remind:SetScript("OnClick", function() ns.Tab.Remind(e.name) end)
        row.paid:SetScript("OnClick", function()
            W.Confirm("Mark everything between you and " .. e.name .. " as paid?", function() ns.Tab.Settle(e.name) end)
        end)
    end
    self.oweList:SetCount(#list)
    self.oweEmpty:SetShown(#list == 0)

    local log = ns.Tab.Log()
    for i, entry in ipairs(log) do
        local row = self.logList:Row(i)
        local when = date and date("%d %b %H:%M", entry.t) or ""
        local text = "|cffaaaaaa" .. when .. "|r  " .. (entry.text or "")
        if entry.undone then text = "|cff777777" .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r" end
        row.text:SetText(text)
        row.undo:SetShown(entry.why ~= "undo")
        row.undo:SetEnabled(not entry.undone)
        row.undo:SetScript("OnClick", function() ns.Tab.Undo(entry) end)
    end
    self.logList:SetCount(#log)
    self.logEmpty:SetShown(#log == 0)
    self.clearButton:SetEnabled(#log > 0 or #list > 0)
end
