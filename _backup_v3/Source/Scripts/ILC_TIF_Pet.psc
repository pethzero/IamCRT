Scriptname ILC_TIF_Pet Extends TopicInfo Hidden
{ILoveCreature V.2 - pet command fragments (one function per dialogue line).}

ILC_Followers Function F()
	Return (GetOwningQuest() as ILC_Main).Followers
EndFunction

Function Fragment_Tame(ObjectReference akSpeakerRef)
	F().TameWithMessage(akSpeakerRef as Actor)
EndFunction

Function Fragment_Follow(ObjectReference akSpeakerRef)
	F().SetFollow(akSpeakerRef as Actor, True)
EndFunction

Function Fragment_StopFollow(ObjectReference akSpeakerRef)
	F().SetFollow(akSpeakerRef as Actor, False)
EndFunction

Function Fragment_Wait(ObjectReference akSpeakerRef)
	F().SetWait(akSpeakerRef as Actor, True)
EndFunction

Function Fragment_Resume(ObjectReference akSpeakerRef)
	F().SetWait(akSpeakerRef as Actor, False)
EndFunction

Function Fragment_SetHome(ObjectReference akSpeakerRef)
	Actor a = akSpeakerRef as Actor
	F().SetHome(a, True)
	Debug.Notification(a.GetDisplayName() + " will live here when it is not following you")
EndFunction

Function Fragment_ClearHome(ObjectReference akSpeakerRef)
	F().SetHome(akSpeakerRef as Actor, False)
EndFunction

Function Fragment_Inventory(ObjectReference akSpeakerRef)
	(akSpeakerRef as Actor).OpenInventory(True)
EndFunction

Function Fragment_Release(ObjectReference akSpeakerRef)
	Actor a = akSpeakerRef as Actor
	If F().ReleasePet(a)
		Debug.Notification(a.GetDisplayName() + " is free again")
	EndIf
EndFunction

; "I want to check you." - show its health
Function Fragment_Check(ObjectReference akSpeakerRef)
	Actor a = akSpeakerRef as Actor
	Int hp = (a.GetActorValuePercentage("Health") * 100.0) as Int
	Debug.Notification(a.GetDisplayName() + " - Health " + (a.GetActorValue("Health") as Int) + " / " + (a.GetActorValueMax("Health") as Int) + " (" + hp + "%)")
EndFunction

; "I will heal you." - restore health to 100%
Function Fragment_Heal(ObjectReference akSpeakerRef)
	Actor a = akSpeakerRef as Actor
	a.RestoreActorValue("Health", a.GetActorValueMax("Health"))
	Debug.Notification(a.GetDisplayName() + " is fully healed")
EndFunction

Function Fragment_Ride(ObjectReference akSpeakerRef)
	akSpeakerRef.Activate(Game.GetPlayer(), True)   ; default activation = mount
EndFunction
