# Flintar's Fun 'n' Games TODO

One thing at a time, top to bottom. Move an item to Done when it is built and tested.

## In progress

- [ ] Try Poker, Settle up and the Slot Machine against bots in game (v0.4): looks, animations, flow.

## Next

- [ ] **Arcade** (fun games, no gambling): a second section on the home page next to the Casino.
  1. ~~Lobbies with a scope (Group / Guild / Realm / Private code), lobby browser, whisper to host, Tic-Tac-Toe~~ (done, see Done).
  2. Port HearthPhone's games, all on shared engines (no game builds its own networking):
     - Solo games, next batch: Temple Run, Subway Surfers, Survivor (Roguelike), Tower Defense.
  Note: casino games stay group-only (/roll fairness needs a group) unless we add combined sealed-secret dice.

- [ ] Final name (front-runner: High Roller; also liked: All In). Check CurseForge for clashes, then rename (folder, TOC, SavedVariables, prefix, slash, slot sign, docs).
- [ ] One big group test with friends, all games: pop-up and Join, rolls picked up from other players, check marks, poker hole cards by whisper, deal check, stats on both sides.

## Later

- [ ] Arcade outside a group: disconnects aren't detected yet (the group-based check doesn't apply); add a presence ping.

- [ ] Blackjack: split pairs, insurance.
- [ ] Raffle: several prizes (1st, 2nd, 3rd), a timer that draws by itself.
- [ ] More of our own art: felt texture, dice faces, chips (cards, suits and the poker icon are done).
- [ ] Poker: players leaving mid-table (skip their turn / fold them), a turn timer.
- [ ] Dice face animation: show the die landing on the rolled face, not just tumbling.
- [ ] Play with someone outside your group (nearby / whisper): rolls are only seen nearby, so it needs a range check.
- [ ] Guild games (rolls of far-away guildies are not seen, so this needs another way to verify).
- [ ] "Paid" button: mark a debt as paid, and a trade helper that fills in the gold.
- [ ] Host tools: remove a player, last call, remind players who have not rolled, skip a player who left mid-game.
- [ ] Optional chat announcements of results.
- [ ] CurseForge listing and packaging.

- [ ] Hearthstone next steps: PvP (host runs the engine, players get `E.View`; hidden hands go by whisper like poker), mulligan, weapons, secrets, deathrattle cards, Classic-set class cards (secrets, combo, stealth, enrage), a card choice for Tracking.

- [ ] Warcraft III next: heroes from the altars (Altar of Kings / Altar of Storms are buildable but empty), Blacksmith/War Mill upgrades, Scout Tower to Guard Tower upgrade, orc War Mill as lumber drop-off, the AI building lumber mills, more buildings (gallery picks pending), casters, fog of war, PvP (lockstep: both clients run the engine with the same commands).

- [ ] Flaky test: "a made-up roll is not verified" (group games) failed once in ~5 runs on 2026-10-07; look at its timing.

## Done

- [x] Warcraft III: RTS vs the computer (Human/Orc, economy, buildings, combat, AI waves) (2026-10-07)

- [x] Hearthstone vs the computer: engine (pure state, seeded RNG), data-driven cards/heroes/decks, AI by lookahead, animated board (2026-10-06)

- [x] Space Shooter, Candy Crush, Angry Birds (2026-10-06)

- [x] Tetris, Flappy Bird, Wordle; scrolling home page (2026-10-06)

- [x] Solo page template (UI/Solo.lua) + Scores engine (guild/realm leaderboards) + Snake, 2048, Minesweeper (2026-10-06)

- [x] Battleship on Session: sealed boards, defender answers by itself (OnState hook), end-of-game board check, practice bot (2026-10-06)

- [x] Live engine (Core/Live.lua) + Arcade kit (UI/Kit.lua) + Agar.io: arena, drop-in lobbies, practice bots, leaderboard, best size (2026-10-06)

- [x] Arcade step 1: Casino / Arcade sections, lobby scopes (Group, Guild, Realm channel, Private code), Open lobbies browser, join by code, players whisper the host, Tic-Tac-Toe with rematches and score, Settings switch for the realm channel (2026-10-06)

- [x] Raffle: ticket price / limit / cut, buy with - and +, numbered tickets with chances, /roll draw, spinning ticket, practice (2026-10-06)

- [x] Blackjack: dealer + up to 5 players, sealed deck + /roll cut, hit/stand/double, dealer to 17 (S17), 3:2 blackjack, deal check, practice (2026-10-06)

- [x] Roulette: European wheel, chip table with slips, thrower passes round, /roll 1-37, ball animation into the pocket, optional caps, practice bots (2026-10-06)

- [x] Player lists: wider name area, scroll bar only when needed (all lists) (2026-10-06)

- [x] Slot machine caps (optional): max loss per player, house bankroll (2026-10-06)

- [x] Disconnects: host asked Continue without / Wait, Skip button (offline or a minute idle), rejoin catches up (poker cards resent), host-offline view with Leave game, /gamble dc for practice (2026-10-06)

- [x] Slot Machine: house + players, real /roll 1-512 read into three reels, paytable (~96% payback), spinning reels with lever, marquee and coin shower, join while open, Gazlowe practice house (2026-10-06)

- [x] Settle up tab: running balance per player across games, Paid / Remind, read-only trade watching with Undo, totals on the home page (2026-10-06)

- [x] Money in gold / silver / copper everywhere (three coin boxes), High-Low "each point is worth" (2026-10-06)
- [x] Rules button for every game, Hand rankings for poker with example cards and your hand highlighted (2026-10-06)
- [x] Poker raises: type any amount, Min / Pot / Max, table max raise (2026-10-06)

- [x] Poker v1: Hold'em 2-6 players, fixed bets, sealed deck + /roll cut, whispered hole cards, deal check, settle-up at End table, bots (2026-10-06)
- [x] Card animations: deal from the deck, flips, board reveals, coins to the pot and the winner, dealer button slides, turn glow (2026-10-06)
- [x] Our own card art (Art/*.tga, made by dev/make_art.py) (2026-10-06)
- [x] Stats handle multi-player settlements; summary table per game (2026-10-06)

- [x] Start over (v0.2): game picker, one tab per game, Statistics tab; games survive tab switches (2026-10-06)
- [x] Death Roll and High-Low with real /rolls, host-verified and player-checked (2026-10-06)
- [x] Practice with bots, + Bot button (2026-10-06)
- [x] Forever-style look: portrait window, side tabs, marble panels with bronze borders, green felt table, tumbling die and spinning numbers (2026-10-06)
