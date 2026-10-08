# Makes the Warcraft maps (Games/Warcraft/Maps.lua) from short specs: python dev/make_maps.py
# Each spec draws one side; rot180 adds the other side turned round, so maps
# are exactly fair. Tiles: "." open, "T" tree; anchors (top-left of the
# footprint): "1".."9" start (a 4x4 hall), "G" gold mine (3x3).
import os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Games", "Warcraft", "Maps.lua")
RIVERFORD = open(os.path.join(HERE, "maps", "riverford.txt")).read().split()

class Map:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.g = [['.'] * w for _ in range(h)]
        s.anchors = []  # (ch, x, y, size)
    def trees(s, x, y, w, h):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < s.w and 0 <= yy < s.h: s.g[yy][xx] = 'T'
    def clear(s, x, y, w, h):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < s.w and 0 <= yy < s.h: s.g[yy][xx] = '.'
    def border(s, n=2):
        s.trees(0, 0, s.w, n); s.trees(0, s.h - n, s.w, n); s.trees(0, 0, n, s.h); s.trees(s.w - n, 0, n, s.h)
    def start(s, n, x, y): s.anchors.append((str(n), x, y, 4))
    def mine(s, x, y): s.anchors.append(('G', x, y, 3))
    def shop(s, x, y): s.anchors.append(('S', x, y, 2))
    def camp(s, kind, x, y): s.anchors.append((kind, x, y, 1))  # e / m / h
    def merc(s, x, y): s.anchors.append(('X', x, y, 2))
    def mirror4(s):
        # Four corners alike: trees and anchors mirrored left-right and top-bottom
        # (start 1 top left, 3 top right, 4 bottom left, 2 bottom right).
        g2 = [row[:] for row in s.g]
        for y in range(s.h):
            for x in range(s.w):
                for (xx, yy) in ((s.w - 1 - x, y), (x, s.h - 1 - y), (s.w - 1 - x, s.h - 1 - y)):
                    if s.g[yy][xx] == 'T': g2[y][x] = 'T'
        s.g = g2
        swapx = {'1': '3', '3': '1', '2': '4', '4': '2'}
        swapy = {'1': '4', '4': '1', '2': '3', '3': '2'}
        both = {'1': '2', '2': '1', '3': '4', '4': '3'}
        for ch, x, y, size in list(s.anchors):
            s.anchors.append((swapx.get(ch, ch), s.w - x - size, y, size))
            s.anchors.append((swapy.get(ch, ch), x, s.h - y - size, size))
            s.anchors.append((both.get(ch, ch), s.w - x - size, s.h - y - size, size))
        # (the middle shop mirrors onto itself: keep one)
        seen, keep = set(), []
        for a in s.anchors:
            if (a[1], a[2]) not in seen:
                seen.add((a[1], a[2])); keep.append(a)
        s.anchors = keep
    def rot180(s, pairs={'1': '2', '3': '4', '5': '6', '7': '8'}):
        # Trees: union with the turned copy. Anchors: turned copies.
        g2 = [row[:] for row in s.g]
        for y in range(s.h):
            for x in range(s.w):
                if s.g[s.h - 1 - y][s.w - 1 - x] == 'T': g2[y][x] = 'T'
        s.g = g2
        for ch, x, y, size in list(s.anchors):
            s.anchors.append((pairs.get(ch, ch), s.w - x - size, s.h - y - size, size))
    def rows(s):
        g = [row[:] for row in s.g]
        for ch, x, y, size in s.anchors:  # footprints stay clear (with a ring around)
            ring = 2 if size == 1 else 1
            for yy in range(y - ring, y + size + ring):
                for xx in range(x - ring, x + size + ring):
                    if 2 <= xx < s.w - 2 and 2 <= yy < s.h - 2: g[yy][xx] = '.'
        for ch, x, y, size in s.anchors: g[y][x] = ch
        return [''.join(r) for r in g]

maps = []

# Riverford: the original map (64 x 40), unchanged.
def with_camps(rows, camps):
    g = [list(r) for r in rows]
    w, h = len(g[0]), len(g)
    for kind, x, y in camps:
        size = 2 if kind in 'SX' else 1
        for (xx, yy) in ((x, y), (w - x - size, h - y - size)):
            g[yy][xx] = kind
    return [''.join(r) for r in g]

RIVERFORD = with_camps(RIVERFORD, [('m', 16, 33), ('e', 32, 4), ('h', 31, 22), ('S', 40, 12), ('X', 20, 30)])
maps.append(dict(key='riverford', name='Riverford', players=2, symmetry='rot180', rows=RIVERFORD,
    text='The first map: two bases in opposite corners, a gold mine each and one to expand to.'))

