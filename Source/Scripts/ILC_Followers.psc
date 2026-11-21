Scriptname ILC_Followers extends Quest
{ILoveCreature V.2 - creature follower controller (merged from Animal Followers).
Quest ILC_FollowerQuest, priority 40 (lower than ILC/SLAC dialogue quests, so their
ForceGreet packages always win over the pet Follow/Home/Sandbox packages).
Alias ids: pets 0..49, home markers 100..149.}

; ---------------------------------------------------------------- properties
Actor Property PlayerRef Auto
Faction Property PetFaction Auto            ; ILC_PetFaction
Faction Property PetHasHomeFaction Auto     ; ILC_PetHasHome     (package condition)
Faction Property PetWaitingFaction Auto     ; ILC_PetWaiting     (dialogue condition)
Faction Property AllyFaction Auto           ; Skyrim DunPlayerAllyFaction
Faction Property CurrentFollowerFaction Auto ; Skyrim CurrentFollowerFaction (SLAC follower dialogue)
Static Property XMarker Auto                ; Skyrim XMarker (home markers)
ILC_Main Property Main Auto                 ; ILC_DialogueQuest (E on a pet opens its dialogue)
Spell Property CommandPower Auto            ; ILC_PowerCommands (Z power: follow / wait / summon)
Spell Property TameSpell Auto               ; ILC_TameSpell "Creature Bond" (V.3)
GlobalVariable Property gDialogueCommands Auto  ; ILC_DialogueCommands: 1 = K (pet commands shown), 0 = Talk
; V.3.5 companion buffs (60 s, MGEF script ILC_BuffEffect) - used by ILC_Main.GiveReward
Spell Property BuffAttack Auto
Spell Property BuffSpeed Auto
Spell Property BuffDefense Auto
Spell Property BuffRegen Auto

; E-menu on a companion (message box like Animal Followers)
Message Property PetMenu Auto               ; ILC_PetMenu
Message Property ReleaseConfirm Auto        ; ILC_PetReleaseConfirm
GlobalVariable Property gMsgFollow Auto     ; button conditions
GlobalVariable Property gMsgWait Auto
GlobalVariable Property gMsgHome Auto
GlobalVariable Property gMsgHorse Auto
Keyword Property ActorTypeHorse Auto
int Property MenuAliasId = 200 AutoReadOnly ; alias "MenuPet" (name shown in the menu text)
bool _menuOpen = false

; settings (MCM)
bool Property MarkAsFollower = true Auto Hidden     ; add following pets to CurrentFollowerFaction
bool Property TeleportOnLoad = true Auto Hidden     ; following pets catch up after a load screen
bool Property DoorOverride = false Auto Hidden      ; clear CantOpenDoors on pet races (SKSE)
bool Property DebugLog = false Auto Hidden

int Property HomeAliasBase = 100 AutoReadOnly
int Property SlotLimit = 50 AutoReadOnly

; ---------------------------------------------------------------- state
Actor[] tracked
ObjectReference[] homeMarkers
int actorCount = 0
bool initialized = false
bool _lock = false
int currentVersion = 0

; per-slot restore data
int[] dRelAP
int[] dRelPA
float[] dAggression
Faction[] dCrimeFaction
bool[] dStolen
bool[] dActBlocked       ; v2: activation state before taming
Form[] raceOverrides     ; races whose CantOpenDoors flag we cleared
int raceOverrideCount = 0

; Nether's Follower Framework (soft dependency, resolved on every load)
Quest nffController       ; nwsFollowerFramework.esp:00434F nwsFollowerController
MiscObject nffToken       ; nwsFollowerFramework.esp:1CFC8D nwsIgnoreToken (NFF auto-import skips actors carrying it)

; history ring buffer
string[] histText
int histHead = 0
int histCount = 0

import Utility

; ---------------------------------------------------------------- basics
function dtrace(string s)
	if DebugLog
		Debug.Trace("[ILoveCreature/Followers] " + s)
	endif
endfunction

function Lock()
	while _lock
		Wait(0.1)
	endwhile
	_lock = true
endfunction

function Unlock()
	_lock = false
endfunction

event OnInit()
	DoUpdate()
endevent

