;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCAggressive Extends TopicInfo Hidden
{"Do what you will with me. (Rough)" - ported from SLAC slac_TopicCreaturePCAggressive.
Scene tags: Aggressive. Reward: companion Attack +50% for 1 minute. Logic: ILC_Main.MateAggressive}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	Actor creature = CreatureRef.GetActorRef()
	If !creature
		creature = akSpeaker
	EndIf
	Main.MateAggressive(creature)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ILC_Main Property Main Auto
ReferenceAlias Property CreatureRef Auto
