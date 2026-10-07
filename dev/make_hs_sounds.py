# Makes Games/Hearthstone/Sounds.lua from the community listfile (wow-listfile CSV; set LF below). python dev/make_hs_sounds.py
import re
LF = r"C:/Users/Andreas/AppData/Local/Temp/claude/e--Projekter-repository-FlintarBackend/e9a12e1c-bec5-4819-9cb9-2f70d2cb8cf9/scratchpad/listfile.csv"
ADDON = r"x:/Games/World of Warcraft/_classic_beta_/Interface/AddOns/FlintarsFunNGames/"
OUT = ADDON + "Games/Hearthstone/Sounds.lua"

dirs = {}
for line in open(LF, encoding='utf-8', errors='ignore'):
    if ';sound/creature/' not in line or not line.rstrip().endswith('.ogg'):
        continue
    fid, path = line.rstrip().split(';', 1)
    parts = path.split('/')
    if len(parts) != 4 or int(fid) > 2000000:
        continue
    dirs.setdefault(parts[2], []).append((int(fid), parts[3]))

def npc(d):
    out = {}
    for fid, name in sorted(dirs[d]):
        if 'greeting' in name: out.setdefault('play', []).append(fid)
        elif 'farewell' in name: out.setdefault('attack', []).append(fid)
    return out

def beast(d):
    out = {}
    for fid, name in sorted(dirs[d]):
        n = name.lower()
        if 'death' in n: k = 'death'
        elif 'aggro' in n and 'pre' not in n: k = 'play'
        elif 'attack' in n: k = 'attack'
        elif 'preaggro' in n or 'stand' in n or 'fidget' in n: k = 'idle'
        elif 'wound' in n and 'crit' not in n: k = 'hurt'
        else: continue
        out.setdefault(k, []).append(fid)
    if 'play' not in out: out['play'] = out.get('idle') or out.get('attack') or out.get('hurt') or [f for f, n in sorted(dirs[d]) if 'death' not in n.lower()][:3] or [f for f, n in sorted(dirs[d])]
    if 'attack' not in out: out['attack'] = out.get('play', [])
    out.pop('idle', None)
    return out

DEATH = {'human': [540722, 540838, 540852], 'woman': [540526], 'dwarf': [539885, 539958], 'orc': [541234],
         'tauren': [542895], 'troll': [541234], 'gnome': [539885]}

