Scriptname ILC_Main extends Quest
{ILoveCreature - main controller. Attach to quest ILC_DialogueQuest.
Hotkey -> creature under the crosshair force-greets the player -> "Hey Hello" + pet commands.}

; ---------------------------------------------------------------
; Properties (fill in CK)
; ---------------------------------------------------------------
Actor Property PlayerRef Auto
ReferenceAlias Property CreatureAlias Auto     ; alias "CreatureAlias" (has the ForceGreet package)
Keyword Property ActorTypeNPC Auto             ; vanilla ActorTypeNPC [KYWD:00013794]
ILC_Followers Property Followers Auto        ; -> ILC_FollowerQuest (V.2 creature followers)
SexLabFramework Property SexLab Auto         ; SexLab.esm:000D62 SexLabQuestFramework (V.3 Mate)
ILC_Peace Property Peace Auto                 ; V.4 same quest: peace spells, G key, "all of you"

; V.3 Mate settings
Bool Property MateStripFirst = False Auto Hidden   ; strip the player and wait before the scene (like SLAC invite)
String Property MateHook = "ILC_CreatureConsent" AutoReadOnly
Actor pendingTame                                  ; tamed when the current ILC scene ends
Actor pendingRewardActor                           ; buffed when the current ILC scene ends
Int pendingReward = 0
Actor[] pendingGroup                               ; extra creatures of a Group scene (also buffed)

; V.3.5 rewards (see GiveReward)
Int Property REWARD_NONE = 0 AutoReadOnly
Int Property REWARD_ATTACK = 1 AutoReadOnly
Int Property REWARD_SPEED = 2 AutoReadOnly
Int Property REWARD_DEFENSE = 3 AutoReadOnly
Int Property REWARD_REGEN = 4 AutoReadOnly
Int Property REWARD_GROUP = 5 AutoReadOnly
Int Property REWARD_HEAL = 6 AutoReadOnly

; MCM "Buffs" page: who receives the mate rewards
Bool Property BuffFollower = True Auto Hidden
Bool Property BuffPlayer = False Auto Hidden

; MCM "Buffs" sliders - balanced defaults (see ResetBuffDefaults)
Float Property BuffMinutes = 3.0 Auto Hidden       ; 1 - 60 minutes (all buffs, typed in the MCM)
Float Property BuffAttackPct = 25.0 Auto Hidden    ; +% weapon damage AND +% spell power
Float Property BuffSpeedPct = 10.0 Auto Hidden     ; +% movement speed (max 30: more makes followers overshoot)
Float Property BuffDefensePct = 30.0 Auto Hidden   ; +% armor (min 1.5 x this in points)
Float Property BuffRegenPct = 0.5 Auto Hidden      ; % of max health per second (0.5 -> 90% over 3 min)
Float Property SpeedCap = 30.0 AutoReadOnly
Int buffSettingsVersion = 0
Bool Property DebugMessages = False Auto Hidden    ; MCM Buffs -> Debug: show every reward step on screen
Bool waitingForScene = False                       ; a mate scene is running, reward pending

Function Dbg(String s)
	Debug.Trace("[ILoveCreature] " + s)
	If DebugMessages
		Debug.Notification("[ILC] " + s)
	EndIf
EndFunction

Function ResetBuffDefaults()
	BuffMinutes = 3.0
	BuffAttackPct = 25.0
	BuffSpeedPct = 10.0
	BuffDefensePct = 30.0
	BuffRegenPct = 0.5
EndFunction

; ---------------------------------------------------------------
; Settings (changed by ILC_Config / MCM)
; ---------------------------------------------------------------
Bool Property ModEnabled = True Auto Hidden
Int Property OpenDialogueKey = 37 Auto Hidden  ; 37 = K
Float Property TimeoutSeconds = 15.0 Auto Hidden

; Set by the MCM "OPEN" button: open dialogue with the nearest creature after the menu closes
Bool Property PendingOpenFromMenu = False Auto Hidden

; ---------------------------------------------------------------
; Init / load
; ---------------------------------------------------------------
Event OnInit()
	Maintenance()
EndEvent

; Called on OnInit and on every game load (ILC_PlayerAlias)
Function Maintenance()
	UnregisterForAllKeys()
	If ModEnabled && OpenDialogueKey > 0
		RegisterForKey(OpenDialogueKey)
	EndIf
	If ModEnabled && Peace && Peace.PeaceKey > 0      ; V.4 G key (handled here, see OnKeyDown)
		RegisterForKey(Peace.PeaceKey)
	EndIf
	RegisterForMenu("Journal Menu")   ; MCM lives in the Journal Menu
	RegisterForModEvent("AnimationEnd_" + MateHook, "OnMateEnd")   ; mod events must be re-registered every load
	If buffSettingsVersion < 2      ; V.3.9: new balanced defaults (Speed 10%, Group = full values)
		ResetBuffDefaults()
		buffSettingsVersion = 2
	EndIf
	If !UI.IsMenuOpen("Dialogue Menu")
		CloseDialogue()
	EndIf
	If Followers
		Followers.DoUpdate()
	EndIf
	If Peace
		Peace.Maintenance()
	EndIf