; called from OnInit and on every game load (ILC_Main.Maintenance)
function DoUpdate()
	if currentVersion < 1
		tracked = new Actor[50]
		homeMarkers = new ObjectReference[50]
		dRelAP = new int[50]
		dRelPA = new int[50]
		dAggression = new float[50]
		dCrimeFaction = new Faction[50]
		dStolen = new bool[50]
		raceOverrides = new Form[64]
		histText = new string[32]
		actorCount = 0
		currentVersion = 1
		initialized = true
	endif
	if !initialized
		return
	endif
	if currentVersion < 2
		; V.2.1: pets talk on Activate (E) -> block default activation of existing pets
		dActBlocked = new bool[50]
		int i = SlotLimit
		while i
			i -= 1
			if tracked[i]
				dActBlocked[i] = tracked[i].IsActivationBlocked()
				tracked[i].BlockActivation(true)
			endif
		endwhile
		currentVersion = 2
	endif
	if CommandPower && !PlayerRef.HasSpell(CommandPower)
		PlayerRef.AddSpell(CommandPower, false)
	endif
	if TameSpell && !PlayerRef.HasSpell(TameSpell)
		PlayerRef.AddSpell(TameSpell, true)
	endif
	ReApplyDoorOverrides()
	NFFMaintenance()
	RegisterForMenu("Loading Menu")
	dtrace("maintenance done, pets: " + actorCount)
endfunction

bool function IsInitialized()
	return initialized
endfunction

ReferenceAlias function PetAlias(int slot)
	return GetAlias(slot) as ReferenceAlias
endfunction

ReferenceAlias function HomeAlias(int slot)
	return GetAlias(HomeAliasBase + slot) as ReferenceAlias
endfunction

; ---------------------------------------------------------------- queries (dialogue / MCM)
int function GetSlotLimit()
	return SlotLimit
endfunction

int function GetActorCount()
	return actorCount
endfunction

Actor function GetActorInSlot(int slot)
	if !initialized || slot < 0 || slot >= SlotLimit
		return none
	endif
	return tracked[slot]
endfunction

int function GetActorSlot(Actor a)
	if !initialized || !a
		return -1
	endif
	return tracked.Find(a)
endfunction

bool function IsPet(Actor a)
	return GetActorSlot(a) > -1
endfunction

bool function HasHome(Actor a)
	return a.IsInFaction(PetHasHomeFaction)
endfunction

bool function IsActorWaiting(Actor a)
	return a.GetActorValue("WaitingForPlayer") > 0.0
endfunction

bool function IsActorStolen(Actor a)
	int s = GetActorSlot(a)
	return s > -1 && dStolen[s]
endfunction

string function GetActorStatus(Actor a)
	if !a
		return "Empty"
	elseif a.IsDead()
		return "Dead"
	elseif a.IsInCombat()
		return "In combat"
	elseif a.IsPlayerTeammate()
		if IsActorWaiting(a)
			return "Waiting"
		endif
		return "Following"
	elseif HasHome(a)
		return "At home"
	endif
	return "Idle"
endfunction

string function GetActorLocationName(Actor a)
	if !a
		return ""
	endif
	Location loc = a.GetCurrentLocation()
	if loc && loc.GetName() != ""
		return loc.GetName()
	endif
	Cell c = a.GetParentCell()
	if c && c.GetName() != ""
		return c.GetName()
	endif
	WorldSpace ws = a.GetWorldSpace()
	if ws && ws.GetName() != ""
		return ws.GetName()
	endif
	return "Unknown"
endfunction