N = lambda d, body: ('npc', d, body)
B = lambda d: ('beast', d, None)
CARD = {
    # beasts
    'sheep': B('sheep'), 'frog': B('frog'), 'stonetusk_boar': B('boar'), 'boar': B('boar'), 'bloodfen_raptor': B('raptor'),
    'river_crocolisk': B('basilisk'), 'oasis_snapjaw': B('seaturtle'), 'ironfur_grizzly': B('bear'),
    'silverback_patriarch': B('gorilla'), 'chillwind_yeti': B('yeti'), 'huffer': B('wolf'), 'leokk': B('cat'),
    'misha': B('bear'), 'timber_wolf': B('wolf'), 'starving_buzzard': B('tallstrider'), 'tundra_rhino': B('kodobeast'),
    'spirit_wolf': B('wolf'), 'core_hound': B('wolf'),
    # murlocs
    'murloc_raider': B('murloc'), 'bluegill_warrior': B('murloc'), 'murloc_tidehunter': B('murloc'),
    'murloc_scout': B('murloc'), 'grimscale_oracle': B('murloc'), 'murloc_tidecaller': B('murloc'),
    'murloc_warleader': B('murloc'), 'old_murk_eye': B('murloc'), 'coldlight_oracle': B('murloc'),
    # elementals, demons, constructs
    'water_elemental': B('waterelemental'), 'fire_elemental': B('fireelemental'), 'magma_rager': B('fireelemental'),
    'earth_elemental': B('infernal'), 'war_golem': B('harvestgolem'), 'ironbark_protector': B('ancientprotector'),
    'voidwalker': B('voidwalker'), 'succubus': B('succubus'), 'dread_infernal': B('infernal'), 'flame_imp': B('kobold'),
    'blood_imp': B('kobold'), 'mechanical_dragonling': B('gyrocopter'), 'harvest_golem': B('harvestgolem'),
    'boulderfist_ogre': B('ogre'), 'kobold_geomancer': B('kobold'), 'razorfen_hunter': B('quillboar'),
    'darkscale_healer': B('naga'),
    # humanoids
    'goldshire_footman': N('humanmalewarriornpc', 'human'), 'stormwind_champion': N('humanmaleofficialnpc', 'human'),
    'raid_leader': N('humanmaleofficialnpc', 'human'), 'guardian_of_kings': N('humanmaleofficialnpc', 'human'),
    'silver_hand_recruit': N('humanmalewarriornpc', 'human'), 'argent_squire': N('humanfemalewarriornpc', 'woman'),
    'scarlet_crusader': N('humanmalewarriornpc', 'human'), 'lord_of_the_arena': N('humanmalewarriornpc', 'human'),
    'stormwind_knight': N('humanmalewarriornpc', 'human'), 'houndmaster': N('humanmalewarriornpc', 'human'),
    'booty_bay_bodyguard': N('humanmalewarriornpc', 'human'),
    'dalaran_mage': N('humanmalestandardnpc', 'human'), 'archmage': N('humanmaleofficialnpc', 'human'),
    'northshire_cleric': N('humanfemalestandardnpc', 'woman'), 'shattered_sun_cleric': N('humanmalestandardnpc', 'human'),
    'mirror_image_token': N('humanfemalestandardnpc', 'woman'),
    'novice_engineer': N('gnomemalestandardnpc', 'gnome'), 'gnomish_inventor': N('gnomemalezanynpc', 'gnome'),
    'dragonling_mechanic': N('gnomemalestandardnpc', 'gnome'), 'reckless_rocketeer': N('gnomemalezanynpc', 'gnome'),
    'ironforge_rifleman': N('dwarfmaleguardnpc', 'dwarf'), 'stormpike_commando': N('dwarfmaleguardnpc', 'dwarf'),
    'frostwolf_grunt': N('orcmaleguardnpc', 'orc'), 'korkron_elite': N('orcmaleguardnpc', 'orc'),
    'warsong_commander': N('orcmaleshadynpc', 'orc'), 'wolfrider': N('orcmalestandardnpc', 'orc'),
    'voodoo_doctor': N('trollmaleshamannpc', 'troll'), 'senjin_shieldmasta': N('trollmalestandardnpc', 'troll'),
    'gurubashi_berserker': N('trollmaledarknpc', 'troll'), 'windspeaker': N('taurenmaleshamannpc', 'tauren'),
    'elven_archer': N('humanfemalewarriornpc', 'woman'),
    'abomination': B('ogre'), 'amani_berserker': N('trollmaledarknpc', 'troll'), 'damaged_golem': B('harvestgolem'),
    'defender': N('humanmalewarriornpc', 'human'), 'defias_bandit': N('humanmalewarriornpc', 'human'),
    'defias_ringleader': N('humanmaleofficialnpc', 'human'), 'jungle_panther': B('cat'),
    'leper_gnome': N('gnomemalezanynpc', 'gnome'), 'loot_hoarder': B('kobold'), 'raging_worgen': B('wolf'),
    'si7_agent': N('humanmalestandardnpc', 'human'), 'snake': B('frog'), 'stranglethorn_tiger': B('cat'),
    'worgen_infiltrator': B('wolf'),
}
HERO = {
    'jaina': 'humanfemalestandardnpc', 'thrall': 'orcmaleguardnpc', 'garrosh': 'orcmaleshadynpc',
    'malfurion': 'nightelfmalewarriornpc', 'rexxar': 'orcmalestandardnpc', 'uther': 'humanmaleofficialnpc',
    'anduin': 'humanmalestandardnpc', 'valeera': 'humanfemalewarriornpc', 'guldan': 'orcmaleshadynpc',
}

def L(v): return '{ ' + ', '.join(str(x) for x in v) + ' }'

lines = ['''-- Hearthstone sounds: file ids in the WoW game files (from the community
-- listfile). Each minion has its creature's voice (WoW NPC voices by race,
-- beast, murloc, elemental and demon sounds) when played, attacking and
-- dying; spells sound by school. Generated by a script; edit freely.
local ADDON, ns = ...
local S = {}
ns.HS.Sounds = S

-- Minions: play, attack, death (any may be missing: then a generic one).
S.Minions = {''']
missing = []
for key in sorted(CARD):
    kind, d, body = CARD[key]
    if d not in dirs:
        missing.append((key, d)); continue
    v = npc(d) if kind == 'npc' else beast(d)
    if kind == 'npc': v['death'] = DEATH[body]
    parts = [f'{k} = {L(v[k])}' for k in ('play', 'attack', 'death') if v.get(k)]
    lines.append(f'    {key} = {{ ' + ', '.join(parts) + ' },')
lines.append('}')
lines.append('-- Heroes: a greeting at the start, a line when they attack.')
lines.append('S.Heroes = {')
for key in sorted(HERO):
    v = npc(HERO[key])
    lines.append(f'    {key} = {{ play = {L(v["play"])}, attack = {L(v["attack"])} }},')
lines.append('}')
lines.append('''-- Spells and hero powers by school.
S.School = {
    fire = { 568429, 568461 }, frost = { 568128, 568493 }, arcane = { 568149, 568313 },
    nature = { 568091, 568246 }, lightning = { 568516, 568188 }, holy = { 569402, 569383 },
    shadow = { 568426 }, physical = { 567880, 567621 },
}
S.Totem = 568287
S.Draw = 567562
S.Play = 567556
S.Mulligan = 567457
S.Hit = { 567880, 567621, 567750 }
S.HeroHit = { 567899, 567788 }
S.MinionDeath = { 567567, 567575 }
S.Heal = 569570
S.Armor = 567554
S.Freeze = 568128
S.Shield = 569738
S.Equip = 567554
S.Break = 567569
S.Buff = 568343
S.TimerLow = 567436
S.Victory = { 567408, 567495 }
S.Defeat = 567488
S.Found = 567409
''')
open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('missing dirs:', missing)
