Scriptname ILC_Config extends SKI_ConfigBase
{ILoveCreature - MCM. Attach to quest ILC_MCMQuest (Start Game Enabled)
with a PlayerRef alias that has SKI_PlayerLoadGameAlias.
V.2 pages: Settings, Follower Status, Slot History, Follower Settings. V.3.7 Buffs. V.4 Peace.}

ILC_Main Property Main Auto             ; -> ILC_DialogueQuest
ILC_Followers Property Followers Auto   ; -> ILC_FollowerQuest
Actor Property PlayerRef Auto

; ---------------------------------------------------------------
; Follower page state
; ---------------------------------------------------------------
Int selSlot = -1
Int[] oidRowSelect
Int[] oidSummon
Int[] oidGoTo
Int[] rowSlot
Int rowCount = 0
Int[] menuSlots

Int oidPetMenu = -1
Int oidFollow = -1
Int oidWait = -1
Int oidSummonOne = -1
Int oidGoToOne = -1
Int oidHomeSet = -1
Int oidHomeClear = -1
Int oidInventory = -1
Int oidRelease = -1
Int oidClearHistory = -1

; commands run after the menu closes (OnUpdate does not fire in menu mode)
; 1 summon, 2 set home, 3 clear home, 4 summon followers, 5 summon all, 6 inventory
Int[] pendingCmd
Actor pendingGoTo

; ---------------------------------------------------------------
; Setup
; ---------------------------------------------------------------
Event OnConfigInit()
	ModName = "ILoveCreature"
	Pages = new String[5]
	Pages[0] = "Settings"
	Pages[1] = "Follower Status"
	Pages[2] = "Slot History"
	Pages[3] = "Follower Settings"
	Pages[4] = "Buffs"
	pendingCmd = new Int[128]
EndEvent

Int Function GetVersion()
	Return 5
EndFunction

Event OnVersionUpdate(Int newVersion)
	If CurrentVersion < 5      ; V.3.7 adds the "Buffs" page, V.4.3 moves "Peace" into "Settings"
		OnConfigInit()
	EndIf
EndEvent

Event OnConfigOpen()
	If !pendingCmd
		pendingCmd = new Int[128]
	EndIf
	If selSlot >= 0 && !Followers.GetActorInSlot(selSlot)
		selSlot = -1
	EndIf
	If selSlot < 0
		selSlot = FirstUsedSlot()
	EndIf
EndEvent

; ---------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------
Int Function FirstUsedSlot()
	Int n = Followers.GetSlotLimit()
	Int i = 0
	While i < n
		If Followers.GetActorInSlot(i)
			Return i
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

String Function PetLabel(Int slot, Actor a)
	Return "#" + (slot + 1) + "  " + a.GetDisplayName()
EndFunction

String Function Pct(Actor a, String av)
	Return ((a.GetActorValuePercentage(av) * 100.0) as Int) + "%"
EndFunction

String Function AVText(Actor a, String av)
	Return (a.GetActorValue(av) as Int) + " / " + (a.GetActorValueMax(av) as Int) + "  (" + Pct(a, av) + ")"
EndFunction

Int Function FlagIf(Bool enabled)
	If enabled
		Return OPTION_FLAG_NONE
	EndIf
	Return OPTION_FLAG_DISABLED
EndFunction

Function Queue(Int slot, Int cmd)
	pendingCmd[slot] = cmd
	RegisterForSingleUpdate(0.5)
EndFunction

; ---------------------------------------------------------------
; Pages
; ---------------------------------------------------------------
Event OnPageReset(String page)
	oidRowSelect = new Int[64]
	oidSummon = new Int[64]
	oidGoTo = new Int[64]
	rowSlot = new Int[64]
	rowCount = 0
	oidPetMenu = -1
	oidFollow = -1
	oidWait = -1
	oidSummonOne = -1
	oidGoToOne = -1
	oidHomeSet = -1
	oidHomeClear = -1
	oidInventory = -1
	oidRelease = -1
	oidClearHistory = -1

	If page == "" || page == "Settings"
		PageSettings()
	ElseIf page == "Buffs"
		PageBuffs()
	ElseIf !Followers || !Followers.IsInitialized()
		SetCursorFillMode(TOP_TO_BOTTOM)
		AddHeaderOption("Follower system is not running")
	ElseIf page == "Follower Status"
		PageStatus()
	ElseIf page == "Slot History"
		PageSlots()
	ElseIf page == "Follower Settings"
		PageFollowerSettings()
	EndIf
EndEvent

