-- Warcraft 4: the game lobby, like Warcraft III's "Create Game" screen.
-- Seats on the left (you, computers, open or closed; race and team for
-- each), the maps on the right with a preview, Start at the bottom.
--
-- A lobby is plain data, so the same screen serves Single Player (kept in
-- the saved variables) and, later, games with other players (kept in the
-- session the host shares):
--   { map = "riverford", mode = "melee",
--     slots = { { kind = "me" | "player" | "cpu" | "open" | "closed",
--                 name, race = "human" | "orc" | "random", team = 1, diff = "normal" }, ... } }
local ADDON, ns = ...

local W = ns.Widgets
local L = {}
ns.WarcraftLobby = L

local function WC() return ns.WC end

local RACES = { "human", "orc", "random" }
local DIFFS = { "easy", "normal", "hard" }
local COLORS = { { 0.25, 0.55, 1 }, { 1, 0.25, 0.2 }, { 0.1, 0.9, 0.75 }, { 0.6, 0.3, 0.9 }, { 1, 0.95, 0.2 },
    { 1, 0.55, 0.1 }, { 0.2, 0.8, 0.2 }, { 1, 0.5, 0.8 }, { 0.6, 0.6, 0.6 }, { 0.6, 0.85, 1 } }
L.COLORS = COLORS
local ROWS = 10

local function Next(list, cur, dir)
    local i = 1
    for k, v in ipairs(list) do if v == cur then i = k end end
    return list[(i - 1 + (dir or 1)) % #list + 1]
end

local function RaceName(r) return r == "random" and "Random" or WC().Factions[r].name end

-- A fresh lobby for a map: you in seat 1, a computer in seat 2, the rest
-- closed; everyone on their own team.
function L.Default(map)
    local lobby = { map = map or "riverford", mode = "melee", slots = {} }
    L.Fit(lobby)
    return lobby
end

-- Make the seats match the map's starts (keeping what's there).
function L.Fit(lobby)
    local m = WC().Maps[lobby.map] or WC().Maps.riverford
    lobby.slots = lobby.slots or {}
    for i = 1, m.players do
        if not lobby.slots[i] then
            lobby.slots[i] = { kind = i == 1 and "me" or (i == 2 and "cpu" or "closed"), race = i == 1 and "human" or "orc",
                team = i, diff = "normal" }
        end
        local s = lobby.slots[i]
        if (s.team or 0) > m.players or (s.team or 0) < 1 then s.team = i end
    end
    for i = #lobby.slots, m.players + 1, -1 do table.remove(lobby.slots, i) end
end