EndFunction

Function SetModEnabled(Bool abEnabled)
	ModEnabled = abEnabled
	If !abEnabled
		PendingOpenFromMenu = False
		CloseDialogue()
	EndIf
	Maintenance()
EndFunction

Function SetOpenDialogueKey(Int aiKey)
	OpenDialogueKey = aiKey
	Maintenance()
EndFunction

; ---------------------------------------------------------------
; Hotkey
; ---------------------------------------------------------------
Event OnKeyDown(Int keyCode)
	If !ModEnabled
		Return
	EndIf
	If Utility.IsInMenuMode() || UI.IsTextInputEnabled() || UI.IsMenuOpen("Dialogue Menu")
		Return
	EndIf
	If keyCode != OpenDialogueKey
		If Peace && keyCode == Peace.PeaceKey
			Peace.OnPeaceKey()           ; V.4: "I come in peace."
		EndIf
		Return
	EndIf

	Actor target = Game.GetCurrentCrosshairRef() as Actor
	If !target
		Debug.Notification("ILoveCreature: No target under crosshair")
		Return
	EndIf
	TryOpenDialogue(target)
EndEvent

; ---------------------------------------------------------------
; MCM "OPEN" button -> runs when the MCM (Journal Menu) closes
; ---------------------------------------------------------------
Event OnMenuClose(String menuName)
	If menuName != "Journal Menu" || !PendingOpenFromMenu
		Return
	EndIf
	PendingOpenFromMenu = False
	If !ModEnabled
		Return
	EndIf

	Actor target = FindNearestCreature()
	If !target
		Debug.Notification("ILoveCreature: No creature nearby")
		Return
	EndIf
	TryOpenDialogue(target)
EndEvent

; Scan the player's current cell for the closest living creature
Actor Function FindNearestCreature()
	Cell c = PlayerRef.GetParentCell()
	If !c
		Return None
	EndIf
	Actor best = None
	Float bestDist = 999999.0
	Int i = c.GetNumRefs(43)   ; 43 = kNPC (base form type of actors)
	While i
		i -= 1
		Actor a = c.GetNthRef(i, 43) as Actor
		If a && a != PlayerRef && IsValidCreature(a)
			Float d = a.GetDistance(PlayerRef)
			If d < bestDist
				bestDist = d
				best = a
			EndIf
		EndIf
	EndWhile
	Return best
EndFunction

; ---------------------------------------------------------------
; Dialogue control
; ---------------------------------------------------------------
Bool Function IsValidCreature(Actor akActor)
	Return akActor && !akActor.IsDead() && !akActor.IsDisabled() && !akActor.HasKeyword(ActorTypeNPC)
EndFunction

; abCommands = True  -> K hotkey / MCM: greeting + pet commands (for our companions)
; abCommands = False -> "Talk" in the companion menu: plain greeting only (commands are in the menu)
Bool Function TryOpenDialogue(Actor akCreature, Bool abCommands = True)
	Return TryOpenDialogueMode(akCreature, abCommands as Int)
EndFunction

; "Mate" in the companion menu: dialogue opens straight into heal / 5 mate choices / Never mind
Bool Function OpenMateDialogue(Actor akCreature)
	Return TryOpenDialogueMode(akCreature, 2)
EndFunction

; V.4 Creature Call (3) / G key (4): normal dialogue menu of every mod, our lines added at the end
Bool Function OpenPeaceDialogue(Actor akCreature, Int aiMode)
	Return TryOpenDialogueMode(akCreature, aiMode)
EndFunction