Function PageSettings()
	SetCursorFillMode(TOP_TO_BOTTOM)

	Int flags = OPTION_FLAG_NONE
	If !Main.ModEnabled
		flags = OPTION_FLAG_DISABLED
	EndIf

	SetCursorPosition(0)
	AddHeaderOption("Global Settings")
	AddToggleOptionST("ILC_ModEnabled", "Mod Enabled", Main.ModEnabled)
	PeaceLeft()

	SetCursorPosition(1)
	AddHeaderOption("Creature Dialogue")
	AddKeyMapOptionST("ILC_OpenKey", "Open Dialogue Hotkey", Main.OpenDialogueKey, OPTION_FLAG_WITH_UNMAP + flags)
	AddTextOptionST("ILC_OpenNow", "Open Dialogue (Nearest Creature)", "OPEN", flags)
	PeaceRight()
EndFunction

; ---- Follower Status: selected pet + commands, overview of all pets below
Function PageStatus()
	SetCursorFillMode(TOP_TO_BOTTOM)
	SetTitleText("Companions: " + Followers.GetActorCount() + " / " + Followers.GetSlotLimit())
	Actor a = Followers.GetActorInSlot(selSlot)

	SetCursorPosition(0)
	AddHeaderOption("Follower Status")
	If !a
		AddMenuOption("Companion", "None", OPTION_FLAG_DISABLED)
		AddTextOption("No creature companions yet.", "", OPTION_FLAG_DISABLED)
		AddTextOption("Cast 'Creature Bond' on a creature, or", "", OPTION_FLAG_DISABLED)
		AddTextOption("press the dialogue hotkey: 'I need a follower.'", "", OPTION_FLAG_DISABLED)
		Return
	EndIf

	oidPetMenu = AddMenuOption("Companion", PetLabel(selSlot, a))
	AddTextOption("Race", a.GetRace().GetName(), OPTION_FLAG_DISABLED)
	AddTextOption("Level", a.GetLevel(), OPTION_FLAG_DISABLED)
	AddTextOption("Behaviour", Followers.GetActorStatus(a), OPTION_FLAG_DISABLED)
	AddTextOption("Health", AVText(a, "Health"), OPTION_FLAG_DISABLED)
	AddTextOption("Stamina", AVText(a, "Stamina"), OPTION_FLAG_DISABLED)
	AddTextOption("Magicka", AVText(a, "Magicka"), OPTION_FLAG_DISABLED)
	AddTextOption("Location", Followers.GetActorLocationName(a), OPTION_FLAG_DISABLED)
	String homeTxt = "No"
	If Followers.HasHome(a)
		homeTxt = "Yes"
	EndIf
	AddTextOption("Home set", homeTxt, OPTION_FLAG_DISABLED)
	If Followers.IsActorStolen(a)
		AddTextOption("Ownership", "Stolen", OPTION_FLAG_DISABLED)
	EndIf

	SetCursorPosition(1)
	AddHeaderOption("Commands")
	Bool alive = !a.IsDead()
	Bool following = a.IsPlayerTeammate()
	If following
		oidFollow = AddTextOption("Follow", "Stop following", FlagIf(alive))
	Else
		oidFollow = AddTextOption("Follow", "Follow me", FlagIf(alive))
	EndIf
	If Followers.IsActorWaiting(a)
		oidWait = AddTextOption("Wait", "Resume", FlagIf(alive && following))
	Else
		oidWait = AddTextOption("Wait", "Wait here", FlagIf(alive && following))
	EndIf
	oidSummonOne = AddTextOption("Summon to me", "Summon", FlagIf(alive))
	oidGoToOne = AddTextOption("Travel to companion", "Go to")
	oidHomeSet = AddTextOption("Home", "Set home here", FlagIf(alive))
	oidHomeClear = AddTextOption("Home", "Clear home", FlagIf(alive && Followers.HasHome(a)))
	oidInventory = AddTextOption("Inventory", "Open", FlagIf(alive))
	oidRelease = AddTextOption("Release companion", "Release")

	SetCursorFillMode(LEFT_TO_RIGHT)
	SetCursorPosition(24)
	AddHeaderOption("All Companions")
	AddEmptyOption()
	Int n = Followers.GetSlotLimit()
	Int i = 0
	While i < n && rowCount < 64
		Actor p = Followers.GetActorInSlot(i)
		If p
			oidRowSelect[rowCount] = AddTextOption(PetLabel(i, p), "HP " + Pct(p, "Health") + " | " + Followers.GetActorStatus(p))
			rowSlot[rowCount] = i
			rowCount += 1
		EndIf
		i += 1
	EndWhile
EndFunction

