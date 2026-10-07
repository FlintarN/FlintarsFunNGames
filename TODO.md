# Flintar's Fun 'n' Games TODO

One thing at a time, top to bottom. Move an item to Done when it is built and tested.

## In progress

- [ ] PvP for Hearthstone and Warcraft III: built; needs a real test with a friend (then the roadmap: step 1, tech and upgrades).
- [ ] Try Poker, Settle up and the Slot Machine against bots in game (v0.4): looks, animations, flow.

## Next

- [ ] **Arcade** (fun games, no gambling): a second section on the home page next to the Casino.
  1. ~~Lobbies with a scope (Group / Guild / Realm / Private code), lobby browser, whisper to host, Tic-Tac-Toe~~ (done, see Done).
  2. Port HearthPhone's games, all on shared engines (no game builds its own networking):
     - Solo games, next batch: Temple Run, Subway Surfers, Survivor (Roguelike), Tower Defense.
  Note: casino games stay group-only (/roll fairness needs a group) unless we add combined sealed-secret dice.

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

- [ ] Hearthstone next steps: secrets, deathrattle cards, Classic-set class cards (combo, stealth, enrage), a card choice for Tracking.

- [ ] Warcraft III: see the roadmap below.

- [ ] Flaky test: "a made-up roll is not verified" (group games) failed once in ~5 runs on 2026-10-07; look at its timing.

## PvP for Hearthstone and Warcraft III

Both engines are already built for it: plain data, seeded random numbers, and every move goes in as a
command, so two clients can run the same game. Lobbies, invites and whispers come from the Arcade
(Session/Live), like Tic-Tac-Toe and Battleship.

### Hearthstone PvP (first: turn-based, little data)
- [x] Lobby: group, guild, realm or code (Arcade lobbies), practice vs bot; both pick a hero and deck; the host deals.
- [x] The host runs the engine and sends each player their view (`E.View`): your own hand, the opponent's hand only as card backs; hidden cards go by whisper, like poker hole cards.
- [x] Moves go to the host as commands (play card, attack, hero power, end turn); the host checks them with the same rules as against the computer.
- [x] A turn timer (75 s, counting down on End Turn), concede; two missed turns in a row lose; a skipped (offline) player loses.
- [x] Mulligan at the start (PvP and against the computer).
- [x] Wins and losses in the stats (history + your PvP record); guild/realm leaderboards on the start screen.

- [x] A realm queue (Core/Queue.lua) and a Hearthstone-style main menu (Play, Solo Adventures, Play a Friend, My Collection).
- [ ] Queue: also match through the guild; rank by PvP record later.

### Warcraft III PvP (second: real time)
- [x] Lockstep: both clients run the engine; every 0.25 s each side sends the commands for that turn (or "nothing"), and a turn only runs when both sides' commands are in. Commands are small (unit ids + a point), so addon messages are enough.
- [x] A checksum of the game state every few seconds to catch a desync, with a message if it happens.
- [x] Lag: a short command delay (2 turns), and "waiting for player" when messages stop; claim victory after 45 s.
- [ ] Lobby: pick races and the map, colours, ready buttons; 1 vs 1 first, then 2 vs 2 with AI allies or enemies. Use the realm queue (Core/Queue.lua) too.
- [x] Fog of war (pulled forward from roadmap step 6), so you can't see the other base.
- [x] Wins and losses in the stats and on a leaderboard (warcraftpvp; no board on the page yet).

## Warcraft III roadmap

Goal: play like Warcraft III (The Frozen Throne melee). Order (user, 2026-10-07): PvP first (above),
then steps 1, 2, 3, 6, 7; Night Elf and Undead at the very end. Every step
comes with engine tests, the AI using it, the Rules text and docs. Models come from the game files
(M2 only), picked by the user from /wcgallery.

### 1. Tech and upgrades
- [ ] Cannon Tower and Arcane Tower (need a Workshop / Arcane Sanctum: step 3); Spiked Barricades; Defend for Footmen.
- [ ] Pick models for the new buildings (Keep, Castle, Stronghold, Fortress, Blacksmith, War Mill, Scout Tower) in /wcgallery.

