-- Help: a page that slides over the game, with the rules in plain words
-- (any game) or the poker hand rankings with example cards.
local ADDON, ns = ...

local W = ns.Widgets
local H = {}
ns.Help = H

local GOLD = "|cffffd100"

---------------------------------------------------------------------------
-- Rules text, per game. Sections: { heading, text }.
---------------------------------------------------------------------------
H.RULES = {
    deathroll = {
        { "The idea", "Two or more players take turns rolling, and the numbers keep getting smaller. "
            .. "Whoever rolls a 1 loses." },
        { "A game, step by step", "1. The host picks a wager and a start number (say 1000).\n"
            .. "2. The first player rolls 1 - 1000. Say they get 437.\n"
            .. "3. The next player rolls 1 - 437. Say 52.\n"
            .. "4. Then 1 - 52, and so on, round the table.\n"
            .. "5. The player who rolls a 1 pays the wager to the player who rolled just before them." },
        { "Your turn", "The Roll! button glows and you hear a ready-check sound. "
            .. "Click it: the addon does a real /roll with the right range for you." },
        { "If someone disconnects", "The game waits for them. The host can click Skip next to their name to go on "
            .. "without them (they leave the turn order), and Bring back to put them in again." },
        { "Fair play", "Every roll is a real /roll that everyone in the group sees. "
            .. "A roll with the wrong range (like a /roll 1-50 typed by hand) does not count. "
            .. "A check mark next to a roll means your own game saw it too." },
    },
    highlow = {
        { "The idea", "Everyone rolls once. The lowest roller pays the highest roller the difference." },
        { "A game, step by step", "1. The host picks a max roll (say 100) and what each point is worth (say 1 silver).\n"
            .. "2. Everyone clicks Roll! and rolls 1 - 100 once.\n"
            .. "3. Highest 80, lowest 30: the difference is 50 points, so the lowest pays the highest 50 silver." },
        { "Ties", "If two players tie for highest (or lowest), only they roll again to break the tie. "
            .. "The payment still uses the first rolls. If everyone rolls the same number, everyone rolls again." },
        { "Fair play", "Every roll is a real /roll that everyone in the group sees. "
            .. "A check mark next to a roll means your own game saw it too." },
    },
    slots = {
        { "The idea", "One player is the house and runs the machine. Everyone else pulls the lever as often as "
            .. "they like. Each spin costs the bet; three of a kind (and cherries on the left) pay out." },
        { "A game, step by step", "1. The house picks the bet per spin and opens the machine.\n"
            .. "2. Players click Join (any time, even while it's open) and pull the lever or click Spin!\n"
            .. "3. Each spin costs the bet, and pays bet x the paytable: three 7s pay 75 times the bet.\n"
            .. "4. Your running total shows next to your name. When the house clicks Close machine, "
            .. "everyone settles up with the house (see the Settle up tab)." },
        { "The paytable", "7 7 7: x75     Gem x3: x30     BAR x3: x20     Bell x3: x15\n"
            .. "Lemon x3: x10     Cherry x3: x10\n"
            .. "Cherry, cherry, anything: x4     Cherry, anything, anything: x1 (your bet back)\n"
            .. "Cherries only count from the left reel." },
        { "Limits", "The house can set two optional caps when opening the machine. Max loss per player: "
            .. "once one more spin would take you past it, your Spin! greys out. House bankroll: once the house "
            .. "has lost that much, the machine closes by itself and everyone settles up (a jackpot still pays "
            .. "in full). 0 means no cap." },
        { "The odds", "Each reel has eight stops: two cherries, two lemons, a bell, a BAR, a gem and a 7. "
            .. "Over many spins the machine pays back about 96% of what goes in, so in the long run the house "
            .. "wins a little. In the short run, anything can happen." },
        { "Fair play", "Every spin is a real /roll 1-512 that the whole group sees, and the three reels are read "
            .. "straight from that number. Anyone can check a spin, and nobody can fake one, the house included." },
        { "Practice", "In practice mode Gazlowe the goblin runs the machine and you play. + Bot adds players who "
            .. "pull the lever a few times by themselves." },
    },
    blackjack = {
        { "The idea", "One player deals (the house). Everyone else plays against the dealer: get closer to 21 than "
            .. "the dealer without going over." },
        { "Card values", "2 to 10 count their number. Jack, Queen and King count 10. An Ace counts 11, or 1 if 11 "
            .. "would take you over 21 (a hand with an Ace counting 11 is \"soft\")." },
        { "A round, step by step", "1. Set your bet in the coin boxes and click Place bet (Sit out skips a round).\n"
            .. "2. The player marked to deal clicks Deal: a real /roll cuts the sealed deck. Bets close.\n"
            .. "3. Everyone gets two cards face up. The dealer gets one face up and one face down.\n"
            .. "4. On your turn: Hit (another card), Stand (keep your hand), or Double (double your bet and take "
            .. "exactly one more card, only on your first two cards). Over 21 is a bust: you lose your bet.\n"
            .. "5. Then the dealer turns over the hidden card and must draw until 17 or more (and stands on a soft 17)." },
        { "What pays", "Closer to 21 than the dealer, or the dealer busts: you win your bet (1 to 1).\n"
            .. "Blackjack (an Ace and a 10, Jack, Queen or King as your first two cards): 3 to 2.\n"
            .. "Same total as the dealer: a push, you keep your bet.\n"
            .. "A dealer blackjack beats any other 21." },
        { "Money", "Your running total shows on your seat. When the dealer clicks Close table, everyone settles up "
            .. "with the dealer. The dealer sets the min and max bet, and an optional bankroll (the table closes "
            .. "when it's gone)." },
        { "Fair deck", "Before each round the dealer's addon seals the deck. A player cuts it with a real /roll, and "
            .. "after the round every addon checks every card dealt (\"Deal checked\"). The dealer's moves are "
            .. "fixed by the rules, so knowing the deck wouldn't help the house." },
        { "Practice", "In practice mode Gazlowe deals, two bots play alongside you, and you deal every round." },
    },
    raffle = {
        { "The idea", "One player organizes. Everyone buys tickets, then one ticket is drawn. Whoever holds it wins "
            .. "the pot: all the ticket money, minus the organizer's cut if there is one." },
        { "Step by step", "1. The organizer sets the ticket price, the most tickets one player may hold, and an "
            .. "optional cut, then opens sales.\n"
            .. "2. Pick how many tickets you want with - and +, and click Buy. You can change it until sales close.\n"
            .. "3. The organizer clicks Draw winner: sales close and a real /roll picks the ticket.\n"
            .. "4. The ticket spins, stops on the winning number, and the winner is shown." },
        { "Ticket numbers", "Tickets are numbered in order down the list: the first player's are #1 onwards, the next "
            .. "player's follow on. The list shows everyone's numbers and their chance to win." },
        { "Money", "Everyone pays the price of the tickets they hold, the winner gets the pot, and the organizer "
            .. "gets the cut. It all goes on the Settle up tab." },
        { "Fair play", "The draw is a real /roll 1 to the number of tickets sold, and everyone can see whose numbers "
            .. "are whose. Nobody can steer it, the organizer included." },
        { "Practice", "In practice mode you organize, and three bots buy tickets. Buy some yourself, then draw." },
    },
    tictactoe = {
        { "The idea", "Two players take turns putting their mark, X or O, in an empty square. Three in a row "
            .. "(across, down or diagonally) wins. A full board without three in a row is a draw." },
        { "Lobbies", "Pick who can join, then Create lobby:\n"
            .. "Group: your party or raid.\n"
            .. "Guild: anyone in your guild sees it in their Open lobbies list.\n"
            .. "Realm: anyone on the realm with the addon (your faction) sees it in their list.\n"
            .. "Private code: you get a code like K7QX2; your friend types it under \"Have a code?\"." },
        { "Playing", "The host is X, the opponent O. Click a square on your turn. After a game the host can call a "
            .. "Rematch (the other player starts) and the lobby keeps the score." },
        { "Practice", "Practice vs bot plays a bot that wins when it can and blocks when it must." },
    },
    battleship = {
        { "The idea", "Each player hides four ships on their own 8x8 waters: a Carrier (4), a Cruiser (3), a "
            .. "Submarine (3) and a Destroyer (2). Take turns firing at the other side. Sink the whole fleet to win." },
        { "Placing", "Hover your board to see where the next ship goes (green fits, red doesn't), click to place it, "
            .. "right-click or Rotate to turn it. Click a placed ship to pick it up again. Random places them all. "
            .. "Click Ready when your fleet is set." },
        { "Firing", "On your turn, click a square in the enemy's waters. A hit explodes, a miss splashes. You are told "
            .. "when you sink a ship. Turns alternate." },
        { "Fair play", "Your board never leaves your client during the game: Ready sends only a sealed fingerprint. "
            .. "After the game both boards are shown, and every addon checks them against their fingerprints and "
            .. "against every hit and miss given (\"board checked\")." },
        { "Lobbies", "Group, guild, realm or a private code, like Tic-Tac-Toe. Rematch keeps the score." },
    },
    snake = {
        { "The idea", "Steer the snake to the apples. Every apple makes it one longer and a little faster. "
            .. "Hitting a wall or your own tail ends the run." },
        { "Keys", "Arrow keys or W A S D to turn. Quick double turns are remembered. P pauses, and switching tabs "
            .. "pauses too." },
        { "Scores", "Your best is saved. New bests show on your guild's and the realm's leaderboard (Realm needs "
            .. "realm lobbies on in Settings)." },
    },
    g2048 = {
        { "The idea", "Every move slides all tiles as far as they go. Two tiles with the same number that meet "
            .. "merge into one with their sum. A new 2 or 4 appears after each move." },
        { "Goal", "Make a 2048 tile, and keep going for a high score: every merge adds the new tile's number. "
            .. "The run ends when no move is possible." },
        { "Keys", "Arrow keys or W A S D. P pauses." },
    },
    mines = {
        { "The idea", "Open every square that isn't a mine. A number shows how many of the eight squares "
            .. "around it hide mines; use that to work out where they are." },
        { "Mouse", "Left-click opens a square. Right-click puts a flag on a square you think is a mine (and "
            .. "takes it off again). The first click is always safe, and empty areas open by themselves." },
        { "Scores", "Your time is your score, so faster is better. Hitting a mine scores nothing." },
    },
    tetris = {
        { "The idea", "Pieces of four blocks fall into the well. Move and turn them so they fill whole rows; a full "
            .. "row clears. This follows the official Tetris rules: pieces come in bags of all seven, you see the "
            .. "next five, and a ghost shows where the piece will land." },
        { "Keys", "Left / Right (A / D) move; hold to slide. Up, W or X turns right; Z, Q or Ctrl turns left. "
            .. "Down (S) drops 20 times faster, Space drops at once and locks. C or Shift holds the piece for "
            .. "later (once per piece). P pauses." },
        { "Landing", "A piece that lands has half a second before it locks. Moving or turning it starts that half "
            .. "second again, up to 15 times. Turns use the official wall kicks, so pieces can twist into tight "
            .. "spots." },
        { "Scores", "Single 100, Double 300, Triple 500, Tetris 800. T-spins (turning a T into a slot with three "
            .. "corners blocked): 400, single 800, double 1200, triple 1600; minis less. All times your level. "
            .. "A Tetris or T-spin right after another is Back-to-Back: x1.5. Clearing lines piece after piece "
            .. "adds a combo bonus, and emptying the whole board is a Perfect Clear. Soft drop 1 per row, hard "
            .. "drop 2 per row." },
        { "Speed", "Level goes up every 10 lines, and the speed follows the official curve: about one row a "
            .. "second at level 1, very fast by level 10, and pieces drop almost at once from level 15." },
    },
    flappy = {
        { "The idea", "Keep the bird in the air and fly it through the gaps between the pipes. Touching a pipe or "
            .. "the ground ends the run." },
        { "Keys", "Space, Up or W (or a click on the game) flaps. The first flap starts the run. P pauses." },
        { "Scores", "One point for every pipe you get past." },
    },
    wordle = {
        { "The idea", "Guess the five-letter word in six tries. After each guess the tiles change colour: green "
            .. "means the right letter in the right spot, yellow means the letter is in the word somewhere else, "
            .. "grey means it isn't in the word." },
        { "Keys", "Type with your keyboard and press Enter, Backspace to fix a letter. You can click the keys "
            .. "below the grid too. Use the Pause button to pause (P is a letter here)." },
        { "Scores", "It never stops: solve a word and the next one comes up. A word solved in one guess gives 6 "
            .. "points, in six guesses 1 point. Missing a word ends the run. The words are from Azeroth." },
    },
    shooter = {
        { "The idea", "Rows of invaders march side to side and step down every time they reach an edge. Shoot "
            .. "them all to clear the wave; the next one is faster. They shoot back." },
        { "Keys", "Left / Right or A / D to move. Hold Space (or Up / W) to keep firing. P pauses." },
        { "Scores", "10, 20 or 30 points by row, times the wave number, plus a bonus for each wave. You have three "
            .. "lives; if the invaders reach the ground the run ends at once." },
    },
    candycrush = {
        { "The idea", "Swap two neighbouring raid marks to make a line of three or more of the same mark. Lines "
            .. "clear, everything above drops down, and new marks fall in. Drops that make new lines are combos." },
        { "Skulls", "A line of four or more leaves a Skull. Swap the Skull with any neighbour to blow up the "
            .. "marks around it." },
        { "Scores", "10 points per mark, times the combo step. You have 25 moves; a swap that makes no line "
            .. "slides back and costs nothing. If no move is possible the board shuffles." },
    },
    angrybirds = {
        { "The idea", "Murlocs are hiding in forts of wood and stone. Fling boulders at them: a hit knocks a "
            .. "murloc out, and so does a fall of two rows or a block landing on it. Wood breaks in one hit, "
            .. "stone takes two." },
        { "Aiming", "Press the mouse anywhere on the game and drag back from the sling; let go to fire. Or "
            .. "use Up / Down to aim and Left / Right for power, then Space. The dotted line shows the start "
            .. "of the arc." },
        { "Scores", "500 per murloc, 50 per wood block, 100 per stone block. Clearing a level gives 300 for "
            .. "every boulder you didn't need. Five levels are hand-built; after that they're random." },
    },
    warcraft = {
        { "The idea", "A small Warcraft III against the computer. You start with a hall, five workers and a gold "
            .. "mine. Gather gold and lumber, build farms (food) and barracks, train an army and destroy every "
            .. "enemy building. Lose all of yours and it's over." },
        { "Mouse", "Left-click to select; drag a box to select several of your units (Shift adds). Right-click: "
            .. "the ground to move, an enemy to attack, the gold mine or a tree to gather, an unfinished "
            .. "building to carry on building it. With a building selected, right-click sets its rally point." },
        { "Command card", "As in Warcraft III. Units: Move (M), Stop (S), Hold Position (H), Attack (A: click an "
            .. "enemy, or the ground to attack-move). Workers also: Gather (G), Return Resources (R) and Build "
            .. "(B), which opens the build menu (Farm F / Burrow O, Barracks B, Hall H). Halls and barracks "
            .. "train (Peasant/Peon P, Footman F, Rifleman R, Grunt G, Headhunter T) and Set Rally Point (Y)." },
        { "Workers", "One worker at a time goes into the gold mine; the others wait at the door, so about five "
            .. "keep a mine busy. Harvesting workers walk through each other. A building only goes up while "
            .. "its worker stays with it (peons go inside); send the worker away and it pauses." },
        { "Call to Arms", "Human Town Hall: Call to Arms (C) rings the alarm. Peasants nearby run to the hall and "
            .. "fight as Militia for 45 seconds. Orc: Battle Stations (B) sends peons into the burrows (4 each), "
            .. "and burrows with peons throw spears. Back to Work (W) ends it early." },
        { "Difficulty", "Pick Easy, Normal or Hard on the start screen. Easy builds slowly and waits 10 minutes "
            .. "before attacking; Normal waits 6; Hard waits 4, builds more and gets 25% more per trip." },
        { "Economy", "Workers carry 10 gold or lumber a trip. Every unit needs food: a hall gives 12, each farm or "
            .. "burrow 6. The Idle button at the top right finds workers with nothing to do." },
    },
    hearthstone = {
        { "The idea", "Two heroes with 30 Health each. Bring the enemy hero to 0. You play minions (they fight "
            .. "on the board) and spells, paid for with mana: one crystal on your first turn, one more every "
            .. "turn, up to 10. You draw a card every turn; the player going second gets The Coin (one extra "
            .. "mana, once)." },
        { "Playing", "Drag a card from your hand onto the board to play it: minions land where you drop them, "
            .. "spells can be dropped right on their target. Or click a card, then its target (right-click "
            .. "cancels). Click one of your minions, then an enemy, to attack. Minions can't attack the turn "
            .. "they come in (unless they have Charge). Your hero power (the round button) can be used once a "
            .. "turn. End turn when you're done." },
        { "Keywords", "Taunt: enemies must attack it first. Charge: can attack at once. Divine Shield: the "
            .. "first damage is ignored. Windfury: attacks twice. Freeze: misses its next attack. Spell "
            .. "Damage: your spells deal more. Battlecry: happens when you play it. Overload: locks some of "
            .. "your mana next turn." },
        { "Decks", "After picking a hero you choose a deck: the basic one or your own. New deck opens the "
            .. "deck builder: click cards to add them (two copies each, 30 cards), click a card in the list on "
            .. "the right to take it out, Auto-fill completes the deck. Only full decks can be played." },
        { "Limits", "Ten cards in hand (more are burned), seven minions on the board. An empty deck deals "
            .. "growing fatigue damage on each draw." },
        { "Heroes", "All nine classes, each with its original basic cards and hero power: Jaina (Mage, "
            .. "Fireblast), Thrall (Shaman, Totemic Call), Garrosh (Warrior, Armor Up!), Malfurion (Druid, "
            .. "Shapeshift), Rexxar (Hunter, Steady Shot), Uther (Paladin, Reinforce), Anduin (Priest, Lesser "
            .. "Heal), Valeera (Rogue, Dagger Mastery) and Gul'dan (Warlock, Life Tap). Wins count on the "
            .. "leaderboard." },
        { "Weapons", "Rogues, Warriors and Paladins equip weapons. Your hero can then attack once a turn; each "
            .. "attack uses one Durability, and the weapon breaks at 0." },
    },
    agario = {
        { "The idea", "Everyone is a blob in one big arena. Eat the coloured dots to grow. Touch a blob that's "
            .. "clearly smaller than you (under 85% of your size) to swallow it. Bigger blobs can swallow you." },
        { "Moving", "W A S D (or the arrow keys) while the arena is open, or hold the left mouse button: your blob "
            .. "heads towards the cursor. Big blobs are slower, and slowly shrink, so nobody stays on top forever." },
        { "Eaten?", "Click the arena to jump back in at the start size." },
        { "Lobbies", "Open the arena to your group, guild, realm, or friends with a code. Players can drop in while "
            .. "it's open; only the host closes it. Your best size is saved." },
        { "Practice", "Practice mode fills the arena with bots that chase smaller blobs, run from bigger ones and "
            .. "graze on dots." },
    },
    roulette = {
        { "The idea", "One player is the house and runs the table. Everyone else puts chips on numbers, colours "
            .. "and more, then one player throws the ball into the wheel. Where it lands decides who wins." },
        { "A round, step by step", "1. Put chips on the table: left-click a spot for one chip, shift-click for five, "
            .. "right-click to take one back. Clear bets takes them all back.\n"
            .. "2. The player marked (throws) clicks Throw the ball when everyone is ready. That closes the bets.\n"
            .. "3. The ball circles the wheel and drops into a pocket. Winning spots light up.\n"
            .. "4. The next round starts at once, and the next player throws." },
        { "What pays", "A single number: 35 to 1 (a 10s chip wins 3g 50s and you keep your chip).\n"
            .. "A dozen (1st 12, 2nd 12, 3rd 12) or a column (2:1): 2 to 1.\n"
            .. "Red or Black, Odd or Even, 1-18 or 19-36: 1 to 1.\n"
            .. "On 0, every bet except a chip on 0 itself loses. That's the house's small edge (about 2.7%)." },
        { "Money", "Your running total shows next to your name. When the house clicks Close table, everyone settles "
            .. "up with the house. The house can set two optional caps: a max loss per player, and a bankroll "
            .. "(the table closes when it's gone). 0 means no cap." },
        { "Fair play", "Every throw is a real /roll 1-37 that the whole group sees: the ball lands on the roll minus one. "
            .. "Anyone can check it, and nobody can steer the ball, the house included." },
        { "Practice", "In practice mode Gazlowe runs the table, two bots bet alongside you, and you throw every ball." },
    },
    poker = {
        { "The idea", "Texas Hold'em. Make the best five-card hand out of your two cards and five shared cards "
            .. "on the table, or make everyone else give up. The winner takes the pot (all the money bet in the hand)." },
        { "A hand, step by step", "1. Two players put in the blinds: the small blind (half) and the big blind. "
            .. "This gives everyone something to play for.\n"
            .. "2. Everyone gets two cards only they can see.\n"
            .. "3. A betting round, starting left of the big blind.\n"
            .. "4. The flop: three shared cards on the table. Another betting round.\n"
            .. "5. The turn: a fourth shared card. Another betting round.\n"
            .. "6. The river: a fifth shared card. A last betting round.\n"
            .. "7. The showdown: players still in show their cards, and the best hand wins the pot." },
        { "On your turn", "Fold: give up this hand (you lose what you already bet).\n"
            .. "Check: pass, when nobody has bet this round.\n"
            .. "Call: put in enough to match the biggest bet.\n"
            .. "Bet / Raise: put in more. Everyone else must then call, raise again or fold. "
            .. "Type an amount, or use Min, Pot or Max." },
        { "Winning", "If everyone else folds, you win the pot right away, without showing your cards. "
            .. "Otherwise the best five cards from your two plus the five on the table win. "
            .. "See Hand rankings for what beats what. Exactly equal hands split the pot." },
        { "This table", "Nobody needs gold on hand while playing: your seat shows how much you are up or down. "
            .. "When the host clicks End table, the addon works out who pays whom.\n"
            .. "At most four bets per round (a bet and three raises). The dealer button (D) moves one seat each hand, "
            .. "and so do the blinds." },
        { "Fair deck", "Before each hand the host's addon seals the deck. A player cuts it with a real /roll, "
            .. "so nobody could pick the cards. After the hand every addon checks the deal (\"Deal checked\")." },
        { "Words you will hear", "Pot: the money bet so far in this hand.\n"
            .. "Blinds: the forced bets that start each hand.\n"
            .. "Dealer button: marks the dealer; the blinds sit to its left.\n"
            .. "Flop, turn, river: the first three shared cards, the fourth, and the fifth.\n"
            .. "Kicker: the highest card that isn't part of your pair or set, used to break ties.\n"
            .. "Suited: your two cards have the same suit (good for flushes).\n"
            .. "Showdown: the cards are turned over at the end." },
    },
}