-- Who plays (seats that aren't open or closed), and is it ready to start?
function L.Players(lobby)
    local out = {}
    for i, s in ipairs(lobby.slots) do
        if s.kind ~= "open" and s.kind ~= "closed" then table.insert(out, { slot = i, s = s }) end
    end
    return out
end

function L.CanStart(lobby)
    local players = L.Players(lobby)
    if #players < 2 then return false, "Add a computer or another player." end
    local teams, n = {}, 0
    for _, p in ipairs(players) do
        if not teams[p.s.team] then teams[p.s.team], n = true, n + 1 end
    end
    if n < 2 then return false, "Everyone is on one team: put someone on another team." end
    return true
end

-- The engine's game options for a lobby: factions, teams, starts,
-- difficulties; which players the computer plays. Random races are rolled.
function L.GameOptions(lobby, roll)
    roll = roll or math.random
    local o = { map = lobby.map, mode = lobby.mode or "melee", creeps = lobby.creeps ~= false, factions = {}, teams = {}, starts = {}, difficulties = {}, cpus = {}, me = nil, names = {} }
    for _, p in ipairs(L.Players(lobby)) do
        local i = #o.factions + 1
        local race = p.s.race
        if race == "random" then race = roll(2) == 1 and "human" or "orc" end
        o.factions[i], o.teams[i], o.starts[i] = race, p.s.team, p.slot
        o.names[i] = p.s.name
        if p.s.kind == "cpu" then
            table.insert(o.cpus, i)
            o.difficulties[i] = p.s.diff or "normal"
        elseif p.s.kind == "me" then
            o.me = i
        end
    end
    return o
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------
-- view: the Warcraft page. Builds into its overlay.
function L.Build(view, o)
    local f = CreateFrame("Frame", nil, o)
    f:SetAllPoints()
    f:SetFrameLevel(o:GetFrameLevel() + 4)
    f:Hide()
    view.lobbyFrame = f

    -- Seats.
    local head = W.Label(f, "Players", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 24, -62)
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(420, 24)
        r:SetPoint("TOPLEFT", 24, -86 - (i - 1) * 28)
        r.swatch = r:CreateTexture(nil, "ARTWORK")
        r.swatch:SetSize(14, 14)
        r.swatch:SetPoint("LEFT", 0, 0)
        local c = COLORS[i]
        r.swatch:SetColorTexture(c[1], c[2], c[3], 1)
        r.who = W.Button(r, "", 170, function() L.Click(view, i, "who") end, 22)
        r.who:SetPoint("LEFT", r.swatch, "RIGHT", 8, 0)
        r.race = W.Button(r, "", 96, function() L.Click(view, i, "race") end, 22)
        r.race:SetPoint("LEFT", r.who, "RIGHT", 6, 0)
        r.team = W.Button(r, "", 80, function() L.Click(view, i, "team") end, 22)
        r.team:SetPoint("LEFT", r.race, "RIGHT", 6, 0)
        W.Tooltip(r.who, "Seat " .. i, "Click to change who sits here: a computer (Easy, Normal or Hard), or closed.")
        W.Tooltip(r.race, "Race", "Human, Orc, or Random (picked when the game starts).")
        W.Tooltip(r.team, "Team", "Players on the same team are allies: they share sight and fight together.")
        r:Hide()
        f.rows[i] = r
    end

    -- Maps.
    local mh = W.Label(f, "Game and map", "GameFontNormalLarge")
    mh:SetPoint("TOPLEFT", 470, -62)
    -- The game mode (Melee, Footmen Frenzy...): the maps follow it.
    f.modes = {}
    for i, key in ipairs(WC().MODE_ORDER) do
        local b = W.Button(f, WC().Modes[key].name, 118, function() L.PickMode(view, key) end, 22)
        b:SetPoint("TOPLEFT", 470 + (i - 1) * 122, -84)
        W.Tooltip(b, WC().Modes[key].name, WC().Modes[key].text)
        b.key = key
        f.modes[i] = b
    end
    f.maps = {}
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(240, 20)
        b:SetPoint("TOPLEFT", 470, -112 - (i - 1) * 21)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 0.82, 0, 0.18)
        b.text = W.Label(b, "", "GameFontHighlight")
        b.text:SetPoint("LEFT", 6, 0)
        b.size = W.Label(b, "", "GameFontDisableSmall")
        b.size:SetPoint("RIGHT", -6, 0)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function() L.PickMap(view, b.key) end)
        b:Hide()
        f.maps[i] = b
    end
    -- The preview: the map's trees, starts and mines.
    f.preview = CreateFrame("Frame", nil, f)
    f.preview:SetSize(160, 104)
    f.preview:SetPoint("TOPLEFT", 470, -246)
    local pbg = f.preview:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.2, 0.32, 0.14, 1)
    f.previewTex = {}
    f.mapText = W.Label(f, "", "GameFontHighlightSmall")
    f.mapText:SetPoint("TOPLEFT", f.preview, "TOPRIGHT", 8, 0)
    f.mapText:SetWidth(84)
    f.mapText:SetJustifyH("LEFT")
    f.mapText:SetJustifyV("TOP")
    f.mapLong = W.Label(f, "", "GameFontHighlightSmall")
    f.mapLong:SetPoint("TOPLEFT", f.preview, "BOTTOMLEFT", 0, -6)
    f.mapLong:SetWidth(250)
    f.mapLong:SetJustifyH("LEFT")

    f.why = W.Label(f, "", "GameFontHighlightSmall")
    f.why:SetPoint("BOTTOMRIGHT", -16, 48)
    -- Creep camps on the map, or not.
    f.creeps = W.Button(f, "", 120, function() L.ToggleCreeps(view) end, 26)
    f.creeps:SetPoint("BOTTOMRIGHT", -146, 16)
    W.Tooltip(f.creeps, "Creeps", "Neutral monster camps guarding the expansions: experience, gold and items for whoever clears them.")
    f.start = W.Button(f, "Start Game", 120, function() L.Start(view) end, 26)
    f.start:SetPoint("BOTTOMRIGHT", -16, 16)
    -- Online, a player who joined says when they're ready (the host then starts).
    f.ready = W.Button(f, "Ready", 120, function()
        local lobby = Lobby(view)
        local mine
        for _, s in ipairs(lobby.slots) do if s.kind == "me" then mine = s end end
        ns.Session.Act(view.kind, "ready:" .. ((mine and mine.ready) and "off" or "on"))
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
    end, 26)
    f.ready:SetPoint("BOTTOMRIGHT", -16, 16)
    f.ready:Hide()
end

-- Online: the session's lobby (the host shares it); nil in Single Player.
local function Online(view)
    if not view.lobbyOnline then return nil end
    local s = ns.Session.Get(view.kind)
    return s and s.phase == "lobby" and s or nil
