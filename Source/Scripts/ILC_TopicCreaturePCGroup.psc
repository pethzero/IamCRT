;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCGroup Extends TopicInfo Hidden
{"Maybe we can find some friends. (Group)" - ported from SLAC slac_TopicCreaturePCGroup.
Scene: the creature + up to 3 of your following companions of the same race nearby.
Reward: Attack/Speed/Defense +50%, health regeneration (1 minute) and full health for the whole pack.
Logic: ILC_Main.MateGroup}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	Actor creature = CreatureRef.GetActorRef()
	If !creature
		creature = akSpeaker
	EndIf
	Main.MateGroup(creature)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ILC_Main Property Main Auto
ReferenceAlias Property CreatureRef Auto