# Echo Ford (80 x 56): a forest band across the middle with three fords;
# a natural expansion by each base, two contested mines in the middle.
m = Map(80, 56); m.border()
m.start(1, 6, 6); m.mine(15, 4); m.mine(4, 20)
m.trees(2, 26, 30, 3); m.trees(36, 24, 10, 3)            # the band (turned: the other half)
m.clear(14, 26, 5, 3)                                     # a ford on the west
m.trees(22, 8, 4, 10); m.trees(10, 14, 6, 3)              # base edge
m.mine(36, 16)                                            # middle mine, north of the band
m.camp('m', 8, 23); m.camp('h', 39, 20); m.camp('e', 30, 6)
m.shop(42, 8); m.merc(10, 36)
m.trees(50, 4, 6, 6); m.trees(28, 36, 4, 4)
m.rot180()
maps.append(dict(key='echo_ford', name='Echo Ford', players=2, symmetry='rot180', rows=m.rows(),
    text='Bigger (80 x 56): a forest band splits the map, crossed at three fords. A natural expansion by each base, two contested mines in the middle.'))

# Lost Grove (64 x 64): starts at the top and bottom; a grove in the centre
# hides two rich mines.
m = Map(64, 64); m.border()
m.start(1, 30, 4); m.mine(22, 3); m.mine(4, 14)
m.trees(2, 22, 18, 4); m.trees(44, 22, 18, 4)
m.trees(24, 26, 16, 3); m.clear(30, 26, 4, 3)            # the grove's north wall with a gap
m.trees(22, 29, 2, 6)                                     # the grove's sides
m.mine(26, 30)                                            # inside the grove
m.camp('h', 30, 31); m.camp('m', 6, 18); m.camp('e', 46, 6)
m.shop(8, 30); m.merc(44, 16)
m.trees(40, 10, 6, 6); m.trees(12, 8, 4, 4)
m.rot180()
maps.append(dict(key='lost_grove', name='Lost Grove', players=2, symmetry='rot180', rows=m.rows(),
    text='Square (64 x 64), bases top and bottom. A walled grove in the centre holds two mines; the side paths go round it.'))

# Duel Pass (48 x 32): small and fast; one mine each, a single pass in the
# middle and a long way round.
m = Map(48, 32); m.border()
m.start(1, 4, 4); m.mine(11, 3)
m.trees(16, 2, 4, 12); m.trees(2, 16, 22, 3); m.clear(20, 16, 4, 3)
m.camp('e', 26, 6)
m.shop(30, 12)
m.rot180()
maps.append(dict(key='duel_pass', name='Duel Pass', players=2, symmetry='rot180', rows=m.rows(),
    text='Small and quick (48 x 32): one mine each, a pass in the middle and a long way round. Rush or be rushed.'))

# Four Crowns (96 x 64): 2v2 (or four players), a base in each corner,
# Lost Temple-like: a ring of expansions round a central plateau.
m = Map(96, 64); m.border()
m.start(1, 6, 6); m.mine(15, 4)
m.start(3, 86, 6); m.mine(78, 4)
m.mine(30, 18); m.mine(62, 18)
m.trees(40, 26, 16, 3); m.clear(46, 26, 4, 3)
m.trees(2, 24, 14, 3); m.trees(80, 24, 14, 3)
m.trees(24, 10, 4, 8); m.trees(68, 10, 4, 8)
m.camp('m', 31, 15); m.camp('m', 63, 15); m.camp('h', 47, 31); m.camp('e', 8, 20); m.camp('e', 86, 20)
m.shop(44, 20); m.merc(20, 30)
m.rot180()
maps.append(dict(key='four_crowns', name='Four Crowns', players=4, symmetry='rot180', rows=m.rows(),
    text='2v2 or four players (96 x 64): a base in each corner, expansions round a central clearing.'))

# Frenzy Fields (64 x 64): Footmen Frenzy for four, a barracks in each corner
# behind a wall with two gaps (to the neighbours and to the middle); a shop
# in the middle.
m = Map(64, 64); m.border()
m.start(1, 6, 6)
m.trees(2, 16, 10, 3); m.trees(16, 2, 3, 10)      # the corner's walls
m.trees(15, 15, 4, 4)                              # a pillar by the diagonal gap
m.trees(26, 10, 3, 6); m.trees(10, 26, 6, 3)       # cover on the edges
m.trees(24, 24, 3, 3)                              # round the middle
m.shop(31, 31)
m.mirror4()
maps.append(dict(key='frenzy_fields', name='Frenzy Fields', players=4, symmetry='rot180', modes='footmen', rows=m.rows(),
    text='Footmen Frenzy for four: a barracks in each corner, paths to both neighbours and the middle, a shop in the centre.'))