; ---------------------------------------------------------------- tame / release
; returns slot, -2 already a pet, -3 no free slot, -1 not running
int function TamePet(Actor a)
	if !initialized || !a || a.IsDead()
		return -1
	endif
	Lock()
	if tracked.Find(a) > -1
		Unlock()
		return -2
	endif
	int slot = tracked.Find(none)
	if slot < 0
		Unlock()
		return -3
	endif

	bool stolen = IsOwnedByOther(a)

	a.StopCombat()
	a.StopCombatAlarm()
	dCrimeFaction[slot] = a.GetCrimeFaction()
	dRelAP[slot] = a.GetRelationshipRank(PlayerRef)
	dRelPA[slot] = PlayerRef.GetRelationshipRank(a)
	dAggression[slot] = a.GetActorValue("Aggression")
	dStolen[slot] = stolen
	dActBlocked[slot] = a.IsActivationBlocked()

	a.SetCrimeFaction(none)
	a.AddToFaction(PetFaction)
	a.AddToFaction(AllyFaction)
	a.SetRelationshipRank(PlayerRef, 3)
	PlayerRef.SetRelationshipRank(a, 3)
	a.SetActorValue("Aggression", 0.0)
	a.SetActorValue("WaitingForPlayer", 0.0)
	a.BlockActivation(true)
	NFFIgnore(a, true)              ; before SetPlayerTeammate, or NFF auto-imports it into its own slots

	tracked[slot] = a
	actorCount += 1
	PetAlias(slot).ForceRefTo(a)
	if DoorOverride
		ClearDoorFlag(a.GetRace())
	endif
	_SetFollow(a, true)
	AddHistory(a, "Tamed", slot)
	Unlock()

	if stolen
		a.SendStealAlarm(PlayerRef)
	endif
	dtrace("tamed " + a + " slot " + slot)
	return slot
endfunction

; TamePet + notification + make sure it really stops fighting (spell / dialogue / Mate)
int function TameWithMessage(Actor a)
	if Main && Main.Peace
		Main.Peace.RestorePeace(a)    ; V.4: give back the real aggression / faction before taming stores them
	endif
	int r = TamePet(a)
	if r > -1
		a.StopCombat()
		a.StopCombatAlarm()
		Debug.Notification(a.GetDisplayName() + " is now your companion")
	elseif r == -2
		Debug.Notification(a.GetDisplayName() + " is already your companion")
	elseif r == -3
		Debug.Notification("You can't have more companions (max " + SlotLimit + ")")
	endif
	return r
endfunction

bool function IsOwnedByOther(Actor a)
	ActorBase owner = a.GetActorOwner()
	if owner && owner != PlayerRef.GetActorBase()
		return true
	endif
	Faction fo = a.GetFactionOwner()
	return fo && fo.GetFormID() != 0x00000DB1
endfunction

bool function ReleasePet(Actor a, string reason = "Released")
	if !initialized || !a
		return false
	endif
	Lock()
	int slot = tracked.Find(a)
	if slot < 0
		Unlock()
		return false
	endif
	AddHistory(a, reason, slot)
	_Cleanup(a, slot)
	tracked[slot] = none
	actorCount -= 1
	Unlock()
	if DoorOverride
		RestoreDoorFlagIfUnused(a.GetRace())
	endif
	return true
endfunction

; ---------------------------------------------------------------- V.5 MCM "Follower Status" -> Edit
; Health / Stamina / Magicka / Confidence / Assistance: the first edit remembers the original value,
; Reset or Release gives it back. Aggression is restored by _Cleanup (dAggression) anyway.
function EditStat(Actor a, string av, float value)
	if !a
		return
	endif
	string k = "ILC.Orig." + av
	if av != "Aggression" && !StorageUtil.HasFloatValue(a, k)
		StorageUtil.SetFloatValue(a, k, a.GetBaseActorValue(av))
	endif
	a.SetActorValue(av, value)
	if av == "Aggression" || av == "Confidence" || av == "Assistance"
		a.EvaluatePackage()
	endif
	dtrace("edit " + a + " " + av + " = " + value)
endfunction

bool function HasEditedStats(Actor a)
	return a && (StorageUtil.HasFloatValue(a, "ILC.Orig.Health") || StorageUtil.HasFloatValue(a, "ILC.Orig.Stamina") \
		|| StorageUtil.HasFloatValue(a, "ILC.Orig.Magicka") || StorageUtil.HasFloatValue(a, "ILC.Orig.Confidence") \
		|| StorageUtil.HasFloatValue(a, "ILC.Orig.Assistance"))
endfunction

function RestoreStats(Actor a)
	if !a
		return
	endif
	RestoreStat(a, "Health")
	RestoreStat(a, "Stamina")
	RestoreStat(a, "Magicka")
	RestoreStat(a, "Confidence")
	RestoreStat(a, "Assistance")
endfunction