; ---- Slot History: every companion with Summon / Go to + event log
Function PageSlots()
	SetCursorFillMode(LEFT_TO_RIGHT)
	SetTitleText("Companions: " + Followers.GetActorCount() + " / " + Followers.GetSlotLimit())
	AddHeaderOption("Companion  (click: Summon)")
	AddHeaderOption("Location  (click: Go to)")

	Int n = Followers.GetSlotLimit()
	Int i = 0
	While i < n && rowCount < 64
		Actor p = Followers.GetActorInSlot(i)
		If p
			oidSummon[rowCount] = AddTextOption(PetLabel(i, p) + "  [" + Followers.GetActorStatus(p) + "]", "Summon", FlagIf(!p.IsDead()))
			oidGoTo[rowCount] = AddTextOption(Followers.GetActorLocationName(p), "Go to")
			rowSlot[rowCount] = i
			rowCount += 1
		EndIf
		i += 1
	EndWhile
	Int used = 6 + rowCount * 2
	If rowCount == 0
		AddTextOption("No companions", "", OPTION_FLAG_DISABLED)
		AddEmptyOption()
		used += 2
	EndIf

	AddEmptyOption()
	AddEmptyOption()
	AddHeaderOption("History (newest first)")
	oidClearHistory = AddTextOption("", "Clear history")

	Int hc = Followers.GetHistoryCount()
	If hc == 0
		AddTextOption("No events yet", "", OPTION_FLAG_DISABLED)
		AddEmptyOption()
	EndIf
	Int maxRows = (128 - used) / 2
	If hc > maxRows
		hc = maxRows
	EndIf
	Int h = 0
	While h < hc
		AddTextOption(Followers.GetHistoryEntry(h), "", OPTION_FLAG_DISABLED)
		AddEmptyOption()
		h += 1
	EndWhile
EndFunction

Function PageFollowerSettings()
	SetCursorFillMode(TOP_TO_BOTTOM)
	SetCursorPosition(0)
	AddHeaderOption("Group Commands")
	AddTextOptionST("ILC_AllResume", "Following companions", "Resume")
	AddTextOptionST("ILC_AllWait", "Following companions", "Wait here")
	AddTextOptionST("ILC_SummonFollowers", "Summon followers", "Summon")
	AddTextOptionST("ILC_SummonAll", "Summon all companions", "Summon")

	SetCursorPosition(1)
	AddHeaderOption("Options")
	AddToggleOptionST("ILC_MarkFollower", "Count as follower (SLAC)", Followers.MarkAsFollower)
	AddToggleOptionST("ILC_TeleportLoad", "Catch up after load screens", Followers.TeleportOnLoad, FlagIf(!Followers.DoorOverride))
	AddToggleOptionST("ILC_DoorOverride", "Companions open doors", Followers.DoorOverride)
	AddToggleOptionST("ILC_Debug", "Debug log", Followers.DebugLog)
	AddEmptyOption()
	AddHeaderOption("Maintenance")
	AddTextOptionST("ILC_ReleaseAll", "Release all companions", "Release")
EndFunction

; ---- Buffs: what each mate choice gives, who receives it, what is active now
Function PageBuffs()
	SetCursorFillMode(TOP_TO_BOTTOM)
	SetCursorPosition(0)
	; short label + short value per row (long text overlaps in SkyUI); full line in the info text
	AddHeaderOption("Mate Rewards (" + (Main.BuffMinutes as Int) + " min, after the scene)")
	AddTextOptionST("ILC_RwJoin", "I will make you happy.", "Join + restore")
	AddTextOptionST("ILC_RwHeal", "I will heal you.", "Restore all")
	AddTextOptionST("ILC_RwRough", "Rough", "Attack +" + (Main.BuffAttackPct as Int) + "%")
	AddTextOptionST("ILC_RwDirty", "Dirty", "Speed +" + (Main.SpeedValue() as Int) + "%")
	AddTextOptionST("ILC_RwBitch", "Bitch", "Defense +" + (Main.BuffDefensePct as Int) + "%")
	AddTextOptionST("ILC_RwOral", "Oral", "Regen " + Main.FmtDec(Main.BuffRegenPct) + "%/s")
	AddTextOptionST("ILC_RwGroup", "Group (whole pack)", "All 4 + heal")

	AddEmptyOption()
	AddHeaderOption("Who Gets the Buffs")
	AddToggleOptionST("ILC_BuffFollower", "Your companion (and the pack)", Main.BuffFollower)
	AddToggleOptionST("ILC_BuffPlayer", "You (player)", Main.BuffPlayer)
	AddEmptyOption()
	AddHeaderOption("Active on You")
	AddBuffRow(PlayerRef)

	SetCursorPosition(1)
	AddHeaderOption("Buff Settings")
	AddInputOptionST("ILC_InMinutes", "Duration (minutes, 1-60)", (Main.BuffMinutes as Int) + " min")
	AddSliderOptionST("ILC_SlAttack", "Attack (weapons + magic)", Main.BuffAttackPct, "+{0}%")
	AddSliderOptionST("ILC_SlSpeed", "Speed (max 30%)", Main.SpeedValue(), "+{0}%")
	AddSliderOptionST("ILC_SlDefense", "Defense (armor)", Main.BuffDefensePct, "+{0}%")
	AddSliderOptionST("ILC_SlRegen", "Health regeneration", Main.BuffRegenPct, "{1}% / s")
	AddTextOptionST("ILC_BuffDefaults", "Balanced defaults", "RESET")
	AddEmptyOption()
	AddHeaderOption("Debug")
	AddToggleOptionST("ILC_BuffDebug", "Show reward steps on screen", Main.DebugMessages)
	AddTextOptionST("ILC_BuffClear", "Clear all buffs (fix stuck values)", "CLEAR")
	Actor a = Followers.GetActorInSlot(selSlot)
	If a
		AddEmptyOption()
		AddHeaderOption("Active on " + a.GetDisplayName())
		AddBuffRow(a)
	EndIf