---------------------------------------------------------------------------
-- Poker hand rankings with example cards (rank 2-14, suit 1 spades,
-- 2 hearts, 3 diamonds, 4 clubs).
---------------------------------------------------------------------------
local function Card(rank, suit) return (suit - 1) * 13 + (rank - 1) end

H.HANDS = {
    { 9, "Royal flush", "A K Q J 10, all the same suit. The best hand there is.",
        { Card(14, 2), Card(13, 2), Card(12, 2), Card(11, 2), Card(10, 2) } },
    { 9, "Straight flush", "Five in a row, all the same suit.",
        { Card(9, 1), Card(8, 1), Card(7, 1), Card(6, 1), Card(5, 1) } },
    { 8, "Four of a kind", "Four cards of the same rank.",
        { Card(12, 1), Card(12, 2), Card(12, 3), Card(12, 4), Card(7, 2) } },
    { 7, "Full house", "Three of a kind plus a pair.",
        { Card(13, 1), Card(13, 3), Card(13, 4), Card(4, 2), Card(4, 1) } },
    { 6, "Flush", "Five cards of the same suit, in any order.",
        { Card(14, 3), Card(11, 3), Card(8, 3), Card(4, 3), Card(2, 3) } },
    { 5, "Straight", "Five in a row, any suits. The ace can also be low: A 2 3 4 5.",
        { Card(10, 4), Card(9, 2), Card(8, 1), Card(7, 3), Card(6, 2) } },
    { 4, "Three of a kind", "Three cards of the same rank.",
        { Card(7, 1), Card(7, 2), Card(7, 4), Card(13, 3), Card(2, 1) } },
    { 3, "Two pair", "Two different pairs.",
        { Card(11, 2), Card(11, 4), Card(5, 1), Card(5, 3), Card(14, 1) } },
    { 2, "Pair", "Two cards of the same rank.",
        { Card(10, 1), Card(10, 3), Card(13, 2), Card(6, 4), Card(3, 1) } },
    { 1, "High card", "Nothing else: your highest card counts.",
        { Card(14, 4), Card(12, 1), Card(9, 2), Card(5, 3), Card(3, 2) } },
}