function RestoreStat(Actor a, string av)
	string k = "ILC.Orig." + av
	if StorageUtil.HasFloatValue(a, k)
		a.SetActorValue(av, StorageUtil.GetFloatValue(a, k))
		StorageUtil.UnsetFloatValue(a, k)
	endif
endfunction

function _Cleanup(Actor a, int slot)
	RestoreStats(a)                 ; V.5 values edited in the MCM go back to the original
	NFFRemove(a)                    ; free a NFF slot if NFF grabbed it (before we restore aggression etc.)
	NFFIgnore(a, false)
	a.SetPlayerTeammate(false, false)
	a.SetActorValue("WaitingForPlayer", 0.0)
	a.RemoveFromFaction(PetFaction)
	a.RemoveFromFaction(PetWaitingFaction)
	a.RemoveFromFaction(PetHasHomeFaction)
	a.RemoveFromFaction(CurrentFollowerFaction)
	a.RemoveFromFaction(AllyFaction)
	a.SetCrimeFaction(dCrimeFaction[slot])
	if !a.IsDead()
		a.SetRelationshipRank(PlayerRef, dRelAP[slot])
		PlayerRef.SetRelationshipRank(a, dRelPA[slot])
		a.SetActorValue("Aggression", dAggression[slot])
	endif
	dStolen[slot] = false
	a.BlockActivation(dActBlocked[slot])
	HomeAlias(slot).Clear()
	PetAlias(slot).Clear()
	a.EvaluatePackage()
endfunction

; ---------------------------------------------------------------- E menu
; "Command Creature" buttons (V.3, max 10 in a message box):
;   0 Follow, 1 Mate, 2 Wait, 3 Let's go, 4 Dismiss, 5 Make your home here, 6 Ride, 7 Release, 8 Talk, 9 Cancel
; ("Forget your home" is in the K dialogue and the MCM)
function OpenPetMenu(Actor a)
	if _menuOpen || !IsPet(a)
		return
	endif
	_menuOpen = true
	gMsgFollow.SetValueInt(a.IsPlayerTeammate() as int)
	gMsgWait.SetValueInt(IsActorWaiting(a) as int)
	gMsgHome.SetValueInt(HasHome(a) as int)
	gMsgHorse.SetValueInt(a.HasKeyword(ActorTypeHorse) as int)
	ReferenceAlias menuAlias = GetAlias(MenuAliasId) as ReferenceAlias
	menuAlias.ForceRefTo(a)

	int b = PetMenu.Show()
	menuAlias.Clear()
	_menuOpen = false
	if b == 0
		SetFollow(a, true)
	elseif b == 1
		Main.OpenMateDialogue(a)           ; dialogue with the 7 mate choices
	elseif b == 2
		SetWait(a, true)
	elseif b == 3
		SetWait(a, false)
	elseif b == 4
		SetFollow(a, false)                ; Dismiss = stop following (goes home / idles)
	elseif b == 5
		SetHome(a, true)
		Debug.Notification(a.GetDisplayName() + " will live here when it is not following you")
	elseif b == 6
		a.Activate(PlayerRef, true)      ; default activation = mount
	elseif b == 7
		menuAlias.ForceRefTo(a)
		if ReleaseConfirm.Show() == 0
			if ReleasePet(a)
				Debug.Notification(a.GetDisplayName() + " is free again")
			endif
		endif
		menuAlias.Clear()
	elseif b == 8
		Main.TryOpenDialogue(a, false)     ; Talk = plain greeting, no pet commands
	endif
endfunction

; ---------------------------------------------------------------- commands
function SetFollow(Actor a, bool follow)
	if IsPet(a)
		Lock()
		_SetFollow(a, follow)
		Unlock()
	endif
endfunction

function _SetFollow(Actor a, bool follow)
	a.SetActorValue("WaitingForPlayer", 0.0)
	a.RemoveFromFaction(PetWaitingFaction)
	a.SetPlayerTeammate(follow, false)
	if follow && MarkAsFollower
		a.AddToFaction(CurrentFollowerFaction)
		a.SetFactionRank(CurrentFollowerFaction, 0)
	else
		a.RemoveFromFaction(CurrentFollowerFaction)
	endif
	a.EvaluatePackage()