EndFunction

; ---- slider helper (SkyUI): shared open dialog
Function OpenSlider(Float value, Float dflt, Float lo, Float hi, Float stepV)
	SetSliderDialogStartValue(value)
	SetSliderDialogDefaultValue(dflt)
	SetSliderDialogRange(lo, hi)
	SetSliderDialogInterval(stepV)
EndFunction

Function AddBuffRow(Actor a)
	AddTextOption("Attack", BuffState(a, Followers.BuffAttack), OPTION_FLAG_DISABLED)
	AddTextOption("Speed", BuffState(a, Followers.BuffSpeed), OPTION_FLAG_DISABLED)
	AddTextOption("Defense", BuffState(a, Followers.BuffDefense), OPTION_FLAG_DISABLED)
	AddTextOption("Regeneration", BuffState(a, Followers.BuffRegen), OPTION_FLAG_DISABLED)
EndFunction

String Function BuffState(Actor a, Spell s)
	If a && s && a.HasMagicEffect(s.GetNthEffectMagicEffect(0))
		Return "Active"
	EndIf
	Return "-"
EndFunction

; ---------------------------------------------------------------
; Stateless options (follower pages)
; ---------------------------------------------------------------
Event OnOptionMenuOpen(Int a_option)
	If a_option != oidPetMenu
		Return
	EndIf
	Int n = Followers.GetSlotLimit()
	String[] names = new String[50]
	Int[] slots = new Int[50]
	Int c = 0
	Int start = 0
	Int i = 0
	While i < n && c < 50
		Actor p = Followers.GetActorInSlot(i)
		If p
			If i == selSlot
				start = c
			EndIf
			names[c] = PetLabel(i, p)
			slots[c] = i
			c += 1
		EndIf
		i += 1
	EndWhile
	menuSlots = slots
	SetMenuDialogOptions(Utility.ResizeStringArray(names, c))
	SetMenuDialogStartIndex(start)
	SetMenuDialogDefaultIndex(start)
EndEvent

Event OnOptionMenuAccept(Int a_option, Int a_index)
	If a_option == oidPetMenu && a_index >= 0 && menuSlots
		selSlot = menuSlots[a_index]
		ForcePageReset()
	EndIf
EndEvent

Event OnOptionSelect(Int a_option)
	Int r = oidRowSelect.Find(a_option)
	If r > -1 && r < rowCount
		selSlot = rowSlot[r]
		ForcePageReset()
		Return
	EndIf
	r = oidSummon.Find(a_option)
	If r > -1 && r < rowCount
		DoSummon(rowSlot[r])
		Return
	EndIf
	r = oidGoTo.Find(a_option)
	If r > -1 && r < rowCount
		DoGoTo(rowSlot[r])
		Return
	EndIf
	If a_option == oidClearHistory
		If ShowMessage("Clear the companion history log?")
			Followers.ClearHistory()
			ForcePageReset()
		EndIf
		Return
	EndIf

	Actor a = Followers.GetActorInSlot(selSlot)
	If !a
		Return
	EndIf
	If a_option == oidFollow
		Followers.SetFollow(a, !a.IsPlayerTeammate())
		ForcePageReset()
	ElseIf a_option == oidWait
		Followers.SetWait(a, !Followers.IsActorWaiting(a))
		ForcePageReset()
	ElseIf a_option == oidSummonOne
		DoSummon(selSlot)
	ElseIf a_option == oidGoToOne
		DoGoTo(selSlot)
	ElseIf a_option == oidHomeSet
		Queue(selSlot, 2)
		ShowMessage(a.GetDisplayName() + " will make its home where it stands now (when you close the menu).", False)
	ElseIf a_option == oidHomeClear
		Queue(selSlot, 3)
		ShowMessage("The home of " + a.GetDisplayName() + " will be cleared when you close the menu.", False)
	ElseIf a_option == oidInventory
		Queue(selSlot, 6)
		ShowMessage("The inventory of " + a.GetDisplayName() + " opens when you close the menu.", False)
	ElseIf a_option == oidRelease
		If ShowMessage("Release " + a.GetDisplayName() + "? It becomes a wild creature again.")
			Followers.ReleasePet(a)
			selSlot = FirstUsedSlot()
			ForcePageReset()
		EndIf
	EndIf
EndEvent

Function DoSummon(Int slot)
	Actor a = Followers.GetActorInSlot(slot)
	If a
		Queue(slot, 1)
		ShowMessage(a.GetDisplayName() + " will come to you when you close the menu.", False)
	EndIf
EndFunction

