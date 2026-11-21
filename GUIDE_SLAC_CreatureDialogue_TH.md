# คู่มือ: SLAC ทำ Creature Dialogue ยังไง → เอามาทำใน ILoveCreature

ที่มา: อ่านตรงจาก `SexLab Aroused Creatures.esp` (v04.18) ด้วยตัว parse ESP และอ่านคู่กับ source `.psc` ของ SLAC
FormID ในเอกสารนี้อ้างตามไฟล์ ESP (index `05` = ตัว SLAC เอง)

---

## 1. ภาพรวม flow ของ SLAC

```
[ผู้เล่นกด E / ปุ่ม Invite ใส่ creature]
        │  slac_PlayerScript.OnKeyDown()
        ▼
ForcedRef.ForceRefTo(creature)  +  creature.EvaluatePackage()
        │  alias "ForcedRef" มี package slac_CreatureForceGreet
        ▼
Package ForceGreet (Target = PlayerRef, Topic = slac_CreatureDialogueForcedBranchTopic)
        │  creature เดินมาหาผู้เล่น แล้วเปิด Dialogue Menu
        ▼
INFO 05061C1A (ข้อความ " ")  ── LinkTo ──►  ตัวเลือกของผู้เล่น:
        │                                     • "Hey, need some fun?"   (slac_CreatureDialogueArousalSucceed)
        │                                     • "Let's go (Ride)"       (slac_CreatureDialogueMount)
        │                                     • "This will do..."        (follow end)
        │                                     • "Never mind (stop following)"
        ▼
ผู้เล่นเลือก "Hey, need some fun?" → INFO 050467B4 (Begin fragment slac_TopicCreatureUseStart)
        │  เคลียร์ ForcedRef แล้วย้าย creature ไปไว้ใน CreatureRef
        ▼
LinkTo → "Do you want me?" / "Maybe <VictimRef> can satisfy you" / "Come with me" / "Never mind"
```

**หัวใจของระบบ:** creature ส่วนใหญ่อยู่ใน race ที่ไม่มีแฟล็ก *Allow PC Dialogue* ผู้เล่นจึงกด E คุยเองไม่ได้
SLAC แก้โดยให้ **creature เป็นฝ่าย ForceGreet เข้ามาหาผู้เล่นแทน** ทำแบบนี้แล้ว dialogue เปิดได้ทุก race โดยไม่ต้องแก้ record Race เลย

---

## 2. Record ใน ESP ที่เกี่ยวข้อง (ดูใน xEdit ได้เลย)

| ประเภท | EditorID | FormID | หน้าที่ |
|---|---|---|---|
| **QUST** | `slac_CreatureDialogue` | 050467B0 | quest ที่เก็บ dialogue, alias และ package ทั้งหมด |
| **PACK** | `slac_CreatureForceGreet` | 050616B3 | ForceGreet ให้ creature เดินมาหาผู้เล่นแล้วเปิด topic |
| **DLBR** | `slac_CreatureDialogueForcedBranch` | 05061C18 | branch ที่ ForceGreet ชี้มา (ไม่ใช่ TopLevel) |
| **DIAL** | `slac_CreatureDialogueForcedBranchTopic` | 05061C19 | topic เริ่มต้นของ ForceGreet |
| **INFO** | (ไม่มี EDID) | 05061C1A | บรรทัดแรกของ creature (`" "`) แล้ว LinkTo ไปยังตัวเลือกของผู้เล่น |
| **DLBR** | `slac_CreatureDialogueBegin` | 050467B2 | branch แบบ **TopLevel** (ใช้ตอนคุยแบบปกติด้วย) |
| **DIAL** | `slac_CreatureDialogueArousalSucceed` | 050467B3 | ตัวเลือกของผู้เล่น "Hey, need some fun?" |
| **INFO** | — | 050467B4 | คำตอบที่มี Begin fragment `slac_TopicCreatureUseStart` |
| **DLBR** | `slac_CreatureDialogueOptions` | 0504BDE5 | เมนูย่อย (Do you want me? / Come with me / Never mind) |
| **GLOB** | `slac_allCreatureDialogueEnabled`, `slac_CreatureDialogueSignal`, `slac_CreatureDialogueArousalMin`, `slac_AllowCreatureDialogueMale/Female` | — | ค่าจาก MCM ที่ condition ของ dialogue อ่าน |

