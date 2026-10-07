// Runs Flintar's Fun 'n' Games outside WoW: one Lua VM per simulated player, with
// addon messages and /roll results passed between them like the server would.
//   node run.mjs
import { LuaFactory } from 'file:///E:/Projekter/WebAddonDemo/node_modules/wasmoon/dist/index.js';
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const here = dirname(fileURLToPath(import.meta.url));
const addon = join(here, '..');
const toc = readFileSync(join(addon, 'FlintarsFunNGames.toc'), 'utf8')
  .split(/\r?\n/).filter(l => l.trim() && !l.startsWith('##'));
const factory = new LuaFactory();

let failures = 0, passes = 0;

async function Player(name, group) {
  const lua = await factory.createEngine();
  lua.global.set('PLAYER_NAME', name);
  await lua.doString(`GROUP = {${group.map(g => `"${g}"`).join(',')}}`);
  await lua.doString(readFileSync(join(here, 'mock.lua'), 'utf8'));
  await lua.doString('ns = {}');
  for (const file of toc) {
    lua.global.set('__SRC', readFileSync(join(addon, file.replace(/\\/g, '/')), 'utf8'));
    lua.global.set('__NAME', file);
    await lua.doString(`local fn, err = load(__SRC, "@" .. __NAME) if not fn then error(err) end fn("FlintarsFunNGames", ns)`);
  }
  lua.global.set('__check', (ok, label) => {
    if (ok) passes++; else { failures++; console.log(`  FAIL [${name}] ${label}`); }
  });
  await lua.doString(`
    function check(ok, label) __check(ok and true or false, label) end
    function TakeOutbox()
      local out = {}
      for _, e in ipairs(OUTBOX) do
        local parts = {}
        for i = 1, #e do parts[i] = tostring(e[i]) end
        table.insert(out, table.concat(parts, "\\2"))
      end
      OUTBOX = {}
      return table.concat(out, "\\1")
    end
    Fire("ADDON_LOADED", "FlintarsFunNGames")
    Fire("PLAYER_ENTERING_WORLD", true, false)
  `);
  return { name, lua, run: (code) => lua.doString(code) };
}

// Deliver everything everyone sent, advance clocks, repeat until quiet.
async function Pump(players, seconds = 0) {
  for (let round = 0; round < 50; round++) {
    let traffic = false;
    for (const p of players) {
      await p.run(`Advance(${round === 0 ? seconds : 0})`);
      const out = await Get(p, 'TakeOutbox()');
      if (!out) continue;
      for (const line of out.split('\x01')) {
        traffic = true;
        const e = line.split('\x02');
        if (e[0] === 'addon') {
          for (const q of players) {
            if (q === p) continue;
            // Who hears it: a whisper its target, the guild its members, a channel those in it.
            if (e[3] === 'WHISPER' && e[4] !== q.name) continue;
            if (e[3] === 'GUILD' && !(await Get(q, 'IN_GUILD'))) continue;
            if (e[3] === 'CHANNEL' && !(await Get(q, `CHANNELS["${e[4]}"] ~= nil`))) continue;
            q.lua.global.set('__m', e[2]);
            await q.run(`Fire("CHAT_MSG_ADDON", "${e[1]}", __m, "${e[3]}", "${p.name}")`);
          }
        } else {
          // The server tells the whole group about a roll, the roller included.
          for (const q of players) await q.run(`Fire("CHAT_MSG_SYSTEM", "${e[1]} rolls ${e[2]} (${e[3]}-${e[4]})")`);
        }
      }
    }
    if (!traffic && round > 0) return;
  }
}

async function Get(p, expr) { await p.lua.doString(`__ret = ${expr}`); return p.lua.global.get("__ret"); }

async function Section(title, fn) {
  if (process.env.ONLY && !title.startsWith(process.env.ONLY)) return;
  console.log(title);
  await fn();
}

// ---------------------------------------------------------------------------
await Section('Rules and helpers', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_unit.lua'), 'utf8'));
});

await Section('Settle up (tab and trades)', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_tab.lua'), 'utf8'));
});

