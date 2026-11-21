Scriptname ILC_TameEffect extends ActiveMagicEffect
{ILoveCreature V.3 - spell "Creature Bond" (MGEF ILC_TameEffect).
Like the Tame Animal spell of Animal Followers, but the target does not need to be calmed first:
the creature stops fighting, becomes friendly and joins you as a following companion.}

ILC_Followers Property Followers Auto
Keyword Property ActorTypeNPC Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If !akTarget || akCaster != Followers.PlayerRef
		Return
	EndIf
	If akTarget.IsDead()
		Return
	EndIf
	If akTarget.HasKeyword(ActorTypeNPC)
		Debug.Notification("Creature Bond only works on creatures")
		Return
	EndIf
	If !Followers.IsInitialized()
		Return
	EndIf
	If Followers.IsPet(akTarget)
		Debug.Notification(akTarget.GetDisplayName() + " is already your companion")
		Return
	EndIf

	; calm it down first, then tame (TamePet makes it an ally with Aggression 0, so it won't attack again)
	akTarget.StopCombat()
	akTarget.StopCombatAlarm()
	Followers.TameWithMessage(akTarget)
EndEvent