end

-- The lobby on screen now: Single Player's saved one, or the session's
-- (seen from my seat: my seat is kind "me").
local function Lobby(view)
    local s = Online(view)
    if s then return ns.Games.warcraft.LobbyView(s, ns.Me()) end
    local rec = ns.db.warcraft
    rec.lobby = rec.lobby or L.Default(rec.map)
    L.Fit(rec.lobby)
    return rec.lobby
end
L.Lobby = Lobby

-- online: the session's lobby (true) or Single Player's.
function L.Show(view, online)
    view.lobbyOnline = online and true or nil
    view.lobbyFrame:Show()
    L.Draw(view)
end

function L.Hide(view)
    if view.lobbyFrame then view.lobbyFrame:Hide() end
end

function L.Click(view, i, what)
    local lobby = Lobby(view)
    local s = lobby.slots[i]
    local m = WC().Maps[lobby.map]
    if Online(view) then
        -- The host decides; a player changes their own seat.
        local act
        if what == "who" then act = "who:" .. i
        elseif what == "race" then act = "race:" .. i .. ":" .. Next(RACES, s.race)
        else act = "team:" .. i .. ":" .. (s.team % m.players + 1) end
        ns.Session.Act(view.kind, act)
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
        return
    end
    if what == "who" then
        if s.kind == "me" then return end
        -- Computer (Normal) > (Hard) > (Easy) > Closed > Computer (Normal)...
        if s.kind == "closed" or s.kind == "open" then
            s.kind, s.diff = "cpu", "normal"
        elseif s.kind == "cpu" then
            if s.diff == "normal" then s.diff = "hard"
            elseif s.diff == "hard" then s.diff = "easy"
            else s.kind = "closed" end
        end
    elseif what == "race" then
        s.race = Next(RACES, s.race)
    elseif what == "team" then
        s.team = s.team % m.players + 1
    end
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    L.Draw(view)
end

function L.ToggleCreeps(view)
    local lobby = Lobby(view)
    local on = lobby.creeps == false
    if Online(view) then
        ns.Session.Act(view.kind, "creeps:" .. (on and "on" or "off"))
    else
        lobby.creeps = on
        L.Draw(view)
    end
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
end

-- The game mode: Melee or a custom game; the first map for it.
function L.PickMode(view, key)
    if Online(view) then
        ns.Session.Act(view.kind, "mode:" .. key)
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
        return
    end
    local lobby = Lobby(view)
    if lobby.mode == key then return end
    lobby.mode = key
    lobby.map = WC().MapsFor(1, key)[1] or lobby.map
    L.Fit(lobby)
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    L.Draw(view)
end

function L.PickMap(view, key)
    if Online(view) then
        ns.Session.Act(view.kind, "map:" .. key)
        W.PlaySound("U_CHAT_SCROLL_BUTTON")
        return
    end
    local lobby = Lobby(view)
    lobby.map = key
    ns.db.warcraft.map = key
    L.Fit(lobby)
    W.PlaySound("U_CHAT_SCROLL_BUTTON")
    L.Draw(view)
end

function L.Start(view)
    if Online(view) then
        local ok, why = ns.Session.Start(view.kind)
        if not ok and why then view.lobbyFrame.why:SetText("|cffff6060" .. why .. "|r") end
        return
    end
    local lobby = Lobby(view)
    local ok, why = L.CanStart(lobby)
    if not ok then
        view.lobbyFrame.why:SetText("|cffff6060" .. why .. "|r")
        return
    end
    view:StartSkirmish(L.GameOptions(lobby))
end