; aiMode = value of ILC_DialogueCommands: 0 Talk, 1 K (commands), 2 Mate, 3 Call spell, 4 G key
Bool Function TryOpenDialogueMode(Actor akCreature, Int aiMode)
	If Followers && Followers.gDialogueCommands
		Followers.gDialogueCommands.SetValue(aiMode as Float)
	EndIf
	If !IsValidCreature(akCreature)
		Debug.Notification("ILoveCreature: Target is not a creature")
		Return False
	EndIf
	If aiMode >= 3                  ; V.4 peace modes: the creature was just calmed, give combat time to end
		Int w = 0
		While w < 6 && (akCreature.IsInCombat() || PlayerRef.IsInCombat())
			Utility.Wait(0.5)
			w += 1
		EndWhile
	EndIf
	If akCreature.IsInCombat() || PlayerRef.IsInCombat()
		Debug.Notification("ILoveCreature: Cannot talk during combat")
		Return False
	EndIf
	If akCreature.IsBeingRidden() || PlayerRef.IsOnMount()
		Debug.Notification("ILoveCreature: Cannot talk while mounted")
		Return False
	EndIf

	; Put the creature in the alias -> its ForceGreet package walks to the player and opens ILC_HelloTopic
	CloseDialogue()
	CreatureAlias.ForceRefTo(akCreature)
	akCreature.EvaluatePackage()
	(CreatureAlias as ILC_CreatureAlias).StartWatch(TimeoutSeconds)
	Debug.Trace("[ILoveCreature] ForceGreet started: " + akCreature.GetDisplayName())
	Return True
EndFunction

; ---------------------------------------------------------------
; V.3 Mate (adapted from SLAC slac_TopicCreaturePCConsent)
; Used by the "I will make you happy." dialogue line (ILC_TopicCreaturePCConsent)
; and by the "Mate" button of the companion menu (ILC_Followers).
; abTameAfter = True: the creature becomes a companion when the scene ends
; (or right away if no scene could start).
; ---------------------------------------------------------------
Bool Function StartMate(Actor akCreature, Bool abTameAfter = False)
	Return StartMateEx(akCreature, abTameAfter)
EndFunction

; "I will make you happy." / "I will heal you." (ILC_TopicCreaturePCConsent): consensual scene,
; then the creature becomes a companion (if it isn't yet) and is healed to full.
Bool Function MateConsent(Actor akCreature)
	Return StartMateEx(akCreature, True, "", "", REWARD_HEAL)
EndFunction

; ---- V.3.5: the 5 companion choices (ported from SLAC slac_TopicCreaturePC*). Called by ILC_TopicCreaturePC<Type>.
Bool Function MateAggressive(Actor akCreature)      ; SLAC PCAggressive: require Aggressive
	Return StartMateEx(akCreature, False, "Aggressive", "", REWARD_ATTACK)
EndFunction

Bool Function MateAnal(Actor akCreature)            ; SLAC PCAnal: require Anal
	Return StartMateEx(akCreature, False, "Anal", "", REWARD_SPEED)
EndFunction

Bool Function MateBitch(Actor akCreature)           ; SLAC PCBitch: require Aggressive, reject Oral
	Return StartMateEx(akCreature, False, "Aggressive", "Oral", REWARD_DEFENSE)
EndFunction

Bool Function MateOral(Actor akCreature)            ; SLAC PCOral: BlowJob (male) / Cunnilingus (female), reject Anal,Vaginal
	String tags = "BlowJob"
	If SexLab && SexLab.GetGender(akCreature) == 3
		tags = "Cunnilingus"
	EndIf
	Return StartMateEx(akCreature, False, tags, "Anal,Vaginal", REWARD_REGEN)
EndFunction

Bool Function MateGroup(Actor akCreature)           ; SLAC PCGroup: creature + up to 3 more nearby companions
	Return StartMateEx(akCreature, False, "", "", REWARD_GROUP, abGroup = True)
EndFunction

; Core: start a consensual scene (player + creature [+ group]), tame and/or reward when it ends.
; asTags / asSuppress pick animations (fallback: any animation); if no scene can start, tame / reward right away.
Bool Function StartMateEx(Actor akCreature, Bool abTameAfter = False, String asTags = "", String asSuppress = "", Int aiReward = 0, Bool abGroup = False)
	String err = CheckMate(akCreature)
	If err != ""
		Debug.Notification("ILoveCreature: " + err)
		FinishMate(akCreature, abTameAfter, aiReward, None)
		Return False
	EndIf

	; positions: player (passive), creature, then extras for a group scene
	Actor[] extras = new Actor[3]
	Int extraCount = 0
	If abGroup
		extraCount = FindGroupCreatures(akCreature, extras)
	EndIf

	sslBaseAnimation[] anims
	Actor[] pos
	While !pos
		pos = MakePositions(akCreature, extras, extraCount)
		If asTags != ""
			anims = SexLab.GetCreatureAnimationsByActorsTags(pos.Length, pos, asTags, asSuppress, False)
		EndIf
		If !anims || anims.Length == 0
			anims = SexLab.GetCreatureAnimationsByActors(pos.Length, pos)   ; no tags / tag fallback (like SLAC)
		EndIf
		If anims.Length == 0 && extraCount > 0
			extraCount -= 1        ; no animation for this many creatures -> try with one less
			pos = None
		EndIf
	EndWhile

	If abGroup
		If extraCount > 0
			Debug.Notification(akCreature.GetDisplayName() + " brought " + extraCount + " friend(s)")
		Else
			Debug.Notification("No compatible friends nearby (same creature type, within reach) - just the two of you")
		EndIf
		Debug.Trace("[ILoveCreature] Group: " + pos.Length + " actors, " + anims.Length + " animations")
	EndIf

	Form[] stripped
	If MateStripFirst
		stripped = SexLab.StripActor(PlayerRef, DoAnimate = True)
		Utility.Wait(3.0)
	EndIf

	pendingTame = None
	If abTameAfter
		pendingTame = akCreature
	EndIf
	pendingReward = aiReward
	pendingRewardActor = akCreature
	pendingGroup = extras

	; anims empty -> SexLab picks its default animations for these actors
	Int tid = SexLab.StartSex(pos, anims, None, None, True, MateHook)
	If tid >= 0
		Dbg("Scene started: " + akCreature.GetDisplayName() + " +" + extraCount + ", tags '" + asTags + "', reward " + aiReward)
		; fallback: if the AnimationEnd event never arrives, OnUpdate notices the scene is over
		waitingForScene = True
		RegisterForSingleUpdate(10.0)
		Return True
	EndIf

	pendingTame = None
	pendingReward = 0
	pendingRewardActor = None
	pendingGroup = None
	If stripped
		SexLab.UnstripActor(PlayerRef, stripped)
	EndIf
	Debug.Notification("ILoveCreature: No animation found for " + akCreature.GetDisplayName())
	FinishMate(akCreature, abTameAfter, aiReward, extras)
	Return False
EndFunction

Actor[] Function MakePositions(Actor akCreature, Actor[] extras, Int extraCount)
	Actor[] pos = PapyrusUtil.ActorArray(2 + extraCount)
	pos[0] = PlayerRef
	pos[1] = akCreature
	Int i = 0
	While i < extraCount
		pos[2 + i] = extras[i]
		i += 1
	EndWhile
	Return pos
EndFunction


; Group friends (max 3), like SLAC FindExtraCreatures:
; compatible = same race OR SexLab says both races share a race key (AllowedCreatureCombination),
; 1) our companions near the player, 2) other non-hostile creatures around the player (MiscUtil scan)
Float Property GroupRadius = 3000.0 Auto Hidden

