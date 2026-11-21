# ILoveCreature — V.4 (Peace spells + "I come in peace.")

## New in V.4
| What | How it works |
|---|---|
| Spell **Creature Peace** (aimed) | The creature stops fighting you (Aggression 0 + DunPlayerAllyFaction) for **5 min** (MCM). Original values come back when it ends. |
| Spell **Creature Call** (aimed) | Peace + the creature comes to talk. The **normal dialogue menu** of every mod is shown; ours is added at the end: **"I will make you happy."** (scene, no taming). |
| Hotkey **G** | You say **"I come in peace."** Every creature within the area (2500 units) becomes peaceful, then the creature under the crosshair (or the nearest) talks to you. Extra line: **"I will make you all happy."** |
| "you all happy" | This creature + **Max extra** (1-5, default 3) creatures nearby. **Stable** = always Max extra, **Random** = 1..Max extra. SexLab allows 4 creatures per scene, the rest get the next scene (chain). **Every creature becomes your companion** after its scene. |
| MCM page **Peace** | Hotkey, duration, area, Max extra, Stable/Random, Debug messages, live counters, **Reset peace + group** (fix stuck). |
| Removed | The test lines **"Hello!"** (K mode and Talk mode). V.3 is kept in `_backup_v3/`. |

Dialogue modes (global `ILC_DialogueCommands`): 0 Talk, 1 K, 2 Mate, **3 Creature Call, 4 G key**.

New records: `ILC_PeaceEffect/Spell`, `ILC_PeaceApplyEffect/Spell` (no projectile, used by G and Call),
`ILC_CallEffect/Spell`, `ILC_CallBranch` + `ILC_CallConsent`, `ILC_CallAllBranch` + `ILC_CallAll`.
New scripts: `ILC_Peace` (2nd script on ILC_DialogueQuest), `ILC_PeaceEffect`, `ILC_CallEffect`,
`ILC_TopicCreaturePCCall`, `ILC_TopicCreaturePCAll`.

# ILoveCreature — V.3 (Creature Bond + Mate)

