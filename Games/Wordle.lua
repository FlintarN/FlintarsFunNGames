-- Wordle: a solo Arcade game. Guess the five-letter word in six tries.
-- Endless: every word you solve adds points (more for fewer guesses) and
-- the next word comes up; missing one ends the run.
local ADDON, ns = ...

ns.Games = ns.Games or {}
local K = setmetatable({}, { __index = function(_, k) return ns.Kit[k] end }) -- UI loads after the games
local W = setmetatable({}, { __index = function(_, k) return ns.Widgets[k] end })

local G = {
    key = "wordle",
    arcade = true,
    solo = true,
    typing = true, -- P is a letter here, not pause
    name = "Wordle",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconWordle",
    short = "Guess the Azeroth word in six tries. How long can you keep a streak?",
    how = "Type a word and press Enter (or click the keys). Green: right spot. Yellow: in the word. Grey: not in it.",
    rules = "Guess the five-letter word in six tries. Solve it for points and the next word comes up.",
    scoreLabel = "Points",
    canvas = { 320, 320 },
    keys = { BACKSPACE = true, ENTER = true },
    fields = {},
}
for i = 65, 90 do G.keys[string.char(i)] = true end
ns.Games.wordle = G

local LEN, TRIES = 5, 6
local WORDS = {}
for w in ([[ABYSS ANVIL ARMOR BEAST BLADE BLOOD BRAWL CHAIN CHAOS CLOTH CROWN CRYPT DANCE DEATH DEMON DRUID
    DWARF EARTH ELDER FEAST FERAL FIEND FLAME FLASK FORGE FROST GHOST GLYPH GNOME GOLEM GREED GRIME GUARD GUILD
    HAUNT HEALS HEART HONOR LIGHT LUNAR MAGES MAGIC MIGHT MOUNT MURKY NIGHT PLATE POWER PRIDE QUEST RAIDS REALM
    RELIC ROGUE RUNIC SCALE SCOUT SHADE SHARD SHIRE SIEGE SIGIL SKULL SOLAR SPELL STAFF STONE STORM SWORD TALON
    THIEF TITAN TOTEM TOWER TRAPS TROLL VALOR WITCH WORLD WRATH ARROW CLOAK SPEAR WANDS BOOTS GLOVE CHEST HERBS
    OGRES ELVES NAARU ROBES TRADE CRAFT TOMES ALTAR DRAKE WHELP HYDRA FOCUS TAUNT SPAWN BOARS FLASH GLEAM BRAVE
    TORCH VAULT SNARE CURSE BLESS FAITH ROOTS GROVE MARSH SWAMP DUNES OASIS TUSKS HORDE ORDER BANES]]):gmatch("%a+") do
    if #w == LEN then table.insert(WORDS, w) end
end
G.WORDS = WORDS

local GREEN, YELLOW, GREY = 3, 2, 1
local COLORS = {
    [0] = { 0.13, 0.13, 0.15 },
    [GREY] = { 0.30, 0.31, 0.33 },
    [YELLOW] = { 0.79, 0.67, 0.22 },
    [GREEN] = { 0.33, 0.62, 0.30 },
}
local TILE, TGAP = 32, 4
local GRID_X = (320 - (LEN * TILE + (LEN - 1) * TGAP)) / 2
local KEY_W, KEY_H, KGAP, KEY_TOP = 28, 28, 3, 222
local ROWS = { "QWERTYUIOP", "ASDFGHJKL", "<ZXCVBNM>" }

-- Two passes so repeated letters are coloured like the real game.
function G.Mark(guess, answer)
    local res, left = {}, {}
    for i = 1, LEN do
        local a = answer:sub(i, i)
        if guess:sub(i, i) == a then res[i] = GREEN else left[a] = (left[a] or 0) + 1 end
    end
    for i = 1, LEN do
        if not res[i] then
            local g = guess:sub(i, i)
            if (left[g] or 0) > 0 then
                res[i] = YELLOW
                left[g] = left[g] - 1
            else
                res[i] = GREY
            end
        end
    end
    return res
end

local function MakeTile(parent, w, h, font)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.text = W.BigLabel(f, font, "GameFontNormalHuge")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetTextColor(1, 1, 1)
    return f
end

function G:Build(view)
    local cv = view.canvas
    view.tiles = {}
    for r = 1, TRIES do
        view.tiles[r] = {}
        for c = 1, LEN do
            local t = MakeTile(cv, TILE, TILE, 20)
            K.Place(t, cv, GRID_X + (c - 1) * (TILE + TGAP) + TILE / 2, 6 + (r - 1) * (TILE + TGAP) + TILE / 2)
            view.tiles[r][c] = t
        end
    end
    view.keyFrames, view.keyRects = {}, {}
    for r, row in ipairs(ROWS) do
        local widths = {}
        local total = 0
        for i = 1, #row do
            local ch = row:sub(i, i)
            widths[i] = (ch == "<" or ch == ">") and 43 or KEY_W
            total = total + widths[i] + (i > 1 and KGAP or 0)
        end
        local x = (320 - total) / 2
        for i = 1, #row do
            local ch = row:sub(i, i)
            local key = ch == "<" and "BACKSPACE" or (ch == ">" and "ENTER" or ch)
            local f = MakeTile(cv, widths[i], KEY_H, ch:match("%a") and 13 or 10)
            f.text:SetText(ch == "<" and "Back" or (ch == ">" and "Enter" or ch))
            local y = KEY_TOP + (r - 1) * (KEY_H + KGAP)
            K.Place(f, cv, x + widths[i] / 2, y + KEY_H / 2)
            view.keyFrames[key] = f
            table.insert(view.keyRects, { key = key, x1 = x, x2 = x + widths[i], y1 = y, y2 = y + KEY_H })
            x = x + widths[i] + KGAP
        end
    end
    view.status = W.Label(view.panel, "", "GameFontNormal")
    view.status:SetPoint("BOTTOMLEFT", 12, 8)