await Section('Practice games (alone, with bots)', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_practice.lua'), 'utf8'));
  // Drive the game loop: click Roll! whenever it is our turn.
  for (const kind of ['deathroll', 'highlow']) {
    await p.run(`PracticeStart("${kind}")`);
    await Pump([p], 3);
    await p.run(`PracticeAfterJoin("${kind}")`);
    for (let i = 0; i < 400; i++) {
      const phase = await Get(p, `ClickRollIfMyTurn("${kind}")`);
      await Pump([p], 2);
      if (phase !== 'rolling') break;
    }
    await p.run(`PracticeEnd("${kind}")`);
  }
});

await Section('Poker practice (with bots)', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_poker.lua'), 'utf8'));
  await p.run('PokerPracticeStart()');
  await Pump([p], 3);
  await p.run('PokerAfterJoin()');
  for (let i = 0; i < 600; i++) {
    const phase = await Get(p, 'PokerStep(6)');
    await Pump([p], 3);
    if (phase !== 'rolling') break;
  }
  await p.run('PokerPracticeEnd()');
});

await Section('Slot machine practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_slots.lua'), 'utf8'));
  await p.run('SlotsPracticeStart()');
  for (let i = 0; i < 200; i++) {
    const r = await Get(p, 'SlotsStep()');
    await Pump([p], 2);
    await p.run('SlotsCheckSpin()');
    if (r === 'done') break;
  }
  await Pump([p], 30);
  await p.run('SlotsPracticeEnd()');
  await p.run('TabsCheck()');
});

await Section('Disconnects in practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_dc.lua'), 'utf8'));
  await p.run('DcDeathRollStart()');
  for (let i = 0; i < 300; i++) {
    const r = await Get(p, 'DcDeathRollStep()');
    if (r !== 'going') break;
  }
  await p.run('DcDeathRollSkip()');
  await p.run('DcDeathRollFinish()');
  await p.run('DcTwoPlayers()');
  await p.run('DcHighLow()');
  await p.run('DcPoker()');
  await p.run('CloseTabTests()');
});

await Section('Blackjack practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_blackjack.lua'), 'utf8'));
  await p.run('BlackjackStart()');
  for (let i = 0; i < 300; i++) {
    await Pump([p], 1);
    const r = await Get(p, 'BlackjackStep()');
    if (r === 'done') break;
  }
  await p.run('BlackjackEnd()');
});

await Section('Raffle practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_raffle.lua'), 'utf8'));
  await p.run('RaffleStart()');
  await Pump([p], 1);
  await p.run('RaffleAfterDraw()');
});

await Section('Roulette practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_roulette.lua'), 'utf8'));
  await p.run('RoulettePracticeStart()');
  await p.run('RoulettePlaceBets()');
  await Pump([p]);
  await p.run('RouletteAfterThrow()');
  await p.run('RouletteClose()');
});

await Section('Tic-Tac-Toe practice', async () => {
  const p = await Player('Flintar', []);
  await p.run('DIRECT_ROLLS = true');
  await p.run(readFileSync(join(here, 'tests_ttt.lua'), 'utf8'));
  await p.run('TttPractice()');
  await p.run('SideCheck()');
});

await Section('Arcade lobbies (realm, guild, code)', async () => {
  const names = ['Flintar', 'Bob', 'Alice'];
  const players = [];
  // Not grouped: these lobbies work without a party.
  for (const n of names) players.push(await Player(n, []));
  for (const p of players) await p.run(readFileSync(join(here, 'tests_ttt.lua'), 'utf8'));
  const [host, bob, alice] = players;
  async function Play() {
    for (let i = 0; i < 30; i++) {
      for (const p of [host, bob]) { await p.run('TttMove()'); await Pump(players, 1); }
      if (await Get(host, 'TttDone()')) return;
    }
  }

  // Realm: Bob and Alice see it in their lists; Bob joins; they play.
  for (const p of players) await p.run('TttOpenSetup()');
  await Pump(players, 2);
  await host.run('TttHost("realm")');
  await Pump(players, 1);
  await bob.run('TttSeesLobby(true)');
  await alice.run('TttSeesLobby(true)');
  await bob.run('TttJoinFromList()');
  await Pump(players, 1);
  await bob.run('TttSeated()');
  await host.run('TttStart()');
  await Pump(players, 1);
  await Play();
  for (const p of [host, bob]) await p.run('TttCheckEnd()');
  for (const p of players) await p.run('TttClose()');
  await Pump(players, 1);

  // Guild: only guild members see it.
  for (const p of [host, alice]) await p.run('IN_GUILD = true');
  await host.run('ns.Session.lobbies = {} ');
  for (const p of [bob, alice]) await p.run('ns.Session.lobbies = {}');
  await host.run('TttHost("guild")');
  await Pump(players, 1);
  await alice.run('TttSeesLobby(true)');
  await bob.run('TttSeesLobby(false)');
  await host.run('TttClose()');
  await Pump(players, 1);

  // Private code: Bob types it; Alice never sees it.
  for (const p of [bob, alice]) await p.run('ns.Session.lobbies = {}');
  const code = await Get(host, 'TttHost("code")');
  await Pump(players, 1);
  await alice.run('TttSeesLobby(false)');
  await bob.run(`TttJoinCode("${code}")`);
  await Pump(players, 2);
  await bob.run('TttSeated()');
  await alice.run('TttSeesLobby(false)');
  await host.run('TttStart()');
  await Pump(players, 1);
  await Play();
  await bob.run('TttCheckEnd()');
});