Requires **SexLab.esm** (master since V.3). Backup of V.2 code: `_backup_v2\`.

- **Spell "Creature Bond"** (added to the player on load, Alteration-style aimed spell copied from AF's Tame Animal):
  cast on any creature → it stops fighting, becomes friendly (ally, Aggression 0) and follows you as a companion.
  Unlike AF, the target does not need to be calmed first. NPCs are refused.
- **K dialogue:** *I need a follower.* → **I will do it.** → consensual SexLab scene (`ILC_TopicCreaturePCConsent` →
  `ILC_Main.StartMate`) → when the scene ends (`AnimationEnd_ILC_CreatureConsent`) the creature becomes a companion.
  If no scene can start, it becomes a companion right away.
- **E on a companion → "Command Creature":** Follow · Mate · Wait · Let's go · Dismiss · Make your home here · Ride ·
  Banish · Talk · Cancel (max 10 buttons; *Forget your home* is in the K dialogue and MCM).
- **Z power** "Companion Commands" unchanged.
- **Talk vs K (V.3.1):** *Talk* in the companion menu opens only the plain greeting (no pet commands — they are in the
  menu). The **K** hotkey shows the greeting + all pet commands. Switch: global `ILC_DialogueCommands` 0866
  (set by `ILC_Main.TryOpenDialogue(creature, abCommands)`), checked by every pet command line.

- **Check / heal (V.3.4):** companions have *I want to check you.* (shows Health) → *I will heal you.* (Health 100%)
  / *Never mind.* — in Talk mode (own TopLevel branch `ILC_PetCheckBranch` 086B) and in the K menu (linked).
  Fragments `Fragment_Check` / `Fragment_Heal` in `ILC_TIF_Pet`.
- **5 mate choices (V.3.5)** in *I want to check you.* (after *I will heal you.*, *Never mind.* last). Ported from SLAC
  `slac_TopicCreaturePC*`: thin TIF scripts `ILC_TopicCreaturePC{Aggressive,Anal,Bitch,Oral,Group}` → logic in
  `ILC_Main.Mate*` / `StartMateEx` (SexLab tags + fallback) → reward when the scene ends (or at once if no scene):
  Rough = Attack +50%, Anal = Speed +50%, Bitch = Defense +50%, Oral = regen 1.5% max HP/s, Group = all four + full
  health for the scene creatures and every following companion nearby (group scene = up to 3 same-race companions).
  Buffs: spells `ILC_Buff{Attack,Speed,Defense,Regen}` 0873/0875/0877/0879 (60 s, MGEF script `ILC_BuffEffect`).
- **Buff settings (V.3.8):** MCM *Buffs* page — sliders Duration 1–60 min, Attack/Speed/Defense %, Regen %/s,
  Group strength %; *Balanced defaults* = 3 min, +25% / +20% / +30%, 0.5%/s, Group 60%. `ILC_Main.CastBuff` writes
  magnitude + duration into the spell (SKSE `SetNthEffectMagnitude/Duration`) right before casting; `ILC_BuffEffect`
  reads `GetMagnitude()`. Applied values are mirrored in StorageUtil (`ILC.Buff.<AV>`, list `ILC.BuffedActors`);
  *Debug → Clear all buffs* dispels everything and repairs leftovers (`ILC_Main.ClearAllBuffs`).
  *I will heal you.* = consent scene → full health, magicka and stamina when the scene ends.
- **Mate dialogue (V.3.6):** the *Mate* button of the companion menu opens the creature dialogue straight into the
  7 choices (heal, 5 mate choices, Never mind): `ILC_Main.OpenMateDialogue` sets `ILC_DialogueCommands` = 2 →
  greeting INFO 0884 in `ILC_HelloTopic` linked to the choices. Modes: 0 Talk, 1 K, 2 Mate.
- **Nether's Follower Framework (V.3.3, soft dependency):** NFF auto-imports every actor with `GetPlayerTeammate == 1`
  unless it carries `nwsIgnoreToken` (nwsFollowerFramework.esp:1CFC8D). Tamed creatures get the token (before they
  become teammates); Banish/Release calls NFF `RemoveFollower(actor, -1, 0)` (controller quest :00434F) and removes the
  token. On load, companions without the token are taken out of NFF slots and keep following/waiting.
  Compile with `tools\stubs` in the import list (stub of `nwsFollowerControllerScript` — never ship its .pex).

V.3 records: `ILC_ConsentSex` DIAL 0859 / INFO 085A, `ILC_TameEffect` MGEF 0864, `ILC_TameSpell` SPEL 0865.
Scripts: `ILC_TameEffect` (new), `ILC_TopicCreaturePCConsent` (new), `ILC_Main` (+SexLab, StartMate), `ILC_Followers` (+TameSpell, TameWithMessage, new menu).

---

# ILoveCreature — V.2 (Creature Followers)

V.2 merges the creature follower system from *Animal Followers (Beta)* into ILoveCreature.
**Uninstall Animal Followers first** (its MCM/power → Uninstall, save, remove it): a creature must not be
managed by both mods.

## Why pets of Animal Followers could not talk (fixed in V.2)
| Animal Followers | V.2 |
|---|---|
| Pet quest priority **100** → its Follow package beats the ILC (60) ForceGreet, so the K hotkey did nothing | `ILC_FollowerQuest` priority **40** → ILC (60) and SLAC (100) ForceGreet always win |
| `BlockActivation(true)` + own activate menu on every pet | no activation override; commands are in the creature dialogue |
| pets not in `CurrentFollowerFaction` | following pets join it (MCM toggle) → SLAC "Follower Dialogue" sees them |

## In game
**Taming:** look at a creature → **K** → it greets you → **I need a follower.** → it reacts →
- **Join me. I'll take care of you.** → it becomes your companion (no animation)
- **Never mind.** → cancel

**Companions:** press **E** (Activate) on a companion → command menu (like Animal Followers):
`Follow me` / `Stop following` · `Wait here` / `Let's go` · `Make your home here` · `Forget your home` ·
`Ride` (horses) · `Talk` (opens the creature dialogue, same as K) · `Release` (asks to confirm) · `Nothing`.
Buttons that don't fit the companion's state are hidden. The K dialogue still has every command too.