---

## 3. รายละเอียดแต่ละตัว

### 3.1 Quest `slac_CreatureDialogue`
- **Start Game Enabled: ไม่ติ๊ก** แต่ script สั่ง start แทน (`slac_Config.psc` บรรทัด ~7959):
  ```papyrus
  If modActive && !slac_CreatureDialogue.IsRunning() && creatureDialogueEnabled
      slac_CreatureDialogue.Start()
  ElseIf !modActive || (slac_CreatureDialogue.IsRunning() && !creatureDialogueEnabled)
      slac_CreatureDialogue.Stop()
  EndIf
  ```
  ปิด MCM เมื่อไหร่ quest ก็หยุด แล้ว dialogue ทั้งหมดก็หายไปด้วย ใช้เป็นสวิตช์ Mod Enabled ได้ดี
- **Priority 100** สูงพอที่ topic ของ SLAC จะไม่ถูก dialogue ของ mod อื่นแย่งไป
- **Dialogue Conditions** (แท็บ Quest Data ช่องบน ใช้กับ *ทุก* INFO ใน quest นี้):
  ```
  HasKeyword(ActorTypeNPC) != 1                     ; ต้องไม่ใช่ NPC
  GetPlayerTeammate == 1            OR
  GetGlobalValue(slac_allCreatureDialogueEnabled) == 1
  GetGlobalValue(slac_AllowCreatureDialogueMale) == 1 OR  GetIsSex(Male) == 1    ← (จับคู่ OR กันตามลำดับ)
  GetGlobalValue(slac_AllowCreatureDialogueFemale) == 1 OR GetIsSex(Female) == 1
  GetInFaction(SexLab.esm:049068) != 1             ; faction ของ SexLab (ดูชื่อใน xEdit)
  GetInFaction(SexLab.esm:00E50F) != 1
  GetInFaction(slac_PursuitFaction) != 1
  IsChild != 1
  GetDead != 1
  GetCombatState < 1 OR GetGlobalValue(slac_AllowCombatEngagements) == 1
  ```
- **Aliases** (quest นี้ไม่มี script ติดที่ quest หรือ alias เลย script ทั้งหมดอยู่ที่ fragment)

  | # | Name | Flags | Alias Package |
  |---|---|---|---|
  | 0 | CreatureRef | Optional, Stores Text | slac_CreatureDialogueFollowPlayer |
  | 1 | VictimRef | Optional, Stores Text | – |
  | 2 | TargetRef | Optional | – |
  | **3** | **ForcedRef** | **Optional, Allow Reuse in Quest**, Stores Text | **slac_CreatureForceGreet** |
  | 5–8 | CreatureRef1..4 | Optional | slac_CreatureDialogueFollowPlayer |

  ตัวที่ต้องดูคือ **ForcedRef** เป็น alias ว่างที่ script จะใส่ creature เข้าไปตอนจะเปิด dialogue

### 3.2 Package `slac_CreatureForceGreet`
- Template: **ForceGreet** (Skyrim.esm `03C1C4`)
- Package data ที่ตั้งไว้:
  - **Topic** = `slac_CreatureDialogueForcedBranchTopic`
  - **Target (SingleRef)** = `PlayerRef` (00000014)
  - ค่า Float = **50** (ระยะทักทาย) ส่วน Bool ที่เหลือเป็น False ทั้งหมด
- **End fragment** `slac_PackageCreatureForceGreet.Fragment_0` เคลียร์ ForcedRef เมื่อ package จบ:
  ```papyrus
  Utility.Wait(0.1)
  ForcedRef.Clear()
  ```

### 3.3 ForceGreet topic
- DLBR `slac_CreatureDialogueForcedBranch` อยู่ใน Category Player, **Flags = 0** (ไม่ TopLevel ไม่ Blocking) และ StartTopic = `...ForcedBranchTopic`
- DIAL `...ForcedBranchTopic` ตั้ง Priority 50, Subtype `CUST` และ**ปล่อยช่อง Topic Text ว่าง**
- INFO `05061C1A`: ข้อความ **`" "`** (เว้นวรรคตัวเดียว), **ไม่มี condition** เพราะ quest condition กรองไว้แล้ว, Flags = No LIP File
  และ **LinkTo** ไป 4 topic ที่จะขึ้นเป็นตัวเลือกให้ผู้เล่น

  สรุปคือ creature ไม่ได้พูดอะไรจริง บรรทัดนี้มีไว้เปิด Dialogue Menu ให้ผู้เล่นเลือกเมนูเท่านั้น