Function DoGoTo(Int slot)
	Actor a = Followers.GetActorInSlot(slot)
	If a && ShowMessage("Travel to " + a.GetDisplayName() + " (" + Followers.GetActorLocationName(a) + ")?\nYou are moved when you close the menu.")
		pendingGoTo = a
		RegisterForSingleUpdate(0.5)
	EndIf
EndFunction

Event OnOptionHighlight(Int a_option)
	If a_option == oidPetMenu
		SetInfoText("Choose which companion to inspect.")
	ElseIf a_option == oidSummonOne || oidSummon.Find(a_option) > -1
		SetInfoText("Bring this companion to you (after the menu closes).")
	ElseIf a_option == oidGoToOne || oidGoTo.Find(a_option) > -1
		SetInfoText("Teleport yourself to this companion (after the menu closes).")
	ElseIf oidRowSelect.Find(a_option) > -1
		SetInfoText("Show this companion in the status panel.")
	ElseIf a_option == oidHomeSet
		SetInfoText("When not following, the companion stays around its current position.")
	ElseIf a_option == oidRelease
		SetInfoText("Release the companion and restore its original relationship and crime faction.")
	EndIf
EndEvent

Event OnUpdate()
	Int i = pendingCmd.Length
	While i
		i -= 1
		Int cmd = pendingCmd[i]
		If cmd != 0
			pendingCmd[i] = 0
			If cmd == 8
				Main.ResetPeaceAndGroup()
			ElseIf cmd == 7
				Main.ClearAllBuffs()
			ElseIf cmd == 4
				Followers.SummonAll(True)
			ElseIf cmd == 5
				Followers.SummonAll(False)
			Else
				Actor a = Followers.GetActorInSlot(i)
				If a
					If cmd == 1
						Followers.SummonPet(a)
					ElseIf cmd == 2
						Followers.SetHome(a, True)
					ElseIf cmd == 3
						Followers.SetHome(a, False)
					ElseIf cmd == 6
						a.OpenInventory(True)
					EndIf
				EndIf
			EndIf
		EndIf
	EndWhile
	If pendingGoTo
		Actor g = pendingGoTo
		pendingGoTo = None
		Followers.MovePlayerToPet(g)
	EndIf
EndEvent

; ---------------------------------------------------------------
; Settings page (V.1)
; ---------------------------------------------------------------
State ILC_ModEnabled
	Event OnSelectST()
		Main.SetModEnabled(!Main.ModEnabled)
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.SetModEnabled(True)
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("Enable or disable ILoveCreature.")
	EndEvent
EndState

State ILC_OpenKey
	Event OnKeyMapChangeST(Int keyCode, String conflictControl, String conflictName)
		If keyCode > 0 && conflictControl != ""
			String msg
			If conflictName != ""
				msg = "This key is already mapped to:\n'" + conflictControl + "'\n(" + conflictName + ")\n\nAre you sure you want to continue?"
			Else
				msg = "This key is already mapped to:\n'" + conflictControl + "'\n\nAre you sure you want to continue?"
			EndIf
			If !ShowMessage(msg, True, "$Yes", "$No")
				Return
			EndIf
		EndIf
		Main.SetOpenDialogueKey(keyCode)
		SetKeyMapOptionValueST(keyCode)
	EndEvent
	Event OnDefaultST()
		Main.SetOpenDialogueKey(37)
		SetKeyMapOptionValueST(37)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Look at a creature and press this key: it walks to you and opens dialogue (also your companions).")
	EndEvent
EndState

