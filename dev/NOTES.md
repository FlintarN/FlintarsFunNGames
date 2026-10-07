# Developer notes

How Flintar's Fun 'n' Games is built, the conventions to keep, and what we learned the hard way. Not shipped (the `dev/` folder is left out of the package).

## Layout

| Folder | What lives there |
|---|---|
| `Core/` | No UI. `Init` (namespace, events, db, money helpers, slash), `Serialize`, `Fair` (SHA-256, shuffle), `Net` (addon messages, chunking, whispers), `Rolls` (reads `/roll` results), `Stats`, `Tab` (Settle up + trade watching), `Session` (the game engine) |
| `Games/` | One rules module per game: `DeathRoll`, `HighLow`, `Poker`, `Slots` |
| `UI/` | `Widgets`, `Cards` (card widget + tween engine), `Home`, `GamePage` (dice games), `PokerPage`, `SlotsPage`, `Help`, `SettlePage`, `StatsPage`, `Main` (window + tabs), `Minimap` |
| `Art/` | Our own `.tga` textures, drawn by `dev/make_art.py` |
| `dev/` | Test harness, art script, these notes |

## How a game works

- `Core/Session.lua` holds one session per game type. The **host's addon runs the game**; after every change it sends the whole game (`S`) to the group, and the other addons display that copy. Pages only draw: switching tabs never loses a game.
- A rules module implements `Setup`, `Begin`, `Expect(s, name)` (the roll range this player needs now, or nil), `Apply(s, name, roll)`, `Status`, `RangeText`, `RollText`. Card-style games add `IsTurn`, `Act(s, name, action)`, `BotAct`, `Options`. Flags: `minPlayers`, `maxPlayers`, `practiceBots`, `joinAnytime`, `fields` (setup inputs; `money = true` gives the gold/silver/copper box).
- **Adding a game**: rules module in `Games/`, add its key to `ns.GAME_ORDER` (Init), a custom page in `ns.CustomPages` if the dice page doesn't fit, a `Help.RULES` entry, TOC lines, tests.
- Keys starting with `_` (like `s._hole`, `s._secret`) are never sent. That's where the host keeps secrets.
- All money is **copper**. Show it with `ns.Money` (coin icons), `ns.Signed` (+/- colored), or `ns.MoneyPlain` for chat (icons can't go in chat messages).
- Finished non-practice games go to `Stats:Record`, which also adds the payments to the Settle up tab (`ns.Tab.AddGame`).

## Conventions

- Every sound goes through `W.PlaySound(kit, alert)` so Settings can mute it; pass `alert = true` for your-turn / disconnect alerts (own switch). Never call `PlaySound` directly.
- The window has a side (`UI:Side()`: "casino" or "arcade", from the home switch or the open game; Statistics/Settings keep it). Settle up, the home "Owed to you" line and the /roll footer are casino-only.
- Side tabs: Games, Settle up (casino side only), Statistics and Settings; a game's tab only while it has a session or is the current tab (`UI:LayoutTabs`). Don't add permanent tabs per game (the user asked for this).

- Look like the Forever client: `ButtonFrameTemplate` portrait window, icon side tabs, `W.Panel` (marble + bronze border). Our own art goes in `Art/` via `make_art.py`.
- **Buttons stay in place and grey out** (`SetEnabled(false)`) until usable. Hide a button only when it doesn't apply to you at all (host-only). **No glowing highlight boxes** on buttons: the user disliked them.
- Every multiplayer feature needs a **practice mode with bots**, so it can be tried alone. The real group test happens later, in one batch.
- Don't post to public chat. Whispers only when the user clicks something (Remind).
- One feature at a time; new ideas go into `TODO.md`.
- Keep `README.md`, `CURSEFORGE.md` and `CHANGELOG.md` up to date with every feature.

## Lessons learned

- A `/reload` picks up new addons and new files (`.lua`, `.tga`) in current clients; no full restart needed.
- **Lua and/or traps**: `cond and false or x` never gives false; `local a, b = x and f()` keeps only f's first return value (this crashed the Roll! tooltip in game). Use an explicit `if`.
- **Roll messages on Forever** didn't match a strict `^...$` pattern. `Rolls.Parse` strips colors and links, doesn't anchor the end, and falls back to "first word = name, last `N (lo-hi)` = roll". `/fng debug` prints what it reads.
- Texture **rotation animations only work on textures**, not frames. Animate the texture (`die.tex`).
- **One set of cards for every card game**: the widget, its art and the dealing (`ns.Cards.New`, `ns.Cards.Deal(card, want, x, y, animate, delay, fromX, fromY)`) live in `UI/Cards.lua` and `Art/Card*.tga`. Poker, Blackjack and the Hand rankings page all use them, so changing the cards is one change. Give overlapping cards their own frame levels (later card higher).
- Movement and flips are done with our own tween loop (`UI/Cards.lua`), not animation groups, so they work on any client. Card flip = squeeze the width to 0, swap face, open up; hide text while the card is thin (text doesn't squeeze).
- Never keep a reference to a table inside `ns.db` across calls (e.g. a game's saved settings): Settings can wipe or replace it (Reset game settings / Reset all). Look it up each time (bug: Practice crashed after Reset game settings).
- After an animation ends, call `ns.Changed()` if buttons depend on it (bug: Spin! stayed grey after the reels stopped).
- Forever's minimap is bigger than the classic one: place the button at `Minimap:GetWidth() / 2 + 10`, never a fixed radius.
- The marble panel background was too dark with a 45% black shade on top; 20% reads well.
- Cards and fair dealing: public `/roll`s alone can't deal hidden cards (every addon could compute them). We use a commit-reveal: SHA-256 seal of a host secret, a non-host `/roll` cut, whispered hole cards, reveal + verify after the hand. The host's addon can still peek; that's stated in the rules.
- WoW has a `bit` library (Lua 5.1 BitOp); the test harness (Lua 5.4) needs a shim in `dev/mock.lua`.
- Disconnects: `UNIT_CONNECTION` + `GROUP_ROSTER_UPDATE` + a 5 s heartbeat call `S.CheckConnections`. A name's unit token comes from looping party1..N / raid1..N (`UnitIsConnected` wants a unit). `p.offline` is detection, `p.out` is the host's decision (Skip / Bring back, `S.Drop` / `S.Undrop`, a switch that can be flipped any time: the user asked for no one-off prompt); each game's `Drop` / `Undrop` / `Rejoin` / `DropEnds` decides what that means. Keep game state reversible: e.g. High-Low keeps skipped players in its tie lists and filters them (`InOnly`) instead of deleting them. Practice bots go offline with `/fng dc <name>` (`S.fakeOffline`).
- A player's addon keeps its poker cards in `S.private` keyed by game id; forget them when the game is closed (`S.Dismiss`).
- Roulette: the number ring never rotates; only the ball moves (and the hub turns for show). That way the ball always ends exactly in the rolled pocket, whatever direction `SetRotation` turns on this client. Pocket i sits at a clockwise angle of (i-1) * 360/37 from the top, both in `make_art.py` and in `RoulettePage`.
- Chatty actions (roulette chips) use "soft" updates: the rules' `Act` returns `true, nil, true`, and `S.Update(s, true)` sends the game 0.4 s later, once. Players also bundle their own clicks into one slip sent half a second after the last click.
- Bots that act without a turn implement `BotThink(s, name)` (returns an action or nil); `DriveBots` calls it.
- Portraits (`W.Portrait`): `SetPortraitTexture(tex, unit)` with the class icon (`UI-Classes-Circles` + `CLASS_ICON_TCOORDS`) underneath as a fallback. The host stores `p.class` when someone sits down (`S.ClassOf`), so every client can show the class icon even when it can't resolve the unit.
- Scopes (`Core/Net.lua`): "group" (casino, always), "guild", "realm" (hidden channel `FunNGamesRealm`), "code:XXXXX" (hidden channel `FNG<code>`). A session's scope is `s.scope` (+ `s.code`); `Broadcast` sends on it, `ToHost` whispers the host outside a group. Incoming games outside a group go to `S.lobbies` (the browser) unless you're seated in them or typed their code (`S.pendingCode`); finished/cancelled games are never picked up again. Hosts re-announce open lobbies every 15 s (heartbeat). Arcade games set `arcade = true` and use `UI/Arcade.lua` for their setup panel.
- After a game ends, `HostAct` only allows actions the game lists in `afterGame` (Tic-Tac-Toe: `rematch`); a rematch uses `s.recordId` so each game records once.
- **Engines, so games don't rebuild the wheel**: `Session` = lobbies + turn-based host-run games; `Live` (`Core/Live.lua`) = real-time games on a Session lobby: `Live.Attach(s, {rate, timeout, onEvent})`, `Live.SetMine`, `Live.Tick` every frame, `Live.Event`, `rt.peers` + `Live.Smooth`; practice bots `Live.Feed` or are simulated by the page. `Kit` (`UI/Kit.lua`) = `Canvas`, `Pool`, `Loop`, `Keys` (captures only the game's keys, off in combat), `MouseDir`. Leaving the view (OnHide) must `Live.Detach` so others drop you.
- `G:OnState(s)` runs on a player's addon after every update of that game, tab open or not: for answers only that player can give (Battleship hit/miss) or end-of-game reveals. Secrets live outside the game table (`G.mine[s.id]`) or in `_` keys on the host.
- Arcade games share `UI/Arcade.lua` (setup panel, lobby browser, `CloseLobby`, `ScopeLine`); pages inherit from it with `setmetatable(P, { __index = ns.Arcade })`.
- Solo games: set `solo = true` and implement `Start / Step / Key / Click / Draw` (see `UI/Solo.lua`); call `view:SetScore` and `view:Over(score, text)`. `lowerIsBetter` for times, `FormatScore` for display, `typing = true` when P is a letter (Wordle) so it doesn't pause. `view:Cursor()` gives the mouse in canvas coordinates (for drag aiming). Careful with `next(Find(x))` when Find returns two values: wrap it, `next((Find(x)))`. Game files load before the UI, so they reach `ns.Kit` / `ns.Widgets` lazily (a small `setmetatable` proxy at the top).
- **Hearthstone** (`Games/Hearthstone/`): `Cards.lua` and `Heroes.lua` are data (effects as `{ op = "damage", to = "target", amount = 6, spell = true }`), `Engine.lua` is the whole rules engine on one plain table (no functions inside, seeded Park-Miller RNG, so it can be saved, copied and sent), `AI.lua` tries every legal action on a copy and keeps the best board (two steps for setup moves like The Coin), so new cards need no AI code. `E.Apply` returns events; `UI/HearthstonePage.lua` animates them and redraws from the state. A played minion keeps its hand card's id so the UI can fly it to the board. For PvP: host runs the engine, sends `E.View(st, i)` per player.
- A game can ask for a bigger window with `G.window = { w, h }` (`UI:ApplySize` resizes smoothly on tab change, keeping the top-left corner). Pages for such a game are laid out for the bigger size.
- **Warcraft III** (`Games/Warcraft/`): `Data.lua` (units, buildings, factions, map), `Engine.lua` (the whole game on one plain table: entities in creation order in `st.list`, A* over tiles, orders as data, seeded RNG; `E.Step(st, dt)` and `E.Command(st, p, cmd)` only), `AI.lua` (build order and waves, using `E.Command` like a player). `UI/WarcraftPage.lua` steps the engine at 20 Hz, runs the AI once a second, and pauses when the tab is hidden. Tests play whole AI-vs-AI games.
- Drop-in games (`joinAnytime`) stay in the lobby browser while running, and hosts keep announcing them.
- Payment tracking: `TRADE_SHOW` + `UnitName("NPC")` gives the partner; snapshot `GetPlayerTradeMoney` / `GetTargetTradeMoney` on `TRADE_MONEY_CHANGED` / `TRADE_ACCEPT_UPDATE` (the values clear on close); the trade is done on `UI_INFO_MESSAGE` = `ERR_TRADE_COMPLETE`, which can come after `TRADE_CLOSED`. Count a payment only up to what's owed.

## Test harness

- `node dev/run.mjs`: about 900 checks. Rules, practice games through the real UI code, the trade watcher, and group games with 2-3 simulated players (one wasmoon Lua VM each; addon messages, whispers and rolls passed between them).
- Uses wasmoon from `e:/Projekter/WebAddonDemo/node_modules`.
- **wasmoon gotcha**: hundreds of `lua.doString('return x')` calls corrupt the VM. Read values through a global (`__ret = x`, then `lua.global.get('__ret')`), as `Get()` in `run.mjs` does.
- Bots play randomly, so the number of checks changes from run to run. Run it a few times after changes to game logic.
- Add a mock to `dev/mock.lua` when the addon starts using a new WoW API (the mock returns no-op functions for unknown methods, but not values).

## Release checklist

1. `node dev/run.mjs` passes, a few times in a row.
2. Bump `## Version` in all TOC files: `FlintarsFunNGames_Forever.toc` (WoW Forever, Interface 16001; Forever runs on the retail engine with its own `_Forever` suffix) and the base `FlintarsFunNGames.toc` are identical; `_Mainline.toc` (Retail, Interface 120100 for 12.1) differs only in `## Interface`. Add new files to all three (a test checks they match).
3. Add the version to `CHANGELOG.md`; update `README.md` and `CURSEFORGE.md`.
4. Full client restart, then try each game in practice.
5. Package: `.pkgmeta` leaves out `dev/`, `TODO.md`, `README.md` and `CURSEFORGE.md`.