Int Function FindGroupCreatures(Actor akCreature, Actor[] outExtras)
	Int want = outExtras.Length        ; Group: 3, V.4 "all of you": 1 - 5
	Int found = 0
	Int companions = 0
	If Followers
		Int n = Followers.GetSlotLimit()
		Int i = 0
		While i < n && found < want
			Actor a = Followers.GetActorInSlot(i)
			If a && a != akCreature
				companions += 1
				If IsGroupCandidate(a, akCreature, outExtras)
					outExtras[found] = a
					found += 1
				EndIf
			EndIf
			i += 1
		EndWhile
	EndIf
	If found < want
		Actor[] near = MiscUtil.ScanCellNPCs(PlayerRef, GroupRadius)
		Int k = 0
		While k < near.Length && found < want
			Actor b = near[k]
			If IsGroupCandidate(b, akCreature, outExtras) && !b.IsHostileToActor(PlayerRef)
				outExtras[found] = b
				found += 1
			EndIf
			k += 1
		EndWhile
		Debug.Trace("[ILoveCreature] Group scan: " + companions + " other companions, " + near.Length + " actors near, " + found + " friends")
	EndIf
	Return found
EndFunction

Bool Function IsGroupCandidate(Actor a, Actor akCreature, Actor[] already)
	If !a || a == akCreature || a == PlayerRef || already.Find(a) >= 0
		Return False
	EndIf
	If a.IsDead() || a.IsDisabled() || !a.Is3DLoaded() || a.IsInCombat() || a.HasKeyword(ActorTypeNPC)
		Return False
	EndIf
	If a.GetDistance(PlayerRef) > GroupRadius || SexLab.IsActorActive(a)
		Return False
	EndIf
	Race r1 = akCreature.GetRace()
	Race r2 = a.GetRace()
	Return r1 == r2 || SexLab.AllowedCreatureCombination(r1, r2)
EndFunction

Function FinishMate(Actor akCreature, Bool abTame, Int aiReward, Actor[] akGroup)
	TameNow(akCreature, abTame)
	GiveReward(akCreature, aiReward, akGroup)
EndFunction