### 2. Heroes
- [x] Spell visuals from the game files (WoW spell models). Tune sizes per spell after seeing them in game.
- [ ] Items and a 6-slot inventory come with shops (step 3) and creeps (step 6).

### 3. The rest of the Human and Orc armies
- [ ] Caster abilities you click (Dispel, Invisibility, Polymorph, Purge, Lightning Shield, Ensnare, Sentry Ward, Stasis Trap...), Spell Breaker, Spirit Walker, Flak/bombs upgrades.
- [ ] Pick models for the new buildings in /wcgallery.

### 6. The map and the match
- [ ] Shared sight for allies (fog of war itself is done).
- [ ] Day and night cycle (shorter sight at night, Night Elf bonuses).
- [ ] Creep camps around the map (WoW creatures) that guard expansions and give heroes experience and item drops; a neutral shop and mercenary camp.
- [ ] Bigger maps, more than one map, map picker; 4 players (2 vs 2 against the AI).
- [ ] Choose your race and the computer's (Human, Orc, Night Elf, Undead, Random).
- [ ] PvP: see "PvP for Hearthstone and Warcraft III" below.

### 7. Feel
- [ ] Unit sounds (WoW voice lines and weapon sounds), building sounds, "Our town is under attack" warnings, a minimap ping.
- [ ] Attack and spell projectiles from the game files (arrows, spears, cannon balls, fireballs).
- [ ] Select and command buildings in groups; rally points for several buildings; Tab between unit types in a selection; a multi-unit selection panel with portraits.
- [ ] Score screen at the end (units, buildings, resources, heroes).

### 8. Night Elf (at the very end)
- [ ] Wisps: gather lumber without cutting the trees down, gold from an entangled mine, are used up when they build.
- [ ] Ancients that walk and fight (Tree of Life > Ages > Eternity, Ancient of War, Ancient of Lore, Ancient of Wind, Ancient Protector), Moon Wells (food, refill mana and health), Hunter's Hall.
- [ ] Units: Archer, Huntress, Glaive Thrower, Dryad, Druid of the Claw, Druid of the Talon, Mountain Giant, Hippogryph, Faerie Dragon, Chimaera.
- [ ] Shadowmeld at night (needs a day/night cycle), Altar of Elders heroes: Demon Hunter, Keeper of the Grove, Priestess of the Moon, Warden.

### 9. Undead (at the very end)
- [ ] Acolytes summon buildings (they don't stay), Ghouls gather lumber, the Necropolis > Halls of the Dead > Black Citadel, Haunted Gold Mine on top of the mine.
- [ ] Blight: Undead build only on blight; it spreads around their buildings; Ziggurats (food, can become Spirit Towers).
- [ ] Units: Ghoul, Crypt Fiend, Gargoyle, Necromancer (raise skeletons from corpses), Banshee, Meat Wagon, Abomination, Obsidian Statue, Frost Wyrm, Shade.
- [ ] Corpses that stay on the ground for a while (needed for Raise Dead, Cannibalize, Meat Wagon).
- [ ] Altar of Darkness heroes: Death Knight, Lich, Dreadlord, Crypt Lord.

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

## Sound (next, after the looks)
- [x] Warcraft III: the real Warcraft III unit voices that are in WoW's files (sound/creature/peasant, peon, footman, grunt, rifleman, tauren...: "yes", "what", "ready", attack, warcry, pissed when clicked a lot); WoW NPC voices for the rest. Ready-when-trained, "work complete", "we're under attack", "not enough gold/lumber", building/construction and death sounds, spell sounds from sound/spells, weapon hits, gold mining and chopping, victory/defeat music.
- Hearthstone: card play and draw, minion attack/death sounds from each creature's own WoW sounds, spell sounds, hero emotes/lines, turn start and timer warning, victory/defeat, a menu/queue sound.
- [x] Two switches: Game sounds (everything inside the games) and Alerts (your turn, disconnects). Only on/off switches, no volume sliders (WoW's own volume settings handle that).
- [ ] Missing: footsteps, mining/chopping, construction, victory/defeat music.
