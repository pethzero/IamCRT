Scriptname ILC_TIF_Pet Extends TopicInfo Hidden
{IamLoveCreature V.2 - pet command fragments (one function per dialogue line).}

ILC_Followers Function F()
	Return (GetOwningQuest() as ILC_Main).Followers
EndFunction

Function Fragment_Tame(ObjectReference akSpeakerRef)
	Actor a = akSpeakerRef as Actor
	Int r = F().TamePet(a)
	If r > -1
		Debug.Notification(a.GetDisplayName() + " is now your companion")
	ElseIf r == -3
		Debug.Notification("You can't have more companions (max " + F().GetSlotLimit() + ")")
	EndIf
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
