Scriptname ILC_PetAlias extends ReferenceAlias
{IamLoveCreature V.2 - attached to every pet alias (Pet01..Pet50) on ILC_FollowerQuest.
Activation of a pet is blocked: pressing E opens the creature dialogue (same as the K hotkey).}

Event OnActivate(ObjectReference akActionRef)
	Actor a = GetActorRef()
	ILC_Followers fol = GetOwningQuest() as ILC_Followers
	If !a || akActionRef != fol.PlayerRef
		Return
	EndIf
	If a.IsDead()
		a.Activate(akActionRef, True)      ; loot as usual
		Return
	EndIf
	If fol.PlayerRef.IsOnMount()
		Return
	EndIf
	fol.Main.TryOpenDialogue(a)
EndEvent

Event OnDeath(Actor akKiller)
	Actor a = GetActorRef()
	If a
		Debug.Notification(a.GetDisplayName() + " has died")
		(GetOwningQuest() as ILC_Followers).ReleasePet(a, "Died")
	EndIf
EndEvent