**Power "Companion Commands"** (added automatically, use it with the shout key **Z**):
Follow me (all resume) · Wait here (all wait) · Summon followers · Summon all · Cancel.

MCM → ILoveCreature:
- **Settings** — V.1 options (Mod Enabled, hotkey, OPEN test).
- **Follower Status** — pick a companion: race, level, behaviour, Health/Stamina/Magicka, location, home; commands
  Follow / Wait / Summon / Go to / Set home / Clear home / Inventory / Release; list of all companions below.
- **Slot History** — every companion: click name = **Summon**, click location = **Go to**; event log (tamed / released / died).
- **Follower Settings** — Summon followers / Summon all / Wait all / Resume all, *Count as follower (SLAC)*,
  *Catch up after load screens*, *Companions open doors* (SKSE race flags), Debug, Release all.

Not ported from Animal Followers: the Tame spell (taming is a dialogue line now) and the arrest/jail confiscation
of stolen pets (taming an owned animal still raises a theft alarm and shows "Stolen" in the MCM).

## V.2 records (new, FormIDs from 0809)
`ILC_FollowerQuest` 0809 (aliases Pet01–Pet50 = ids 0–49 with script `ILC_PetAlias`, Home01–Home50 = ids 100–149),
factions `ILC_PetFaction` 080A / `ILC_PetHasHome` 080B / `ILC_PetWaiting` 080C,
packages `ILC_PetFollowPackage` 080D, `ILC_PetSandboxPackage` 080E, `ILC_PetHomePackage01–50` 080F–0840
(copied from Animal Followers; home packages target their Home alias), command topics 0841–0849 (INFOs 084A–0852,
fragments in `ILC_TIF_Pet`). V.2.1 adds topics `ILC_PetTameJoin` 0853 / `ILC_PetTameCancel` 0854 / `ILC_PetRide` 0855
(INFOs 0856–0858), power `ILC_PowerEffect` MGEF 0859 / `ILC_PowerCommands` SPEL 085A / `ILC_PowerMsg` MESG 085B.
V.2.2: globals `ILC_MsgFollow/Wait/Home/Horse` 085C–085F, messages `ILC_PetMenu` 0860 / `ILC_PetReleaseConfirm` 0861,
alias `MenuPet` id 200 on `ILC_FollowerQuest` (name in the menu text).
Scripts: `ILC_Followers`, `ILC_PetAlias`, `ILC_TIF_Pet`, `ILC_PowerEffect`.
`tools\af_templates.json` caches the Animal Followers template records, so the build does not need that mod.

---

# ILoveCreature — CK Setup (v1 test: "Hey Hello")

Requires: SKSE64, SkyUI 5.x. (Standalone; it does not need SexLab Aroused Creatures as a master and works alongside it.)

## ⭐ The ESP is generated — no CK work needed

`ILoveCreature.esp` and `SEQ\ILoveCreature.seq` are built by `tools\build_esp.py`, which uses the Claude skill
`skyrim-esp-writer`. They contain everything that the CK steps below describe. To rebuild after changing the script:

```
python tools\build_esp.py
```

