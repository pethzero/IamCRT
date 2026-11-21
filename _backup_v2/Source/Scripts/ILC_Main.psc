Scriptname ILC_Main extends Quest
{IamLoveCreature - main controller. Attach to quest ILC_DialogueQuest.
Hotkey -> creature under the crosshair force-greets the player -> "Hey Hello" + pet commands.}

; ---------------------------------------------------------------
; Properties (fill in CK)
; ---------------------------------------------------------------
Actor Property PlayerRef Auto
ReferenceAlias Property CreatureAlias Auto     ; alias "CreatureAlias" (has the ForceGreet package)
Keyword Property ActorTypeNPC Auto             ; vanilla ActorTypeNPC [KYWD:00013794]
ILC_Followers Property Followers Auto        ; -> ILC_FollowerQuest (V.2 creature followers)

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
	RegisterForMenu("Journal Menu")   ; MCM lives in the Journal Menu
	If !UI.IsMenuOpen("Dialogue Menu")
		CloseDialogue()
	EndIf
	If Followers
		Followers.DoUpdate()
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
	If keyCode != OpenDialogueKey || !ModEnabled
		Return
	EndIf
	If Utility.IsInMenuMode() || UI.IsTextInputEnabled() || UI.IsMenuOpen("Dialogue Menu")
		Return
	EndIf

	Actor target = Game.GetCurrentCrosshairRef() as Actor
	If !target
		Debug.Notification("IamLoveCreature: No target under crosshair")
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
		Debug.Notification("IamLoveCreature: No creature nearby")
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

Bool Function TryOpenDialogue(Actor akCreature)
	If !IsValidCreature(akCreature)
		Debug.Notification("IamLoveCreature: Target is not a creature")
		Return False
	EndIf
	If akCreature.IsInCombat() || PlayerRef.IsInCombat()
		Debug.Notification("IamLoveCreature: Cannot talk during combat")
		Return False
	EndIf
	If akCreature.IsBeingRidden() || PlayerRef.IsOnMount()
		Debug.Notification("IamLoveCreature: Cannot talk while mounted")
		Return False
	EndIf

	; Put the creature in the alias -> its ForceGreet package walks to the player and opens ILC_HelloTopic
	CloseDialogue()
	CreatureAlias.ForceRefTo(akCreature)
	akCreature.EvaluatePackage()
	(CreatureAlias as ILC_CreatureAlias).StartWatch(TimeoutSeconds)
	Debug.Trace("[IamLoveCreature] ForceGreet started: " + akCreature.GetDisplayName())
	Return True
EndFunction

Function CloseDialogue()
	Actor a = CreatureAlias.GetActorRef()
	If a
		(CreatureAlias as ILC_CreatureAlias).StopWatch()
		CreatureAlias.Clear()
		a.EvaluatePackage()
	EndIf
EndFunction
