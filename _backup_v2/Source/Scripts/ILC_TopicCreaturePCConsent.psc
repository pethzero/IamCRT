;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname ILC_TopicCreaturePCConsent Extends TopicInfo Hidden
{IamLoveCreature - TopicInfo fragment: player chooses "Do you want me?" (consensual sex).
Adapted from slac_TopicCreaturePCConsent for IamLoveCreature.
Uses SexLab Framework directly — does not require SLAC as a master.

Dialogue flow:
  ForceGreet -> "Hey Hello" -> player options:
    "Do you want me?"       -> THIS script (ILC_TopicCreaturePCConsent)
    "Come with me."         -> tame as follower
    "Never mind."           -> goodbye

What this script does (mirrors SLAC flow, simplified):
  1. Get the creature from CreatureRef alias
  2. Validate: creature alive/loaded, not already animating, SexLab enabled + creatures allowed
  3. (Optional) Play invite animation + strip via SexLab
  4. Start consensual creature sex via SexLab.QuickStart()
  5. Notify result
  6. Reset dialogue state}

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
	; ---- Get actors ----
	Actor player = PlayerRef
	Actor creature = CreatureRef.GetActorRef()

	If !creature
		Debug.Notification("IamLoveCreature: No creature in dialogue")
		Return
	EndIf

	String creatureName = creature.GetDisplayName()

	; ---- Validate creature ----
	If creature.IsDead()
		Debug.Notification("IamLoveCreature: " + creatureName + " is dead")
		Return
	EndIf
	If creature.IsDisabled() || !creature.Is3DLoaded()
		Debug.Notification("IamLoveCreature: " + creatureName + " is not accessible")
		Return
	EndIf
	If creature.GetCombatState() > 0 || player.GetCombatState() > 0
		Debug.Notification("IamLoveCreature: Cannot start while in combat")
		Return
	EndIf

	; ---- Validate SexLab (property filled from ESP — SexLab.esm is a master) ----
	If !SexLab
		Debug.Notification("IamLoveCreature: SexLab Framework not found")
		Return
	EndIf
	If !SexLab.Enabled
		Debug.Notification("IamLoveCreature: SexLab is disabled")
		Return
	EndIf
	If !SexLab.AllowCreatures
		Debug.Notification("IamLoveCreature: Creature animations are disabled in SexLab MCM")
		Return
	EndIf
	If SexLab.IsActorActive(player)
		Debug.Notification("IamLoveCreature: Player is already in a scene")
		Return
	EndIf
	If SexLab.IsActorActive(creature)
		Debug.Notification("IamLoveCreature: " + creatureName + " is already in a scene")
		Return
	EndIf
	If SexLab.IsForbidden(creature)
		Debug.Notification("IamLoveCreature: " + creatureName + " is forbidden by SexLab")
		Return
	EndIf

	; ---- Invite animation (optional, matches SLAC behavior) ----
	Form[] stripped
	If InviteAnimation
		stripped = SexLab.StripActor(player, DoAnimate = True)
		Utility.Wait(3.0)
	EndIf

	; ---- Start consensual creature sex ----
	; QuickStart: Actor1 = player (passive), Actor2 = creature
	; No Victim = consensual. Hook lets external mods listen for ILC scenes.
	sslThreadController thread = SexLab.QuickStart( \
		player, \
		creature, \
		Victim = None, \
		Hook = "ILC_CreatureConsent" \
	)

	If thread
		Debug.Notification("IamLoveCreature: " + creatureName + " ♥")
		Debug.Trace("[IamLoveCreature] Consensual scene started with " + creatureName + " (tid " + thread.tid + ")")
	Else
		If stripped
			SexLab.UnStripActor(player, stripped)
		EndIf
		Debug.Notification("IamLoveCreature: No animation found for " + creatureName)
		Debug.Trace("[IamLoveCreature] QuickStart failed for " + creatureName)
	EndIf

	; ---- Cleanup ----
	; Dialogue closes (Goodbye flag) -> ILC_CreatureAlias.OnMenuClose
	; calls ILC_Main.CloseDialogue() which clears the alias.
	If DialogueSignal
		DialogueSignal.SetValue(0)
	EndIf
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

; -------------------------------------------------------------------
; Properties — fill in CK (or in build_esp.py VMAD)
; -------------------------------------------------------------------

; Core references
ILC_Main Property Main Auto
{ILC_DialogueQuest quest script — used to read settings and close dialogue.}

ReferenceAlias Property CreatureRef Auto
{Alias "CreatureAlias" on ILC_DialogueQuest — the creature in dialogue.}

Actor Property PlayerRef Auto
{PlayerRef (00000014).}

; SexLab Framework (SexLab.esm is a master — property filled by ESP)
SexLabFramework Property SexLab Auto
{SexLabQuestFramework (SexLab.esm:0xD62).}

; Optional settings
Bool Property InviteAnimation = False Auto
{If true, strip the player and wait before starting the scene
(mirrors SLAC's inviteAnimationPC). Default false for simplicity.}

GlobalVariable Property DialogueSignal = None Auto
{(Optional) GlobalVariable to reset when the dialogue action finishes.
Mirrors SLAC's slac_CreatureDialogueSignal. Set to None if not used.}
