;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCAnal Extends TopicInfo Hidden
{"Let's do something dirty. (Anal)" - ported from SLAC slac_TopicCreaturePCAnal.
Scene tags: Anal. Reward: companion Speed +50% for 1 minute. Logic: ILC_Main.MateAnal}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	Actor creature = CreatureRef.GetActorRef()
	If !creature
		creature = akSpeaker
	EndIf
	Main.MateAnal(creature)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ILC_Main Property Main Auto
ReferenceAlias Property CreatureRef Auto
