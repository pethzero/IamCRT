Scriptname ILC_BuffEffect extends ActiveMagicEffect
{ILoveCreature - timed companion buff (MGEF ILC_BuffAttack/Speed/Defense/Regen).
Strength = effect magnitude, duration = effect duration: both are written into the spell by
ILC_Main.CastBuff right before casting (MCM "Buffs" sliders). The engine ends the effect (also across
save/load); OnEffectFinish removes the bonus. Every applied bonus is also recorded in StorageUtil so
ILC_Main.ClearAllBuffs can repair values if an effect ever vanished without finishing.
  Attack: +magnitude % weapon/unarmed damage (AttackDamageMult) AND +magnitude % spell power (Destruction)
  Speed: +magnitude % of the base value
  Defense: +magnitude % of the current armor (at least 1.5 x magnitude points)
  Regen: magnitude = % of max health restored every second}

Int Property BuffType Auto          ; 0 attack, 1 speed, 2 defense, 3 health regen

Actor target
Float applied = 0.0
Float magicApplied = 0.0     ; attack buff: extra spell power (Destruction = all damage spells)
String magicAV = ""
Float regenShare = 0.0

; actor value that makes damage spells stronger (what Fortify Destruction potions use).
; Checked through SKSE so a wrong name can never be modified.
String Function MagicAV() Global
	If ActorValueInfo.GetActorValueInfoByName("DestructionPowerModifier")
		Return "DestructionPowerModifier"
	ElseIf ActorValueInfo.GetActorValueInfoByName("DestructionPowerMod")
		Return "DestructionPowerMod"
	EndIf
	Return ""
EndFunction

String Function AVName()
	If BuffType == 0
		Return "AttackDamageMult"
	ElseIf BuffType == 1
		Return "SpeedMult"
	ElseIf BuffType == 2
		Return "DamageResist"
	EndIf
	Return ""
EndFunction

Event OnEffectStart(Actor akTarget, Actor akCaster)
	target = akTarget
	Float m = GetMagnitude()
	Debug.Trace("[ILoveCreature] buff " + BuffType + " start on " + akTarget + ", magnitude " + m + ", duration " + GetDuration())
	If m <= 0.0
		Return
	EndIf
	If BuffType == 0
		applied = target.GetBaseActorValue("AttackDamageMult") * m / 100.0
		If applied <= 0.0
			applied = m / 100.0
		EndIf
		; magic: +m % spell power (power modifier values are in percent)
		magicAV = MagicAV()
		If magicAV != ""
			magicApplied = m
			target.ModActorValue(magicAV, magicApplied)
			StorageUtil.AdjustFloatValue(target, "ILC.Buff." + magicAV, magicApplied)
		EndIf
	ElseIf BuffType == 1
		applied = target.GetBaseActorValue("SpeedMult") * m / 100.0
		If applied <= 0.0
			applied = m
		EndIf
	ElseIf BuffType == 2
		applied = target.GetActorValue("DamageResist") * m / 100.0
		If applied < m * 1.5
			applied = m * 1.5      ; creatures often have little armor
		EndIf
	ElseIf BuffType == 3
		regenShare = m / 100.0
		RegisterForSingleUpdate(1.0)
		Return
	EndIf
	target.ModActorValue(AVName(), applied)
	StorageUtil.AdjustFloatValue(target, "ILC.Buff." + AVName(), applied)
	StorageUtil.FormListAdd(None, "ILC.BuffedActors", target, False)
	If BuffType == 1
		RefreshSpeed(target)
	EndIf
EndEvent

Event OnUpdate()
	If regenShare > 0.0 && target && !target.IsDead()
		target.RestoreActorValue("Health", target.GetActorValueMax("Health") * regenShare + 1.0)
		RegisterForSingleUpdate(1.0)
	EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	regenShare = 0.0
	If akTarget && magicApplied != 0.0 && magicAV != ""
		akTarget.ModActorValue(magicAV, -magicApplied)
		StorageUtil.AdjustFloatValue(akTarget, "ILC.Buff." + magicAV, -magicApplied)
		magicApplied = 0.0
	EndIf
	If !akTarget || applied == 0.0
		Return
	EndIf
	akTarget.ModActorValue(AVName(), -applied)
	StorageUtil.AdjustFloatValue(akTarget, "ILC.Buff." + AVName(), -applied)
	If BuffType == 1
		RefreshSpeed(akTarget)
	EndIf
	applied = 0.0
EndEvent

; SpeedMult only takes effect after a CarryWeight change
Function RefreshSpeed(Actor a)
	a.ModActorValue("CarryWeight", 0.1)
	a.ModActorValue("CarryWeight", -0.1)
EndFunction
