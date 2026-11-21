"""
Builds ILoveCreature.esp (+ SEQ\\ILoveCreature.seq) without the Creation Kit.

    python build_esp.py            -> writes ..\\ILoveCreature.esp and ..\\SEQ\\ILoveCreature.seq

V.1  hotkey ForceGreet creature dialogue ("Hey Hello").
V.2  creature followers (merged from Animal Followers): tame / follow / wait / home / inventory / release
     through the creature dialogue, plus MCM pages. FormIDs of V.1 records are unchanged.
V.3  Creature Bond spell, consent / mate choices, buffs.
V.4  peace spells (Creature Peace, Creature Call), G key "I come in peace.", "I will make you all happy."
     group chain (every creature of it becomes a companion). The test lines "Hello!" were removed (kept in _backup_v3).

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

p = Plugin(masters=["Skyrim.esm", "SexLab.esm"], author="pethzero",
           desc="ILoveCreature V.4 - creature dialogue + creature followers + SexLab consent + peace spells")

PLAYER_REF = p.skyrim("PlayerRef")
ACTOR_TYPE_NPC = p.skyrim("ActorTypeNPC")
XMARKER = p.master("Skyrim.esm", 0x00003B)              # STAT XMarker
DUN_PLAYER_ALLY = p.master("Skyrim.esm", 0x05A1A4)      # FACT DunPlayerAllyFaction
CURRENT_FOLLOWER = p.skyrim("CurrentFollowerFaction")
SEXLAB_QUEST = p.master("SexLab.esm", 0x000D62)          # QUST SexLabQuestFramework


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
AF_MGEF_TAME, AF_SPEL_TAME = 0x01000810, 0x01000811  # "Tame Animal" spell (visuals for V.3 "Creature Bond")
AF_WANTED = {AF_PET_FACTION, AF_FOLLOW, AF_SANDBOX, AF_HOME1, AF_MGEF_CTL, AF_SPEL_POW, AF_MGEF_TAME, AF_SPEL_TAME}
AF_PLUGIN = os.path.normpath(os.path.join(HERE, r"..\..\Animal Followers (Beta)\_backup_original\nPetFollowers.esp"))
if not os.path.isfile(AF_PLUGIN):
    AF_PLUGIN = os.path.normpath(os.path.join(HERE, r"..\..\Animal Followers (Beta)\Data\nPetFollowers.esp"))
import json  # noqa: E402
if os.path.isfile(AF_PLUGIN):
    AF = read_records(AF_PLUGIN, AF_WANTED)
    assert len(AF) == len(AF_WANTED), f"Animal Followers templates not found in {AF_PLUGIN}"
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
    notes="ILoveCreature test line - proves the creature dialogue works",
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
            Prop.obj("SexLab", SEXLAB_QUEST),
        ])],
        alias_scripts={
            ALIAS_PLAYER: [Script("ILC_PlayerAlias")],
            ALIAS_CREATURE: [Script("ILC_CreatureAlias")],
        },
        quest_formid=q_dlg.formid),
    FULL("ILoveCreature Dialogue"),
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
    FULL("ILoveCreature MCM"),
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
    infos[edid] = command_info(topic, resp, frag, conds)

# V.3: Consensual creature sex option (SexLab.esm is a master)
t_consent = p.reserve("ILC_ConsentSex", "DIAL")
p.fill(t_consent, dial(q_dlg.formid, branch=br.formid, prompt="I will do it."))
p.add_info(t_consent, info(
    " ",
    flags=("Goodbye",) + silent,
    conditions=[is_creature_alias],
    vmad=VMAD_info(
        [Script("ILC_TopicCreaturePCConsent", [
            Prop.obj("Main", q_dlg.formid),
            Prop.obj("CreatureRef", q_dlg.formid, ALIAS_CREATURE),
        ])],
        "ILC_TopicCreaturePCConsent",
        begin="Fragment_0"),
    notes="V.3 consent - starts SexLab scene via ILC_TopicCreaturePCConsent",
))

tame_info = infos["ILC_PetTame"]
i_cnam = next(i for i, (t, _) in enumerate(tame_info.subs) if t == "CNAM")
tame_info.subs[i_cnam + 1:i_cnam + 1] = [sub("TCLT", u32(t_consent.formid))] + [sub("TCLT", u32(t.formid)) for t in sub_topics]
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
        d = zstr("ILoveCreature Pet")
    elif t == "XNAM" and struct.unpack_from("<I", d)[0] == AF_PET_FACTION:
        d = u32(f_pet.formid) + d[4:]
    pet_subs.append((t, d))
p.fill(f_pet, pet_subs)
for rec, name in ((f_home, "ILoveCreature Pet Has Home"), (f_wait, "ILoveCreature Pet Waiting")):
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

# ---- V.2.2: E on a companion opens a command message box (Animal Followers style)
g_follow = p.add("ILC_MsgFollow", "GLOB", glob(0, "s"))
g_wait = p.add("ILC_MsgWait", "GLOB", glob(0, "s"))
g_home = p.add("ILC_MsgHome", "GLOB", glob(0, "s"))
g_horse = p.add("ILC_MsgHorse", "GLOB", glob(0, "s"))
mesg_menu = p.reserve("ILC_PetMenu", "MESG")
mesg_release = p.reserve("ILC_PetReleaseConfirm", "MESG")
MENU_ALIAS = 200

# ---- V.3: spell "Creature Bond" (new FormIDs after 0863)
mgef_tame = p.reserve("ILC_TameEffect", "MGEF")
spel_tame = p.reserve("ILC_TameSpell", "SPEL")
TAME_NAME = "Creature Bond"
mg = []
for t, d in af_subs(AF_MGEF_TAME):
    if t == "CTDA":
        continue                      # AF needs a Calm/Pacify effect first - ours calms the creature itself
    if t == "VMAD":
        d = VMAD([Script("ILC_TameEffect", [Prop.obj("Followers", q_fol.formid),
                                            Prop.obj("ActorTypeNPC", ACTOR_TYPE_NPC)])])[1]
    elif t == "FULL":
        d = zstr(TAME_NAME)
    elif t == "DNAM":
        d = zstr("The creature stops fighting, becomes friendly and follows you as a companion.")
    mg.append((t, d))
p.fill(mgef_tame, mg)
p.fill(spel_tame, [(t, zstr(TAME_NAME) if t == "FULL" else u32(mgef_tame.formid) if t == "EFID" else d)
                   for t, d in af_subs(AF_SPEL_TAME)])

# ---- V.3.1: "Talk" from the companion menu = plain greeting, K hotkey = greeting + pet commands.
# ILC_Main.TryOpenDialogue sets this global (1 = K / commands, 0 = Talk); every pet command line needs it == 1.
g_cmds = p.add("ILC_DialogueCommands", "GLOB", glob(1, "s"))
for edid, prompt, resp, frag, conds in COMMANDS + EXTRA:
    if "pet" in conds.split():
        infos[edid].subs.append(CTDA("GetGlobalValue", "==", 1, p1=g_cmds.formid))

# ---- V.3.2: Talk = normal dialogue menu (every mod's top-level topics) + "Hello!" at the bottom.
# A greeting line WITH LinkTo shows only its links, so Talk mode gets its own greeting line without links.
talk_mode = CTDA("GetGlobalValue", "==", 0, p1=g_cmds.formid)
info_hello.subs.append(CTDA("GetGlobalValue", "==", 1, p1=g_cmds.formid))   # K: old line + command links
p.add_info(t_hello, info(
    "Hey Hello",
    flags=silent,
    conditions=[is_creature_alias, talk_mode],
    notes="Talk mode greeting (no links -> normal top-level dialogue menu)",
))
br_talk = p.reserve("ILC_TalkBranch", "DLBR")
t_talk_bye = p.reserve("ILC_TalkHello", "DIAL")
p.fill(br_talk, dlbr(q_dlg.formid, t_talk_bye.formid, top_level=True))
p.fill(t_talk_bye, dial(q_dlg.formid, branch=br_talk.formid, prompt="Hello!", priority=1.0))   # low = last
p.add_info(t_talk_bye, info(
    "...",
    flags=("Goodbye",) + silent,
    conditions=[is_creature_alias, talk_mode],
))

# ---- V.3.4: "I want to check you." -> shows health -> "I will heal you." (100% health) / "Never mind."
# Own TopLevel branch (a TopLevel branch shows only its start topic) -> shows in Talk mode;
# also linked from the K greeting. The two answers live in the normal (non-top-level) branch.
br_check = p.reserve("ILC_PetCheckBranch", "DLBR")
t_check = p.reserve("ILC_PetCheck", "DIAL")
t_heal = p.reserve("ILC_PetHeal", "DIAL")
t_check_no = p.reserve("ILC_PetCheckCancel", "DIAL")
pet_only = [is_creature_alias, COND["pet"]]
p.fill(br_check, dlbr(q_dlg.formid, t_check.formid, top_level=True))
p.fill(t_check, dial(q_dlg.formid, branch=br_check.formid, prompt="I want to check you.", priority=40.0))
p.fill(t_heal, dial(q_dlg.formid, branch=br.formid, prompt="I will heal you."))
p.fill(t_check_no, dial(q_dlg.formid, branch=br.formid, prompt="Never mind."))
info_check = p.add_info(t_check, info(
    "*It lets you look it over.*",
    flags=silent,
    links=[t_heal.formid, t_check_no.formid],
    conditions=pet_only,
    vmad=VMAD_info([Script("ILC_TIF_Pet")], "ILC_TIF_Pet", begin="Fragment_Check"),
))
p.add_info(t_heal, info(           # V.3.7: consent scene, full health afterwards (ILC_Main.MateConsent)
    "*It nuzzles against you.*",
    flags=("Goodbye",) + silent,
    conditions=pet_only,
    vmad=VMAD_info([Script("ILC_TopicCreaturePCConsent", [Prop.obj("Main", q_dlg.formid),
                                                          Prop.obj("CreatureRef", q_dlg.formid, ALIAS_CREATURE)])],
                   "ILC_TopicCreaturePCConsent", begin="Fragment_0"),
))
p.add_info(t_check_no, info("*It wags happily.*", flags=("Goodbye",) + silent, conditions=pet_only))
i_tclt = max(i for i, (t, _) in enumerate(info_hello.subs) if t == "TCLT")
info_hello.subs[i_tclt + 1:i_tclt + 1] = [sub("TCLT", u32(t_check.formid))]

# ---- V.3.5: companion buff spells (60 s, Self, script ILC_BuffEffect) built from the tame MGEF template
def put_u32(b, off, v):
    return b[:off] + struct.pack("<I", v & 0xFFFFFFFF) + b[off + 4:]


tame_mgef_data = next(d for t, d in af_subs(AF_MGEF_TAME) if t == "DATA")
buff_data = tame_mgef_data
buff_data = put_u32(buff_data, 0, 0x800)                  # flags: No Area (magnitude = strength, has duration, not hostile)
buff_data = buff_data[:4] + struct.pack("<f", 0.0) + buff_data[8:]   # base cost 0
for off, v in ((12, -1), (16, -1), (24, 0), (32, 0), (40, 0), (72, 0), (80, 1), (84, 0),
               (92, 0), (96, 0), (100, 0), (108, 0)):
    # skill, resist AV, light, hit shader, min skill, projectile, Fire&Forget, Self, art/impact/dual-cast off
    buff_data = put_u32(buff_data, off, v)
spel_tpl = af_subs(AF_SPEL_TAME)
BUFFS = [("ILC_BuffAttack", "Pack Fury (Attack +50%)", 0), ("ILC_BuffSpeed", "Pack Swiftness (Speed +50%)", 1),
         ("ILC_BuffDefense", "Pack Hide (Defense +50%)", 2), ("ILC_BuffRegen", "Pack Vigor (Regeneration)", 3)]
buff_spells = {}
for edid, name, kind in BUFFS:
    m = p.reserve(edid + "Effect", "MGEF")
    s = p.reserve(edid, "SPEL")
    mg = []
    for t, d in af_subs(AF_MGEF_TAME):
        if t == "CTDA" or t == "SNDD":
            continue
        if t == "VMAD":
            d = VMAD([Script("ILC_BuffEffect", [Prop.int("BuffType", kind)])])[1]
        elif t == "FULL":
            d = zstr(name)
        elif t == "DNAM":
            d = zstr("A gift from your bond.")
        elif t == "DATA":
            d = buff_data
        mg.append((t, d))
    p.fill(m, mg)
    sp = []
    for t, d in spel_tpl:
        if t == "FULL":
            d = zstr(name)
        elif t == "SPIT":   # cost 0, manual cost, spell, charge 0, fire&forget, self, 0, 0, no perk
            d = u32(0) + u32(1) + u32(0) + struct.pack("<f", 0.0) + u32(1) + u32(0) + struct.pack("<ff", 0.0, 0.0) + u32(0)
        elif t == "EFID":
            d = u32(m.formid)
        elif t == "EFIT":   # magnitude / duration: overwritten before every cast by ILC_Main.CastBuff (MCM sliders)
            d = struct.pack("<f", 25.0) + u32(0) + u32(180)
        sp.append((t, d))
    p.fill(s, sp)
    buff_spells[edid] = s

# ---- V.3.5: 5 choices in "I want to check you." (after "I will heal you.", "Never mind." stays last)
MATE_CHOICES = [
    # rewards are listed in the MCM "Buffs" page, not in the prompt
    ("ILC_PetMateRough", "Do what you will with me.",
     "*It growls and pins you down.*", "ILC_TopicCreaturePCAggressive"),
    ("ILC_PetMateAnal", "Let's do something dirty.",
     "*Its eyes light up.*", "ILC_TopicCreaturePCAnal"),
    ("ILC_PetMateBitch", "Make me your bitch.",
     "*It circles you, ready to claim you.*", "ILC_TopicCreaturePCBitch"),
    ("ILC_PetMateOral", "I'll do something special for you.",
     "*It steps closer eagerly.*", "ILC_TopicCreaturePCOral"),
    ("ILC_PetMateGroup", "Maybe we can find some friends.",
     "*It calls its packmates.*", "ILC_TopicCreaturePCGroup"),
]
mate_topics = []
for edid, prompt, resp, script in MATE_CHOICES:
    t = p.reserve(edid, "DIAL")
    p.fill(t, dial(q_dlg.formid, branch=br.formid, prompt=prompt))
    p.add_info(t, info(
        resp,
        flags=("Goodbye",) + silent,
        conditions=pet_only,
        vmad=VMAD_info([Script(script, [Prop.obj("Main", q_dlg.formid),
                                        Prop.obj("CreatureRef", q_dlg.formid, ALIAS_CREATURE)])],
                       script, begin="Fragment_0"),
        notes="V.3.5 " + script,
    ))
    mate_topics.append(t)
i_no = next(i for i, (t, d) in enumerate(info_check.subs) if t == "TCLT" and d == u32(t_check_no.formid))
info_check.subs[i_no:i_no] = [sub("TCLT", u32(t.formid)) for t in mate_topics]

# ---- V.3.6: "Mate" button of the companion menu opens the dialogue straight into the 7 choices.
# ILC_DialogueCommands == 2 (set by ILC_Main.OpenMateDialogue) -> this greeting line, linked to the choices.
p.add_info(t_hello, info(
    "*It looks at you expectantly.*",
    flags=silent,
    links=[t_heal.formid] + [t.formid for t in mate_topics] + [t_check_no.formid],
    conditions=[is_creature_alias, COND["pet"], CTDA("GetGlobalValue", "==", 2, p1=g_cmds.formid)],
    notes="Mate mode greeting (companion menu -> Mate)",
))


def gv(g, v):
    return CTDA("GetGlobalValue", "==", v, p1=g.formid)


MENU_BUTTONS = [                       # index order = ILC_Followers.OpenPetMenu (max 10 buttons)
    ("Follow",              [gv(g_follow, 0)]),
    ("Mate",                []),
    ("Wait",                [gv(g_follow, 1), gv(g_wait, 0)]),
    ("Let's go",            [gv(g_wait, 1)]),
    ("Dismiss",             [gv(g_follow, 1)]),
    ("Make your home here", []),
    ("Ride",                [gv(g_horse, 1)]),
    ("Release",             []),
    ("Talk",                []),
    ("Cancel",              []),
]
menu = [sub("DESC", zstr("Command <Alias=MenuPet>")), FULL("Command Creature"),
        sub("INAM", u32(0)), sub("QNAM", u32(q_fol.formid)), sub("DNAM", u32(1))]
for text, conds in MENU_BUTTONS:
    menu += [sub("ITXT", zstr(text))] + conds
p.fill(mesg_menu, menu)
p.fill(mesg_release, [sub("DESC", zstr("Release <Alias=MenuPet>? It becomes a wild creature again.")),
                      FULL("Release"), sub("INAM", u32(0)), sub("QNAM", u32(q_fol.formid)), sub("DNAM", u32(1)),
                      sub("ITXT", zstr("Yes, release")), sub("ITXT", zstr("No"))])

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
            Prop.obj("TameSpell", spel_tame.formid),
            Prop.obj("gDialogueCommands", g_cmds.formid),
            Prop.obj("BuffAttack", buff_spells["ILC_BuffAttack"].formid),
            Prop.obj("BuffSpeed", buff_spells["ILC_BuffSpeed"].formid),
            Prop.obj("BuffDefense", buff_spells["ILC_BuffDefense"].formid),
            Prop.obj("BuffRegen", buff_spells["ILC_BuffRegen"].formid),
            Prop.obj("PetMenu", mesg_menu.formid),
            Prop.obj("ReleaseConfirm", mesg_release.formid),
            Prop.obj("gMsgFollow", g_follow.formid),
            Prop.obj("gMsgWait", g_wait.formid),
            Prop.obj("gMsgHome", g_home.formid),
            Prop.obj("gMsgHorse", g_horse.formid),
            Prop.obj("ActorTypeHorse", p.master("Skyrim.esm", 0x026110)),
        ])],
        alias_scripts=alias_scripts,
        quest_formid=q_fol.formid),
    FULL("ILoveCreature Followers"),
    # priority 40 < dialogue quest 60 (and SLAC 100): ForceGreet packages beat Follow/Home/Sandbox
    quest_dnam(start_game_enabled=True, priority=40),
    NEXT(),
    ANAM_next_alias(MENU_ALIAS + 1),
    *aliases,
    *ref_alias(MENU_ALIAS, "MenuPet", flags=("Optional", "AllowReuse", "StoresText")),
])

mgef_pow.subs = [(t, VMAD([Script("ILC_PowerEffect", [Prop.obj("Followers", q_fol.formid),
                                                      Prop.obj("CommandMsg", mesg_pow.formid)])])[1])
                 if t == "VMAD" else (t, d) for t, d in mgef_pow.subs]


# =====================================================================================
#  V.4 (new FormIDs at the end; nothing above moves)
# =====================================================================================
# ---- remove the test lines "Hello!" (K-mode goodbye + Talk-mode bottom line). Kept in _backup_v3.
info_hello.subs = [(t, d) for t, d in info_hello.subs if not (t == "TCLT" and d == u32(t_reply.formid))]
p.records = [r for r in p.records if r not in (t_reply, br_talk, t_talk_bye)]

# ---- spells: "Creature Peace" (aimed, has duration), its no-projectile twin for the G key,
#      and "Creature Call" (aimed, instant: peace + dialogue). Built from the Tame Animal templates.
PEACE_SECONDS = 300            # 5 min default; ILC_Peace.ApplyDuration rewrites it from the MCM
mgef_peace = p.reserve("ILC_PeaceEffect", "MGEF")
spel_peace = p.reserve("ILC_PeaceSpell", "SPEL")
mgef_peace_apply = p.reserve("ILC_PeaceApplyEffect", "MGEF")
spel_peace_apply = p.reserve("ILC_PeaceApplySpell", "SPEL")
mgef_call = p.reserve("ILC_CallEffect", "MGEF")
spel_call = p.reserve("ILC_CallSpell", "SPEL")

peace_data = put_u32(tame_mgef_data, 0, struct.unpack_from("<I", tame_mgef_data, 0)[0] & ~0x200)  # has duration
apply_data = put_u32(put_u32(peace_data, 84, 3), 72, 0)     # delivery Target Actor, no projectile


def spell_effect(rec, script, name, desc, data=None):
    out = []
    for t, d in af_subs(AF_MGEF_TAME):
        if t == "CTDA":
            continue
        if t == "VMAD":
            d = VMAD([Script(script, [Prop.obj("Peace", q_dlg.formid)])])[1]
        elif t == "FULL":
            d = zstr(name)
        elif t == "DNAM":
            d = zstr(desc)
        elif t == "DATA" and data is not None:
            d = data
        out.append((t, d))
    p.fill(rec, out)


def spell(rec, mgef, name, duration=0, delivery=None):
    out = []
    for t, d in af_subs(AF_SPEL_TAME):
        if t == "FULL":
            d = zstr(name)
        elif t == "EFID":
            d = u32(mgef.formid)
        elif t == "EFIT":
            d = struct.pack("<f", 0.0) + u32(0) + u32(duration)
        elif t == "SPIT" and delivery is not None:
            d = put_u32(put_u32(d, 0, 0), 20, delivery)          # cost 0, delivery
        out.append((t, d))
    p.fill(rec, out)


spell_effect(mgef_peace, "ILC_PeaceEffect", "Creature Peace",
             "The creature stops fighting you for a few minutes.", peace_data)
spell(spel_peace, mgef_peace, "Creature Peace", PEACE_SECONDS)
spell_effect(mgef_peace_apply, "ILC_PeaceEffect", "Creature Peace",
             "The creature stops fighting you for a few minutes.", apply_data)
spell(spel_peace_apply, mgef_peace_apply, "Creature Peace", PEACE_SECONDS, delivery=3)
spell_effect(mgef_call, "ILC_CallEffect", "Creature Call",
             "The creature stops fighting you and comes to talk.")
spell(spel_call, mgef_call, "Creature Call")

# ---- dialogue: ILC_DialogueCommands 3 = Creature Call, 4 = G key.
# Greeting WITHOUT links -> the normal top-level menu of every mod; our two lines are TopLevel
# branches with low priority, so they are added at the END (other mods' dialogue is not replaced).
peace_mode = CTDA("GetGlobalValue", ">=", 3, p1=g_cmds.formid)
p.add_info(t_hello, info(
    "*It watches you calmly.*",
    flags=silent,
    conditions=[is_creature_alias, peace_mode],
    notes="V.4 Creature Call / G greeting (no links -> normal top-level dialogue menu)",
))
br_call = p.reserve("ILC_CallBranch", "DLBR")
t_call = p.reserve("ILC_CallConsent", "DIAL")
br_all = p.reserve("ILC_CallAllBranch", "DLBR")
t_all = p.reserve("ILC_CallAll", "DIAL")
p.fill(br_call, dlbr(q_dlg.formid, t_call.formid, top_level=True))
p.fill(t_call, dial(q_dlg.formid, branch=br_call.formid, prompt="I will make you happy.", priority=2.0))
p.add_info(t_call, info(
    "*It comes closer.*",
    flags=("Goodbye",) + silent,
    conditions=[is_creature_alias, peace_mode],
    vmad=VMAD_info([Script("ILC_TopicCreaturePCCall", [Prop.obj("Main", q_dlg.formid),
                                                       Prop.obj("CreatureRef", q_dlg.formid, ALIAS_CREATURE)])],
                   "ILC_TopicCreaturePCCall", begin="Fragment_0"),
    notes="V.4 Call / G: scene with this creature (no taming)",
))
p.fill(br_all, dlbr(q_dlg.formid, t_all.formid, top_level=True))
p.fill(t_all, dial(q_dlg.formid, branch=br_all.formid, prompt="I will make you all happy.", priority=1.0))
p.add_info(t_all, info(
    "*The others gather around you.*",
    flags=("Goodbye",) + silent,
    conditions=[is_creature_alias, CTDA("GetGlobalValue", "==", 4, p1=g_cmds.formid)],
    vmad=VMAD_info([Script("ILC_TopicCreaturePCAll", [Prop.obj("Main", q_dlg.formid),
                                                      Prop.obj("CreatureRef", q_dlg.formid, ALIAS_CREATURE)])],
                   "ILC_TopicCreaturePCAll", begin="Fragment_0"),
    notes="V.4 G only: this creature + Max extra (Stable / Random), scenes one after another, all become companions",
))

# ---- dialogue quest: ILC_Main gets "Peace", second script ILC_Peace
q_dlg.subs = [(t, VMAD_quest(
    [Script("ILC_Main", [
        Prop.obj("PlayerRef", PLAYER_REF),
        Prop.obj("CreatureAlias", q_dlg.formid, ALIAS_CREATURE),
        Prop.obj("ActorTypeNPC", ACTOR_TYPE_NPC),
        Prop.obj("Followers", q_fol.formid),
        Prop.obj("SexLab", SEXLAB_QUEST),
        Prop.obj("Peace", q_dlg.formid),
    ]),
     Script("ILC_Peace", [
        Prop.obj("PlayerRef", PLAYER_REF),
        Prop.obj("ActorTypeNPC", ACTOR_TYPE_NPC),
        Prop.obj("AllyFaction", DUN_PLAYER_ALLY),
        Prop.obj("Main", q_dlg.formid),
        Prop.obj("Followers", q_fol.formid),
        Prop.obj("PeaceSpell", spel_peace.formid),
        Prop.obj("CallSpell", spel_call.formid),
        Prop.obj("PeaceApplySpell", spel_peace_apply.formid),
    ])],
    alias_scripts={
        ALIAS_PLAYER: [Script("ILC_PlayerAlias")],
        ALIAS_CREATURE: [Script("ILC_CreatureAlias")],
    },
    quest_formid=q_dlg.formid)[1]) if t == "VMAD" else (t, d) for t, d in q_dlg.subs]

# ---- write
esp = os.path.join(OUT_DIR, "ILoveCreature.esp")
size = p.write(esp)
os.makedirs(os.path.join(OUT_DIR, "SEQ"), exist_ok=True)
seq_quests = p.write_seq(os.path.join(OUT_DIR, "SEQ", "ILoveCreature.seq"))
print(f"wrote {esp} ({size} bytes)")
print(f"SEQ quests: {seq_quests}")
for r in p.records:
    if r.type == "PACK" and r.edid.startswith("ILC_PetHomePackage") and not r.edid.endswith(("01", f"{SLOTS:02d}")):
        continue
    print(f"  {r.formid:08X} {r.type} {r.edid}")
    for inf in r.infos:
        print(f"  {inf.formid:08X}   INFO")