-- The preview: trees in blocks, then the starts (in their colours) and mines.
function L.DrawPreview(view, key)
    local f = view.lobbyFrame
    local m, p = WC().Maps[key], WC().ParseMap(key)
    local scale = math.min(160 / p.w, 104 / p.h)
    f.preview:SetSize(p.w * scale, p.h * scale)
    local block = math.max(2, math.ceil(4 / (scale * 2)) * 2)
    local n = 0
    local function Tex()
        n = n + 1
        local t = f.previewTex[n]
        if not t then
            t = f.preview:CreateTexture(nil, "ARTWORK")
            f.previewTex[n] = t
        end
        t:ClearAllPoints()
        t:Show()
        return t
    end
    for by = 0, p.h - 1, block do
        for bx = 0, p.w - 1, block do
            local trees = 0
            for y = by, math.min(p.h - 1, by + block - 1) do
                local row = m.grid[y + 1]
                for x = bx, math.min(p.w - 1, bx + block - 1) do
                    if row:sub(x + 1, x + 1) == "T" then trees = trees + 1 end
                end
            end
            if trees * 2 >= block * block then
                local t = Tex()
                t:SetColorTexture(0.06, 0.22, 0.08, 1)
                t:SetSize(block * scale, block * scale)
                t:SetPoint("TOPLEFT", bx * scale, -by * scale)
            end
        end
    end
    for _, g in ipairs(p.mines) do
        local t = Tex()
        t:SetColorTexture(1, 0.82, 0.1, 1)
        t:SetSize(math.max(3, 3 * scale), math.max(3, 3 * scale))
        t:SetPoint("TOPLEFT", g[1] * scale, -g[2] * scale)
    end
    for i, s in pairs(p.starts) do
        local t = Tex()
        local c = COLORS[i] or COLORS[1]
        t:SetColorTexture(c[1], c[2], c[3], 1)
        t:SetSize(math.max(5, 4 * scale), math.max(5, 4 * scale))
        t:SetPoint("TOPLEFT", s[1] * scale, -s[2] * scale)
    end
    for j = n + 1, #f.previewTex do f.previewTex[j]:Hide() end
end

function L.Draw(view)
    local f = view.lobbyFrame
    local lobby = Lobby(view)
    local online = Online(view)
    local host = not online or ns.Session.IsHost(online)
    local m = WC().Maps[lobby.map]
    local p = WC().ParseMap(lobby.map)
    for i, r in ipairs(f.rows) do
        local s = lobby.slots[i]
        r:SetShown(s ~= nil)
        if s then
            local who
            if s.kind == "me" then
                who = (ns.Me and ns.Me() or "You") .. ((online and not host and s.ready) and " |cff40ff40(ready)|r" or "")
            elseif s.kind == "player" then who = (s.name or "Player") .. (s.ready and " |cff40ff40(ready)|r" or "")
            elseif s.kind == "cpu" then who = "Computer (" .. WC().DIFFICULTY[s.diff or "normal"].name .. ")"
            elseif s.kind == "open" then who = "Open"
            else who = "Closed" end
            r.who:SetText(who)
            local playing = s.kind ~= "closed" and s.kind ~= "open"
            r.race:SetText(playing and RaceName(s.race) or "")
            r.team:SetText(playing and ("Team " .. s.team) or "")
            r.race:SetShown(playing)
            r.team:SetShown(playing)
            r.swatch:SetAlpha(playing and 1 or 0.25)
            -- Online: the host runs the seats; you set your own race and team.
            local yours = s.kind == "me" or (host and s.kind == "cpu")
            r.who:SetEnabled(host and s.kind ~= "me" and s.kind ~= "player")
            r.race:SetEnabled(yours)
            r.team:SetEnabled(yours)
        end
    end
    for _, b in ipairs(f.modes) do
        b:SetEnabled(host and b.key ~= (lobby.mode or "melee")) -- the chosen one is greyed out
    end
    local i = 0
    for _, key in ipairs(WC().MapsFor(1, lobby.mode)) do
        i = i + 1
        local b = f.maps[i]
        if b then
            local mm, pp = WC().Maps[key], WC().ParseMap(key)
            b.key = key
            b.text:SetText(mm.name)
            b.size:SetText(mm.players .. " players")
            b.bg:SetShown(key == lobby.map)
            b:SetEnabled(host)
            b:Show()
        end
    end
    for j = i + 1, #f.maps do f.maps[j]:Hide() end
    L.DrawPreview(view, lobby.map)
    f.mapText:SetText(string.format("%s\n%d x %d\n%d players", m.name, p.w, p.h, m.players))
    f.mapLong:SetText(m.text)
    f.creeps:SetText("Creeps: " .. (lobby.creeps == false and "Off" or "On"))
    f.creeps:SetShown((lobby.mode or "melee") == "melee")
    f.creeps:SetEnabled(host)
    local ok, why = L.CanStart(lobby)
    f.start:SetShown(host)
    f.start:SetEnabled(ok)
    -- Online: Start for the host (when all are ready), Ready for the others.
    local mine
    for _, s in ipairs(lobby.slots) do if s.kind == "me" then mine = s end end
    f.ready:SetShown(online ~= nil and not host)
    f.ready:SetText((mine and mine.ready) and "Not ready" or "Ready")
    if online and host then
        local ok2, why2 = ns.Games.warcraft:CanStart(online)
        if not ok2 then ok, why = false, why2 end
        f.start:SetEnabled(ok)
    end
    if not host then ok, why = false, (mine and mine.ready) and "Waiting for the host to start." or "Click Ready when you are." end
    f.why:SetText(ok and "" or ("|cffaaaaaa" .. why .. "|r"))
end
