Scriptname ILC_CallEffect extends ActiveMagicEffect
{ILoveCreature V.4 - MGEF ILC_CallEffect (spell "Creature Call", aimed).
The creature becomes peaceful and comes to talk: normal dialogue menu, our lines at the end.}

ILC_Peace Property Peace Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If !Peace || akCaster != Peace.PlayerRef
		Return
	EndIf
	Peace.CallCreature(akTarget)
EndEvent