# Tower Defense (Line Tower Wars): a lane per player side by side, 10 tiles
# wide between walls of trees (2 thick). Creeps come in at the top (row 2),
# towers go in rows 5..32, row 33 is the exit; under it the player's gate
# (the start, 4 x 4) in a pocket. Games/Warcraft/TowerDefense.lua reads the
# lanes from the starts (lane x = start x - 3).
def td_map(n):
    w = max(12 * n + 2, 40)
    w += (w - (12 * n - 2)) % 2
    h = 40
    margin = (w - (12 * n - 2)) // 2
    g = [['T'] * w for _ in range(h)]
    for i in range(n):
        x0 = margin + i * 12
        for y in range(2, 34):
            for x in range(x0, x0 + 10): g[y][x] = '.'
        for y in range(34, 38):
            for x in range(x0 + 3, x0 + 7): g[y][x] = '.'
        g[34][x0 + 3] = str(i + 1)
    return [''.join(r) for r in g]

for n, key, name in ((2, 'td_duel', 'Tower Duel'), (4, 'td_four', 'Four Lanes'), (8, 'td_eight', 'Eight Lanes')):
    maps.append(dict(key=key, name=name, players=n, symmetry='none', modes='td', rows=td_map(n),
        text=f'Tower Defense for up to {n}: a lane each. Build a maze of towers; what gets through costs a life.'))

def lua_str(s): return '"' + s + '"'

out = ['''-- Warcraft III maps: a grid of text, one character per tile.
--   .  open ground        T  tree
--   1..9  a start (the top-left tile of its 4 x 4 hall)
--   G  a gold mine (the top-left tile of its 3 x 3 footprint)
--   S  a shop for everyone (the top-left tile of its 2 x 2 footprint): a Goblin Merchant
--   X  a Mercenary Camp (2 x 2): hire creeps there
--   e m h  a creep camp: easy, medium, hard (its middle; Creeps.lua)
-- mode: the game mode the map is for ("melee", "footmen", "td").
-- symmetry "rot180": the map is the same turned round (start 1 <-> 2,
-- 3 <-> 4), so both sides are fair; the tests check it. Made by a script
-- (dev/make_maps.py), but fine to edit by hand: keep it symmetric.
-- players: how many starts it has (a map fits games of that many or fewer).
local ADDON, ns = ...
local WC = ns.WC
WC.Maps = {}
WC.MAP_ORDER = {}
''']
for m in maps:
    out.append(f'WC.Maps.{m["key"]} = {{ name = {lua_str(m["name"])}, players = {m["players"]}, symmetry = "{m["symmetry"]}", mode = "{m.get("modes", "melee")}",')
    out.append(f'    text = {lua_str(m["text"])},')
    out.append('    grid = {')
    for r in m['rows']: out.append('        ' + lua_str(r) + ',')
    out.append('    } }')
    out.append(f'table.insert(WC.MAP_ORDER, "{m["key"]}")')
    out.append('')
