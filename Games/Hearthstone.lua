-- Hearthstone: a solo Arcade card game against the computer, on the
-- rules engine in Games\Hearthstone\ (cards, heroes, engine, AI) and the
-- board in UI\HearthstonePage.lua. The engine is pure state, so PvP later
-- means a host running it and sending each player their view (E.View).
local ADDON, ns = ...

ns.Games = ns.Games or {}

local G = {
    key = "hearthstone",
    arcade = true,
    solo = true,
    name = "Hearthstone",
    icon = "Interface\\AddOns\\FlintarsFunNGames\\Art\\IconHearthstone",
    short = "The card game: pick a hero, play minions and spells, beat the computer.",
    how = "Click a card to play it, click a minion then a target to attack. Right-click cancels.",
    rules = "Bring the enemy hero from 30 Health to 0 with minions, spells and your hero power.",
    scoreLabel = "Wins",
    window = { 760, 560 }, -- the main window grows for this game
    fields = {},
}
ns.Games.hearthstone = G
