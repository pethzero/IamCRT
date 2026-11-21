;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCConsent Extends TopicInfo Hidden
{ILoveCreature - Begin fragment of "I will make you happy." (ILC_ConsentSex) and "I will heal you." (ILC_PetHeal).
After the scene the creature becomes a companion (if needed) and is healed to full (ILC_Main.MateConsent).
Adapted from SLAC slac_TopicCreaturePCConsent: the player agrees, a consensual SexLab
scene starts, and when it ends the creature becomes a following companion.
The real work is in ILC_Main.StartMate (shared with the companion menu "Mate" button).}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	Actor creature = CreatureRef.GetActorRef()
	If !creature
		creature = akSpeaker
	EndIf
	Main.MateConsent(creature)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ILC_Main Property Main Auto
{ILC_DialogueQuest}

ReferenceAlias Property CreatureRef Auto
{Alias CreatureAlias on ILC_DialogueQuest - the creature in dialogue}
