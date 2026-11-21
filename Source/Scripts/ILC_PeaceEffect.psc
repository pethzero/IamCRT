Scriptname ILC_PeaceEffect extends ActiveMagicEffect
{ILoveCreature V.4 - MGEF ILC_PeaceEffect / ILC_PeaceApplyEffect (spells "Creature Peace" and the G key).
The creature stops fighting you while the effect lasts (default 5 min, MCM "Peace").}

ILC_Peace Property Peace Auto
Actor target

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If !Peace || !akTarget || akTarget.IsDead()
		Return
	EndIf
	If akTarget.HasKeyword(Peace.ActorTypeNPC)
		If akCaster == Peace.PlayerRef
			Debug.Notification("Creature Peace only works on creatures")
		EndIf
		Return
	EndIf
	If !Peace.CanPacify(akTarget)
		Return                   ; your companion: already friendly
	EndIf
	target = akTarget
	Peace.BeginPeace(akTarget)
	If akCaster == Peace.PlayerRef && !Peace.Main.DebugMessages
		; aimed cast: short feedback (the G key prints its own summary)
		If GetBaseObject() == Peace.PeaceSpell.GetNthEffectMagicEffect(0)
			Debug.Notification(akTarget.GetDisplayName() + " will not fight you for " + (Peace.PeaceMinutes as Int) + " min")
		EndIf
	EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	If target
		Peace.EndPeace(target)
		target = None
	EndIf
EndEvent
