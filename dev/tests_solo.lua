-- Solo games (Snake, 2048, Minesweeper), the Solo page and the Scores engine.
local S = ns.Session

local function Open(kind)
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab(kind)
    Advance(0)
    return ns.UI.pages[kind].view
end

-- Run a solo game's loop for `seconds`.
local function Run(view, seconds)
    for _ = 1, math.floor(seconds / 0.05) do
        Advance(0.05)
        view.canvas._scripts.OnUpdate(view.canvas, 0.05)
    end
end

function SoloTests()
    ---------------------------------------------------------------- Snake
    local sn = Open("snake")
    local G = ns.Games.snake
    check(sn.overlay:IsShown() and sn.overlayText:GetText() == "Ready?", "snake: waits for New game")
    sn.newButton._scripts.OnClick()
    check(sn.running and not sn.overlay:IsShown() and #sn.snake == 3, "snake: a run starts")
    -- An apple right in front.
    sn.apple_at = { sn.snake[1][1] + 1, sn.snake[1][2] }
    Run(sn, 0.3)
    check(sn.score == 1 and #sn.snake == 4, "snake: eat an apple, grow")
    -- Down, then left into our own body is refused (no reversing).
    G:Key(sn, "DOWN")
    G:Key(sn, "UP")
    check(#sn.turns == 1, "snake: no turning straight back")
    -- Pause by switching tabs: the tab stays while the run is on.
    ns.UI:SelectTab("stats")
    Advance(0)
    check(sn.paused, "snake: switching tabs pauses")
    local shown = false
    for _, tab in ipairs(ns.UI.tabs) do if tab.key == "snake" and tab:IsShown() then shown = true end end
    check(shown, "snake: its tab stays while a run is going")
    ns.UI:SelectTab("snake")
    sn:TogglePause()
    check(not sn.paused, "snake: resume")
    -- Into the wall.
    for _ = 1, 40 do
        Run(sn, 0.2)
        if not sn.running then break end
    end
    check(not sn.running and sn.over, "snake: hitting a wall ends the run")
    check(sn.score >= 1 and ns.Scores.Best("snake") == sn.score, "snake: best saved")
    Advance(0)
    check(sn.rows[1]:IsShown() and sn.rows[1].score:GetText() == tostring(sn.score), "snake: your best on the leaderboard")

    ---------------------------------------------------------------- 2048
    local tw = Open("g2048")
    local T = ns.Games.g2048
    tw.newButton._scripts.OnClick()
    local count = 0
    for r = 1, 4 do for c = 1, 4 do if tw.grid[r][c] then count = count + 1 end end end
    check(count == 2, "2048: two tiles to start")
    -- A known row: 2 2 4 _ slides left to 4 4 _ _ (one merge per tile).
    for r = 1, 4 do tw.grid[r] = {} end
    tw.grid[1][1] = { v = 2, r = 1, c = 1 }
    tw.grid[1][2] = { v = 2, r = 1, c = 2 }
    tw.grid[1][3] = { v = 4, r = 1, c = 3 }
    T:Key(tw, "LEFT")
    check(tw.grid[1][1].v == 4 and tw.grid[1][2].v == 4 and tw.score == 4, "2048: 2 2 4 slides to 4 4, score 4")
    ns.Cards.Tick(true)
    -- A full checkerboard of 2s and 4s has no moves left.
    for r = 1, 4 do
        for c = 1, 4 do
            tw.grid[r][c] = { v = ((r + c) % 2 == 0) and 2 or 4, r = r, c = c }
        end
    end
    check(not T.CanMove(tw), "2048: a stuck board has no moves")
    tw.grid[4][4].v = tw.grid[4][3].v
    check(T.CanMove(tw), "2048: two equal neighbours can still merge")
    tw:Over(tw.score, "No more moves")
    check(tw.over and ns.Scores.Best("g2048") == 4, "2048: the run ends and its score is saved")

    ---------------------------------------------------------------- Minesweeper
    local ms = Open("mines")
    local M = ns.Games.mines
    ms.newButton._scripts.OnClick()
    M:Press(ms, 6, 6, "LeftButton")
    check(not ms.over and ms.open[6][6] and ms.near[6][6] == 0, "mines: the first click is safe and opens an area")
    local safe = 0
    for r = 5, 7 do for c = 5, 7 do if not ms.mine[r][c] then safe = safe + 1 end end end
    check(safe == 9, "mines: no mine next to the first click")
    M:Press(ms, 1, 1, "RightButton")
    check(ms.flag[1][1] or ms.open[1][1], "mines: right-click flags")
    if ms.flag[1][1] then M:Press(ms, 1, 1, "RightButton") end
    Run(ms, 1)
    -- Open every safe square: cleared.
    for r = 1, 12 do
        for c = 1, 12 do
            if not ms.mine[r][c] and not ms.open[r][c] then M:Press(ms, r, c, "LeftButton") end
        end
    end
    check(ms.over and ms.overlayText:GetText() == "Cleared!", "mines: clearing the field wins")
    local t1 = ns.Scores.Best("mines")
    check(t1 ~= nil and t1 >= 1, "mines: your time is saved")
    -- Lower is better: a slower clear doesn't replace it.
    ns.Scores.Submit("mines", t1 + 30)
    check(ns.Scores.Best("mines") == t1, "mines: a slower time isn't a best")
    -- Boom.
    ms.newButton._scripts.OnClick()
    M:Press(ms, 6, 6, "LeftButton")
    for r = 1, 12 do
        for c = 1, 12 do
            if ms.mine[r][c] then M:Press(ms, r, c, "LeftButton") break end
        end
        if ms.over then break end
    end
    check(ms.over and ms.overlayText:GetText() == "Boom!" and ns.Scores.Best("mines") == t1, "mines: a mine ends it without a score")
    check(M.FormatScore(75) == "1:15", "mines: times show as m:ss")
end

-- Two players in a guild share bests.
function ScoreShare(score)
    ns.Scores.Submit("snake", score)
end

function ScoreBoard(name, score)
    local list = ns.Scores.Board("snake", "guild")
    local found
    for _, e in ipairs(list) do if e.name == name then found = e.score end end
    check(found == score, "scores: " .. PLAYER_NAME .. " sees " .. name .. "'s best in the guild board (" .. tostring(found) .. ")")
end

function ScoreAsk()
    ns.Scores.Ask("snake")
end

-- Tetris, Flappy Bird, Wordle.
function SoloTests2()
    ---------------------------------------------------------------- Tetris (Guideline)
    local te = Open("tetris")
    local T = ns.Games.tetris
    te.newButton._scripts.OnClick()
    check(te.piece and #te.queue >= 5, "tetris: a piece and five next")
    check(te.piece.y == -1, "tetris: spawns above the field and drops a row (" .. te.piece.y .. ")")
    check(T.Gravity(1) == 1 and math.abs(T.Gravity(5) - 0.3552) < 0.001 and T.Gravity(15) < 0.008,
        "tetris: Guideline gravity (" .. string.format("%.4f %.4f", T.Gravity(5), T.Gravity(15)) .. ")")
    local function Clean()
        for y = T.TOP, T.ROWS - 1 do te.board[y] = {} end
        te.flash, te.flashRows, te.das = nil, nil, nil
    end
    local function Put(kind, rot, x, y)
        te.piece = { kind = kind, rot = rot, x = x, y = y, resets = 0, lockT = 0, lowest = y }
        te.fall = 0
    end
    -- A single.
    Clean()
    for x = 0, 9 do if x < 3 or x > 6 then te.board[19][x] = "O" end end
    Put("I", 0, 3, 10)
    local s0 = te.score
    T:Key(te, "SPACE")
    check(te.flashRows and #te.flashRows == 1, "tetris: a full row flashes")
    Run(te, 0.4)
    check(te.lines == 1 and te.score - s0 == 100 + 2 * 8 + 800, "tetris: single 100 + hard drop 2/row + perfect clear 800 (" .. te.score - s0 .. ")")
    check(te.callout:GetText():find("Perfect Clear") ~= nil, "tetris: it says Perfect Clear")
    -- Lock delay: 0.5 s on the ground, a move restarts it.
    Clean()
    Put("O", 0, 4, 18)
    local p = te.piece
    Run(te, 0.4)
    check(te.piece == p, "tetris: no lock before 0.5 s")
    T:Key(te, "LEFT")
    Run(te, 0.4)
    check(te.piece == p, "tetris: moving restarts the lock timer")
    Run(te, 0.2)
    check(te.piece ~= p and te.board[19][3] == "O", "tetris: locks after 0.5 s still")
    Clean()
    Put("O", 0, 4, 18)
    p = te.piece
    p.resets = 15
    Run(te, 0.05)
    check(te.piece ~= p, "tetris: after 15 resets it locks at once")
    -- SRS: an upright I on the left wall turns and kicks back in.
    Clean()
    Put("I", 1, -2, 5)
    check(T.Fits(te, "I", 1, -2, 5), "tetris: upright I against the wall fits")
    T:Key(te, "UP")
    check(te.piece.rot == 2 and te.piece.x == 0, "tetris: SRS kick to the right (x " .. te.piece.x .. ")")
    T:Key(te, "Z")
    check(te.piece.rot == 1, "tetris: Z turns the other way")
    -- T-spin double: 1200 at level 1.
    local function TsdSetup()
        Clean()
        for x = 0, 9 do
            if x < 3 or x > 5 then te.board[18][x] = "J" end
            if x ~= 4 then te.board[19][x] = "L" end
        end
        te.board[17][3] = "S" -- the overhang
        Put("T", 2, 3, 17)
        te.piece.lastRot, te.piece.kick = true, 1
    end
    TsdSetup()
    check(T.TSpin(te, te.piece) == "full", "tetris: 3-corner rule sees a T-spin")
    te.combo, te.b2b = -1, false
    s0 = te.score
    T:Key(te, "SPACE")
    check(te.score - s0 == 1200, "tetris: T-spin double scores 1200 (" .. te.score - s0 .. ")")
    check(te.callout:GetText():find("T%-Spin Double") ~= nil, "tetris: it says T-Spin Double")
    Run(te, 0.3)
    -- Again: back-to-back (x1.5) and a combo (+50).
    TsdSetup()
    s0 = te.score
    T:Key(te, "SPACE")
    check(te.score - s0 == 1850, "tetris: back-to-back and combo (" .. te.score - s0 .. ")")
    Run(te, 0.3)
    -- Not a T-spin when the last move wasn't a turn.
    TsdSetup()
    te.piece.lastRot = false
    check(T.TSpin(te, te.piece) == nil, "tetris: no T-spin without a turn")
    -- Hold: once per piece.
    Clean()
    te.hold, te.holdUsed = nil, false
    Put("S", 0, 3, 2)
    T:Key(te, "C")
    local second = te.piece and te.piece.kind
    check(te.hold == "S" and te.holdUsed, "tetris: C holds the piece")
    T:Key(te, "LSHIFT")
    check(te.hold == "S" and te.piece.kind == second, "tetris: only one hold per piece")
    -- Stack to the top: topped out.
    for _ = 1, 80 do
        if not te.running then break end
        if te.piece then T:Key(te, "SPACE") end
        Run(te, 0.3)
    end
    local why = te.overlayText:GetText()
    check(not te.running and (why == "Block out" or why == "Lock out"), "tetris: stacking to the top ends the run (" .. tostring(why) .. ")")
    check(ns.Scores.Best("tetris") ~= nil, "tetris: score saved")

    ---------------------------------------------------------------- Flappy Bird
    local fl = Open("flappy")
    local F = ns.Games.flappy
    fl.newButton._scripts.OnClick()
    Run(fl, 1)
    check(not fl.started and fl.running and math.abs(fl.y - 150) < 8, "flappy: the bird hovers until the first flap")
    F:Key(fl, "SPACE")
    check(fl.started and fl.vy < 0 and #fl.list == 1, "flappy: flapping starts the run")
    -- Hold it in the gap and let pipes pass.
    for _ = 1, 120 do
        local p = fl.list[1]
        for _, q in ipairs(fl.list) do if not q.passed then p = q break end end
        fl.y, fl.vy = p.gap, 0
        Run(fl, 0.05)
        if fl.score >= 2 then break end
    end
    check(fl.running and fl.score >= 2, "flappy: flying through gaps scores (" .. fl.score .. ")")
    check(F.Hits({ x = F.BIRD_X, gap = 150 }, 150 - F.GAP / 2) and not F.Hits({ x = F.BIRD_X, gap = 150 }, 150),
        "flappy: the pipe edge hits, the middle of the gap doesn't")
    for _ = 1, 100 do
        if not fl.running then break end
        fl.list = {}
        Run(fl, 0.05)
    end
    check(not fl.running and fl.overlayText:GetText() == "Splat!", "flappy: falling to the ground ends it")
    check(ns.Scores.Best("flappy") >= 2, "flappy: score saved")

    ---------------------------------------------------------------- Wordle
    local wo = Open("wordle")
    local Wd = ns.Games.wordle
    local function m(g, a) return table.concat(Wd.Mark(g, a)) end
    check(m("STORM", "STORM") == "33333", "wordle: all green")
    check(m("ABBEY", "BABES") == "22331", "wordle: repeated letters are coloured once each (" .. m("ABBEY", "BABES") .. ")")
    check(m("SPELL", "LIGHT") == "11121", "wordle: a repeated letter that's in the word once")
    for _, w in ipairs(Wd.WORDS) do
        if #w ~= 5 then check(false, "wordle: bad word " .. w) end
    end
    check(#Wd.WORDS >= 100, "wordle: a decent word list (" .. #Wd.WORDS .. ")")
    wo.newButton._scripts.OnClick()
    wo.answer = "FROST"
    local function Type(word)
        for i = 1, #word do Wd:Key(wo, word:sub(i, i)) end
        Wd:Key(wo, "ENTER")
    end
    Wd:Key(wo, "P")
    check(wo.cur == "P" and not wo.paused, "wordle: P types a letter instead of pausing")
    Wd:Key(wo, "BACKSPACE")
    Type("FRO")
    check(#wo.guesses == 0 and wo.cur == "FRO", "wordle: Enter needs five letters")
    Wd:Key(wo, "BACKSPACE"); Wd:Key(wo, "BACKSPACE"); Wd:Key(wo, "BACKSPACE")
    Type("STORM")
    check(#wo.guesses == 1 and wo.keyState.S == 2 and wo.keyState.M == 1, "wordle: the keyboard remembers colours")
    Type("FROST")
    check(wo.solved and wo.score == 5, "wordle: solved in two scores 5")
    Run(wo, 2)
    check(wo.words == 2 and #wo.guesses == 0 and wo.answer ~= nil, "wordle: the next word comes up")
    -- Click the on-screen keys.
    local k = wo.keyRects[1]
    Wd:Click(wo, (k.x1 + k.x2) / 2, (k.y1 + k.y2) / 2)
    check(wo.cur == k.key, "wordle: clicking a key types it")
    Wd:Key(wo, "BACKSPACE")
    wo.answer = "GNOME"
    for _ = 1, 6 do Type("TROLL") end
    Run(wo, 1.5)
    check(not wo.running and wo.overlayText:GetText() == "It was GNOME", "wordle: six misses end the run")
    check(ns.Scores.Best("wordle") == 5, "wordle: points saved")
    ns.Cards.Tick(true)
end

-- Space Shooter, Candy Crush, Angry Birds.
function SoloTests3()
    ---------------------------------------------------------------- Space Shooter
    local sh = Open("shooter")
    local Sh = ns.Games.shooter
    sh.newButton._scripts.OnClick()
    check(#sh.aliens == 32 and sh.wave == 1 and sh.lives == 3, "shooter: a wave of 32")
    Run(sh, 2)
    -- Line up under an invader and shoot.
    local target = sh.aliens[25]
    sh.x = Sh.AlienPos(sh, target)
    sh.fireIn = 99
    sh.cooldown = 0
    Sh:Key(sh, "SPACE")
    for _ = 1, 20 do
        Run(sh, 0.05)
        if sh.score > 0 then break end
    end
    check(sh.score > 0, "shooter: a shot downs an invader (" .. sh.score .. ")")
    -- Holding right moves the ship.
    local x0 = sh.x
    sh.held.RIGHT = true
    Run(sh, 0.2)
    sh.held.RIGHT = nil
    check(sh.x > x0, "shooter: holding Right moves")
    -- Clearing the wave brings the next.
    for _, a in ipairs(sh.aliens) do a.alive = false end
    Run(sh, 0.1)
    check(sh.wave == 2 and #sh.aliens == 32, "shooter: wave 2 after a clear")
    -- Getting hit costs a life and gives a moment of safety.
    sh.bannerTime = 0
    sh.fireIn = 99
    sh.alienShots = { { x = sh.x, y = Sh.PLAYER_Y - 4 } }
    Run(sh, 0.05)
    check(sh.lives == 2 and sh.hurt > 0, "shooter: hit, two lives left")
    sh.alienShots = { { x = sh.x, y = Sh.PLAYER_Y - 4 } }
    Run(sh, 0.05)
    check(sh.lives == 2, "shooter: no second hit while blinking")
    -- Invaders on the ground end it.
    sh.oy = Sh.PLAYER_Y
    Run(sh, 0.1)
    check(not sh.running and sh.overlayText:GetText() == "Invaded!", "shooter: invaders landing ends the run")

    ---------------------------------------------------------------- Candy Crush
    local rm = Open("candycrush")
    local R = ns.Games.candycrush
    rm.newButton._scripts.OnClick()
    Run(rm, 2)
    check(not rm.resolving and not next((R.Find(rm.grid))) and rm.moves == R.MOVES, "candy crush: a settled board with no lines")
    check(R.HasMove(rm.grid), "candy crush: there's a move to make")
    local function Set(rows)
        for r = 1, R.N do
            for c = 1, R.N do
                local k = tonumber(rows[r]:sub(c, c))
                rm.grid[r][c] = { kind = k, px = c, py = r }
            end
        end
    end
    -- Row 8 reads 1 1 2 ..., and (7,3) is a 1: swapping them makes 1 1 1.
    Set({ "34563456", "45634563", "56345634", "63456345", "34563456", "45634563", "56145634", "11256345" })
    check(not next((R.Find(rm.grid))), "candy crush: the test board has no lines")
    local s0 = rm.score
    R:Swap(rm, 7, 3, 8, 3)
    check(rm.moves == R.MOVES - 1, "candy crush: a good swap uses a move")
    Run(rm, 2)
    check(rm.score >= s0 + 30 and not rm.resolving, "candy crush: three in a row clears and scores (" .. rm.score - s0 .. ")")
    -- A swap that makes nothing slides back for free.
    Set({ "34563456", "45634563", "56345634", "63456345", "34563456", "45634563", "56345634", "11316345" })
    rm.resolving = false
    local before = rm.grid[1][1].kind
    R:Swap(rm, 1, 1, 1, 2)
    Run(rm, 1)
    check(rm.grid[1][1].kind == before and rm.moves == R.MOVES - 1, "candy crush: a swap with no line goes back, no move used")
    -- Four in a row leaves a Skull.
    Set({ "34563456", "45634563", "56345634", "63456345", "34563456", "45634563", "56145634", "11216345" })
    rm.resolving = false
    R:Swap(rm, 7, 3, 8, 3)
    local skull
    for _ = 1, 40 do
        Run(rm, 0.05)
        for r = 1, R.N do for c = 1, R.N do if rm.grid[r][c] and rm.grid[r][c].kind == R.SKULL then skull = c end end end
        if skull then break end
    end
    check(skull ~= nil, "candy crush: four in a row makes a Skull")
    Run(rm, 2)
    -- Swap the Skull: it blows a hole around it.
    local sr, sc
    for r = 1, R.N do for c = 1, R.N do if rm.grid[r][c].kind == R.SKULL then sr, sc = r, c end end end
    if sr then
        local s1 = rm.score
        R:Swap(rm, sr, sc, sr > 1 and sr - 1 or sr + 1, sc)
        check(#rm.dying >= 4, "candy crush: the Skull blows up its neighbours (" .. #rm.dying .. ")")
        Run(rm, 2)
        check(rm.score > s1, "candy crush: the blast scores")
    end
    -- Out of moves ends the run.
    rm.moves = 1
    for _ = 1, 20 do
        if not rm.running then break end
        if not rm.resolving then
            for r = 1, R.N do
                for c = 1, R.N - 1 do
                    if rm.moves > 0 and not rm.resolving then
                        R:Swap(rm, r, c, r, c + 1)
                        if rm.pending then Run(rm, 1) end
                    end
                end
            end
        end
        Run(rm, 1)
    end
    check(not rm.running and rm.overlayText:GetText() == "Out of moves", "candy crush: out of moves, it's over")

    ---------------------------------------------------------------- Angry Birds
    local ca = Open("angrybirds")
    local C = ns.Games.angrybirds
    ca.newButton._scripts.OnClick()
    check(ca.level == 1 and ca.murlocs == 1 and ca.shotsLeft == 3 and ca.state == "aim", "angry birds: level 1, one murloc, three boulders")
    local a0 = ca.angle
    C:Key(ca, "UP")
    check(ca.angle > a0, "angry birds: Up aims higher")
    -- A shot that misses: the boulder lands, one less.
    ca.angle, ca.power = 1.4, 0.3
    C:Key(ca, "SPACE")
    check(ca.state == "flying" and ca.shotsLeft == 2, "angry birds: Space fires")
    Run(ca, 4)
    check(ca.state == "aim" and ca.murlocs == 1, "angry birds: a miss, back to aiming")
    -- Knock the legs out: the block falls.
    ca.cells[0][3], ca.cells[0][5] = nil, nil
    ca.state, ca.falling = "flying", true
    Run(ca, 1)
    check(ca.cells[0][4] and ca.cells[0][4].kind == "W", "angry birds: unsupported blocks fall")
    -- A boulder straight at the murloc.
    local mr
    for r = 0, 13 do for c = 0, 8 do if ca.cells[r][c] and ca.cells[r][c].kind == "M" then mr = { r, c } end end end
    if mr then
        local x = C.X0 + mr[2] * C.CELL + C.CELL / 2
        local y = C.GROUND - mr[1] * C.CELL - C.CELL / 2
        ca.ball = { x = x - 30, y = y, vx = 300, vy = 0, t = 0, spin = 0 }
        ca.state = "flying"
        Run(ca, 3)
    end
    check(ca.score >= 500 + 300 * 2, "angry birds: the murloc is knocked out, with the bonus (" .. ca.score .. ")")
    check(ca.level == 2 and ca.state == "aim", "angry birds: the level clears and level 2 loads")
    -- A block landing on a murloc knocks it out.
    for r = 0, 13 do ca.cells[r] = {} end
    ca.cells[0][0] = { kind = "M" }
    ca.cells[2][0] = { kind = "S", hp = 2 }
    ca.murlocs = 1
    ca.state, ca.falling = "flying", true
    Run(ca, 1)
    check(ca.murlocs == 0, "angry birds: a falling block squashes a murloc")
    Run(ca, 2)
    -- Mouse drag: pulling back and down aims up and right.
    check(ca.state == "aim", "angry birds: level 3 ready")
    ca.dragging = true
    MOUSE_DOWN = true
    ca.Cursor = function() return C.SLING_X - 30, C.SLING_Y + 30 end
    Run(ca, 0.05)
    check(ca.angle > 0.6 and ca.angle < 0.95 and ca.power > 0.7, "angry birds: dragging back aims (" .. string.format("%.2f %.2f", ca.angle, ca.power) .. ")")
    MOUSE_DOWN = false
    Run(ca, 0.05)
    check(ca.state == "flying", "angry birds: letting go fires")
    ca.Cursor = nil
    -- No boulders, murlocs left: over.
    for _ = 1, 10 do
        if not ca.running then break end
        Run(ca, 6)
        if ca.state == "aim" then ca.angle, ca.power = 1.4, 0.2; C:Key(ca, "SPACE") end
    end
    check(not ca.running and ca.overlayText:GetText() == "Out of boulders", "angry birds: out of boulders ends the run")
    ns.Cards.Tick(true)
end
