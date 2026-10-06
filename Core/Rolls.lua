-- Rolls: the game's own /roll is the only source of numbers.
--
-- The Roll! button asks the game to roll. The result comes back as a system
-- message ("Bob rolls 37 (1-100)") that everyone in the group sees, so no
-- addon can make up a number. Every client also remembers the rolls it saw,
-- so it can check the host's numbers against its own.
local ADDON, ns = ...

local R = {}
ns.Rolls = R

local SEEN_FOR = 30 * 60 -- seconds a roll stays checkable
R.seen = {}
local listeners = {}

-- "%s rolls %d (%d-%d)" -> "^(.+) rolls (%d+) %((%d+)%-(%d+)%)$", from the
-- client's own string so other languages work too.
local function BuildPattern()
    local s = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    s = s:gsub("%%%d%$", "%%") -- positional "%1$s" -> "%s"
    s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    s = s:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. s
end
R.PATTERN = BuildPattern()

-- Chat text without colours and links: "|Hplayer:Bob|h[Bob]|h" -> "Bob".
local function Plain(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end

function R.Parse(text)
    if type(text) ~= "string" then return end
    text = Plain(text)
    local name, roll, lo, hi = text:match(R.PATTERN)
    if not name then
        -- Fallback for clients that word it differently: a character name is
        -- one word, and the roll is the last "N (lo-hi)" in the message.
        roll, lo, hi = text:match("(%d+) %((%d+)%-(%d+)%)[^%d]*$")
        name = roll and text:match("^%[?([^%s%]]+)")
    end
    if not name then return end
    name = name:gsub("^%[(.*)%]$", "%1"):match("^%S+")
    return ns.Short(name), tonumber(roll), tonumber(lo), tonumber(hi)
end

function R.OnRoll(fn)
    table.insert(listeners, fn)
end

local function Prune()
    local cutoff = ns.Now() - SEEN_FOR
    while R.seen[1] and R.seen[1].t < cutoff do table.remove(R.seen, 1) end
end

-- A roll arrived: remember it, then let the games look at it.
function R.Dispatch(name, roll, lo, hi)
    Prune()
    table.insert(R.seen, { name = name, roll = roll, lo = lo, hi = hi, t = ns.Now() })
    for _, fn in ipairs(listeners) do fn(name, roll, lo, hi) end
end

-- Did this client see that exact roll itself?
function R.Saw(name, roll, lo, hi)
    for i = #R.seen, 1, -1 do
        local e = R.seen[i]
        if e.name == name and e.roll == roll and e.lo == lo and e.hi == hi then return true end
    end
    return false
end

-- Ask the game for a real roll.
function R.Roll(lo, hi)
    if RandomRoll then
        RandomRoll(lo, hi)
    elseif C_RandomRoll and C_RandomRoll.RandomRoll then
        C_RandomRoll.RandomRoll(lo, hi)
    end
end

ns.On("CHAT_MSG_SYSTEM", function(text)
    -- Newer clients can hand addons protected ("secret") text; reading it throws.
    if issecretvalue and issecretvalue(text) then
        if ns.debug then ns.Print("debug: a system message was protected, can't read it") end
        return
    end
    local name, roll, lo, hi = R.Parse(text)
    if ns.debug and type(text) == "string" and (name or text:find("%d+%-%d+")) then
        ns.Print("debug: " .. text:gsub("|", "||") .. " -> " .. (name and (name .. " " .. roll .. " (" .. lo .. "-" .. hi .. ")") or "not a roll"))
    end
    if name then R.Dispatch(name, roll, lo, hi) end
end)