; ---- rewards (spells ILC_Buff* last 60 s, see ILC_BuffEffect)
Function GiveReward(Actor akCreature, Int aiReward, Actor[] akGroup = None)
	If aiReward == REWARD_NONE || !akCreature || !Followers
		Return
	EndIf
	Bool toCreature = BuffFollower && !akCreature.IsDead()
	If aiReward != REWARD_GROUP
		If toCreature
			ApplyReward(akCreature, aiReward)
		EndIf
		If BuffPlayer
			ApplyReward(PlayerRef, aiReward)
		EndIf
		If toCreature || BuffPlayer
			String who = ""
			If toCreature
				who = akCreature.GetDisplayName()
			EndIf
			If BuffPlayer
				If who != ""
					who += " and you"
				Else
					who = "You"
				EndIf
			EndIf
			Debug.Notification(who + ": " + RewardName(aiReward))
		EndIf
		Return
	EndIf

	; group: the creature, the other creatures of the scene and every following companion nearby (each once)
	If BuffPlayer
		BuffAll(PlayerRef)
	EndIf
	If !BuffFollower
		If BuffPlayer
			Debug.Notification("You: " + RewardName(REWARD_GROUP))
		EndIf
		Return
	EndIf
	Actor[] pack = PapyrusUtil.ActorArray(1, akCreature)
		Int i = 0
		While akGroup && i < akGroup.Length
			If akGroup[i] && pack.Find(akGroup[i]) < 0
				pack = PapyrusUtil.PushActor(pack, akGroup[i])
			EndIf
			i += 1
		EndWhile
		Int n = Followers.GetSlotLimit()
		i = 0
		While i < n
			Actor a = Followers.GetActorInSlot(i)
			If a && pack.Find(a) < 0 && a.IsPlayerTeammate() && a.Is3DLoaded() && a.GetDistance(PlayerRef) < 4000.0
				pack = PapyrusUtil.PushActor(pack, a)
			EndIf
			i += 1
		EndWhile
		Int c = 0
		i = 0
		While i < pack.Length
			c += BuffAll(pack[i])
			i += 1
		EndWhile
		If BuffPlayer
			Debug.Notification("You and the pack (" + c + "): " + RewardName(REWARD_GROUP))
		Else
			Debug.Notification("The pack (" + c + "): " + RewardName(REWARD_GROUP))
		EndIf
EndFunction

Function ApplyReward(Actor a, Int aiReward)
	If aiReward == REWARD_ATTACK
		CastBuff(Followers.BuffAttack, a, BuffAttackPct)
	ElseIf aiReward == REWARD_SPEED
		CastBuff(Followers.BuffSpeed, a, SpeedValue())
	ElseIf aiReward == REWARD_DEFENSE
		CastBuff(Followers.BuffDefense, a, BuffDefensePct)
	ElseIf aiReward == REWARD_REGEN
		CastBuff(Followers.BuffRegen, a, BuffRegenPct)
	ElseIf aiReward == REWARD_HEAL
		a.RestoreActorValue("Health", a.GetActorValueMax("Health"))
		a.RestoreActorValue("Magicka", a.GetActorValueMax("Magicka"))
		a.RestoreActorValue("Stamina", a.GetActorValueMax("Stamina"))
	EndIf
EndFunction

; text for notifications and the MCM "Buffs" page (uses the current slider values)
String Function RewardName(Int aiReward)
	String dur = " for " + (BuffMinutes as Int) + " min"
	If aiReward == REWARD_ATTACK
		Return "Attack +" + (BuffAttackPct as Int) + "% (weapons and magic)" + dur
	ElseIf aiReward == REWARD_SPEED
		Return "Speed +" + (SpeedValue() as Int) + "%" + dur
	ElseIf aiReward == REWARD_DEFENSE
		Return "Defense +" + (BuffDefensePct as Int) + "%" + dur
	ElseIf aiReward == REWARD_REGEN
		Return "Regen " + FmtDec(BuffRegenPct) + "% HP/s" + dur
	ElseIf aiReward == REWARD_GROUP
		Return "Attack +" + (BuffAttackPct as Int) + "%, Speed +" + (SpeedValue() as Int) + "%, Defense +" + (BuffDefensePct as Int) \
			+ "%, Regen " + FmtDec(BuffRegenPct) + "%/s" + dur + " + full health"
	ElseIf aiReward == REWARD_HEAL
		Return "Full health, magicka and stamina"
	EndIf
	Return ""
EndFunction

; Group: all 4 buffs with the same values as the single choices + full health
Int Function BuffAll(Actor a)
	If !a || a.IsDead()
		Return 0
	EndIf
	CastBuff(Followers.BuffAttack, a, BuffAttackPct)
	CastBuff(Followers.BuffSpeed, a, SpeedValue())
	CastBuff(Followers.BuffDefense, a, BuffDefensePct)
	CastBuff(Followers.BuffRegen, a, BuffRegenPct)
	a.RestoreActorValue("Health", a.GetActorValueMax("Health"))
	Return 1
EndFunction

