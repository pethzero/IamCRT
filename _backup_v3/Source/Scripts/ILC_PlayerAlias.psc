Scriptname ILC_PlayerAlias extends ReferenceAlias
{ILoveCreature - attach to alias "PlayerAlias" (Specific Reference = PlayerRef) on ILC_DialogueQuest.
Re-registers the hotkey and cleans up on every game load.}

Event OnPlayerLoadGame()
	(GetOwningQuest() as ILC_Main).Maintenance()
EndEvent