end

local function NextWord(view)
    if #view.bag == 0 then
        for i, w in ipairs(WORDS) do view.bag[i] = w end
    end
    view.answer = table.remove(view.bag, math.random(#view.bag))
    view.guesses, view.cur, view.keyState, view.wait, view.solved = {}, "", {}, nil, false
    view.words = view.words + 1
end

function G:Start(view)
    view.bag, view.words, view.lastPts = {}, 0, nil
    NextWord(view)
end

local function Submit(view)
    local guess = view.cur
    local marks = G.Mark(guess, view.answer)
    table.insert(view.guesses, { word = guess, marks = marks })
    view.cur = ""
    for i = 1, LEN do
        local ch = guess:sub(i, i)
        view.keyState[ch] = math.max(view.keyState[ch] or 0, marks[i])
    end
    G:Draw(view, #view.guesses)
    if guess == view.answer then
        view.solved = true
        view.lastPts = TRIES + 1 - #view.guesses
        view:SetScore(view.score + view.lastPts)
        view.wait = 1.8
        W.Sfx("win")
    else
        if #view.guesses >= TRIES then view.wait = 1.2 end
        W.Sfx("enter")
    end
end

function G:Key(view, key)
    if view.wait then return end
    if key == "BACKSPACE" then
        if view.cur == "" then return end
        view.cur = view.cur:sub(1, -2)
        W.Sfx("click")
    elseif key == "ENTER" then
        if #view.cur < LEN then return W.Sfx("wrong") end
        return Submit(view)
    elseif #key == 1 and key:match("%u") then
        if #view.cur >= LEN then return end
        view.cur = view.cur .. key
        W.Sfx("type")
    else
        return
    end
    self:Draw(view)
end

function G:Click(view, x, y)
    for _, k in ipairs(view.keyRects) do
        if x >= k.x1 and x <= k.x2 and y >= k.y1 and y <= k.y2 then return self:Key(view, k.key) end
    end
end

function G:Step(view, dt)
    if not view.wait then return end
    view.wait = view.wait - dt
    if view.wait > 0 then return end
    view.wait = nil
    if view.solved then
        NextWord(view)
        self:Draw(view)
    else
        view:Over(view.score, "It was " .. view.answer)
    end
end

-- `flipRow`: the row just guessed turns over tile by tile.
function G:Draw(view, flipRow)
    for r = 1, TRIES do
        local g = view.guesses[r]
        for c = 1, LEN do
            local t = view.tiles[r][c]
            local ch, state = "", 0
            if g then
                ch, state = g.word:sub(c, c), g.marks[c]
            elseif r == #view.guesses + 1 then
                ch = view.cur:sub(c, c)
            end
            t.text:SetText(ch)
            local col = COLORS[state]
            local typed = state == 0 and ch ~= ""
            local function Paint(s)
                local cc = COLORS[s]
                local lift = (s == 0 and typed) and 0.08 or 0
                t.bg:SetColorTexture(cc[1] + lift, cc[2] + lift, cc[3] + lift, 1)
            end
            if flipRow == r then
                -- Squash to nothing, change colour, open back up.
                Paint(0)
                ns.Cards.Tween(0.22, function(k)
                    if k >= 0.5 then Paint(state) end
                    t:SetHeight(math.max(1, TILE * math.abs(1 - 2 * k)))
                end, function() t:SetHeight(TILE) end, (c - 1) * 0.15)
            else
                t:SetHeight(TILE)
                Paint(state)
            end
            if col and typed and r == #view.guesses + 1 and c == #view.cur then
                t:SetSize(TILE + 4, TILE + 4)
                ns.Cards.Tween(0.08, function(k) t:SetSize(TILE + 4 - 4 * k, TILE + 4 - 4 * k) end)
            else
                t:SetWidth(TILE)
            end
        end
    end
    for key, f in pairs(view.keyFrames) do
        local s = view.keyState[key] or 0
        local cc = s == 0 and { 0.42, 0.43, 0.46 } or COLORS[s]
        local lag = flipRow and LEN * 0.15 + 0.1 or 0
        if lag > 0 and s > 0 then
            ns.Cards.Tween(0.01, function() end, function() f.bg:SetColorTexture(cc[1], cc[2], cc[3], 1) end, lag)
        else
            f.bg:SetColorTexture(cc[1], cc[2], cc[3], 1)
        end
    end
    local msg = "Word " .. view.words
    if view.lastPts then msg = msg .. "   |cff9d9d9dLast: +" .. view.lastPts .. "|r" end
    view.status:SetText(msg)
end
