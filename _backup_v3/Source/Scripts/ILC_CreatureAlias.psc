Scriptname ILC_CreatureAlias extends ReferenceAlias
{ILoveCreature - attach to alias "CreatureAlias" (Optional, Allow Reuse in Quest).
Alias Package Data: ILC_ForceGreetPackage.
Clears itself when the dialogue closes, or if the creature never reaches the player.}

Bool inDialogue = False

Function StartWatch(Float afTimeout)
	inDialogue = False
	RegisterForMenu("Dialogue Menu")
	RegisterForSingleUpdate(afTimeout)
EndFunction

Function StopWatch()
	inDialogue = False
	UnregisterForUpdate()
	UnregisterForMenu("Dialogue Menu")
EndFunction

Event OnMenuOpen(String menuName)
	If menuName == "Dialogue Menu"
		inDialogue = True
		UnregisterForUpdate()
	EndIf
EndEvent

Event OnMenuClose(String menuName)
	If menuName == "Dialogue Menu" && inDialogue
		(GetOwningQuest() as ILC_Main).CloseDialogue()
	EndIf
EndEvent

; Timeout: creature could not reach / greet the player
Event OnUpdate()
	If UI.IsMenuOpen("Dialogue Menu")
		inDialogue = True
		Return
	EndIf
	Debug.Notification("ILoveCreature: Creature could not reach you")
	(GetOwningQuest() as ILC_Main).CloseDialogue()
EndEvent

Event OnDeath(Actor akKiller)
	(GetOwningQuest() as ILC_Main).CloseDialogue()
EndEvent

Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
	If aeCombatState != 0
		(GetOwningQuest() as ILC_Main).CloseDialogue()
	EndIf
EndEvent