Float Function SpeedValue()      ; speed bonus is capped to avoid movement bugs
	If BuffSpeedPct > SpeedCap
		Return SpeedCap
	EndIf
	Return BuffSpeedPct
EndFunction

; MCM duration editor: typed minutes, clamped to 1 - 60
Function SetBuffMinutes(Float afMinutes)
	If afMinutes < 1.0
		afMinutes = 1.0
	ElseIf afMinutes > 60.0
		afMinutes = 60.0
	EndIf
	BuffMinutes = (afMinutes as Int) as Float
EndFunction

; strength + duration are written into the spell right before the cast (SKSE), the effect reads them
Function CastBuff(Spell akSpell, Actor a, Float afMagnitude)
	If !akSpell || !a || afMagnitude <= 0.0
		Return
	EndIf
	Float mins = BuffMinutes
	If mins < 1.0
		mins = 1.0
	ElseIf mins > 60.0
		mins = 60.0
	EndIf
	akSpell.SetNthEffectMagnitude(0, afMagnitude)
	akSpell.SetNthEffectDuration(0, (mins * 60.0) as Int)
	a.DispelSpell(akSpell)          ; replace an older buff of the same kind cleanly
	akSpell.Cast(a, a)
	; make sure it landed; if the cast did not apply, apply the spell directly
	MagicEffect me = akSpell.GetNthEffectMagicEffect(0)
	Utility.Wait(0.3)
	If me && !a.HasMagicEffect(me)
		a.DoCombatSpellApply(akSpell, a)
		Utility.Wait(0.3)
		If a.HasMagicEffect(me)
			Dbg(akSpell.GetName() + " on " + a.GetDisplayName() + ": applied directly")
		Else
			Dbg(akSpell.GetName() + " on " + a.GetDisplayName() + ": FAILED")
		EndIf
	Else
		Dbg(akSpell.GetName() + " on " + a.GetDisplayName() + ": OK (" + afMagnitude + ", " + (mins as Int) + " min)")
	EndIf
EndFunction

String Function FmtDec(Float f)       ; 0.5 -> "0.5"
	Int whole = f as Int
	Int tenth = ((f - whole) * 10.0 + 0.5) as Int
	If tenth >= 10
		whole += 1
		tenth = 0
	EndIf
	Return whole + "." + tenth
EndFunction

; ---- MCM debug: remove every ILoveCreature buff and repair values an effect may have left behind
Int Function ClearAllBuffs()
	If !Followers
		Return 0
	EndIf
	Actor[] list = PapyrusUtil.ActorArray(1, PlayerRef)
	Int i = 0
	Int n = Followers.GetSlotLimit()
	While i < n
		Actor a = Followers.GetActorInSlot(i)
		If a && list.Find(a) < 0
			list = PapyrusUtil.PushActor(list, a)
		EndIf
		i += 1
	EndWhile
	i = StorageUtil.FormListCount(None, "ILC.BuffedActors")
	While i
		i -= 1
		Actor b = StorageUtil.FormListGet(None, "ILC.BuffedActors", i) as Actor
		If b && list.Find(b) < 0
			list = PapyrusUtil.PushActor(list, b)
		EndIf
	EndWhile

	; 1) dispel -> OnEffectFinish removes the bonus normally
	i = 0
	While i < list.Length
		list[i].DispelSpell(Followers.BuffAttack)
		list[i].DispelSpell(Followers.BuffSpeed)
		list[i].DispelSpell(Followers.BuffDefense)
		list[i].DispelSpell(Followers.BuffRegen)
		i += 1
	EndWhile
	Utility.Wait(1.0)

	; 2) whatever is still recorded was left behind by a lost effect -> take it off
	Int fixed = 0
	String magicAV = ILC_BuffEffect.MagicAV()
	i = 0
	While i < list.Length
		If magicAV != ""
			fixed += RepairAV(list[i], magicAV)
		EndIf
		fixed += RepairAV(list[i], "AttackDamageMult")
		fixed += RepairAV(list[i], "SpeedMult")
		fixed += RepairAV(list[i], "DamageResist")
		list[i].ModActorValue("CarryWeight", 0.1)     ; refresh movement speed
		list[i].ModActorValue("CarryWeight", -0.1)
		i += 1
	EndWhile
	StorageUtil.FormListClear(None, "ILC.BuffedActors")
	Debug.Notification("ILoveCreature: buffs cleared on " + list.Length + " actor(s), " + fixed + " value(s) repaired")
	Return list.Length
EndFunction

Int Function RepairAV(Actor a, String av)
	Float left = StorageUtil.GetFloatValue(a, "ILC.Buff." + av)
	StorageUtil.UnsetFloatValue(a, "ILC.Buff." + av)
	If left > 0.001 || left < -0.001
		a.ModActorValue(av, -left)
		Debug.Trace("[ILoveCreature] repaired " + av + " " + (-left) + " on " + a)
		Return 1
	EndIf
	Return 0