await Section('Battleship practice', async () => {
  const p = await Player('Flintar', []);
  await p.run('DIRECT_ROLLS = true');
  await p.run(readFileSync(join(here, 'tests_bs.lua'), 'utf8'));
  await p.run('BsPractice()');
});

for (const cheat of [false, true]) {
  await Section(cheat ? 'Battleship: Bob lies about hits' : 'Battleship over a code lobby', async () => {
    const host = await Player('Flintar', []);
    const bob = await Player('Bob', []);
    const players = [host, bob];
    for (const p of players) await p.run(readFileSync(join(here, 'tests_bs.lua'), 'utf8'));
    if (cheat) await bob.run('BsCheat()');
    const code = await Get(host, 'BsHost()');
    await Pump(players, 1);
    await bob.run(`BsJoinCode("${code}")`);
    await Pump(players, 2);
    await host.run('BsStart()');
    await Pump(players, 1);
    for (const p of players) { await p.run('BsPlace()'); await Pump(players, 1); }
    for (let i = 0; i < 200; i++) {
      for (const p of players) { await p.run('BsFire()'); await Pump(players, 1); }
      if (await Get(host, 'BsDone()')) break;
    }
    await Pump(players, 1);
    for (const p of players) await p.run(`BsCheckEnd(${cheat ? 'false' : 'true'})`);
  });
}

await Section('Solo games', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_solo.lua'), 'utf8'));
  await p.run('SoloTests()');
  await p.run('SoloTests2()');
  await p.run('SoloTests3()');
});

await Section('Shared leaderboards (guild)', async () => {
  const a = await Player('Flintar', []);
  const b = await Player('Bob', []);
  const players = [a, b];
  for (const p of players) { await p.run('IN_GUILD = true'); await p.run(readFileSync(join(here, 'tests_solo.lua'), 'utf8')); }
  await a.run('ScoreShare(42)');
  await Pump(players, 1);
  await b.run('ScoreBoard("Flintar", 42)');
  // Bob joins later: asking brings in Flintar's best again (from a fresh board).
  await b.run('ns.db.boards = {} ScoreAsk()');
  await Pump(players, 1);
  await Pump(players, 5); // answers come after a short random wait
  await b.run('ScoreBoard("Flintar", 42)');
  await b.run('ScoreShare(50)');
  await Pump(players, 1);
  await a.run('ScoreBoard("Bob", 50)');
});

await Section('Agar.io practice', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_agar.lua'), 'utf8'));
  await p.run('AgarPractice()');
});

