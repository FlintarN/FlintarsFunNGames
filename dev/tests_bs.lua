-- Battleship: boards, answers, the check, practice and a code lobby.
local BS = ns.Games.battleship
local S = ns.Session

do
    local b = BS.Empty()
    local cells = BS.Cells(b, 1, 1, 4, true)
    check(cells and #cells == 4, "a carrier fits across the top row")
    b = BS.Put(b, cells, 1)
    check(BS.Cells(b, 1, 3, 3, false) == nil, "ships can't overlap")
    check(BS.Cells(b, 1, 6, 4, true) == nil, "ships can't stick out")
    check(not BS.Complete(b), "one ship isn't a fleet")
    local r = BS.Random()
    check(BS.Complete(r), "Random places the whole fleet")
    local shots = {}
    check(BS.Answer(b, shots, 2, 2) == "miss", "water is a miss")
    check(BS.Answer(b, shots, 1, 1) == "hit", "a ship is a hit")
    shots["1,1"], shots["1,2"], shots["1,3"] = "hit", "hit", "hit"
    check(BS.Answer(b, shots, 1, 4) == "sunk:1", "the last cell sinks it")

    -- The check after a game.
    local s = { players = { { name = "A" }, { name = "B" } }, commits = {}, reveals = {}, shots = { A = {} } }
    local salt = "abc123"
    s.commits.A = BS.Seal(r, salt)
    s.reveals.A = { board = r, salt = salt }
    for key in pairs({ ["1,1"] = 1, ["5,5"] = 1, ["8,8"] = 1 }) do
        local rr, cc = key:match("(%d),(%d)")
        s.shots.A[key] = BS.Cell(r, tonumber(rr), tonumber(cc)) ~= 0 and "hit" or "miss"
    end
    check(BS.Check(s, "A") == true, "an honest board checks out")
    s.reveals.A = { board = BS.Random(), salt = salt }
    check(BS.Check(s, "A") == false, "a swapped board is caught by the seal")
    s.reveals.A = { board = r, salt = salt }
    local liar = nil
    for i = 1, 64 do
        local rr, cc = math.floor((i - 1) / 8) + 1, (i - 1) % 8 + 1
        if BS.Cell(r, rr, cc) ~= 0 and not s.shots.A[BS.Key(rr, cc)] then liar = BS.Key(rr, cc) break end
    end
    s.shots.A[liar] = "miss"
    check(BS.Check(s, "A") == false, "calling a hit a miss is caught")
end

local function View() return ns.UI.pages.battleship.view end

function BsOpen()
    if not ns.UI.frame then SlashCmdList.FUNNGAMES("") end
    ns.UI.frame:Show()
    ns.UI:SelectTab("battleship")
    Advance(0)
end

-- Fire at the first square not fired at yet, on my turn.
function BsFire()
    local s = S.Get("battleship")
    if not (s and s.stage == "battle" and S.MyTurn(s)) then return false end
    BsOpen()
    local other
    for _, p in ipairs(s.players) do if p.name ~= PLAYER_NAME then other = p.name end end
    for r = 1, 8 do
        for c = 1, 8 do
            if not s.shots[other][BS.Key(r, c)] then
                View().theirCells[r][c]._scripts.OnClick()
                return true
            end
        end
    end
end

function BsPlace()
    BsOpen()
    local view = View()
    -- Place one ship by hand, then the rest at random.
    view.myCells[1][1]._scripts.OnClick(view.myCells[1][1], "LeftButton")
    check(BS.Cell(view.board, 1, 1) == 1 and BS.Cell(view.board, 1, 4) == 1, "battleship: the carrier goes where you click")
    view.myCells[1][1]._scripts.OnClick(view.myCells[1][1], "RightButton")
    check(view.horiz == false, "battleship: right-click turns the next ship")
    view.random._scripts.OnClick()
    check(BS.Complete(view.board), "battleship: Random completes the fleet")
    check(view.ready._enabled ~= false, "battleship: Ready once the fleet is placed")
    view.ready._scripts.OnClick()
    local s = S.Get("battleship")
    local mine = BS.mine[s.id]
    check(mine and #BS.Seal(mine.board, mine.salt) == 64, "battleship: your fleet is sealed")
    check(not ns.Serialize.Encode(s):find(view.board, 1, true), "battleship: your board isn't in the shared game")
end

function BsPractice()
    BsOpen()
    View().practiceButton._scripts.OnClick()
    Advance(2)
    local s = S.Get("battleship")
    View().buttons.start._scripts.OnClick()
    check(s.stage == "placing" and s.ready.Ragnar, "battleship: the bot has placed its fleet")
    BsPlace()
    check(s.stage == "battle" and s.shooter == "Flintar", "battleship: battle, you fire first")
    for _ = 1, 200 do
        if s.phase ~= "rolling" then break end
        BsFire()
        Advance(2)
    end
    check(s.phase == "done" and s.result.winner, "battleship: someone sank the whole fleet")
    check(BS.Check(s, "Flintar") == true and BS.Check(s, "Ragnar") == true, "battleship: both boards check out")
    View().buttons.rematch._scripts.OnClick()
    check(s.stage == "placing" and s.games == 2, "battleship: rematch, place again")
    View():CloseLobby()
end

-- Two real players.
function BsHost()
    BsOpen()
    ns.db.arcadeScope = "code"
    Advance(0)
    View().createButton._scripts.OnClick()
    return S.Get("battleship").code
end

function BsJoinCode(code)
    BsOpen()
    View().codeBox:SetText(code)
    View().codeBox._scripts.OnEnterPressed(View().codeBox)
end

function BsStart() View().buttons.start._scripts.OnClick() end

function BsDone()
    local s = S.Get("battleship")
    return s and s.phase == "done"
end

function BsCheckEnd(expectBob)
    local s = S.Get("battleship")
    check(s.phase == "done", "battleship: " .. PLAYER_NAME .. " sees the game over")
    check(BS.Check(s, "Flintar") == true, "battleship: " .. PLAYER_NAME .. " checked Flintar's board")
    check(BS.Check(s, "Bob") == expectBob, "battleship: " .. PLAYER_NAME .. " checked Bob's board (" .. tostring(BS.Check(s, "Bob")) .. ")")
end

-- Bob's addon lies: every shot at him is a miss.
function BsCheat()
    BS.Answer = function() return "miss" end
end