---------------------------------------------------------------------------
-- The overlay
---------------------------------------------------------------------------
local ROW_H, CARD_W = 52, 26
local CONTENT_W = 490

function H:Build(f)
    if self.frame then return end
    local o = W.Panel(f)
    o:SetPoint("TOPLEFT", 10, -66)
    o:SetPoint("BOTTOMRIGHT", -12, 32)
    o:SetFrameLevel(f:GetFrameLevel() + 30)
    o:EnableMouse(true) -- clicks don't fall through to the game below
    o:Hide()
    self.frame = o

    -- Darker, solid background so the page under it doesn't show through.
    local bg = o:CreateTexture(nil, "BORDER", nil, 4)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(0.06, 0.05, 0.04, 0.92)

    self.title = W.Label(o, "", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 14, -12)
    local back = W.Button(o, "Back to the game", 140, function() H:Hide() end, 22)
    back:SetPoint("TOPRIGHT", -10, -8)
    local line = W.Divider(o)
    line:SetPoint("TOPLEFT", 10, -36)
    line:SetPoint("TOPRIGHT", -10, -36)

    local sf = CreateFrame("ScrollFrame", nil, o, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -42)
    sf:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(CONTENT_W, 10)
    sf:SetScrollChild(content)
    self.scroll, self.content = sf, content

    -- Rules: one long text.
    self.text = W.Label(content, "", "GameFontHighlight")
    self.text:SetPoint("TOPLEFT", 4, -4)
    self.text:SetWidth(CONTENT_W - 12)
    self.text:SetJustifyH("LEFT")
    if self.text.SetSpacing then self.text:SetSpacing(3) end

    -- Hand rankings: a row per hand.
    self.rows = {}
    for i, hand in ipairs(H.HANDS) do
        local y = -(i - 1) * ROW_H
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(CONTENT_W, ROW_H)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 0.82, 0, 0.18)
        row.hl:Hide()
        row.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        row.stripe:SetAllPoints()
        row.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
        row.rank = W.Label(row, i .. ".", "GameFontNormalLarge")
        row.rank:SetPoint("LEFT", 6, 0)
        row.cards = {}
        for k, c in ipairs(hand[4]) do
            local card = ns.Cards.New(row, CARD_W)
            card:SetCard(c)
            card.frame:ClearAllPoints()
            card.frame:SetPoint("LEFT", 30 + (k - 1) * (CARD_W + 3), 0)
            row.cards[k] = card
        end
        row.name = W.Label(row, hand[2], "GameFontNormal")
        row.name:SetPoint("TOPLEFT", 30 + 5 * (CARD_W + 3) + 10, -9)
        row.desc = W.Label(row, hand[3], "GameFontHighlightSmall")
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.desc:SetJustifyH("LEFT")
        row.mine = W.Label(row, "", "GameFontNormalSmall")
        row.mine:SetPoint("TOPRIGHT", -8, -9)
        self.rows[i] = row
    end
    self.footer = W.Label(content, "Best five cards from your two plus the five on the table. Same kind of hand? "
        .. "The higher cards win (a pair of kings beats a pair of tens; then the kicker decides). "
        .. "Exactly equal hands split the pot.", "GameFontDisableSmall")
    self.footer:SetPoint("TOPLEFT", 6, -(#H.HANDS * ROW_H) - 8)
    self.footer:SetWidth(CONTENT_W - 12)
    self.footer:SetJustifyH("LEFT")
end

function H:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function H:Hide()
    if self.frame then self.frame:Hide() end
end

function H:ShowRules(kind)
    local G = ns.Games[kind]
    self.title:SetText(G.name .. ": how to play")
    local parts = {}
    for _, section in ipairs(H.RULES[kind] or {}) do
        table.insert(parts, GOLD .. section[1] .. "|r\n" .. section[2])
    end
    self.text:SetText(table.concat(parts, "\n\n"))
    self.text:Show()
    for _, row in ipairs(self.rows) do row:Hide() end
    self.footer:Hide()
    local h = self.text.GetStringHeight and self.text:GetStringHeight() or 600
    self.content:SetHeight(math.max(10, (h or 600) + 16))
    self.scroll:SetVerticalScroll(0)
    self.frame:Show()
end

-- `current`: the category (1-9) of the hand you hold now, to highlight.
function H:ShowHands(current)
    self.title:SetText("Poker hand rankings, best first")
    self.text:Hide()
    for i, row in ipairs(self.rows) do
        row:Show()
        local hand = H.HANDS[i]
        -- A royal flush is a straight flush too; only light the royal one when it is royal.
        local match = current and hand[1] == current.cat
            and (hand[1] ~= 9 or (i == 1) == (current.high == 14))
        row.hl:SetShown(match and true or false)
        row.mine:SetText(match and "Your hand" or "")
    end
    self.footer:Show()
    self.content:SetHeight(#H.HANDS * ROW_H + 50)
    self.scroll:SetVerticalScroll(0)
    self.frame:Show()
end
