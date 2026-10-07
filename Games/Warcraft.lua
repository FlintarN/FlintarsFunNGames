-- Warcraft III: a small real-time strategy game against the computer, on
-- the engine in Games\Warcraft\ (data, engine, AI) and the page in
-- UI\WarcraftPage.lua. The engine is deterministic plain data, so PvP later
-- means both clients running it with the same commands.
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "warcraft",
    arcade = true,
    solo = true,
    name = "Warcraft III",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconWarcraft",
    short = "Real-time strategy: gather gold and lumber, build a base, crush the enemy.",
    how = "Left-click or drag to select, right-click to move, attack or gather. A attacks, S stops.",
    rules = "Gather gold and lumber, build farms and barracks, train an army and destroy every enemy building.",
    scoreLabel = "Wins",
    window = { 760, 560 },
    fullscreen = true, -- offers a Fullscreen button
    fields = {},
}
ns.Games.warcraft = G
