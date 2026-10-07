# Flintar's Fun 'n' Games

A games room for World of Warcraft, in one window styled like the game's own. A **Casino** for your group (Death Roll, High-Low, Poker, Blackjack, Slot Machine, Roulette, Raffle), where every number comes from the game's own `/roll` so nobody can fake a result, and an **Arcade** of just-for-fun games: Hearthstone against the computer, Tic-Tac-Toe, Battleship, Agar.io, Tetris and more, with guild and realm leaderboards.

![Retail](https://img.shields.io/badge/World%20of%20Warcraft-Retail-blue) ![WoW Forever](https://img.shields.io/badge/World%20of%20Warcraft-Forever-blue)

## Installation

1. Download the latest release.
2. Extract the folder into your game's `Interface/AddOns/` folder: `World of Warcraft/_retail_/Interface/AddOns/` for Retail, `World of Warcraft/_classic_beta_/Interface/AddOns/` for WoW Forever.
3. Make sure the folder is named `FlintarsFunNGames`.
4. `/reload` in game (or log in), then type `/fng`.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/fng` (or `/funngames`, `/gamble`) | Open or close the window (also the dice button on the minimap) |
| `/fng popup` | Turn the automatic pop-up on or off when someone in your group starts a game |
| `/fng mute` | Turn the addon's sounds off or on |
| `/fng reset` | Move the window back to the middle of the screen |
| `/fng debug` | Print what the addon reads from roll messages (for bug reports) |
| `/fng dc <bot>` | Practice: make a bot go offline, or come back (to try disconnects alone) |

## Games

- **Death Roll**: players take turns. The first roll is 1 - start, then each roll is 1 - the number before it. Whoever rolls a 1 pays the wager to the player who rolled just before them.
- **High-Low** (the classic): everyone rolls 1 - max once. The lowest roller pays the highest roller the difference, times what each point is worth (for example 1 silver). Ties roll again to break the tie.
- **Poker**: Texas Hold'em for 2-6 players. The host sets the big blind and a max raise. Type any bet or raise, or use **Min**, **Pot** or **Max**; at most four bets per round. Everyone keeps a running total, and **End table** works out who pays whom.
- **Blackjack**: one player deals; up to five play against the dealer. Bet between the table's min and max, a player cuts the sealed deck with a real `/roll`, then Hit, Stand or Double. The dealer draws to 17 and stands on soft 17. A win pays 1 to 1, blackjack 3 to 2, a tie is a push. Same cards and the same sealed-deck check as poker.
- **Slot Machine**: one player is the house; everyone else pulls the lever as often as they like and can walk up while it's open. Three of a kind pays up to 75 times the bet. Pays back about 96% over time. Optional caps: a max loss per player, and a house bankroll that closes the machine when it's gone. When the house closes the machine, everyone settles up with the house.

- **Roulette**: a European wheel (0-36). One player is the house; everyone else puts chips on numbers, colours, dozens and more, and one player throws the ball (the job passes round the table). A number pays 35 to 1, red or black 1 to 1. The throw is a real `/roll 1-37`, and the ball lands on the roll minus one. Same optional caps as the slot machine.

- **Raffle**: the organizer sets a ticket price (plus a max per player and an optional cut), everyone buys tickets, and one ticket is drawn with a real `/roll 1-N`. Tickets are numbered down the list for everyone to see. The winner takes the pot.

## Arcade

Next to the Casino, the home page has an **Arcade**: games just for fun, no betting.
- **Tic-Tac-Toe**: X against O, rematches keep the score.
- **Battleship**: hide four ships on an 8x8 board, take turns firing. Your board stays on your client, sealed with a fingerprint; after the game both boards are checked against the seals and every hit and miss.
- **Agar.io**: one big arena, eat dots to grow, swallow smaller blobs; the camera zooms out as you grow. Drop in while it's open; W A S D or hold the mouse to move. Your best size is saved.
- **Solo games** with high scores and leaderboards (You / Guild / Realm): **Snake**, **2048**, **Minesweeper**, **Tetris** (by the official rules: SRS, hold, T-spins, back-to-back), **Flappy Bird**, **Wordle** (endless, with words from Azeroth), **Space Shooter**, **Candy Crush** (match-3 with the raid target icons and Skull bombs) and **Angry Birds** (fling boulders at murlocs in their forts). New bests are shared with your guild and, with realm lobbies on, the realm.

Arcade lobbies can be open to more than your group. When you create one, pick who can join:
- **Group**: your party or raid.
- **Guild**: anyone in your guild sees it under **Open lobbies** in that game's tab.
- **Realm**: anyone on the realm with the addon sees it (your faction). This uses a hidden chat channel that never shows in your chat; turn it off in Settings.
- **Private code**: you get a code like `K7QX2`; friends type it under **Have a code?**.

Outside a group, players talk to the host by whisper, and lobbies don't pop up on anyone's screen. The casino games stay group-only, because their fairness relies on everyone in a group seeing each other's `/roll`s.

Every game tab has a **Rules** button explaining it in plain words. The poker tab also has **Hand rankings**: every hand from best to worst with example cards, and your current hand highlighted.

## Features

- Game picker on the first tab, a **Settle up** tab and a **Statistics** tab. A game gets its own tab while it has a table (or while you look at it), so the side tabs stay short.
- Games keep running while you switch tabs or close the window.
- **Hearthstone** (Arcade): the card game against the computer. Pick any of the nine classes (Jaina, Thrall, Garrosh, Malfurion, Rexxar, Uther, Anduin, Valeera, Gul'dan), each with its original basic cards and hero power; weapons included: minions, spells, hero powers, Taunt, Charge, Divine Shield, Windfury, Freeze, Spell Damage, Battlecries, Overload, fatigue. Attacks lunge, damage numbers pop, cards fly from your hand. Build your own decks (class and neutral cards, 2 copies each, 30 cards) or use the basic ones. Drag cards to the board, or click. The window grows for this game to fit a Hearthstone-style board; the Fullscreen button (Hearthstone and Warcraft III) fills the screen. Your game survives a /reload; wins go on the leaderboard. A main menu like Hearthstone's: **Play** queues you on the realm (Core/Queue.lua: queued players announce themselves on the realm channel, the name that sorts first hosts a private-code lobby and whispers the code, the game starts by itself with the decks picked before queueing), **Solo Adventures** (the computer), **Play a Friend**, **My Collection**. **PvP**: "Play a friend" opens an Arcade lobby (group, guild, realm, private code, or practice vs a bot); the host runs the engine and sends each player the public game plus their own hand by whisper; moves go to the host as commands and are checked with the same rules; the player in chair 2 sees the game mirrored so they sit at the bottom; mulligan at the start; 75-second turns (two missed turns in a row lose), concede, rematch; guild/realm leaderboards for wins vs the computer and PvP wins.
- Hearthstone sound: Games/Hearthstone/Sounds.lua (generated from the listfile: a voice per minion and hero, spells by school), played from P:EventSounds in UI/HearthstonePage.lua in step with the animations.
- **Warcraft 4** (Blizzard Games; was Warcraft III): a small RTS against the computer. Maps as data (Games/Warcraft/Maps.lua: a text grid per map, "." open, "T" tree, digits = starts, "G" = gold mines; WC.ParseMap, WC.CheckMap, WC.MapsFor; dev/make_maps.py makes them symmetric); Single Player opens a lobby (UI/WarcraftLobby.lua: a lobby is plain data, slots with kind/race/team/diff, map, mode; GameOptions turns it into engine options). Teams: E.Team/E.Foe/E.Ally decide who fights; the last team with buildings wins. Online: s.lobby in the session (Games/Warcraft.lua: LobbyView, lobby acts map/who/race/team), s.game on Start; Core/Lockstep.lua runs any number of seats (peers by seat, acks per seat, group broadcast or whispers), the computer seats think inside the turns. A main menu like Hearthstone's (Single Player, Find an Opponent, Play a Friend). Human or Orc; workers gather gold (mine) and lumber (trees); build farms (food), barracks, towers that shoot, altars (heroes later) and (Human) a Lumber Mill, a lumber drop-off near the trees; train Footman/Rifleman or Grunt/Troll Headhunter; destroy every enemy building to win. Units are their WoW creatures (3D, animated). Workers behave like Warcraft III (one in the mine at a time, builders stay with their building, peons build from inside). Warcraft III command card and hotkeys: Move M, Stop S, Hold H, Attack A, Gather G, Return R, Build B (then F/O, B, L, T, A, H), train P/F/R/G/T, Rally Y; Call to Arms C / Battle Stations B, Back to Work W; Idle worker button. Shift queues orders (several buildings in a row too); double-click selects all of a unit type; control groups Ctrl+1..0. The computer builds up and attacks in growing waves. The full Human and Orc armies (Games/Warcraft/Army.lua: casters with autocast, siege, beasts, flyers and air/ground targeting, splash, shops and items, upkeep). Heroes as in Warcraft III (Games/Warcraft/Heroes.lua data, HeroRules.lua rules): 8 heroes, 32 abilities, levels/XP, skill points, mana, effects (stun, invulnerable, invisible, slow, hex, banish), auras, summons, area spells, revive. Tech as in Warcraft III: hall tiers (Keep/Castle, Stronghold/Fortress), building requirements, research queued in buildings (Blacksmith, Lumber Mill, War Mill, Barracks upgrades, Scout > Guard Tower), damage and armour types; the AI researches too. Showcase (main menu or /wcdemo: everything on one map to try yourself; st.peace turns off auto-attacks and autocast). Sound (Games/Warcraft/Sounds.lua, generated from the listfile: voices per unit, spells, hits; W.PlayFile with kinds game/voice/alert; Settings: Game sounds (db.sound) and Alerts (db.alertSound)). Looks per unit and per buff (P.UNIT_LOOK, BUFF_LOOK: size, grey, animation speed, see-through, spin). Spell effects from WoW spell models (P.SPELL_FX / BUFF_FX / AURA_FX in UI/WarcraftPage.lua: file ids, scale, height). Cancel builds, upgrades and training. Fog of war (black unexplored, dim out of sight). Runs on a deterministic engine (plain data, seeded). **PvP**: lobbies (Play a friend) or the realm queue (Find an opponent); both pick a race; both clients run the engine in lockstep (Core/Lockstep.lua): 0.25 s turns, commands two turns ahead, sent by whisper over four rotating addon prefixes (WoW throttles each prefix), resent until acknowledged, a state fingerprint every 20 turns to catch a desync; waiting/claim victory, surrender, rematch.
- Done with a game? **Right-click its tab** to close it (the host closes it for everyone; a solo run stops without a score).
- Group play: when the host starts a game, the window pops up for everyone in the party or raid who has the addon.
- **Practice with bots** for every game: bots join and play by themselves, **+ Bot** adds more. Nothing is sent to anyone and nothing is counted.
- All amounts in gold, silver and copper, with the game's coin icons.
- **Settle up**: a running tab per player across games. Nobody has to pay right away. **Paid** and **Remind** buttons, and completed trades are read to track payments (the trade itself is never touched).
- **Statistics**: games played, won and lost, best game and net gold per game; everyone you have played with; your recent games.
- Looks like the game's own windows: portrait frame, side tabs, marble panels with bronze borders, a green felt card table.
- Poker seats with character portraits in gold rings (class icons when a portrait can't be drawn, and for bots).
- Animations: a tumbling die and spinning numbers on every roll; cards that fly from the deck and turn over; coins into the pot and out to the winner; a sliding dealer button; slot reels that spin and stop one by one, a pulling lever and a blinking marquee; a roulette ball that circles the wheel and drops into its pocket.
- Our own art: playing cards, suits, slot symbols, lever, the roulette wheel and ball, and icons.
- Buttons stay in place and grey out until you can use them.
- **Settings** tab: mute sounds (the your-turn alert has its own switch), pop-ups, the minimap button, window size, and clearing statistics, Settle up, game settings or everything.

## Fair play

- **Dice and slots**: every number is a real `/roll` that the whole group sees. The **Roll!** and **Spin!** buttons only ask the game to roll for you. The host's addon only counts a roll it saw in its own chat, from the right player, with the right range. Everyone's addon checks the host's numbers too: a check mark next to a roll means your own game saw it. A slot spin is a `/roll 1-512`, and the three reels are read straight from that number. A roulette throw is a `/roll 1-37`.
- **Poker**: before each hand the host's addon seals the deck (a SHA-256 fingerprint of a secret). A player who isn't the host cuts it with a real `/roll`. The shuffle comes from secret + cut, so nobody can pick the cards or change them mid-hand. Your cards are whispered to you only. After the hand the secret is shown and every addon checks the deal ("Deal checked"). The host's addon does know the cards while dealing, so play poker with people you trust.
- Only the host can describe its own game; anything else claiming to be that game is ignored.
- Nothing is ever posted to public chat. **Remind** whispers one person, only when you click it.

## Disconnects

The game never waits by force, and nobody is thrown out by force.

- When a player goes offline (or leaves the group) mid-game, everyone sees **(offline)** next to their name. The game **waits** for them by default, for when they're on voice saying "brb, relogging", and the host gets a chat message.
- Next to the player the host has a switch: **Skip** goes on without them, **Bring back** puts them back in and waits again. It can be flipped as often as you like. Skip also shows for someone who hasn't moved for a minute. Only when skipping would leave a single player does it ask first, because that ends the game.
- A player who comes back catches up by themselves: their window opens on the game, and in poker they get their cards again.
- Continuing without someone: in Death Roll they leave the turn order; in High-Low the round is settled between the others (fewer than two left cancels the game, and no one pays); in poker they fold and sit out until they're back, and their total still counts at the end; at the slot machine their total just stays.
- If the host goes offline, players see it, **Roll!** greys out, and they can wait or **Leave game**. The host's game is saved, so it goes on when they log back in.

## Settling up

Finished games add to a running balance with each player ("Bob owes you 1g 20s"). When a trade with someone on your tab completes, the gold that went each way counts as a payment, up to what is owed: buying an item from them for more doesn't clear anything extra. Every change is listed with an **Undo**, for a trade that wasn't a payment. Practice games are never added.

## For Addon Developers

- Addon message prefix: `FunNGames`. Group messages go to PARTY / RAID / INSTANCE_CHAT; Arcade lobbies can also use GUILD, the hidden channel `FunNGamesRealm`, or `FNG<code>` for a private lobby. Private poker cards, and players talking to a host outside a group, go by WHISPER.
- Message types: `S` game state (host to group), `J` / `L` join / leave, `A` a move (fold, call, raise:copper, deal, end), `H` private cards, `Q` "send me your games" after a /reload (the host answers with the game and, in poker, your cards).
- Solo games use `UI/Solo.lua` (a page template: canvas, score, pause, game over, leaderboard) and `Core/Scores.lua` (bests, shared over the guild and realm channels: `SC` / `SQ`).
- Engines: every game uses `Core/Session.lua` for lobbies (turn-based games run on it directly), real-time games add `Core/Live.lua` (each player broadcasts its own state; others smooth it), and games that draw every frame use `UI/Kit.lua` (canvas, sprite pools, loop, keyboard). No game sends messages itself.
- `dev/` holds a test harness that runs the addon outside the game: `node dev/run.mjs` plays every game with simulated players (1-3 players, each in their own Lua VM). `python dev/make_art.py` redraws the textures in `Art/`. See `dev/NOTES.md` for how it's built and what we learned.

## License

This project is licensed under the [MIT License](LICENSE).