await Section('Agar.io live (realm)', async () => {
  const host = await Player('Flintar', []);
  const bob = await Player('Bob', []);
  const players = [host, bob];
  for (const p of players) await p.run(readFileSync(join(here, 'tests_agar.lua'), 'utf8'));
  // Bob opens the tab first so he's on the realm channel.
  await bob.run('SlashCmdList.FUNNGAMES("") ns.UI:SelectTab("agario") Advance(0)');
  await host.run('AgarHost()');
  await Pump(players, 1);
  await bob.run('AgarJoin()');
  await Pump(players, 1);
  for (let i = 0; i < 6; i++) {
    for (const p of players) await p.run('AgarRun(0.2)');
    await Pump(players, 0);
  }
  await bob.run('AgarSees("Flintar")');
  await host.run('AgarSees("Bob")');
  // Bob sits still and small; the host grows big right on top of him.
  await bob.run('AgarPlace(500, 500, 12)');
  for (let i = 0; i < 3; i++) { await bob.run('AgarRun(0.2)'); await Pump(players, 0); }
  await host.run('AgarPlace(505, 505, 50) AgarRun(0.4)');
  await Pump(players, 0);
  await bob.run('AgarRun(0.05)');
  await bob.run(`check(not AgarAlive(), "agar: the host swallowed Bob over the network")`);
  // Bob leaves the tab: the host's arena drops him.
  await bob.run('AgarHide()');
  await Pump(players, 0);
  await host.run('AgarRun(0.1) AgarGone("Bob")');
});