State ILC_OpenNow
	Event OnSelectST()
		Main.PendingOpenFromMenu = True
		SetTextOptionValueST("CLOSE MENU")
		ShowMessage("Close the menu.\nThe nearest creature will come to talk to you.", False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Test: after closing the menu, the nearest creature in this cell opens dialogue with you.")
	EndEvent
EndState

; ---------------------------------------------------------------
; Follower Settings page
; ---------------------------------------------------------------
State ILC_AllResume
	Event OnSelectST()
		Followers.SetAllWait(False)
		ShowMessage("Your waiting companions follow you again.", False)
	EndEvent
EndState

State ILC_AllWait
	Event OnSelectST()
		Followers.SetAllWait(True)
		ShowMessage("Your following companions wait here.", False)
	EndEvent
EndState

State ILC_SummonFollowers
	Event OnSelectST()
		Queue(126, 4)
		ShowMessage("Your following companions come to you when you close the menu.", False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Summon only the companions that currently follow you.")
	EndEvent
EndState

State ILC_SummonAll
	Event OnSelectST()
		Queue(127, 5)
		ShowMessage("All companions (also those at home) come to you when you close the menu.", False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Summon every companion, including those at home or not following.")
	EndEvent
EndState

State ILC_MarkFollower
	Event OnSelectST()
		Followers.MarkAsFollower = !Followers.MarkAsFollower
		SetToggleOptionValueST(Followers.MarkAsFollower)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Following companions join CurrentFollowerFaction, so SexLab Aroused Creatures treats them as followers (Follower Dialogue). Applies on the next Follow command.")
	EndEvent
EndState

State ILC_TeleportLoad
	Event OnSelectST()
		Followers.TeleportOnLoad = !Followers.TeleportOnLoad
		SetToggleOptionValueST(Followers.TeleportOnLoad)
	EndEvent
	Event OnHighlightST()
		SetInfoText("After a load screen (doors, fast travel) following companions that were left behind are moved to you.")
	EndEvent
EndState

State ILC_DoorOverride
	Event OnSelectST()
		If !Followers.DoorOverride && !ShowMessage("Let the races of your companions open doors? (changes race flags while companions of that race exist)")
			Return
		EndIf
		Followers.SetDoorOverride(!Followers.DoorOverride)
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("Companions walk through doors by themselves instead of being moved after the load screen.")
	EndEvent
EndState

State ILC_Debug
	Event OnSelectST()
		Followers.DebugLog = !Followers.DebugLog
		SetToggleOptionValueST(Followers.DebugLog)
	EndEvent
EndState

; ---------------------------------------------------------------
; Buffs page
; ---------------------------------------------------------------
State ILC_BuffFollower
	Event OnSelectST()
		Main.BuffFollower = !Main.BuffFollower
		SetToggleOptionValueST(Main.BuffFollower)
	EndEvent
	Event OnDefaultST()
		Main.BuffFollower = True
		SetToggleOptionValueST(True)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Mate rewards go to the creature (Group: every creature of the scene and your following companions nearby).")
	EndEvent
EndState

State ILC_BuffPlayer
	Event OnSelectST()
		Main.BuffPlayer = !Main.BuffPlayer
		SetToggleOptionValueST(Main.BuffPlayer)
	EndEvent
	Event OnDefaultST()
		Main.BuffPlayer = False
		SetToggleOptionValueST(False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("You receive the same mate rewards as your companion.")
	EndEvent
EndState

; reward rows: info text only (full dialogue line + full effect)
State ILC_RwJoin
	Event OnHighlightST()
		SetInfoText("\"I will make you happy.\" (creature that is not your companion yet) - it joins you, then " + Main.RewardName(Main.REWARD_HEAL) + ".")
	EndEvent
EndState
State ILC_RwHeal
	Event OnHighlightST()
		SetInfoText("\"I will heal you.\" - " + Main.RewardName(Main.REWARD_HEAL) + ".")
	EndEvent
EndState
State ILC_RwRough
	Event OnHighlightST()
		SetInfoText("\"Do what you will with me.\" - " + Main.RewardName(Main.REWARD_ATTACK) + ".")
	EndEvent
EndState
State ILC_RwDirty
	Event OnHighlightST()
		SetInfoText("\"Let's do something dirty.\" - " + Main.RewardName(Main.REWARD_SPEED) + ".")
	EndEvent
EndState
State ILC_RwBitch
	Event OnHighlightST()
		SetInfoText("\"Make me your bitch.\" - " + Main.RewardName(Main.REWARD_DEFENSE) + ".")
	EndEvent
EndState
State ILC_RwOral
	Event OnHighlightST()
		SetInfoText("\"I'll do something special for you.\" - " + Main.RewardName(Main.REWARD_REGEN) + ".")
	EndEvent
EndState
State ILC_RwGroup
	Event OnHighlightST()
		SetInfoText("\"Maybe we can find some friends.\" - the creature, its friends and your companions nearby get " + Main.RewardName(Main.REWARD_GROUP) + ".")
	EndEvent
EndState

State ILC_InMinutes
	Event OnInputOpenST()
		SetInputDialogStartText((Main.BuffMinutes as Int) as String)
	EndEvent
	Event OnInputAcceptST(String s)
		Float v = s as Float
		If v <= 0.0
			ShowMessage("Type a number of minutes from 1 to 60.", False)
			Return
		EndIf
		Main.SetBuffMinutes(v)
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.SetBuffMinutes(3.0)
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("Type how long every mate buff lasts: 1 - 60 minutes (real time). Values outside are clamped. Balanced: 3.")
	EndEvent
EndState

State ILC_SlAttack
	Event OnSliderOpenST()
		OpenSlider(Main.BuffAttackPct, 25.0, 5.0, 100.0, 5.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.BuffAttackPct = v
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.BuffAttackPct = 25.0
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("\"Do what you will with me.\" - extra damage for weapons / claws / bites AND damage spells. Balanced: 25%.")
	EndEvent
EndState

State ILC_SlSpeed
	Event OnSliderOpenST()
		OpenSlider(Main.SpeedValue(), 10.0, 5.0, 30.0, 5.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.BuffSpeedPct = v
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.BuffSpeedPct = 10.0
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("\"Let's do something dirty.\" - movement speed, max 30% (more makes followers overshoot and stutter). Balanced: 10%.")
	EndEvent
EndState

State ILC_SlDefense
	Event OnSliderOpenST()
		OpenSlider(Main.BuffDefensePct, 30.0, 5.0, 100.0, 5.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.BuffDefensePct = v
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.BuffDefensePct = 30.0
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("\"Make me your bitch.\" - extra armor (+% of current armor, at least 1.5 x this value in points). Balanced: 30%.")
	EndEvent
EndState

State ILC_SlRegen
	Event OnSliderOpenST()
		OpenSlider(Main.BuffRegenPct, 0.5, 0.1, 3.0, 0.1)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.BuffRegenPct = v
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.BuffRegenPct = 0.5
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("\"I'll do something special for you.\" - % of max health restored every second, also in combat. Balanced: 0.5% (90% over 3 minutes).")
	EndEvent
EndState

State ILC_BuffDefaults
	Event OnSelectST()
		Main.ResetBuffDefaults()
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("3 min, Attack +25% (weapons + magic), Speed +10%, Defense +30%, Regen 0.5%/s. Group gets all four.")
	EndEvent
EndState

State ILC_BuffDebug
	Event OnSelectST()
		Main.DebugMessages = !Main.DebugMessages
		SetToggleOptionValueST(Main.DebugMessages)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Shows [ILC] messages: scene started, scene end, reward given, and for every buff OK / applied directly / FAILED.")
	EndEvent
EndState

State ILC_BuffClear
	Event OnSelectST()
		Queue(125, 7)
		SetTextOptionValueST("CLOSE MENU")
		ShowMessage("All ILoveCreature buffs are removed from you and your companions when you close the menu. Values left behind by a lost effect are repaired.", False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Debug: remove every mate buff and repair attack / speed / armor values that may be stuck.")
	EndEvent
EndState

State ILC_ReleaseAll
	Event OnSelectST()
		If ShowMessage("Release ALL companions?")
			Followers.ReleaseAll()
			selSlot = -1
			ShowMessage("All companions were released.", False)
		EndIf
	EndEvent
	Event OnHighlightST()
		SetInfoText("Releases every companion and restores door flags. Do this before uninstalling.")
	EndEvent
EndState

; ---------------------------------------------------------------
; V.4 Peace options (shown on the Settings page since V.4.3): G key, peace spells, "I will make you all happy.", debug
; ---------------------------------------------------------------
; left column of "Settings" (under Global Settings)
Function PeaceLeft()
	ILC_Peace P = Main.Peace
	If !P
		Return
	EndIf
	AddEmptyOption()
	AddHeaderOption("Peace (I come in peace.)")
	AddKeyMapOptionST("ILC_PeaceKey", "Peace hotkey", P.PeaceKey, OPTION_FLAG_WITH_UNMAP + FlagIf(Main.ModEnabled))
	AddSliderOptionST("ILC_PeaceMinutes", "Peace duration", P.PeaceMinutes, "{0} min")
	AddSliderOptionST("ILC_PeaceRadius", "Hotkey area", P.PeaceRadius, "{0} units")
	AddEmptyOption()
	AddHeaderOption("Spells")
	AddTextOptionST("ILC_InfoPeaceSpell", "Creature Peace", "Calm")
	AddTextOptionST("ILC_InfoCallSpell", "Creature Call", "Calm + talk")
	AddTextOptionST("ILC_PeaceSpellsAdd", "Learn the spells again", "ADD")
EndFunction

; right column of "Settings" (under Creature Dialogue)
Function PeaceRight()
	ILC_Peace P = Main.Peace
	If !P
		AddEmptyOption()
		AddHeaderOption("Peace system is not running")
		Return
	EndIf
	AddEmptyOption()
	AddHeaderOption("Group (you all happy)")
	AddSliderOptionST("ILC_MaxExtra", "Max extra creatures", P.MaxExtra, "{0}")
	If P.RandomExtra
		AddTextOptionST("ILC_ExtraMode", "Extra mode", "Random 2-" + P.MaxExtra)
	Else
		AddTextOptionST("ILC_ExtraMode", "Extra mode", "Stable " + P.MaxExtra)
	EndIf
	AddEmptyOption()
	AddHeaderOption("Debug")
	AddToggleOptionST("ILC_PeaceDebug", "Show debug messages", Main.DebugMessages)
	AddTextOption("Peaceful creatures now", P.PeacefulCount(), OPTION_FLAG_DISABLED)
	AddTextOption("Group queue", Main.ChainStatus(), OPTION_FLAG_DISABLED)
	AddTextOptionST("ILC_PeaceReset", "Reset peace + group (fix stuck)", "RESET")
EndFunction

State ILC_PeaceKey
	Event OnKeyMapChangeST(Int keyCode, String conflictControl, String conflictName)
		If keyCode > 0 && conflictControl != ""
			String msg
			If conflictName != ""
				msg = "This key is already mapped to:\n'" + conflictControl + "'\n(" + conflictName + ")\n\nAre you sure you want to continue?"
			Else
				msg = "This key is already mapped to:\n'" + conflictControl + "'\n\nAre you sure you want to continue?"
			EndIf
			If !ShowMessage(msg, True, "$Yes", "$No")
				Return
			EndIf
		EndIf
		If keyCode > 0 && keyCode == Main.OpenDialogueKey
			ShowMessage("This is already the Open Dialogue hotkey.", False)
			Return
		EndIf
		Main.Peace.PeaceKey = keyCode
		Main.Maintenance()
		SetKeyMapOptionValueST(keyCode)
	EndEvent
	Event OnDefaultST()
		Main.Peace.PeaceKey = 34
		Main.Maintenance()
		SetKeyMapOptionValueST(34)
	EndEvent
	Event OnHighlightST()
		SetInfoText("You say \"I come in peace.\": every creature around you stops fighting you, then the creature you look at (or the nearest) comes to talk. Extra line: \"I will make you all happy.\" Default: G.")
	EndEvent
EndState

State ILC_PeaceMinutes
	Event OnSliderOpenST()
		OpenSlider(Main.Peace.PeaceMinutes, 5.0, 1.0, 30.0, 1.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.Peace.PeaceMinutes = v
		Main.Peace.ApplyDuration()
		SetSliderOptionValueST(v, "{0} min")
	EndEvent
	Event OnDefaultST()
		Main.Peace.PeaceMinutes = 5.0
		Main.Peace.ApplyDuration()
		SetSliderOptionValueST(5.0, "{0} min")
	EndEvent
	Event OnHighlightST()
		SetInfoText("How long a creature stays peaceful (Creature Peace, Creature Call and the hotkey). Real minutes. Default: 5.")
	EndEvent
EndState

State ILC_PeaceRadius
	Event OnSliderOpenST()
		OpenSlider(Main.Peace.PeaceRadius, 2500.0, 500.0, 6000.0, 250.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.Peace.PeaceRadius = v
		SetSliderOptionValueST(v, "{0} units")
	EndEvent
	Event OnDefaultST()
		Main.Peace.PeaceRadius = 2500.0
		SetSliderOptionValueST(2500.0, "{0} units")
	EndEvent
	Event OnHighlightST()
		SetInfoText("Radius of the peace hotkey around you. 2500 units ~ 35 m. Default: 2500.")
	EndEvent
EndState

State ILC_InfoPeaceSpell
	Event OnHighlightST()
		SetInfoText("Creature Peace (aimed): the creature stops fighting you and your companions for the peace duration. No dialogue.")
	EndEvent
EndState

State ILC_InfoCallSpell
	Event OnHighlightST()
		SetInfoText("Creature Call (aimed): peace + the creature comes to talk. You see the normal dialogue of every mod, \"I will make you happy.\" is added at the end.")
	EndEvent
EndState

State ILC_PeaceSpellsAdd
	Event OnSelectST()
		Main.Peace.Maintenance()
		ShowMessage("Creature Peace and Creature Call are in your spell list.", False)
	EndEvent
EndState

State ILC_MaxExtra
	Event OnSliderOpenST()
		OpenSlider(Main.Peace.MaxExtra, 3.0, 2.0, 5.0, 1.0)
	EndEvent
	Event OnSliderAcceptST(Float v)
		Main.Peace.MaxExtra = v as Int
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.Peace.MaxExtra = 3
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("\"I will make you all happy.\": how many creatures join besides the one you talk to (2 - 5). All of them become your companions after their scene. SexLab allows 4 creatures per scene - the rest get the next scene. Default: 3.")
	EndEvent
EndState

State ILC_ExtraMode
	Event OnSelectST()
		Main.Peace.RandomExtra = !Main.Peace.RandomExtra
		ForcePageReset()
	EndEvent
	Event OnDefaultST()
		Main.Peace.RandomExtra = False
		ForcePageReset()
	EndEvent
	Event OnHighlightST()
		SetInfoText("Stable: always Max extra creatures (if that many are nearby). Random: a random number from 2 to Max extra every time.")
	EndEvent
EndState

State ILC_PeaceDebug
	Event OnSelectST()
		Main.DebugMessages = !Main.DebugMessages
		SetToggleOptionValueST(Main.DebugMessages)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Shows [ILC] messages: peace start / end per creature, hotkey scan, group queue steps (also the Buffs debug). Always written to Papyrus.0.log.")
	EndEvent
EndState

State ILC_PeaceReset
	Event OnSelectST()
		Queue(124, 8)
		SetTextOptionValueST("CLOSE MENU")
		ShowMessage("When you close the menu: the group queue stops, the creature dialogue is cleared and every peaceful creature gets its original aggression and factions back.", False)
	EndEvent
	Event OnHighlightST()
		SetInfoText("Debug: use this if a creature stays friendly, the group scenes do not continue, or the hotkey stops working.")
	EndEvent
EndState