EndFunction

; "" = OK, otherwise the reason why the scene can't start
String Function CheckMate(Actor akCreature)
	If !akCreature || akCreature.IsDead() || akCreature.IsDisabled() || !akCreature.Is3DLoaded()
		Return "The creature is not available"
	ElseIf akCreature.IsInCombat() || PlayerRef.IsInCombat()
		Return "Cannot do that during combat"
	ElseIf !SexLab
		Return "SexLab Framework not found"
	ElseIf !SexLab.Enabled
		Return "SexLab is disabled"
	ElseIf !SexLab.AllowCreatures
		Return "Creature animations are disabled in the SexLab MCM"
	ElseIf SexLab.IsActorActive(PlayerRef)
		Return "You are already in a scene"
	ElseIf SexLab.IsActorActive(akCreature)
		Return akCreature.GetDisplayName() + " is already in a scene"
	ElseIf SexLab.IsForbidden(akCreature)
		Return akCreature.GetDisplayName() + " is forbidden by SexLab"
	EndIf
	Return ""
EndFunction

Function TameNow(Actor akCreature, Bool abTame)
	If abTame && akCreature && !akCreature.IsDead() && Followers && !Followers.IsPet(akCreature)
		Followers.TameWithMessage(akCreature)
	EndIf
EndFunction

; SexLab sends "AnimationEnd_<hook>" (string argString = thread id) when the scene ends
Event OnMateEnd(String eventName, String argString, Float argNum, Form sender)
	Dbg("Scene end event received")
	FinishPending()
EndEvent

; fallback poll while a mate scene runs (the menu-safe Wait is not needed: OnUpdate pauses in menus)
Event OnUpdate()
	If chainNext && !waitingForScene
		If SexLab && SexLab.IsActorActive(PlayerRef)
			RegisterForSingleUpdate(2.0)       ; previous scene still cleaning up
			Return
		EndIf
		chainNext = False
		StartNextChainScene()
		Return
	EndIf
	If !waitingForScene
		Return
	EndIf
	If SexLab && (SexLab.IsActorActive(PlayerRef) || (pendingRewardActor && SexLab.IsActorActive(pendingRewardActor)))
		RegisterForSingleUpdate(3.0)
		Return
	EndIf
	Dbg("Scene end detected (check)")
	FinishPending()
EndEvent

; tame / reward of the last scene - runs once, from whichever comes first (event or check)
Function FinishPending()
	waitingForScene = False
	UnregisterForUpdate()
	Actor a = pendingTame
	Actor r = pendingRewardActor
	Int reward = pendingReward
	Actor[] grp = pendingGroup
	pendingTame = None
	pendingRewardActor = None
	pendingReward = 0
	pendingGroup = None
	If !a && !r
		Return
	EndIf
	TameNow(a, True)
	If chainQueue && grp              ; V.4 "you all happy": the other creatures of the scene join too
		Int g = 0
		While g < grp.Length
			TameNow(grp[g], True)
			g += 1
		EndWhile
	EndIf
	Dbg("Giving reward " + reward + " (companion " + BuffFollower + ", player " + BuffPlayer + ")")
	GiveReward(r, reward, grp)
	If chainQueue && chainPos < chainQueue.Length     ; V.4 "all of you": next creature(s)
		chainNext = True
		RegisterForSingleUpdate(3.0)
	ElseIf chainQueue
		Dbg("All of you: done")
		ClearChain()
	EndIf
EndFunction

Function CloseDialogue()
	Actor a = CreatureAlias.GetActorRef()
	If a
		(CreatureAlias as ILC_CreatureAlias).StopWatch()
		CreatureAlias.Clear()
		a.EvaluatePackage()
	EndIf
EndFunction

; ---------------------------------------------------------------
; V.4 Peace dialogue lines (Creature Call spell / G key)
; ---------------------------------------------------------------
; "I will make you happy." at the end of the Call / G dialogue: scene with this creature only, no taming
Bool Function MateCall(Actor akCreature)
	Return StartMateEx(akCreature, False, "", "", REWARD_NONE)
EndFunction

; "I will make you all happy." (G only): this creature + ExtraCount() creatures around.
; Every creature becomes a companion when its scene ends (see FinishPending).
; SexLab allows max 5 actors (player + 4 creatures) per scene, so the creatures are queued and the
; scenes run one after another until everyone had a turn.
Actor[] chainQueue
Int chainPos = 0
Bool chainNext = False