### 3.4 ตัวเลือกของผู้เล่น
- `slac_CreatureDialogueArousalSucceed` ตั้ง Topic Text = "Hey, need some fun?" และอยู่ใน branch **TopLevel** (`slac_CreatureDialogueBegin`)
  จึงขึ้นทั้งตอนที่ถูก ForceGreet และตอนกด E คุยกับ creature ที่ race คุยได้อยู่แล้ว
- คำตอบของ topic นี้แยกตาม condition:
  - `[ The dog shows no interest ]` / `[ The horse shows no interest ]` → Flag **Goodbye** (ใช้เมื่อ arousal ต่ำ)
  - INFO `050467B4` ข้อความ `" "` มี **Begin fragment `slac_TopicCreatureUseStart`** แล้ว LinkTo ไปเมนูถัดไป
- Fragment ตัวนั้นเป็นจุดที่ "ฟังก์ชันเริ่มทำงาน":
  ```papyrus
  ; เคลียร์ ForceGreet แล้วย้าย creature ไปไว้ใน CreatureRef (alias หลัก)
  Actor fg = ForcedRef.GetActorRef()
  ForcedRef.Clear()
  If fg
      fg.EvaluatePackage()
  EndIf
  CreatureRef.ForceRefTo(akSpeakerRef)
  ```

### 3.5 ฝั่ง Script: ใครสั่ง ForceGreet
`slac_PlayerScript.psc` (script บน alias ของผู้เล่น):
- `RegisterForKey(Input.GetMappedKey("Activate"))` ดักปุ่ม E
- ใน `OnKeyDown` จะเช็คว่าเป้าเป็น creature, race ไม่มี `AllowPCDialogue()`, ไม่ได้ขี่อยู่, ไม่ตาย และเป็น teammate หรือเปิด all creatures ไว้
  ถ้าผ่านทั้งหมดก็สั่ง:
  ```papyrus
  slacUtility.CreatureDialogueForcedRef.ForceRefTo(tempCHRef)
  tempCHRef.EvaluatePackage()
  ```
- ปุ่ม Invite (Ins) ทำแบบเดียวกันเมื่อเปิด `Invite Opens Creature Dialogue` ไว้
- ตัวเก็บกวาด: ถ้า ForcedRef ยังมี actor ค้างอยู่แต่ Dialogue Menu ไม่ได้เปิด script จะ `Clear()` ให้
- กับม้า SLAC ใช้ `BlockActivation(True)` กัน E ไม่ให้ขึ้นขี่ เพื่อให้ ForceGreet ทำงานแทน

---

## 4. เอามาใช้กับ ILoveCreature: เทียบทีละตัว

| SLAC | ILoveCreature | หมายเหตุ |
|---|---|---|
| `slac_CreatureDialogue` (QUST) | `ILC_DialogueQuest` | ตั้ง Priority **60–100** และใส่ Dialogue Conditions แบบ 3.1 (อย่างน้อย `HasKeyword ActorTypeNPC != 1`, `GetDead != 1`, `IsChild != 1`) |
| alias `ForcedRef` | alias `CreatureAlias` | Optional + **Allow Reuse in Quest** และใส่ package ในช่อง Alias Package Data |
| `slac_CreatureForceGreet` (PACK) | `ILC_ForceGreetPackage` | Template ForceGreet, Topic = topic ของเรา, Target = PlayerRef |
| `slac_CreatureDialogueForcedBranch` | `ILC_HelloBranch` | Category Player, ไม่ติ๊ก TopLevel/Blocking |
| `...ForcedBranchTopic` + INFO `" "` | `ILC_HelloTopic` + INFO **"Hey Hello"** | ของเราให้ creature พูดจริงเพื่อทดสอบ |
| ปุ่ม E ใน `slac_PlayerScript.OnKeyDown` | hotkey ใน `ILC_Main.OnKeyDown` | ใช้ hotkey แยก จะได้ไม่ชนกับปุ่ม E ของ SLAC |
| Package End fragment / TIF Begin fragment ที่เคลียร์ alias | `ILC_CreatureAlias.OnMenuClose` | ของเราเคลียร์ตอนปิด Dialogue Menu ไม่ต้องใช้ fragment |
| `slac_Config` สั่ง `Start()/Stop()` quest | `ILC_Main.SetModEnabled` | (ทางเลือก) ให้ Stop quest ตอนปิด mod เหมือน SLAC |

