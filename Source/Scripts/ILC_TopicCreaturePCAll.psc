;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCAll Extends TopicInfo Hidden
{V.4 "I will make it happen for all of you." (only after the G key): this creature + 1..5 extra
creatures around you (MCM Peace: Max extra, Stable / Random). Scenes run one after another until
every creature had its turn (SexLab allows max 5 actors per scene). Logic: ILC_Main.MateAll}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	Actor creature = CreatureRef.GetActorRef()
	If !creature
		creature = akSpeaker
	EndIf
	Main.MateAll(creature)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ILC_Main Property Main Auto
ReferenceAlias Property CreatureRef Auto