Bool Function MateAll(Actor akCreature)
	String err = CheckMate(akCreature)
	If err != ""
		Debug.Notification("ILoveCreature: " + err)
		Return False
	EndIf
	Int want = 3
	If Peace
		want = Peace.ExtraCount()
	EndIf
	Actor[] extras = PapyrusUtil.ActorArray(want)
	Int found = FindGroupCreatures(akCreature, extras)
	chainQueue = PapyrusUtil.ActorArray(found + 1)
	chainQueue[0] = akCreature
	Int i = 0
	While i < found
		chainQueue[i + 1] = extras[i]
		i += 1
	EndWhile
	chainPos = 0
	chainNext = False
	If found < want
		Debug.Notification("All of you: " + (found + 1) + " creature(s) (wanted 1 + " + want + ", only " + found + " compatible nearby)")
	Else
		Debug.Notification("All of you: " + (found + 1) + " creature(s)")
	EndIf
	Dbg("All of you: want " + want + " extra, found " + found)
	If !StartNextChainScene()
		Debug.Notification("ILoveCreature: No animation found for these creatures")
		Return False
	EndIf
	Return True
EndFunction

Bool Function ChainOK(Actor a)
	Return a && !a.IsDead() && !a.IsDisabled() && a.Is3DLoaded() && !a.IsInCombat() \
		&& a.GetDistance(PlayerRef) < GroupRadius * 1.5 && !SexLab.IsActorActive(a)
EndFunction

; next scene of the queue: 1 lead creature + up to 3 more (fewer if no animation fits)
Bool Function StartNextChainScene()
	If !chainQueue || !SexLab
		ClearChain()
		Return False
	EndIf
	If PlayerRef.IsInCombat() || PlayerRef.IsDead()
		Debug.Notification("All of you: stopped (combat)")
		ClearChain()
		Return False
	EndIf
	While chainPos < chainQueue.Length
		Actor lead = chainQueue[chainPos]
		chainPos += 1
		If ChainOK(lead) && !SexLab.IsForbidden(lead)
			Actor[] ex = new Actor[3]
			Int[] idx = new Int[3]
			Int k = 0
			While k < 3 && chainPos < chainQueue.Length
				Actor b = chainQueue[chainPos]
				If ChainOK(b) && !SexLab.IsForbidden(b)
					ex[k] = b
					idx[k] = chainPos
					k += 1
				EndIf
				chainPos += 1
			EndWhile

			Actor[] pos
			sslBaseAnimation[] anims
			While !pos
				pos = MakePositions(lead, ex, k)
				anims = SexLab.GetCreatureAnimationsByActors(pos.Length, pos)
				If anims.Length == 0 && k > 0
					k -= 1
					chainPos = idx[k]          ; the dropped creature waits for a later scene
					ex[k] = None
					pos = None
				EndIf
			EndWhile

			pendingTame = lead                ; "you all happy": the lead and its group join you
			pendingReward = REWARD_NONE
			pendingRewardActor = lead
			pendingGroup = ex
			Int tid = SexLab.StartSex(pos, anims, None, None, True, MateHook)
			If tid >= 0
				Int left = chainQueue.Length - chainPos
				Dbg("All of you: scene " + lead.GetDisplayName() + " +" + k + ", " + left + " waiting")
				If left > 0
					Debug.Notification(lead.GetDisplayName() + " +" + k + " (" + left + " more waiting)")
				EndIf
				waitingForScene = True
				RegisterForSingleUpdate(10.0)
				Return True
			EndIf
			pendingTame = None
			pendingRewardActor = None
			pendingGroup = None
			If k > 0
				chainPos = idx[0]             ; the others get their own turn
			EndIf
			Dbg("All of you: scene failed for " + lead.GetDisplayName())
		Else
			Dbg("All of you: skipped " + lead)
		EndIf
	EndWhile
	ClearChain()
	Return False
EndFunction

Function ClearChain()
	chainQueue = None
	chainPos = 0
	chainNext = False
EndFunction

String Function ChainStatus()
	If !chainQueue
		Return "Idle"
	EndIf
	Return (chainQueue.Length - chainPos) + " waiting"
EndFunction

; MCM Peace -> Debug: stop the queue, forget the running scene, end every peace effect
Function ResetPeaceAndGroup()
	ClearChain()
	waitingForScene = False
	UnregisterForUpdate()
	pendingTame = None
	pendingRewardActor = None
	pendingReward = 0
	pendingGroup = None
	CloseDialogue()
	If Followers && Followers.gDialogueCommands
		Followers.gDialogueCommands.SetValue(1.0)
	EndIf
	Int n = 0
	If Peace
		n = Peace.ClearAllPeace()
	EndIf
	Maintenance()
	Debug.Notification("ILoveCreature: peace and group reset (" + n + " creature(s) restored)")
EndFunction