Install layout (MO2 mod folder or `Data\`):
```
ILoveCreature.esp
SEQ\ILoveCreature.seq
Scripts\ILC_Main.pex, ILC_CreatureAlias.pex, ILC_PlayerAlias.pex, ILC_TIF_HeyHello.pex, ILC_Config.pex
Source\Scripts\*.psc   (optional)
```
FormIDs: ILC_DialogueQuest 0800, ILC_MCMQuest 0801, ILC_ForceGreetPackage 0802, ILC_HelloBranch 0803,
ILC_HelloTopic 0804, ILC_HelloReply 0805, ILC_DialogueView 0806, INFO "Hey Hello" 0807, INFO "..." 0808.

Before the first in-game test, open the plugin in SSEEdit and run **Check for Errors** once.

The CK steps below remain as a reference for what the plugin contains, or in case you want to rebuild it by hand.

How it works (same trick SLAC uses for silent creatures): the hotkey puts the creature under the crosshair
into the `CreatureAlias` ReferenceAlias → the alias's **ForceGreet** package makes it walk to the player and open
`ILC_HelloTopic` → the creature says **"Hey Hello"**. When the Dialogue Menu closes, the alias is cleared.

## Scripts (`Source/Scripts`)
| File | Attach to |
|---|---|
| `ILC_Main.psc` | Quest `ILC_DialogueQuest` |
| `ILC_PlayerAlias.psc` | Alias `PlayerAlias` on `ILC_DialogueQuest` |
| `ILC_CreatureAlias.psc` | Alias `CreatureAlias` on `ILC_DialogueQuest` |
| `ILC_TIF_HeyHello.psc` | TopicInfo "Hey Hello" (End fragment, optional) |
| `ILC_TopicCreaturePCConsent.psc` | TopicInfo "Do you want me?" (Begin fragment — starts consensual SexLab scene) |
| `ILC_Config.psc` | Quest `ILC_MCMQuest` |

Compile includes: vanilla source + SKSE64 source + SkyUI SDK (`SKI_ConfigBase`, `SKI_QuestBase`) + SexLab Framework source (`SexLabFramework.psc`, `sslThreadModel.psc`, `sslThreadController.psc`, `sslBaseAnimation.psc`).

## 1. Quest `ILC_DialogueQuest`
- Quest Data: **Start Game Enabled** ✔, Run Once ✘, Priority `60`, Type: None.
- **Quest Aliases**
  1. `PlayerAlias` — Specific Reference: `PlayerRef` (`00000014`). Script: `ILC_PlayerAlias`.
  2. `CreatureAlias` — Fill Type: Specific Reference = *none*, flags **Optional** ✔, **Allow Reuse in Quest** ✔.
     - Alias Package Data → add `ILC_ForceGreetPackage` (step 2).
     - Script: `ILC_CreatureAlias`.
- **Scripts** tab → add `ILC_Main`, properties:
  - `PlayerRef` → PlayerRef (auto-fill)
  - `CreatureAlias` → CreatureAlias
  - `ActorTypeNPC` → `ActorTypeNPC` (auto-fill)

## 2. Package `ILC_ForceGreetPackage`
- Template: **ForceGreet**.
- Target / Ref: Specific Reference → `PlayerRef`.
- Topic: `ILC_HelloTopic` (step 3; make the topic first, then come back).
- Flags (General): **Must Complete** ✔ (optional), keep "Interrupt" defaults.

## 3. Dialogue (on `ILC_DialogueQuest` → Player Dialogue tab)
1. New Branch `ILC_HelloBranch` (Type: Normal) — starting topic `ILC_HelloTopic`, Topic Text: *(leave empty)*.
2. In `ILC_HelloTopic` add a Topic Info:
   - Response text: **`Hey Hello`**
   - Conditions: `GetIsAliasRef  CreatureAlias == 1` (Run On: **Subject**)
   - *(optional)* End fragment → type `;` → compile → Advanced tab → **Rename Script** → `ILC_TIF_HeyHello`
     (it uses `Fragment_0`, so the End fragment must be the first fragment you create).
   - Link To: `ILC_HelloReply` (step 3).
3. New topic `ILC_HelloReply` — Topic Text (what the player says): `Hello!`
   - Info response: `...` (same condition `GetIsAliasRef CreatureAlias == 1`), flag **Goodbye** ✔.

> Creatures usually have no voice files. Without audio, a line can flash past too quickly to read —
> install **Fuz Ro D-oh** (silent voice) so the subtitle stays on screen.

### 3b. Expanded dialogue tree (V.3: creature consent / SexLab integration)

The "Hey Hello" topic now links to a **player-choice menu** instead of a Goodbye reply.
This mirrors SLAC's `slac_CreatureDialogueOptions` branch.

**New dialogue flow:**
```
ForceGreet → creature says "Hey Hello" (ILC_HelloTopic)
  └─ LinkTo ILC_ConsentBranch (player choices):
       ├── "Do you want me?"         → ILC_TopicCreaturePCConsent (starts SexLab scene)
       ├── "Come with me."           → ILC_PetTameJoin (tame as follower, V.2)
       └── "Never mind."             → Goodbye
```

**CK steps for the consent topic:**
1. On `ILC_DialogueQuest` → Player Dialogue tab, create a new Branch `ILC_ConsentBranch`:
   - Type: Normal (not TopLevel, not Blocking)
   - Starting Topic: `ILC_ConsentTopic`
   - Topic Text: `Do you want me?` (this is what the player says)
2. In `ILC_ConsentTopic`, add a Topic Info:
   - Response text: `" "` (a space — creature doesn't speak, same trick as SLAC)
   - Conditions: `GetIsAliasRef CreatureAlias == 1` (Run On: **Subject**)
   - Flags: **Goodbye** ✔, **No LIP File** ✔
   - **Begin fragment** → type `;` → compile → Advanced → Rename Script → `ILC_TopicCreaturePCConsent`
     (must be Fragment_0 = the first fragment you create)
   - Properties (fill in CK Properties dialog):
     - `Main` → `ILC_DialogueQuest`
     - `CreatureRef` → alias `CreatureAlias` on `ILC_DialogueQuest`
     - `PlayerRef` → `PlayerRef` (00000014)
     - `SexLab` → `SexLabQuestFramework` (auto-fill from SexLab.esm)
     - `InviteAnimation` → False (or True to strip + wait before scene)
     - `DialogueSignal` → None (or a GlobalVariable if you use one)
3. Go back to the **"Hey Hello"** INFO in `ILC_HelloTopic`:
   - Remove the old LinkTo to `ILC_HelloReply` (the "Hello! → Goodbye" path)
   - Add LinkTo → `ILC_ConsentTopic` ("Do you want me?")
   - Add LinkTo → `ILC_PetTameJoin` ("Come with me." — from V.2 taming)
   - Add LinkTo → a new Goodbye topic ("Never mind." with Goodbye flag)

**Requires:** SexLab Framework (SexLab.esm as a master, or soft-dependency via property).
Creature animations must be enabled in SexLab MCM → the script checks `SexLab.AllowCreatures`.

## 4. Quest `ILC_MCMQuest` (MCM)
- **Start Game Enabled** ✔.
- Alias `PlayerAlias` → Specific Reference `PlayerRef`, Script: **`SKI_PlayerLoadGameAlias`**.
- Script: `ILC_Config`, property `Main` → `ILC_DialogueQuest`.

## In game
MCM → **ILoveCreature → Settings**
- **Mod Enabled** — on/off.
- **Open Dialogue Hotkey** — default **K**. Look at a creature and press it.
- **Open Dialogue (Nearest Creature) → OPEN** — test button: close the menu, and the nearest living creature in
  the cell walks over and says "Hey Hello".

If the notification `ILoveCreature: Dialogue OK - <name> says Hey Hello` shows, the dialogue is wired correctly.
Debug log: look for `[ILoveCreature]` in `Papyrus.0.log`.