endfunction

function SetWait(Actor a, bool wait)
	if !IsPet(a)
		return
	endif
	if wait
		a.SetActorValue("WaitingForPlayer", 1.0)
		a.AddToFaction(PetWaitingFaction)
	else
		a.SetActorValue("WaitingForPlayer", 0.0)
		a.RemoveFromFaction(PetWaitingFaction)
	endif
	a.EvaluatePackage()
endfunction

function SetAllWait(bool wait)
	int i = SlotLimit
	while i
		i -= 1
		Actor a = tracked[i]
		if a && a.IsPlayerTeammate()
			SetWait(a, wait)
		endif
	endwhile
endfunction

bool function SetHome(Actor a, bool setHome)
	int slot = GetActorSlot(a)
	if slot < 0
		return false
	endif
	if setHome
		ObjectReference m = homeMarkers[slot]
		if !m
			m = a.PlaceAtMe(XMarker, 1, true)
			homeMarkers[slot] = m
		else
			m.MoveTo(a)
		endif
		HomeAlias(slot).ForceRefTo(m)
		a.AddToFaction(PetHasHomeFaction)
	else
		HomeAlias(slot).Clear()
		a.RemoveFromFaction(PetHasHomeFaction)
	endif
	a.EvaluatePackage()
	return true
endfunction

bool function SummonPet(Actor a)
	if !IsPet(a) || a.IsDead()
		return false
	endif
	a.StopCombat()
	a.StopCombatAlarm()
	a.MoveTo(PlayerRef, RandomFloat(-120.0, 120.0), RandomFloat(-150.0, -100.0), 0.0)
	a.EvaluatePackage()
	return true
endfunction

bool function MovePlayerToPet(Actor a)
	if !IsPet(a)
		return false
	endif
	PlayerRef.MoveTo(a, 0.0, -120.0, 0.0)
	return true
endfunction

; followersOnly = true -> only pets that follow you (Summon followers)
int function SummonAll(bool followersOnly)
	int c = 0
	int i = 0
	while i < SlotLimit
		Actor a = tracked[i]
		if a && !a.IsDead() && (!followersOnly || a.IsPlayerTeammate())
			SummonPet(a)
			c += 1
		endif
		i += 1
	endwhile
	return c
endfunction

; ---------------------------------------------------------------- load screen catch-up
event OnMenuClose(string menuName)
	if menuName != "Loading Menu" || !initialized || !TeleportOnLoad || DoorOverride
		return
	endif
	Cell pc = PlayerRef.GetParentCell()
	int i = 0
	while i < SlotLimit
		Actor a = tracked[i]
		if a && !a.IsDead() && a.IsPlayerTeammate() && !IsActorWaiting(a)
			if a.GetParentCell() != pc && (!a.Is3DLoaded() || a.GetDistance(PlayerRef) > 3000.0)
				a.StopCombat()
				a.MoveTo(PlayerRef, RandomFloat(-100.0, 100.0), RandomFloat(-150.0, -100.0), 0.0)
			endif
		endif
		i += 1
	endwhile
endevent

; ---------------------------------------------------------------- door override (SKSE race flags)
function SetDoorOverride(bool on)
	DoorOverride = on
	if on
		int i = SlotLimit
		while i
			i -= 1
			if tracked[i]
				ClearDoorFlag(tracked[i].GetRace())
			endif
		endwhile
	else
		while raceOverrideCount
			raceOverrideCount -= 1
			Race r = raceOverrides[raceOverrideCount] as Race
			if r
				r.SetRaceFlag(r.kRace_CantOpenDoors)
			endif
			raceOverrides[raceOverrideCount] = none
		endwhile
	endif
endfunction

function ClearDoorFlag(Race r)
	if r && r.IsRaceFlagSet(r.kRace_CantOpenDoors) && raceOverrides.Find(r) < 0 && raceOverrideCount < 64
		r.ClearRaceFlag(r.kRace_CantOpenDoors)
		raceOverrides[raceOverrideCount] = r
		raceOverrideCount += 1
	endif
endfunction

