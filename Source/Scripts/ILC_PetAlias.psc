Scriptname ILC_PetAlias extends ReferenceAlias
{IamLoveCreature V.2 - attached to every pet alias (Pet01..Pet50) on ILC_FollowerQuest.
No activation override: the pet stays talkable (K hotkey / SLAC).}

Event OnDeath(Actor akKiller)
	Actor a = GetActorRef()
	If a
		Debug.Notification(a.GetDisplayName() + " has died")
		(GetOwningQuest() as ILC_Followers).ReleasePet(a, "Died")
	EndIf
EndEvent