### ขั้นตอนใน CK ตามลำดับ (ต้องสร้างตามนี้ เพราะแต่ละตัวต้องอ้างถึงตัวก่อนหน้า)
1. **Quest** `ILC_DialogueQuest`: Priority 60 แล้วกด OK ก่อนหนึ่งครั้งให้ quest ถูกบันทึก
2. **Quest Aliases**: สร้าง `PlayerAlias` (Specific Ref = PlayerRef) และ `CreatureAlias` (Optional + Allow Reuse, ไม่ต้องกำหนด fill)
3. **Player Dialogue tab**: New Branch `ILC_HelloBranch` จะได้ topic `ILC_HelloTopic` มาเอง
   - ปล่อย Topic Text ว่าง
   - New INFO: Response = `Hey Hello` (ถ้าอยากทำแบบ SLAC 100% ให้ใช้ `" "` แล้ว LinkTo ไป topic ที่เป็นตัวเลือกของผู้เล่น)
   - Condition: `GetIsAliasRef CreatureAlias == 1` (Subject) จะใส่หรือไม่ก็ได้ ถ้าใส่ Dialogue Conditions ระดับ quest แล้ว
   - Flags: Goodbye (ถ้าอยากให้จบในบรรทัดเดียว) หรือ LinkTo `ILC_HelloReply`
4. **Package** `ILC_ForceGreetPackage` (Object Window → Character → Package): Template **ForceGreet**
   - Topic = `ILC_HelloTopic`
   - Target = Specific Reference `PlayerRef`
5. กลับไปที่ **CreatureAlias**, ช่อง Alias Package Data: Add → `ILC_ForceGreetPackage`
6. **Quest Data → Dialogue Conditions**: ใส่ condition กรองแบบ 3.1
7. **Scripts**: แนบ `ILC_Main` กับ quest, `ILC_PlayerAlias` และ `ILC_CreatureAlias` กับ alias แล้วกด Properties เพื่อเติมค่าให้ครบ
8. สร้าง SEQ: ต้องมีเพราะ quest ที่เป็น Start Game Enabled และมี dialogue ต้องใช้ไฟล์ `.seq`
   (ใน SSEEdit คลิกขวาที่ plugin แล้วเลือก *Other → Create SEQ File*, ได้ไฟล์ `Data\SEQ\<plugin>.seq`)

### ข้อควรระวังที่เห็นจาก SLAC
- **ห้ามใช้ topic, branch หรือ alias ร่วมกับ SLAC** ให้สร้างของตัวเองทั้งหมด ESP ของเราจะได้ไม่ต้องใช้ SLAC เป็น master
- ถ้าเปิดทั้งสอง mod แล้วกด E ใส่ creature ตัวเดียวกัน SLAC จะ ForceGreet ของมันเอง hotkey ของเราใช้ปุ่มอื่นจึงไม่ชนกัน
- SLAC ใส่ข้อความ `" "` แทนข้อความว่าง เพราะ INFO ที่ไม่มีข้อความเลยอาจถูกข้ามไป **ห้ามปล่อย Response ว่างเปล่า**
- creature ไม่มีไฟล์เสียง บรรทัดของ creature ใน SLAC จึงติ้ก flag **Force Subtitle** + **No LIP File** (บรรทัดที่จบบทสนทนาติ้ก Goodbye ด้วย)
  *(ฉบับแรกของคู่มือเขียนผิดเป็น Requires Post-Processing / Can Move While Greeting เพราะตัวอ่าน flag เพี้ยนไป 1 bit แก้แล้วโดยเทียบกับ xEdit)*
  ถ้าติ้กสอง flag นี้แล้วบรรทัดยังขึ้นแวบเดียวแล้วหาย ให้ติดตั้ง Fuz Ro D-oh
- Package ForceGreet จะทำงานก็ต่อเมื่อ quest **กำลัง run อยู่** และ alias มี actor แล้ว ต้องสั่ง `EvaluatePackage()` ทุกครั้ง
