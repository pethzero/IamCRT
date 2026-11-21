Scriptname ILC_Peace extends Quest
{ILoveCreature V.4 - "Peace" system. Second script on ILC_DialogueQuest (no events of its own:
keys and updates stay in ILC_Main, which calls into this script).
 - Spell "Creature Peace" (aimed): the creature stops fighting you for PeaceMinutes (default 5).
 - Spell "Creature Call" (aimed): peace + dialogue. Our lines are added at the END of the normal
   dialogue menu (other mods' topics stay): "I will make you happy."
 - Hotkey G: the player says "I come in peace.", every creature around becomes peaceful, then the
   dialogue opens with an extra line: "I will make you all happy." (group chain, ILC_Main.MateAll).
A peaceful creature: Aggression 0 + DunPlayerAllyFaction, original values are restored when the effect ends.}

Actor Property PlayerRef Auto
Keyword Property ActorTypeNPC Auto
Faction Property AllyFaction Auto          ; Skyrim DunPlayerAllyFaction
ILC_Main Property Main Auto                ; same quest (ILC_DialogueQuest)
ILC_Followers Property Followers Auto
Spell Property PeaceSpell Auto             ; ILC_PeaceSpell "Creature Peace" (aimed, player spell)
Spell Property CallSpell Auto              ; ILC_CallSpell "Creature Call" (aimed, player spell)
Spell Property PeaceApplySpell Auto        ; ILC_PeaceApplySpell (target actor, no projectile: G key + Call)

; value of ILC_DialogueCommands for the two new dialogue modes (0 Talk, 1 K, 2 Mate)
Int Property MODE_CALL = 3 AutoReadOnly
Int Property MODE_AREA = 4 AutoReadOnly

; ---- MCM page "Peace"
Int Property PeaceKey = 34 Auto Hidden          ; 34 = G
Float Property PeaceMinutes = 5.0 Auto Hidden   ; 1 - 30 real minutes
Float Property PeaceRadius = 2500.0 Auto Hidden ; G area
Int Property MaxExtra = 3 Auto Hidden           ; 1 - 5 extra creatures for "you all happy"
Bool Property RandomExtra = False Auto Hidden   ; False = Stable (always MaxExtra), True = Random 1..MaxExtra
Int Property MaxExtraLimit = 5 AutoReadOnly

String Property LIST_KEY = "ILC.PeaceActors" AutoReadOnly
Bool busy = False

; ---------------------------------------------------------------
; Setup (ILC_Main.Maintenance, every load)
; ---------------------------------------------------------------
Function Maintenance()
	If PeaceSpell && !PlayerRef.HasSpell(PeaceSpell)
		PlayerRef.AddSpell(PeaceSpell, True)
	EndIf
	If CallSpell && !PlayerRef.HasSpell(CallSpell)
		PlayerRef.AddSpell(CallSpell, True)
	EndIf
	ApplyDuration()
	busy = False
EndFunction

; duration is written into both peace spells (SKSE), so the MCM value is used by every new cast
Function ApplyDuration()
	If PeaceMinutes < 1.0
		PeaceMinutes = 1.0
	ElseIf PeaceMinutes > 30.0
		PeaceMinutes = 30.0
	EndIf
	Int secs = (PeaceMinutes * 60.0) as Int
	If PeaceSpell
		PeaceSpell.SetNthEffectDuration(0, secs)
	EndIf
	If PeaceApplySpell
		PeaceApplySpell.SetNthEffectDuration(0, secs)
	EndIf
EndFunction

Int Function ExtraCount()
	Int m = MaxExtra
	If m < 1
		m = 1
	ElseIf m > MaxExtraLimit
		m = MaxExtraLimit
	EndIf
	If RandomExtra
		Return Utility.RandomInt(1, m)
	EndIf
	Return m
EndFunction

; ---------------------------------------------------------------
; Peace on one creature (called by ILC_PeaceEffect)
; ---------------------------------------------------------------
Bool Function IsCreature(Actor a)
	Return a && a != PlayerRef && !a.IsDead() && !a.IsDisabled() && !a.HasKeyword(ActorTypeNPC)
EndFunction

; companions are already friendly - the follower system owns their faction / aggression
Bool Function CanPacify(Actor a)
	Return IsCreature(a) && !(Followers && Followers.IsPet(a))
EndFunction

Bool Function IsPeaceful(Actor a)
	Return a && StorageUtil.GetIntValue(a, "ILC.PeaceCount") > 0
EndFunction

Int Function PeacefulCount()
	Return StorageUtil.FormListCount(None, LIST_KEY)
EndFunction

Function BeginPeace(Actor a)
	If !CanPacify(a)
		Return
	EndIf
	Int n = StorageUtil.GetIntValue(a, "ILC.PeaceCount")
	If n <= 0
		n = 0
		; first effect on this creature: remember what we change
		StorageUtil.SetFloatValue(a, "ILC.PeaceAggr", a.GetActorValue("Aggression"))
		If a.IsInFaction(AllyFaction)
			StorageUtil.SetIntValue(a, "ILC.PeaceAlly", 0)
		Else
			StorageUtil.SetIntValue(a, "ILC.PeaceAlly", 1)
			a.AddToFaction(AllyFaction)
		EndIf
		StorageUtil.FormListAdd(None, LIST_KEY, a, False)
	EndIf
	StorageUtil.SetIntValue(a, "ILC.PeaceCount", n + 1)
	a.SetActorValue("Aggression", 0.0)
	a.StopCombat()
	a.StopCombatAlarm()
	a.EvaluatePackage()
	Main.Dbg("Peace on " + a.GetDisplayName() + " (" + (n + 1) + ")")
EndFunction

; one peace effect ended (re-casts overlap: the last one restores)
Function EndPeace(Actor a)
	If !a
		Return
	EndIf
	Int n = StorageUtil.GetIntValue(a, "ILC.PeaceCount") - 1
	If n > 0
		StorageUtil.SetIntValue(a, "ILC.PeaceCount", n)
		Return
	EndIf
	RestorePeace(a)
EndFunction

; give back the original aggression / faction (also called before taming, see ILC_Followers.TameWithMessage)
Function RestorePeace(Actor a)
	If !a || (StorageUtil.FormListFind(None, LIST_KEY, a) < 0 && !StorageUtil.HasFloatValue(a, "ILC.PeaceAggr"))
		Return
	EndIf
	If !(Followers && Followers.IsPet(a))
		If StorageUtil.HasFloatValue(a, "ILC.PeaceAggr")
			a.SetActorValue("Aggression", StorageUtil.GetFloatValue(a, "ILC.PeaceAggr"))
		EndIf
		If StorageUtil.GetIntValue(a, "ILC.PeaceAlly") == 1
			a.RemoveFromFaction(AllyFaction)
		EndIf
		a.EvaluatePackage()
	EndIf
	StorageUtil.UnsetIntValue(a, "ILC.PeaceCount")
	StorageUtil.UnsetIntValue(a, "ILC.PeaceAlly")
	StorageUtil.UnsetFloatValue(a, "ILC.PeaceAggr")
	StorageUtil.FormListRemove(None, LIST_KEY, a, True)
	Main.Dbg("Peace ended on " + a.GetDisplayName())
EndFunction

; cast the no-projectile peace spell on a creature (G key / Creature Call)
Bool Function ApplyPeace(Actor a)
	If !CanPacify(a) || !PeaceApplySpell
		Return False
	EndIf
	ApplyDuration()
	PeaceApplySpell.Cast(PlayerRef, a)
	Return True
EndFunction

; if Cast did not land (rare), apply the effect directly
Function VerifyPeace(Actor a)
	If a && CanPacify(a) && !IsPeaceful(a)
		PlayerRef.DoCombatSpellApply(PeaceApplySpell, a)
		Utility.Wait(0.2)
		If !IsPeaceful(a)
			Main.Dbg("Peace FAILED on " + a.GetDisplayName() + " - applied by script")
			BeginPeace(a)    ; no timer: ends with the MCM reset or when a later effect ends
		EndIf
	EndIf
EndFunction

; ---------------------------------------------------------------
; Spell "Creature Call" (ILC_CallEffect)
; ---------------------------------------------------------------
Function CallCreature(Actor a)
	If !a || a.IsDead()
		Return
	EndIf
	If a.HasKeyword(ActorTypeNPC)
		Debug.Notification("Creature Call only works on creatures")
		Return
	EndIf
	If ApplyPeace(a)
		Utility.Wait(0.5)
		VerifyPeace(a)
	EndIf
	Main.OpenPeaceDialogue(a, MODE_CALL)
EndFunction

; ---------------------------------------------------------------
; Hotkey G (ILC_Main.OnKeyDown)
; ---------------------------------------------------------------
Function OnPeaceKey()
	If busy
		Return
	EndIf
	busy = True
	Debug.Notification("I come in peace.")

	Actor[] near = MiscUtil.ScanCellNPCs(PlayerRef, PeaceRadius)
	Actor[] calmed = PapyrusUtil.ActorArray(0)
	Int i = 0
	While i < near.Length
		Actor a = near[i]
		If a && a.Is3DLoaded() && ApplyPeace(a)
			calmed = PapyrusUtil.PushActor(calmed, a)
		EndIf
		i += 1
	EndWhile
	If calmed.Length > 0
		Utility.Wait(0.5)
		i = 0
		While i < calmed.Length
			VerifyPeace(calmed[i])
			i += 1
		EndWhile
		Debug.Notification(calmed.Length + " creature(s) will not fight you for " + (PeaceMinutes as Int) + " min")
	EndIf
	Main.Dbg("G: " + near.Length + " actors in " + (PeaceRadius as Int) + ", " + calmed.Length + " calmed")

	; dialogue: creature under the crosshair, otherwise the nearest creature around
	Actor target = Game.GetCurrentCrosshairRef() as Actor
	If !IsCreature(target)
		target = NearestCreature(near)
	EndIf
	If target
		Main.OpenPeaceDialogue(target, MODE_AREA)
	Else
		Debug.Notification("No creature around you")
	EndIf
	busy = False
EndFunction

Actor Function NearestCreature(Actor[] list)
	Actor best = None
	Float bestDist = 999999.0
	Int i = 0
	While i < list.Length
		Actor a = list[i]
		If IsCreature(a) && a.Is3DLoaded()
			Float d = a.GetDistance(PlayerRef)
			If d < bestDist
				bestDist = d
				best = a
			EndIf
		EndIf
		i += 1
	EndWhile
	Return best
EndFunction

; ---------------------------------------------------------------
; Debug (MCM "Peace" page -> Reset)
; ---------------------------------------------------------------
Int Function ClearAllPeace()
	Int n = 0
	Int i = StorageUtil.FormListCount(None, LIST_KEY)
	While i
		i -= 1
		Actor a = StorageUtil.FormListGet(None, LIST_KEY, i) as Actor
		If a
			a.DispelSpell(PeaceSpell)
			a.DispelSpell(PeaceApplySpell)
		EndIf
	EndWhile
	Utility.Wait(0.5)
	; whatever is still listed lost its effect (unloaded, killed...) -> restore by hand
	i = StorageUtil.FormListCount(None, LIST_KEY)
	While i
		i -= 1
		Actor b = StorageUtil.FormListGet(None, LIST_KEY, i) as Actor
		If b
			RestorePeace(b)
			n += 1
		Else
			StorageUtil.FormListRemove(None, LIST_KEY, None, True)
		EndIf
	EndWhile
	StorageUtil.FormListClear(None, LIST_KEY)
	busy = False
	Return n
EndFunction
