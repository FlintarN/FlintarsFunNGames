-- Agar.io: an Arcade live game. Eat the dots to grow, swallow smaller
-- players, don't get swallowed. Everyone runs the arena on their own
-- client and shares only their own blob (Core\Live.lua); food is local.
--
-- The lobby (Session) decides who's in: open it to your group, guild,
-- realm or a code. Players can drop in while the arena is open.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "agario",
    arcade = true,
    live = true,
    name = "Agar.io",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconAgario",
    short = "Eat the dots to grow, swallow smaller players, don't get swallowed.",
    rules = "Steer your blob with W A S D or by holding the left mouse button. Eat dots to grow. Touch a blob "
        .. "clearly smaller than you to swallow it; stay away from bigger ones. Big blobs are slow.",
    minPlayers = 1,
    maxPlayers = 20,
    practiceBots = 4,
    joinAnytime = true,
    fields = {},
    afterGame = {},
}
ns.Games.agario = G

-- The arena, shared by everyone's client.
G.ARENA_W, G.ARENA_H = 2400, 1700
G.FOOD = 220
G.START_R, G.MAX_R = 10, 300
G.SPEED = 150           -- world units per second at the start size
G.EAT_RATIO = 0.85      -- you swallow blobs under 85% of your size
G.SHRINK = 0.003        -- share of your mass lost per second above the start size

-- Growing goes by area, as in the real game: a dot adds the same mass to
-- everyone (so it matters less the bigger you are), a swallowed blob adds
-- most of its mass.
function G.Feed(r)
    return math.min(G.MAX_R, math.sqrt(r * r + 14))
end

function G.Swallow(r, other)
    return math.min(G.MAX_R, math.sqrt(r * r + other * other * 0.85))
end

function G.Decay(r, dt)
    if r <= G.START_R then return r end
    return math.max(G.START_R, r * (1 - G.SHRINK * dt))
end

-- The camera zooms out as you grow, so big blobs still see around them.
function G.Zoom(r)
    return math.max(0.3, math.min(1, (24 / r) ^ 0.55))
end

function G:Setup(s) end

function G:Begin(s)
    s.banner = "The arena is open! Players can drop in any time."
end

function G:Expect() return nil end

function G:Act(s, name, action)
    if action ~= "end" or name ~= s.host then return false end
    s.phase = "done"
    s.result = { summary = "Agar.io" }
    s.banner = "The arena is closed."
    return true
end

function G:Status(s)
    if s.phase == "lobby" then return #s.players .. " ready" end
    if s.phase == "rolling" then return "Arena open" end
end

function G:RangeText() return nil end
function G:RollText() return "" end
