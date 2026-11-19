"""
Builds IamLoveCreature.esp (+ SEQ\\IamLoveCreature.seq) without the Creation Kit.

    python build_esp.py            -> writes ..\\IamLoveCreature.esp and ..\\SEQ\\IamLoveCreature.seq

V.1  hotkey ForceGreet creature dialogue ("Hey Hello").
V.2  creature followers (merged from Animal Followers): tame / follow / wait / home / inventory / release
     through the creature dialogue, plus MCM pages. FormIDs of V.1 records are unchanged.

Uses espwriter.py from the Claude skill "skyrim-esp-writer".
The follow / sandbox / home packages are copied byte-for-byte from Animal Followers (nPetFollowers.esp,
see AF_ESP below) and re-pointed at this plugin, because they are known to work in game.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
for cand in (HERE,
             os.path.expanduser(r"~\.claude\skills\skyrim-esp-writer\scripts"),
             os.path.join(HERE, r"..\..\..\Cluade AI\Skill\skyrim-esp-writer\scripts")):
    if os.path.isfile(os.path.join(cand, "espwriter.py")):
        sys.path.insert(0, cand)
        break
from espwriter import *  # noqa: E402

OUT_DIR = os.path.normpath(os.path.join(HERE, ".."))
AF_CACHE = os.path.join(HERE, "af_templates.json")  # cached AF template records (so AF is not needed)
SLOTS = 50                 # pet slots (must match ILC_Followers.SlotLimit)
HOME_ALIAS_BASE = 100      # must match ILC_Followers.HomeAliasBase

p = Plugin(masters=["Skyrim.esm"], author="pethzero",
           desc="IamLoveCreature V.2 - creature dialogue + creature followers")

PLAYER_REF = p.skyrim("PlayerRef")
ACTOR_TYPE_NPC = p.skyrim("ActorTypeNPC")
XMARKER = p.master("Skyrim.esm", 0x00003B)              # STAT XMarker
DUN_PLAYER_ALLY = p.master("Skyrim.esm", 0x05A1A4)      # FACT DunPlayerAllyFaction
CURRENT_FOLLOWER = p.skyrim("CurrentFollowerFaction")


# =====================================================================================
#  helpers: read records from Animal Followers (templates)
# =====================================================================================
def read_records(path, wanted):
    """{formid: (type, flags, [(sub, data)...])} for the wanted formids of a plugin."""
    d = open(path, "rb").read()
    out = {}

    def walk(o, end):
        while o < end:
            t = d[o:o + 4].decode("latin1")
            size = struct.unpack_from("<I", d, o + 4)[0]
            if t == "GRUP":
                walk(o + 24, o + size)
                o += size
                continue
            flags, fid = struct.unpack_from("<II", d, o + 8)
            if fid in wanted:
                body = d[o + 24:o + 24 + size]
                if flags & 0x40000:
                    body = zlib.decompress(body[4:])
                    flags &= ~0x40000
                subs, q = [], 0
                while q < len(body):
                    st = body[q:q + 4].decode("ascii")
                    ln = struct.unpack_from("<H", body, q + 4)[0]
                    subs.append((st, body[q + 6:q + 6 + ln]))
                    q += 6 + ln
                out[fid] = (t, flags, subs)
            o += 24 + size

    walk(0, len(d))
    return out


AF_PET_FACTION, AF_FOLLOW, AF_SANDBOX, AF_HOME1 = 0x01000800, 0x01000812, 0x01000887, 0x0100080D
AF_MGEF_CTL, AF_SPEL_POW = 0x01000892, 0x01000891   # "Pet Commands" power
AF_PLUGIN = os.path.normpath(os.path.join(HERE, r"..\..\Animal Followers (Beta)\_backup_original\nPetFollowers.esp"))
if not os.path.isfile(AF_PLUGIN):
    AF_PLUGIN = os.path.normpath(os.path.join(HERE, r"..\..\Animal Followers (Beta)\Data\nPetFollowers.esp"))
import json  # noqa: E402
if os.path.isfile(AF_PLUGIN):
    AF = read_records(AF_PLUGIN, {AF_PET_FACTION, AF_FOLLOW, AF_SANDBOX, AF_HOME1, AF_MGEF_CTL, AF_SPEL_POW})
    assert len(AF) == 6, f"Animal Followers templates not found in {AF_PLUGIN}"
    with open(AF_CACHE, "w", encoding="utf-8") as f:
        json.dump({hex(k): [t, fl, [[st, d.hex()] for st, d in subs]] for k, (t, fl, subs) in AF.items()}, f, indent=1)
else:
    with open(AF_CACHE, encoding="utf-8") as f:
        AF = {int(k, 16): (t, fl, [(st, bytes.fromhex(d)) for st, d in subs]) for k, (t, fl, subs) in json.load(f).items()}


def af_subs(fid, drop=("EDID",)):
    return [(t, d) for t, d in AF[fid][2] if t not in drop]


def replace_subs(subs, sub_type, new_list):
    """Replace every `sub_type` subrecord by new_list (inserted where the first one was)."""
    out, done = [], False
    for t, d in subs:
        if t == sub_type:
            if not done:
                out += new_list
                done = True
            continue
        out.append((t, d))
    assert done, sub_type
    return out


def insert_before(subs, sub_type, new_list):
    i = next(i for i, (t, _) in enumerate(subs) if t == sub_type)
    return subs[:i] + new_list + subs[i:]


# =====================================================================================
#  V.1 records (keep this order: FormIDs 0800-0808 must not change)
# =====================================================================================
q_dlg = p.reserve("ILC_DialogueQuest", "QUST")
q_mcm = p.reserve("ILC_MCMQuest", "QUST")
pk_fg = p.reserve("ILC_ForceGreetPackage", "PACK")
br = p.reserve("ILC_HelloBranch", "DLBR")
t_hello = p.reserve("ILC_HelloTopic", "DIAL")
t_reply = p.reserve("ILC_HelloReply", "DIAL")
view = p.reserve("ILC_DialogueView", "DLVW")

ALIAS_PLAYER, ALIAS_CREATURE = 0, 1
is_creature_alias = CTDA("GetIsAliasRef", "==", 1, p1=ALIAS_CREATURE)
silent = ("ForceSubtitle", "NoLIPFile")   # creatures have no voice files

info_hello = p.add_info(t_hello, info(
    "Hey Hello",
    flags=silent,
    links=[t_reply.formid],
    conditions=[is_creature_alias],
    vmad=VMAD_info([Script("ILC_TIF_HeyHello")], "ILC_TIF_HeyHello", end="Fragment_0"),
    notes="IamLoveCreature test line - proves the creature dialogue works",
))
p.add_info(t_reply, info(
    "...",
    flags=("Goodbye",) + silent,
    conditions=[is_creature_alias],
))

# =====================================================================================
#  V.2 records (new FormIDs from 0809)
# =====================================================================================
q_fol = p.reserve("ILC_FollowerQuest", "QUST")
f_pet = p.reserve("ILC_PetFaction", "FACT")
f_home = p.reserve("ILC_PetHasHome", "FACT")
f_wait = p.reserve("ILC_PetWaiting", "FACT")
pk_follow = p.reserve("ILC_PetFollowPackage", "PACK")
pk_sandbox = p.reserve("ILC_PetSandboxPackage", "PACK")
pk_home = [p.reserve(f"ILC_PetHomePackage{i + 1:02d}", "PACK") for i in range(SLOTS)]

# player commands (topic text = what the player says, response = what the creature "does")
COMMANDS = [
    # edid,              prompt,                              response,                                       fragment,             conditions
    ("ILC_PetTame",      "I need a follower.",                "*It looks at you curiously.*",                None,                 "notpet"),
    ("ILC_PetFollow",    "Follow me.",                        "*It comes to your side.*",                    "Fragment_Follow",    "pet notfollow"),
    ("ILC_PetWait",      "Wait here.",                        "*It sits down and waits.*",                   "Fragment_Wait",      "pet follow notwait"),
    ("ILC_PetResume",    "Let's go.",                         "*It jumps up, ready to go.*",                 "Fragment_Resume",    "pet follow wait"),
    ("ILC_PetStop",      "You can stop following me.",        "*It wanders off.*",                           "Fragment_StopFollow", "pet follow"),
    ("ILC_PetSetHome",   "Make your home here.",              "*It sniffs around its new home.*",            "Fragment_SetHome",   "pet"),
    ("ILC_PetClearHome", "You don't need that home anymore.", "*It tilts its head.*",                        "Fragment_ClearHome", "pet home"),
    ("ILC_PetInventory", "Let me see what you carry.",        "*It lets you look.*",                         "Fragment_Inventory", "pet"),
    ("ILC_PetRelease",   "You are free now. (Release)",       "*It looks at you one last time.*",            "Fragment_Release",   "pet"),
]
cmd_topics = [p.reserve(c[0], "DIAL") for c in COMMANDS]

COND = {
    "pet":       CTDA("GetInFaction", "==", 1, p1=f_pet.formid),
    "notpet":    CTDA("GetInFaction", "!=", 1, p1=f_pet.formid),
    "follow":    CTDA("GetPlayerTeammate", "==", 1),
    "notfollow": CTDA("GetPlayerTeammate", "!=", 1),
    "wait":      CTDA("GetInFaction", "==", 1, p1=f_wait.formid),
    "notwait":   CTDA("GetInFaction", "!=", 1, p1=f_wait.formid),
    "home":      CTDA("GetInFaction", "==", 1, p1=f_home.formid),
}

# ---- dialogue quest (V.1 + Followers property)
p.fill(q_dlg, [
    VMAD_quest(
        [Script("ILC_Main", [
            Prop.obj("PlayerRef", PLAYER_REF),
            Prop.obj("CreatureAlias", q_dlg.formid, ALIAS_CREATURE),
            Prop.obj("ActorTypeNPC", ACTOR_TYPE_NPC),
            Prop.obj("Followers", q_fol.formid),
        ])],
        alias_scripts={
            ALIAS_PLAYER: [Script("ILC_PlayerAlias")],
            ALIAS_CREATURE: [Script("ILC_CreatureAlias")],
        },
        quest_formid=q_dlg.formid),
    FULL("IamLoveCreature Dialogue"),
    quest_dnam(start_game_enabled=True, priority=60),
    CTDA("HasKeyword", "!=", 1, p1=ACTOR_TYPE_NPC),
    NEXT(),
    ANAM_next_alias(2),
    *ref_alias(ALIAS_PLAYER, "PlayerAlias", forced_ref=PLAYER_REF),
    *ref_alias(ALIAS_CREATURE, "CreatureAlias", flags=("Optional", "AllowReuse"), packages=[pk_fg.formid]),
])

# ---- MCM quest
p.fill(q_mcm, [
    VMAD_quest(
        [Script("ILC_Config", [
            Prop.obj("Main", q_dlg.formid),
            Prop.obj("Followers", q_fol.formid),
            Prop.obj("PlayerRef", PLAYER_REF),
        ])],
        alias_scripts={0: [Script("SKI_PlayerLoadGameAlias")]},
        quest_formid=q_mcm.formid),
    FULL("IamLoveCreature MCM"),
    quest_dnam(start_game_enabled=True, priority=0),
    NEXT(),
    ANAM_next_alias(1),
    *ref_alias(0, "PlayerAlias", forced_ref=PLAYER_REF),
])

p.fill(pk_fg, forcegreet_package(owner_quest=q_dlg.formid, topic=t_hello.formid, target_ref=PLAYER_REF))

# ---- dialogue: hello line now also links to the pet commands
p.fill(br, dlbr(q_dlg.formid, t_hello.formid))
p.fill(t_hello, dial(q_dlg.formid, branch=br.formid))
p.fill(t_reply, dial(q_dlg.formid, branch=br.formid, prompt="Hello!", priority=10.0))   # last = "goodbye"

i_tclt = max(i for i, (t, _) in enumerate(info_hello.subs) if t == "TCLT")
info_hello.subs[i_tclt + 1:i_tclt + 1] = [sub("TCLT", u32(t.formid)) for t in cmd_topics]

def command_info(topic, resp, frag, conds, goodbye=True):
    return p.add_info(topic, info(
        resp,
        flags=(("Goodbye",) if goodbye else ()) + silent,
        conditions=[is_creature_alias] + [COND[c] for c in conds.split()],
        vmad=VMAD_info([Script("ILC_TIF_Pet")], "ILC_TIF_Pet", end=frag) if frag else None,
        notes="V.2 pet command",
    ))


infos = {}
for (edid, prompt, resp, frag, conds), topic in zip(COMMANDS, cmd_topics):
    p.fill(topic, dial(q_dlg.formid, branch=br.formid, prompt=prompt))
    infos[edid] = command_info(topic, resp, frag, conds, goodbye=frag is not None)

# ---- V.2.1 (appended: FormIDs above stay the same)
# "I need a follower." -> creature reacts -> player picks Join (tame) or Never mind (cancel)
SUB_CHOICES = [
    ("ILC_PetTameJoin",   "Join me. I'll take care of you.", "*It decides to trust you.*",     "Fragment_Tame", "notpet"),
    ("ILC_PetTameCancel", "Never mind.",                     "*It loses interest.*",           None,            "notpet"),
]
ACTOR_TYPE_HORSE = p.master("Skyrim.esm", 0x026110)
COND["horse"] = CTDA("HasKeyword", "==", 1, p1=ACTOR_TYPE_HORSE)
EXTRA = [("ILC_PetRide", "Let me ride you.", "*It lowers its back for you.*", "Fragment_Ride", "pet horse")]

sub_topics = [p.reserve(c[0], "DIAL") for c in SUB_CHOICES]
extra_topics = [p.reserve(c[0], "DIAL") for c in EXTRA]
for (edid, prompt, resp, frag, conds), topic in zip(SUB_CHOICES + EXTRA, sub_topics + extra_topics):
    p.fill(topic, dial(q_dlg.formid, branch=br.formid, prompt=prompt))
    command_info(topic, resp, frag, conds)

tame_info = infos["ILC_PetTame"]
i_cnam = next(i for i, (t, _) in enumerate(tame_info.subs) if t == "CNAM")
tame_info.subs[i_cnam + 1:i_cnam + 1] = [sub("TCLT", u32(t.formid)) for t in sub_topics]
i_tclt = max(i for i, (t, _) in enumerate(info_hello.subs) if t == "TCLT")
info_hello.subs[i_tclt + 1:i_tclt + 1] = [sub("TCLT", u32(t.formid)) for t in extra_topics]

# "Companion Commands" power (Z): MGEF + SPEL copied from AF's "Pet Commands", new message box
mgef_pow = p.reserve("ILC_PowerEffect", "MGEF")
spel_pow = p.reserve("ILC_PowerCommands", "SPEL")
mesg_pow = p.reserve("ILC_PowerMsg", "MESG")
p.fill(mesg_pow, [
    sub("DESC", zstr("Command your creature companions")),
    FULL("Companion Commands"),
    sub("INAM", u32(0)),
    sub("DNAM", u32(1)),          # message box
    *[sub("ITXT", zstr(b)) for b in ("Follow me", "Wait here", "Summon followers", "Summon all", "Cancel")],
])
mg = []
for t, d in af_subs(AF_MGEF_CTL):
    if t == "VMAD":
        d = VMAD([Script("ILC_PowerEffect", [Prop.obj("Followers", 0), Prop.obj("CommandMsg", mesg_pow.formid)])])[1]
    elif t == "FULL":
        d = zstr("Companion Commands")
    elif t == "DNAM":
        d = zstr("Follow / wait / summon your creature companions")
    mg.append((t, d))
p.fill(mgef_pow, mg)
sp = []
for t, d in af_subs(AF_SPEL_POW):
    if t == "FULL":
        d = zstr("Companion Commands")
    elif t == "EFID":
        d = u32(mgef_pow.formid)
    sp.append((t, d))
p.fill(spel_pow, sp)

p.fill(view, dlvw(q_dlg.formid, [br.formid]))

# =====================================================================================
#  V.2 follower quest, factions, packages
# =====================================================================================
# factions: PetFaction copies AF's relations (friend/ally/enemy to vanilla factions, ally to itself)
pet_subs = []
for t, d in af_subs(AF_PET_FACTION):
    if t == "FULL":
        d = zstr("IamLoveCreature Pet")
    elif t == "XNAM" and struct.unpack_from("<I", d)[0] == AF_PET_FACTION:
        d = u32(f_pet.formid) + d[4:]
    pet_subs.append((t, d))
p.fill(f_pet, pet_subs)
for rec, name in ((f_home, "IamLoveCreature Pet Has Home"), (f_wait, "IamLoveCreature Pet Waiting")):
    p.fill(rec, [(t, zstr(name) if t == "FULL" else d) for t, d in af_subs(0x01000800) if t != "XNAM"])

teammate_off = CTDA("GetPlayerTeammate", "==", 0)

# follow: identical to AF (template Skyrim.esm:0750BE, target PlayerRef, honours WaitingForPlayer)
p.fill(pk_follow, af_subs(AF_FOLLOW))

# sandbox (no home): "not teammate" and "not in HasHome faction"
sb = af_subs(AF_SANDBOX)
sb = replace_subs(sb, "CTDA", [teammate_off, CTDA("GetInFaction", "!=", 1, p1=f_home.formid)])
p.fill(pk_sandbox, sb)

# home N: sandbox template near alias "HomeNN" (marker placed at runtime by ILC_Followers.SetHome)
home_tpl = af_subs(AF_HOME1)
for i, rec in enumerate(pk_home):
    s = replace_subs(home_tpl, "CTDA", [teammate_off, CTDA("GetInFaction", "==", 1, p1=f_home.formid)])
    old_pldt = next(d for t, d in s if t == "PLDT")
    radius = struct.unpack_from("<i", old_pldt, 8)[0]
    s = [(t, (i32(8) + u32(HOME_ALIAS_BASE + i) + i32(radius)) if t == "PLDT" else d) for t, d in s]
    s = insert_before(s, "PKCU", [sub("QNAM", u32(q_fol.formid))])
    p.fill(rec, s)

aliases = []
alias_scripts = {}
for i in range(SLOTS):
    aliases += ref_alias(i, f"Pet{i + 1:02d}", flags=("Optional", "AllowReuse"),
                         packages=[pk_follow.formid, pk_home[i].formid, pk_sandbox.formid])
    alias_scripts[i] = [Script("ILC_PetAlias")]
for i in range(SLOTS):
    aliases += ref_alias(HOME_ALIAS_BASE + i, f"Home{i + 1:02d}", flags=("Optional", "AllowReuse"))

p.fill(q_fol, [
    VMAD_quest(
        [Script("ILC_Followers", [
            Prop.obj("PlayerRef", PLAYER_REF),
            Prop.obj("PetFaction", f_pet.formid),
            Prop.obj("PetHasHomeFaction", f_home.formid),
            Prop.obj("PetWaitingFaction", f_wait.formid),
            Prop.obj("AllyFaction", DUN_PLAYER_ALLY),
            Prop.obj("CurrentFollowerFaction", CURRENT_FOLLOWER),
            Prop.obj("XMarker", XMARKER),
            Prop.obj("Main", q_dlg.formid),
            Prop.obj("CommandPower", spel_pow.formid),
        ])],
        alias_scripts=alias_scripts,
        quest_formid=q_fol.formid),
    FULL("IamLoveCreature Followers"),
    # priority 40 < dialogue quest 60 (and SLAC 100): ForceGreet packages beat Follow/Home/Sandbox
    quest_dnam(start_game_enabled=True, priority=40),
    NEXT(),
    ANAM_next_alias(HOME_ALIAS_BASE + SLOTS),
    *aliases,
])

mgef_pow.subs = [(t, VMAD([Script("ILC_PowerEffect", [Prop.obj("Followers", q_fol.formid),
                                                      Prop.obj("CommandMsg", mesg_pow.formid)])])[1])
                 if t == "VMAD" else (t, d) for t, d in mgef_pow.subs]

# ---- write
esp = os.path.join(OUT_DIR, "IamLoveCreature.esp")
size = p.write(esp)
os.makedirs(os.path.join(OUT_DIR, "SEQ"), exist_ok=True)
seq_quests = p.write_seq(os.path.join(OUT_DIR, "SEQ", "IamLoveCreature.seq"))
print(f"wrote {esp} ({size} bytes)")
print(f"SEQ quests: {seq_quests}")
for r in p.records:
    if r.type == "PACK" and r.edid.startswith("ILC_PetHomePackage") and not r.edid.endswith(("01", f"{SLOTS:02d}")):
        continue
    print(f"  {r.formid:08X} {r.type} {r.edid}")
    for inf in r.infos:
        print(f"  {inf.formid:08X}   INFO")