out.append(r'''-- Read a map's grid once: size, trees, starts, mines.
function WC.ParseMap(key)
    local m = WC.Maps[key]
    if not m then return nil end
    if m.parsed then return m.parsed end
    local p = { h = #m.grid, w = #m.grid[1], trees = {}, starts = {}, mines = {}, shops = {}, camps = {}, mercs = {} }
    for y, row in ipairs(m.grid) do
        for x = 1, #row do
            local c = row:sub(x, x)
            if c == "T" then
                table.insert(p.trees, { x - 1, y - 1 })
            elseif c == "G" then
                table.insert(p.mines, { x - 1, y - 1 })
            elseif c == "S" then
                table.insert(p.shops, { x - 1, y - 1 })
            elseif c == "X" then
                table.insert(p.mercs, { x - 1, y - 1 })
            elseif c == "e" or c == "m" or c == "h" then
                table.insert(p.camps, { x - 1, y - 1, c })
            elseif c:match("%d") then
                p.starts[tonumber(c)] = { x - 1, y - 1 }
            end
        end
    end
    m.parsed = p
    return p
end

-- The maps that fit a game of n players (in a mode: default melee).
function WC.MapsFor(n, mode)
    local out = {}
    for _, key in ipairs(WC.MAP_ORDER) do
        local m = WC.Maps[key]
        if m.players >= (n or 2) and (m.mode or "melee") == (mode or "melee") then table.insert(out, key) end
    end
    return out
end

-- Problems with a map (for the tests): rows the same width, starts and
-- mines on open ground, a mine near every start, the starts reach each
-- other, and the symmetry holds.
function WC.CheckMap(key)
    local m, p = WC.Maps[key], WC.ParseMap(key)
    local bad = {}
    for y, row in ipairs(m.grid) do
        if #row ~= p.w then table.insert(bad, "row " .. y .. " is " .. #row .. " wide") end
    end
    local function Tile(x, y)
        local row = m.grid[y + 1]
        return row and row:sub(x + 1, x + 1) or "T"
    end
    local function Clear(x, y, size)
        for yy = y, y + size - 1 do
            for xx = x, x + size - 1 do
                local c = Tile(xx, yy)
                if c == "T" or (c ~= "." and not (xx == x and yy == y)) then return false end
            end
        end
        return true
    end
    for n = 1, m.players do
        local s = p.starts[n]
        if not s then
            table.insert(bad, "no start " .. n)
        else
            if not Clear(s[1], s[2], 4) then table.insert(bad, "start " .. n .. " is not clear") end
            local near = (m.mode or "melee") ~= "melee" -- (only melee needs mines)
            for _, g in ipairs(p.mines) do
                if math.abs(g[1] - s[1]) + math.abs(g[2] - s[2]) <= 16 then near = true end
            end
            if not near then table.insert(bad, "start " .. n .. " has no mine near") end
        end
    end
    for _, g in ipairs(p.mines) do
        if not Clear(g[1], g[2], 3) then table.insert(bad, "mine at " .. g[1] .. "," .. g[2] .. " is not clear") end
    end
    for _, list in ipairs({ p.shops, p.mercs }) do
        for _, g in ipairs(list) do
            if not Clear(g[1], g[2], 2) then table.insert(bad, "shop at " .. g[1] .. "," .. g[2] .. " is not clear") end
        end
    end
    -- Every start reaches start 1 (open tiles, four ways).
    local open, seen = {}, {}
    for y = 0, p.h - 1 do for x = 0, p.w - 1 do open[y * p.w + x] = Tile(x, y) ~= "T" end end
    for _, g in ipairs(p.mines) do
        for yy = g[2], g[2] + 2 do for xx = g[1], g[1] + 2 do open[yy * p.w + xx] = false end end
    end
    for _, list in ipairs({ p.shops, p.mercs }) do
        for _, g in ipairs(list) do
            for yy = g[2], g[2] + 1 do for xx = g[1], g[1] + 1 do open[yy * p.w + xx] = false end end
        end
    end
    local s1 = p.starts[1]
    if s1 and (m.mode or "melee") ~= "td" then -- (Tower Defense lanes are walled off on purpose)
        local q, head = { (s1[2] + 4) * p.w + s1[1] + 4 }, 1
        seen[q[1]] = true
        while head <= #q do
            local i = q[head]
            head = head + 1
            local x, y = i % p.w, math.floor(i / p.w)
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = x + d[1], y + d[2]
                local j = ny * p.w + nx
                if nx >= 0 and ny >= 0 and nx < p.w and ny < p.h and open[j] and not seen[j] then
                    seen[j] = true
                    table.insert(q, j)
                end
            end
        end
        for n = 2, m.players do
            local s = p.starts[n]
            if s and not seen[(s[2] + 4) * p.w + s[1] + 4] and not seen[(s[2] - 1) * p.w + s[1] - 1] then
                table.insert(bad, "start " .. n .. " can't be reached from start 1")
            end
        end
    end
    if m.symmetry == "rot180" then
        local pair = { ["1"] = "2", ["2"] = "1", ["3"] = "4", ["4"] = "3", ["5"] = "6", ["6"] = "5", ["7"] = "8", ["8"] = "7" }
        local function Same(a, b) return (a == "T") == (b == "T") and (a:match("[emh]") or ".") == (b:match("[emh]") or ".") end
        -- (2 x 2 anchors land on the other corner of their footprint when turned: checked by their twins)
        for y = 0, p.h - 1 do
            for x = 0, p.w - 1 do
                if not Same(Tile(x, y), Tile(p.w - 1 - x, p.h - 1 - y)) then
                    table.insert(bad, "not symmetric at " .. x .. "," .. y)
                    break
                end
            end
        end
        for n, s in pairs(p.starts) do
            local o = p.starts[tonumber(pair[tostring(n)] or n)]
            if not o or o[1] ~= p.w - s[1] - 4 or o[2] ~= p.h - s[2] - 4 then table.insert(bad, "start " .. n .. " has no twin") end
        end
    end
    return #bad == 0, bad
end
''')
open(OUT, 'w', encoding='utf-8').write('\n'.join(out))
for m in maps[1:]:
    print('==', m['name']); print('\n'.join(m['rows']))