function RestoreDoorFlagIfUnused(Race r)
	int idx = raceOverrides.Find(r)
	if idx < 0
		return
	endif
	int i = SlotLimit
	while i
		i -= 1
		if tracked[i] && tracked[i].GetRace() == r
			return
		endif
	endwhile
	r.SetRaceFlag(r.kRace_CantOpenDoors)
	raceOverrideCount -= 1
	raceOverrides[idx] = raceOverrides[raceOverrideCount]
	raceOverrides[raceOverrideCount] = none
endfunction

; race flags are not saved by the game -> re-apply on every load
function ReApplyDoorOverrides()
	int i = raceOverrideCount
	while i
		i -= 1
		Race r = raceOverrides[i] as Race
		if r
			r.ClearRaceFlag(r.kRace_CantOpenDoors)
		endif
	endwhile
endfunction

; ---------------------------------------------------------------- Nether's Follower Framework
; NFF's auto-import quest takes every actor with GetPlayerTeammate == 1 unless it carries nwsIgnoreToken.
; Our pets get the token; pets NFF already grabbed (older saves) are taken out of its slots on load.
function NFFMaintenance()
	nffController = none
	nffToken = none
	if Game.GetModByName("nwsFollowerFramework.esp") == 255
		return
	endif
	nffController = Game.GetFormFromFile(0x00434F, "nwsFollowerFramework.esp") as Quest
	nffToken = Game.GetFormFromFile(0x1CFC8D, "nwsFollowerFramework.esp") as MiscObject
	if !nffToken
		return
	endif
	int i = SlotLimit
	while i
		i -= 1
		Actor a = tracked[i]
		if a && !a.IsDead() && a.GetItemCount(nffToken) == 0
			NFFIgnore(a, true)
			NFFDetach(a)
		endif
	endwhile
endfunction

function NFFIgnore(Actor a, bool ignore)
	if !nffToken || !a
		return
	endif
	if ignore
		if a.GetItemCount(nffToken) == 0
			a.AddItem(nffToken, 1, true)
		endif
	else
		a.RemoveItem(nffToken, a.GetItemCount(nffToken), true)
	endif
endfunction

; NFF RemoveFollower(actor, iMessage -1 = no message, iSayLine 0 = right now). No-op if the actor is not in a NFF slot.
function NFFRemove(Actor a)
	nwsFollowerControllerScript nff = nffController as nwsFollowerControllerScript
	if nff && a
		nff.RemoveFollower(a, -1, 0)
	endif
endfunction

; take a pet out of NFF but keep it as OUR companion (NFF dismissal clears teammate/waiting)
function NFFDetach(Actor a)
	bool wasFollowing = a.IsPlayerTeammate()
	bool wasWaiting = IsActorWaiting(a)
	NFFRemove(a)
	a.SetActorValue("Aggression", 0.0)
	_SetFollow(a, wasFollowing)
	if wasFollowing && wasWaiting
		SetWait(a, true)
	endif
	dtrace("detached from NFF: " + a)
endfunction

; ---------------------------------------------------------------- uninstall
function ReleaseAll()
	int i = SlotLimit
	while i
		i -= 1
		if tracked[i]
			ReleasePet(tracked[i], "Released (uninstall)")
		endif
	endwhile
	SetDoorOverride(false)
	if CommandPower
		PlayerRef.RemoveSpell(CommandPower)
	endif
	if TameSpell
		PlayerRef.RemoveSpell(TameSpell)
	endif
endfunction

; ---------------------------------------------------------------- history
function AddHistory(Actor a, string what, int slot)
	string nm = "?"
	if a
		nm = a.GetDisplayName()
	endif
	string line = "Day " + (GetCurrentGameTime() as int) + "  #" + (slot + 1) + " " + nm + ": " + what
	if a
		line += " (" + GetActorLocationName(a) + ")"
	endif
	histText[histHead] = line
	histHead = (histHead + 1) % 32
	if histCount < 32
		histCount += 1
	endif
endfunction

int function GetHistoryCount()
	return histCount
endfunction

string function GetHistoryEntry(int n)   ; 0 = newest
	if n < 0 || n >= histCount
		return ""
	endif
	return histText[(histHead - 1 - n + 32) % 32]
endfunction

function ClearHistory()
	histText = new string[32]
	histHead = 0
	histCount = 0
endfunction
