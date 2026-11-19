Scriptname ILC_PowerEffect extends ActiveMagicEffect
{IamLoveCreature V.2 - "Companion Commands" power (Z): group commands for creature companions.}

ILC_Followers Property Followers Auto
Message Property CommandMsg Auto      ; buttons: Follow me / Wait here / Summon followers / Summon all / Cancel

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If !Followers.IsInitialized()
		Return
	EndIf
	If Followers.GetActorCount() == 0
		Debug.Notification("You have no creature companions")
		Return
	EndIf
	Int b = CommandMsg.Show()
	If b == 0
		Followers.SetAllWait(False)
	ElseIf b == 1
		Followers.SetAllWait(True)
	ElseIf b == 2
		Debug.Notification(Followers.SummonAll(True) + " companion(s) summoned")
	ElseIf b == 3
		Debug.Notification(Followers.SummonAll(False) + " companion(s) summoned")
	EndIf
EndEvent