await Section('Group games (two and three players)', async () => {
  const names = ['Flintar', 'Bob', 'Alice'];
  const players = [];
  for (const n of names) players.push(await Player(n, names.filter(x => x !== n)));
  for (const p of players) await p.run(readFileSync(join(here, 'tests_group.lua'), 'utf8'));
  const [host, bob, alice] = players;
  await Pump(players, 4);

  for (const [kind, seats] of [['deathroll', [bob]], ['highlow', [bob, alice]]]) {
    await host.run(`HostOpen("${kind}")`);
    await Pump(players);
    for (const p of [bob, alice]) await p.run(`CheckPoppedUp("${kind}")`);
    for (const p of seats) await p.run(`ClickJoin("${kind}")`);
    await Pump(players);
    await host.run(`HostStart("${kind}", ${seats.length + 1})`);
    await Pump(players);
    let phase = 'rolling';
    for (let i = 0; i < 400 && phase === 'rolling'; i++) {
      for (const p of [host, ...seats]) {
        phase = await Get(p, `ClickRollIfMyTurn("${kind}")`);
        await Pump(players, 1);
      }
    }
    for (const p of players) await p.run(`CheckDone("${kind}")`);
    await host.run(`CheckLedgers("${kind}")`);
    for (const p of seats) await p.run(`CheckLedgers("${kind}")`);
    for (const p of players) await p.run(`CloseGame("${kind}")`);
    await Pump(players);
  }

  // Poker, three players: cards are private, deals verify, stats match.
  await host.run(`HostOpen("poker")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`CheckPoppedUp("poker")`);
  for (const p of [bob, alice]) await p.run(`ClickJoin("poker")`);
  await Pump(players);
  await host.run(`HostStart("poker", 3)`);
  await Pump(players);
  for (const p of players) await p.run('PortraitCheck()');
  let pphase = 'rolling';
  for (let i = 0; i < 600 && pphase === 'rolling'; i++) {
    for (const p of players) {
      const ph = await Get(p, 'PokerGroupStep(3)');
      if (p === host) pphase = ph;
      await Pump(players, 1);
    }
  }
  for (const p of players) await p.run('PokerGroupCheckEnd()');
  for (const p of players) await p.run(`CloseGame("poker")`);
  await Pump(players);

  // Slot machine: the host is the house; Alice walks up after it opens.
  await host.run(`HostOpen("slots")`);
  await Pump(players);
  await bob.run(`ClickJoin("slots")`);
  await Pump(players);
  await host.run(`HostStart("slots", 2)`);
  await Pump(players);
  await alice.run(`ClickJoin("slots")`);
  await Pump(players);
  await alice.run(`check(ns.Session.Find(ns.Session.Get("slots"), "Alice") ~= nil, "slots: joined an open machine")`);
  for (let i = 0; i < 12; i++) {
    for (const p of [bob, alice]) { await p.run('SlotsGroupPull()'); await Pump(players, 1); }
  }
  for (const p of players) await p.run('SlotsGroupCheck()');
  await host.run(`ns.UI.pages.slots.view.buttons.endTable._scripts.OnClick() AnswerPopup()`);
  await Pump(players);
  for (const p of players) await p.run(`check(ns.Session.Get("slots").phase == "done", "slots: closed for " .. PLAYER_NAME)`);
  for (const p of players) await p.run(`CloseGame("slots")`);
  await Pump(players);

  // Disconnects: Bob drops (host waits), comes back after a reload; then the host drops.
  await host.run(`HostOpen("deathroll")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`ClickJoin("deathroll")`);
  await Pump(players);
  await host.run(`HostStart("deathroll", 3)`);
  await Pump(players);
  await host.run(`DcGroupPlayerOffline("Bob", true)`);
  await Pump(players);
  await host.run(`DcHostSeesOffline("deathroll", "Bob")`);
  await alice.run(`DcPlayerSeesTag("deathroll", "Bob")`);
  await bob.run('DcReload()');
  await host.run(`DcGroupPlayerOffline("Bob", false)`);
  await Pump(players, 4);
  await host.run(`DcHostSeesBack("deathroll", "Bob")`);
  await bob.run(`DcAfterReload("deathroll")`);
  await alice.run(`DcGroupPlayerOffline("Flintar", true)`);
  await alice.run(`DcHostGone("deathroll")`);
  await alice.run(`DcGroupPlayerOffline("Flintar", false)`);
  await alice.run(`check(not ns.Session.HostOffline(ns.Session.Get("deathroll")), "deathroll: host back for Alice")`);
  await host.run(`ns.Session.Cancel("deathroll")`);
  await Pump(players);
  for (const p of players) await p.run(`CloseGame("deathroll")`);
  await Pump(players);

  // Poker: Bob reloads mid-hand and gets his cards back.
  await host.run(`HostOpen("poker")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`ClickJoin("poker")`);
  await Pump(players);
  await host.run(`HostStart("poker", 3)`);
  await Pump(players);
  for (let i = 0; i < 3; i++) { for (const p of players) { await p.run('PokerGroupStep(99)'); await Pump(players, 1); } }
  await bob.run('DcReload()');
  await Pump(players, 4);
  await bob.run(`DcAfterReload("poker")`);
  await host.run(`ns.Session.Cancel("poker")`);
  await Pump(players);

  // Roulette: Bob and Alice bet; Bob throws, then Alice.
  await host.run(`HostOpen("roulette")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`ClickJoin("roulette")`);
  await Pump(players);
  await host.run(`HostStart("roulette", 3)`);
  await Pump(players);
  for (const [round, thrower] of [[1, bob], [2, alice]]) {
    await bob.run(`RouletteGroupBet("red")`); await Pump(players);
    await alice.run(`RouletteGroupBet("n17")`); await Pump(players, 1);
    await thrower.run('RouletteGroupThrow()');
    await Pump(players, 1);
    for (const p of players) await p.run(`RouletteGroupCheck(${round})`);
  }
  await host.run(`ns.Session.Act("roulette", "end")`);
  await Pump(players);
  for (const p of players) await p.run(`CloseGame("roulette")`);
  await Pump(players);

  // Blackjack: the host deals; Bob cuts round 1, Alice round 2.
  await host.run(`HostOpen("blackjack")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`ClickJoin("blackjack")`);
  await Pump(players);
  await host.run(`HostStart("blackjack", 3)`);
  await Pump(players);
  let bphase = 'rolling';
  for (let i = 0; i < 200 && bphase === 'rolling'; i++) {
    for (const p of players) {
      const ph = await Get(p, 'BjGroupStep()');
      if (p === host) bphase = ph;
      await Pump(players, 1);
    }
  }
  await host.run(`check(ns.Session.Get("blackjack").phase == "done", "blackjack: two rounds played and closed")`);
  for (const p of players) await p.run(`CloseGame("blackjack")`);
  await Pump(players);

  // Raffle: the host organizes; Bob and Alice buy; the host draws.
  await host.run(`HostOpen("raffle")`);
  await Pump(players);
  for (const p of [bob, alice]) await p.run(`ClickJoin("raffle")`);
  await Pump(players);
  await host.run(`HostStart("raffle", 3)`);
  await Pump(players);
  await bob.run('RaffleGroupBuy(3)'); await Pump(players, 1);
  await alice.run('RaffleGroupBuy(2)'); await Pump(players, 1);
  await bob.run('RaffleGroupBuy(4)'); await Pump(players, 1);
  await host.run(`check(ns.Session.Get("raffle").tickets.Bob == 4 and ns.Session.Get("raffle").tickets.Alice == 2, "raffle: tickets reached the organizer")`);
  await host.run('RaffleGroupDraw()');
  await Pump(players, 1);
  for (const p of players) await p.run('RaffleGroupCheck()');
  for (const p of players) await p.run(`CloseGame("raffle")`);
  await Pump(players);

  // Anti-cheat paths.
  await host.run(`HostOpen("deathroll")`);
  await Pump(players);
  await bob.run(`ClickJoin("deathroll")`);
  await Pump(players);
  await host.run(`HostStart("deathroll", 2)`);
  await Pump(players);
  // Host rolls first; then it's Bob's turn. Bob types /roll 1-50 by hand.
  await Get(host, `ClickRollIfMyTurn("deathroll")`);
  await Pump(players, 1);
  await bob.run(`WrongRangeRoll()`);
  await Pump(players, 1);
  await host.run(`CheckWrongRangeBanner()`);
  await bob.run(`SpoofHost()`);
  await Pump(players);
  await alice.run(`CheckNotSpoofed()`);
  await bob.run(`FakeTimelineCheck()`);
  await host.run(`ns.Session.Cancel("deathroll")`);
  await Pump(players);
  await bob.run(`check(ns.Session.Get("deathroll").phase == "cancelled", "cancel reaches players")`);
});

await Section('Hearthstone engine and AI', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_hs.lua'), 'utf8'));
  await p.run('HsDataTests()');
  await p.run('HsRuleTests()');
  await p.run('HsBotGames()');
  await p.run('HsClassTests()');
  await p.run('HsPageTests()');
  await p.run('HsDeckTests()');
  await p.run('HsPreloadTests()');
});

await Section('Hearthstone PvP', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_hspvp.lua'), 'utf8'));
  await p.run('HsMirrorTests()');
  await p.run('HsPvpPractice()');
});

await Section('Hearthstone PvP over a code lobby', async () => {
  const host = await Player('Flintar', []);
  const bob = await Player('Bob', []);
  const players = [host, bob];
  for (const q of players) await q.run(readFileSync(join(here, 'tests_hspvp.lua'), 'utf8'));
  const code = await Get(host, 'HsPvpHost()');
  await Pump(players, 1);
  await bob.run(`HsPvpJoin("${code}")`);
  await Pump(players, 2);
  await host.run('HsPvpStart()');
  await Pump(players, 1);
  await host.run('HsPvpDeck("jaina")');
  await Pump(players, 1);
  await bob.run('HsPvpDeck("thrall")');
  await Pump(players, 1);
  for (const q of players) await q.run('HsPvpCheck()');
  for (let i = 0; i < 300; i++) {
    for (const q of players) { await q.run('HsPvpMove()'); await Pump(players, 1); }
    if (await Get(host, 'HsPvpDone()')) break;
  }
  await Pump(players, 1);
  for (const q of players) await q.run('HsPvpEnd()');
});

await Section('Warcraft III engine and AI', async () => {
  const p = await Player('Flintar', []);
  await p.run(readFileSync(join(here, 'tests_wc.lua'), 'utf8'));
  await p.run('WcEngineTests()');
  await p.run('WcWorkerTests()');
  await p.run('WcCommandTests()');
  await p.run('WcBuildTests()');
  await p.run('WcAlarmTests()');
  await p.run('WcDifficultyTests()');
  await p.run('WcDifficultyGames()');
  await p.run('WcAIGames()');
  await p.run('WcPageTests()');
  await p.run('WcGalleryTests()');
  await p.run('WcQueueTests()');
});

// The TOC files (base: Forever and Retail; _Forever) list the same files and version.
{
  const body = n => readFileSync(join(addon, n), 'utf8').split(/\r?\n/).filter(l => !l.startsWith('## Interface'));
  const base = body('FlintarsFunNGames.toc').join('\n');
  for (const n of ['FlintarsFunNGames_Forever.toc']) {
    if (body(n).join('\n') === base) passes++; else { failures++; console.log(`  FAIL ${n} differs from FlintarsFunNGames.toc`); }
  }
}

console.log(`\n${passes} passed, ${failures} failed`);
process.exit(failures ? 1 : 0);
