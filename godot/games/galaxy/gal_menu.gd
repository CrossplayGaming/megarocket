# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_us_2.c (the control-panel card system) and
# ck_us_2.c (the Galaxy menus it #includes), by David Gow and the Omnispeak
# authors, GPL v2 or later. Names, order and arithmetic follow omnispeak
# upstream (A10).
class_name GalMenu
extends GalGame
## The control panel (SIM-G-01i): the stack of cards, their items and
## callbacks, the main menu, new game, load and save, configure (sound, music,
## options, keyboard), paddle war and the dialogs. GalUS's US_RunCards and
## US_DrawCards stand-ins are replaced here.
##
## The vanilla build (CK_VANILLA): no QUICKSAVE_ENABLED, EXTRA_GRAPHICS_OPTIONS,
## EXTRA_KEYBOARD_OPTIONS or EXTRA_JOYSTICK_OPTIONS code, no scrolling cards,
## and the menu colours are #defines. id_us_2.c #includes ck_us_2.c after its
## first forward declarations, so ck_us_2.c's part comes first here, then the
## rest of id_us_2.c.
##
## Structs: a US_CardItem and a US_Card are inner classes; a card's `items`
## keeps C's terminating US_ITEM_None entry, and an empty array is C's NULL
## items pointer. A caption or gfxChunk of "" is C's NULL. The pointer
## arithmetic `item - array` is the item's place in the array (Array.find, by
## identity). Callbacks are method names called with call() (&"" for NULL).

# ===================================================================== id_us.h (ID_US_2)

## Colours (CK_VANILLA: #defines)
const us_menu_backgroundColour: int = 8
const us_menu_foregroundColour: int = 10
const us_menu_disabledColour: int = 2

# US_CardMsg: messages passed to the callback.
const US_MSG_CardEntered: int = 0    # The card has become the active card
const US_MSG_Draw: int = 1           # Allows the callback to draw the card
const US_MSG_PostDraw: int = 2       # Called after the card is drawn, for overlays
const US_MSG_DrawItemIcon: int = 3   # Draws the icon of a single CardItem
const US_MSG_DrawItem: int = 4       # Draws an item
const US_MSG_ItemEntered: int = 5    # An item was triggered

# US_CardItemType
const US_ITEM_None: int = 0      # An empty CardItem to end the list
const US_ITEM_Normal: int = 1    # A normal item
const US_ITEM_Radio: int = 2     # A 'radio' item, only one can be selected in a given card
const US_ITEM_Submenu: int = 3   # The item triggers a submenu when activated

# US_CardItemState flags
const US_IS_Checked: int = 0x01
const US_IS_Selected: int = 0x02
const US_IS_Disabled: int = 0x04
const US_IS_Gap: int = 0x08
const US_IS_Hidden: int = 0x10    # Used for scrolling

# (US_CardCommand: US_Comm_None ... US_Comm_NewHardGame are gal_us.gd's)


class US_CardItem:
	var type: int = 0            # US_CardItemType
	var state: int = 0           # US_CardItemState (uint16_t)
	var shortcutKey: int = 0     # IN_ScanCode
	var caption: String = ""     # "" for NULL
	var command: int = 0         # US_CardCommand
	var subMenu: US_Card = null
	var x: int = 0
	var y: int = 0

	func copy_from(o: US_CardItem) -> void:
		type = o.type
		state = o.state
		shortcutKey = o.shortcutKey
		caption = o.caption
		command = o.command
		subMenu = o.subMenu
		x = o.x
		y = o.y


class US_Card:
	var x: int = 0
	var y: int = 0
	var gfxChunk: String = ""        # chunk_id_t: the chunk's name ("" for NULL); CK_LookupChunk gives the number
	var unknown: int = 0             # An unknown int
	var items: Array = []            # US_CardItem, ending with a US_ITEM_None entry; [] for NULL
	var msgCallback: StringName = &""    # US_CardCallbackFunc
	var selectedItem: int = 0        # Index of selected item.
	var unk1: int = 0
	var unk2: int = 0

	func copy_from(o: US_Card) -> void:
		x = o.x
		y = o.y
		gfxChunk = o.gfxChunk
		unknown = o.unknown
		items = o.items
		msgCallback = o.msgCallback
		selectedItem = o.selectedItem
		unk1 = o.unk1
		unk2 = o.unk2


## A US_CardItem initialiser: {type, state, shortcutKey, caption, command, subMenu, x, y}.
static func _us_item(type: int, state: int, shortcutKey: int, caption: String, command: int, subMenu: US_Card) -> US_CardItem:
	var item: US_CardItem = US_CardItem.new()
	item.type = type
	item.state = state
	item.shortcutKey = shortcutKey
	item.caption = caption
	item.command = command
	item.subMenu = subMenu
	item.x = 0
	item.y = 0
	return item


## The terminating {US_ITEM_None, 0, IN_SC_None, NULL, US_Comm_None, NULL, 0, 0}.
static func _us_item_end() -> US_CardItem:
	return _us_item(US_ITEM_None, 0, IN_SC_None, "", US_Comm_None, null)


## A US_Card initialiser: {x, y, gfxChunk, unknown, items, msgCallback, selectedItem, unk1, unk2}.
static func _us_card(x: int, y: int, gfxChunk: String, unknown: int, items: Array, msgCallback: StringName,
		selectedItem: int, unk1: int, unk2: int) -> US_Card:
	var card: US_Card = US_Card.new()
	card.x = x
	card.y = y
	card.gfxChunk = gfxChunk
	card.unknown = unknown
	card.items = items
	card.msgCallback = msgCallback
	card.selectedItem = selectedItem
	card.unk1 = unk1
	card.unk2 = unk2
	return card


# ===================================================================== ck_us_2.c

const US_MAX_JOYSTICK_NAME_LENGTH: int = 28

const US_MAX_JOYSTICKS: int = 2


func CK_US_ScoreBoxMenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered:
		return false

	ck_scoreBoxEnabled = not ck_scoreBoxEnabled
	USL_CtlDialog(("Score box now on" if ck_scoreBoxEnabled else "Score box now off"), "Press any key", "")
	CK_US_UpdateOptionsMenus()
	return true


func CK_US_TwoButtonFiringMenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered:
		return false

	ck_twoButtonFiring = not ck_twoButtonFiring
	USL_CtlDialog(("Two-button firing now on" if ck_twoButtonFiring else "Two-button firing now off"), "Press any key", "")
	CK_US_UpdateOptionsMenus()
	return true


func CK_US_FixJerkyMotionMenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered:
		return false

	ck_fixJerkyMotion = not ck_fixJerkyMotion
	USL_CtlDialog(("Jerky motion fix enabled" if ck_fixJerkyMotion else "Jerky motion fix disabled"), "Press any key", "")
	CK_US_UpdateOptionsMenus()
	return true


func CK_US_SVGACompatibilityMenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered:
		return false

	ck_svgaCompatibility = not ck_svgaCompatibility
	USL_CtlDialog(("SVGA compatibility now on" if ck_svgaCompatibility else "SVGA compatibility now off"), "Press any key", "")
	CK_US_UpdateOptionsMenus()
	return true


# (EXTRA_GRAPHICS_OPTIONS, EXTRA_JOYSTICK_OPTIONS and QUICKSAVE_ENABLED menu
# procs are not in the vanilla build.)

# A debug menu which doesn't seem to ever appear in the game.
var ck_us_debugMenuItems: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "DEBUG", US_Comm_None, null),
	_us_item_end()]

var ck_us_debugMenu: US_Card = _us_card(0, 0, "PIC_DEBUGCARD", 0, ck_us_debugMenuItems, &"", 0, 0, 0)

# Sound Menu
var ck_us_soundMenuItems: Array = [
	_us_item(US_ITEM_Radio, 0, IN_SC_N, "NO SOUND EFFECTS", US_Comm_None, null),
	_us_item(US_ITEM_Radio, 0, IN_SC_P, "PC SPEAKER", US_Comm_None, null),
	_us_item(US_ITEM_Radio, 0, IN_SC_A, "ADLIB/SOUNDBLASTER", US_Comm_None, null),
	_us_item(US_ITEM_Radio, 0, IN_SC_Q, "QUIET ADLIB/SOUNDBLASTER", US_Comm_None, null),
	_us_item_end()]

var ck_us_soundMenu: US_Card = _us_card(8, 0, "PIC_SOUNDCARD", 0, ck_us_soundMenuItems, &"", 0, 0, 0)

# Music Menu
var ck_us_musicMenuItems: Array = [
	_us_item(US_ITEM_Radio, 0, IN_SC_N, "NO MUSIC", US_Comm_None, null),
	_us_item(US_ITEM_Radio, 0, IN_SC_A, "ADLIB/SOUNDBLASTER", US_Comm_None, null),
	_us_item_end()]

var ck_us_musicMenu: US_Card = _us_card(8, 0, "PIC_MUSICCARD", 0, ck_us_musicMenuItems, &"", 0, 0, 0)

# New Game Menu
var ck_us_newGameMenuItems: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_E, "BEGIN EASY GAME", US_Comm_NewEasyGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_N, "BEGIN NORMAL GAME", US_Comm_NewNormalGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_H, "BEGIN HARD GAME", US_Comm_NewHardGame, null),
	_us_item_end()]

# (selectedItem 1: the normal game is the one first highlighted)
var ck_us_newGameMenu: US_Card = _us_card(8, 0, "PIC_NEWGAMECARD", 0, ck_us_newGameMenuItems, &"", 1, 0, 0)

# Load/Save Game Menus
var ck_us_loadSaveMenuItems: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_One, "", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_Two, "", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_Three, "", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_Four, "", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_Five, "", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_Six, "", US_Comm_None, null),
	_us_item_end()]


func CK_US_DrawSavegameItemBorder(item: US_CardItem) -> void:
	var c: int = 0

	# Set the item's position
	item.y = us_currentCard.y + 60
	item.y += ck_us_loadSaveMenuItems.find(item) * 11

	# Choose an appropriate color
	US_SetPrintColour(us_menu_disabledColour if (item.state & US_IS_Selected) != 0 else us_menu_foregroundColour)
	c = US_GetPrintColour() ^ (us_menu_foregroundColour ^ us_menu_disabledColour)

	# Draw the rectangle
	VH_HLine(item.x, item.x + 148, item.y, c)
	VH_HLine(item.x, item.x + 148, item.y + 9, c)
	VH_VLine(item.y, item.y + 9, item.x, c)
	VH_VLine(item.y, item.y + 9, item.x + 148, c)


## (static in ck_us_2.c)
func US_LoadMain(i: int, fromMenu: bool) -> bool:
	var error: int = 0
	var fp: FS_File = null
	var fname: String = ""
	var e: US_Savefile = null

	e = us_savefiles[i]
	fname = US_GetSavefileName(i)
	fp = FS_OpenUserFile(fname)
	if FS_IsFileValid(fp):
		# Omnispeak - reading US_Savefile fields one-by-one
		# for cross-platform support
		# (each field is stored only when it was read whole; C's fread may
		# leave part of a short field in the record)
		var read_ok: bool = false
		var b: PackedByteArray = FS_Read(4, 1, fp)    # e->id
		if b.size() == 4:
			e.id = _cstr(b, 0, 4)
			var r: PackedInt64Array = FS_ReadInt16LE(1, fp)
			if r.size() == 1:
				e.printXOffset = u16(r[0])
				var u: Array = FS_ReadBoolFrom16LE(1, fp)
				if u.size() == 1:
					e.used = u[0]
					b = FS_Read(US_MAX_SAVEDGAMENAME_LEN + 1, 1, fp)    # e->name
					if b.size() == US_MAX_SAVEDGAMENAME_LEN + 1:
						e.name = _cstr(b, 0, US_MAX_SAVEDGAMENAME_LEN + 1)
						b = FS_Read(1, 1, fp)    # One byte of struct padding
						read_ok = b.size() == 1
		if read_ok:
			if p_load_game != &"" and not call(p_load_game, fp, fromMenu):
				load_game_error = 1
				# (errno: whatever the last failing call left; 0 makes the
				# load count as done below, as in C)
				error = errno
				USL_HandleError(error)
		else:
			error = errno
			USL_HandleError(error)
		FS_CloseFile(fp)
	else:
		error = errno
		USL_HandleError(error)

	if error != 0:
		CK_Cross_LogMessage(CK_LOG_MSG_ERROR, "US_LoadMain: Failed to load savegame %d\n" % i)
		return false
	else:
		ck_startingSavedGame = 1
		e.used = true
		in_Paused = true
		in_PausedMessage = "GAME LOADED"
		CK_Cross_LogMessage(CK_LOG_MSG_NORMAL, "US_LoadMain: Loaded savegame %d\n" % i)
		return true


func USL_ConfirmQuick(saving: bool, quickSaveSlot: int) -> bool:
	# (the shell's OPTIONS row QUICKSAVE ASKS stands for omnispeak's ck_quickSaveConfirm)
	var confirm: bool = bool(options.get_value("quicksave_confirm")) if options != null else CFG_GetConfigBool("ck_quickSaveConfirm", true)
	if confirm:
		# Draw a hint that the confirmation can be disabled.

		US_DrawWindow((320 / 8 - 20) / 2, 200 / 8 - 6, 20, 4)
		US_SetPrintY(US_GetPrintY() + 1)
		US_CPrint("Hint: This confirmation\ndialog can be disabled\nin the options menu.")

		# Draw the main confirmation dialog.
		US_CenterWindow(30, 6)
		US_SetPrintY(US_GetPrintY() + 3)
		if saving:
			US_CPrintF("QuickSave will save to slot number %d", [quickSaveSlot + 1])
		else:
			US_CPrintF("QuickLoad will load slot number %d", [quickSaveSlot + 1])
		US_SetPrintY(US_GetWindowY() + 20)
		US_CPrintF("%s\n", [(us_savefiles[quickSaveSlot] as US_Savefile).name])
		US_SetPrintY(US_GetWindowY() + 36)
		if saving:
			US_CPrintF("Really overwrite this game (Y/N)?", [])
		else:
			US_CPrintF("Really load this game (Y/N)?", [])

		VH_UpdateScreen()

		if not IN_YesNo():
			return false

		US_ClearWindow()
		return true
	return true


func US_QuickLoad() -> bool:
	var quickSaveSlot: int = CFG_GetConfigInt("quickSaveSlot", US_MAX_NUM_OF_SAVED_GAMES - 1)
	quickSaveSlot = CK_Cross_clamp(quickSaveSlot, 0, US_MAX_NUM_OF_SAVED_GAMES - 1)
	if not (us_savefiles[quickSaveSlot] as US_Savefile).used:
		return false
	if not USL_ConfirmQuick(false, quickSaveSlot):
		return false
	return US_LoadMain(quickSaveSlot, false)


func load_savegame_item(item: US_CardItem) -> void:
	if USL_ConfirmComm(US_Comm_LoadGame) != 0:
		var i: int = ck_us_loadSaveMenuItems.find(item)
		# (QUICKSAVE_ENABLED's CFG_SetConfigInt("quickSaveSlot", i) is not in the vanilla build)
		USL_LoadSaveMessage("Loading", (us_savefiles[i] as US_Savefile).name)
		if not US_LoadMain(i, true):
			# is this condition right?
			load_game_error = 1
			us_currentCommand = US_Comm_None    # ? last command ?
			command_confirmed = false           # ? command success state ?
		US_DrawCards()


func CK_US_LoadGameMenuProc(msg: int, item: US_CardItem) -> bool:
	var result: int = 0
	var i: int = 0

	result = 0

	match msg:
		US_MSG_CardEntered:
			if getenv("UID") != "":
				US_GetSavefiles()

			for j: int in range(US_MAX_NUM_OF_SAVED_GAMES):
				i = j
				if (us_savefiles[i] as US_Savefile).used:
					(ck_us_loadSaveMenuItems[i] as US_CardItem).state &= ~US_IS_Disabled
				else:
					(ck_us_loadSaveMenuItems[i] as US_CardItem).state |= US_IS_Disabled

		US_MSG_DrawItemIcon:
			CK_US_DrawSavegameItemBorder(item)
			result = 1

		US_MSG_DrawItem:
			CK_US_DrawSavegameItemBorder(item)

			# Draw the caption
			VH_Bar(item.x + 1, item.y + 2, 146, 7, us_menu_backgroundColour)
			i = ck_us_loadSaveMenuItems.find(item)
			var e: US_Savefile = us_savefiles[i]
			if e.used:
				US_SetPrintX(item.x + 2)
			else:
				US_SetPrintX(item.x + 60)

			US_SetPrintY(item.y + 2)
			VH_DrawPropString(e.name if e.used else "Empty", US_GetPrintX(), US_GetPrintY(), US_GetPrintFont(), US_GetPrintColour())
			result = 1

		US_MSG_ItemEntered:
			load_savegame_item(item)
			result = 1

		_:
			pass

	return result != 0


## (static in ck_us_2.c)
func US_SaveMain(i: int) -> bool:
	var n: bool = false
	var error: int = 0
	var fp: FS_File = null
	var fname: String = ""
	var e: US_Savefile = null

	e = us_savefiles[i]
	fname = US_GetSavefileName(i)
	fp = FS_CreateUserFile(fname)
	if FS_IsFileValid(fp):
		# Omnispeak - writing US_Savefile fields one-by-one
		# for cross-platform support
		var id: PackedByteArray = PackedByteArray()
		_putstr(id, e.id, 4)
		var name: PackedByteArray = PackedByteArray()
		_putstr(name, e.name, US_MAX_SAVEDGAMENAME_LEN + 1)
		var padding: PackedByteArray = PackedByteArray([0])    # One byte of struct padding
		if FS_Write(id, 4, 1, fp) == 1 and \
				FS_WriteInt16LE([e.printXOffset], 1, fp) == 1 and \
				FS_WriteBoolTo16LE([e.used], 1, fp) == 1 and \
				FS_Write(name, US_MAX_SAVEDGAMENAME_LEN + 1, 1, fp) == 1 and \
				FS_Write(padding, 1, 1, fp) == 1:
			# if ( write( handle, e, sizeof ( SAVEFILE_ENTRY ) ) == sizeof ( SAVEFILE_ENTRY ) )
			if p_save_game != &"":
				n = call(p_save_game, fp)
				if not n:
					# (errno as the last failing call left it; 0 counts as saved, as in C)
					error = errno
					USL_HandleError(error)
		else:
			error = 8 if errno == 2 else errno
			USL_HandleError(error)
		FS_CloseFile(fp)
	else:
		error = 8 if errno == 2 else errno
		USL_HandleError(error)

	# Delete the file if an error occurred
	if error != 0:
		remove(fname)
		e.used = false
		CK_Cross_LogMessage(CK_LOG_MSG_ERROR, "US_SaveMain: Failed to save game %d\n" % i)
		return false
	else:
		game_unsaved = 0
		CK_Cross_LogMessage(CK_LOG_MSG_NORMAL, "US_SaveMain: Saved game %d\n" % i)
		return true


## QUICKSAVE_ENABLED's (omnispeak upstream; not in the vanilla build): the game saved in the quick
## slot (the last), named QuickSave unless it has a name, after the confirmation the player may turn off.
## The shell's Enhanced mode turns the keys on (SAVE-02, shell_quicksave_on): off, the original exactly.
func US_QuickSave() -> bool:
	var quickSaveSlot: int = CFG_GetConfigInt("quickSaveSlot", US_MAX_NUM_OF_SAVED_GAMES - 1)
	quickSaveSlot = CK_Cross_clamp(quickSaveSlot, 0, US_MAX_NUM_OF_SAVED_GAMES - 1)
	if not USL_ConfirmQuick(true, quickSaveSlot):
		return false
	var e: US_Savefile = us_savefiles[quickSaveSlot]
	e.printXOffset = CK_INT("ck_exe_printXOffset", 0xF00D)
	# Only update the name if it doesn't already exist. (omnispeak tests the name alone, and an unused
	# slot's is "Empty" (US_GetSavefiles), so a first quicksave kept that name: an unused slot is named too)
	if e.name == "" or not e.used:
		e.name = "QuickSave"
	e.used = true
	return US_SaveMain(quickSaveSlot)


## SAVE-02 (Enhanced): F5 quicksaves and F9 quickloads during play (Megarocket 1.0's keys for Keen 4-6),
## through the original's own save and load; off in Classic and with no player (tests, oracle runs).
func shell_quicksave_on() -> bool:
	return options != null and bool(options.get_value("quicksave"))


func save_savegame_item(item: US_CardItem) -> void:
	var i: int = 0
	var n: bool = false
	var e: US_Savefile = null

	footer_str[2] = "Type name"
	footer_str[1] = "Enter accepts"
	US_DrawCards()

	i = ck_us_loadSaveMenuItems.find(item)
	e = us_savefiles[i]

	# Prompt the user to enter a name
	US_SetPrintColour(us_menu_disabledColour)
	# fontcolour = 2;
	VH_Bar(item.x + 1, item.y + 2, 146, 7, us_menu_backgroundColour)
	e.printXOffset = u16(CK_INT("ck_exe_printXOffset", 0xF00D))
	# US_LineInput writes e->name only when Enter accepts the text
	var typed: Array = US_LineInput(item.x + 2, item.y + 2, (e.name if e.used else ""), true, 32, 138)
	n = typed[0]
	if n:
		e.name = typed[1]

	# If they entered no name, give a default
	if e.name.length() == 0:
		e.name = "Untitled"

	# If the input was not canceled
	if n:
		e.used = true
		# (QUICKSAVE_ENABLED's CFG_SetConfigInt("quickSaveSlot", i) is not in the vanilla build)
		USL_LoadSaveMessage("Saving", e.name)
		US_SaveMain(i)
	USL_SetMenuFooter()


func CK_US_SaveGameMenuProc(msg: int, item: US_CardItem) -> bool:
	match msg:
		US_MSG_CardEntered:
			if getenv("UID") != "":
				US_GetSavefiles()

			# Enable all the entries
			for i: int in range(US_MAX_NUM_OF_SAVED_GAMES):
				(ck_us_loadSaveMenuItems[i] as US_CardItem).state &= ~US_IS_Disabled

			return false

		US_MSG_ItemEntered:
			save_savegame_item(item)
			return true

		_:
			return CK_US_LoadGameMenuProc(msg, item)


var ck_us_loadGameMenu: US_Card = _us_card(4, 3, "PIC_LOADCARD", 0, ck_us_loadSaveMenuItems, &"CK_US_LoadGameMenuProc", 0, 0, 0)
var ck_us_saveGameMenu: US_Card = _us_card(4, 3, "PIC_SAVECARD", 0, ck_us_loadSaveMenuItems, &"CK_US_SaveGameMenuProc", 0, 0, 0)

# Dummy Menus

var ck_us_scoreBoxMenu: US_Card = _us_card(0, 0, "", 0, [], &"CK_US_ScoreBoxMenuProc", 0, 0, 0)
var ck_us_twoButtonFiringMenu: US_Card = _us_card(0, 0, "", 0, [], &"CK_US_TwoButtonFiringMenuProc", 0, 0, 0)
var ck_us_fixJerkyMotionMenu: US_Card = _us_card(0, 0, "", 0, [], &"CK_US_FixJerkyMotionMenuProc", 0, 0, 0)
var ck_us_svgaCompatibilityMenu: US_Card = _us_card(0, 0, "", 0, [], &"CK_US_SVGACompatibilityMenuProc", 0, 0, 0)
# Options menu
var ck_us_optionsMenuItems: Array = [
	_us_item(US_ITEM_Submenu, 0, IN_SC_S, "", US_Comm_None, ck_us_scoreBoxMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_T, "", US_Comm_None, ck_us_twoButtonFiringMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_M, "", US_Comm_None, ck_us_fixJerkyMotionMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_C, "", US_Comm_None, ck_us_svgaCompatibilityMenu),
	_us_item_end()]

var ck_us_optionsMenu: US_Card = _us_card(8, 0, "PIC_OPTIONSCARD", 0, ck_us_optionsMenuItems, &"", 0, 0, 0)
## The original four OPTIONS items, by reference (MENU-02 inserts the shell's MODE row before them).
var ck_us_optionsOriginal: Array = ck_us_optionsMenuItems.slice(0, 4)

# Movement Kbd Controls Menu
var ck_us_movementMenuItems: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "UP & LEFT", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "UP", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "UP & RIGHT", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "RIGHT", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "DOWN & RIGHT", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "DOWN", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "DOWN & LEFT", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_None, "LEFT", US_Comm_None, null),
	_us_item_end()]

var ck_us_movementMenu: US_Card = _us_card(0, 0, "PIC_MOVEMENTCARD", 0, ck_us_movementMenuItems, &"CK_US_ControlsMenuProc", 0, 0, 0)

# Buttons Kbd Controls Menu
var ck_us_buttonsMenuItems: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_J, "JUMP", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_P, "POGO", US_Comm_None, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_F, "FIRE", US_Comm_None, null),
	_us_item_end()]

var ck_us_buttonsMenu: US_Card = _us_card(0, 0, "PIC_BUTTONSCARD", 0, ck_us_buttonsMenuItems, &"CK_US_ControlsMenuProc", 0, 0, 0)

# Keyboard Menu
# (both items have the shortcut M, as in C: the first one wins)
var ck_us_keyboardMenuItems: Array = [
	_us_item(US_ITEM_Submenu, 0, IN_SC_M, "MOVEMENT", US_Comm_None, ck_us_movementMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_M, "BUTTONS", US_Comm_None, ck_us_buttonsMenu),
	_us_item_end()]

var ck_us_keyboardMenu: US_Card = _us_card(8, 0, "PIC_KEYBOARDCARD", 0, ck_us_keyboardMenuItems, &"CK_US_KeyboardMenuProc", 0, 0, 0)

# Custom Menus

var ck_us_joystick1Menu: US_Card = _us_card(0, 0, "PIC_JOYSTICKCARD", 0, [], &"CK_US_Joystick1MenuProc", 0, 0, 0)
var ck_us_joystick2Menu: US_Card = _us_card(0, 0, "PIC_JOYSTICKCARD", 0, [], &"CK_US_Joystick2MenuProc", 0, 0, 0)
var ck_us_gamepadMenu: US_Card = _us_card(0, 0, "PIC_JOYSTICKCARD", 0, [], &"CK_US_GamepadMenuProc", 0, 0, 0)

# Configure Menu
var ck_us_configureMenuItems: Array = [
	_us_item(US_ITEM_Submenu, 0, IN_SC_S, "SOUND", US_Comm_None, ck_us_soundMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_M, "MUSIC", US_Comm_None, ck_us_musicMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_O, "OPTIONS", US_Comm_None, ck_us_optionsMenu),
	_us_item(US_ITEM_Submenu, US_IS_Gap, IN_SC_K, "KEYBOARD", US_Comm_None, ck_us_keyboardMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_One, "USE JOYSTICK #1", US_Comm_None, ck_us_joystick1Menu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_Two, "USE JOYSTICK #2", US_Comm_None, ck_us_joystick2Menu),
	# { US_ITEM_Submenu, 0, IN_SC_G, "", US_Comm_None, &ck_us_gamepadMenu, 0, 0 },
	_us_item_end()]

var ck_us_configureMenu: US_Card = _us_card(0, 0, "PIC_CONFIGURECARD", 0, ck_us_configureMenuItems, &"CK_US_ConfigureMenuProc", 0, 0, 0)
## The two joystick items, by reference (MENU-02 inserts DISPLAY after MUSIC).
var ck_us_joystickItems: Array = [ck_us_configureMenuItems[4], ck_us_configureMenuItems[5]]

# Paddle War!

var ck_us_paddleWarMenu: US_Card = _us_card(0, 0, "", 0, [], &"CK_PaddleWar", 0, 0, 0)

# Main Menu
# (item 4's caption is NULL here; USL_UpdateCards names it)
var ck_us_mainMenuItems: Array = [
	_us_item(US_ITEM_Submenu, 0, IN_SC_N, "NEW GAME", US_Comm_None, ck_us_newGameMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_L, "LOAD GAME", US_Comm_None, ck_us_loadGameMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_S, "SAVE GAME", US_Comm_None, ck_us_saveGameMenu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_C, "CONFIGURE", US_Comm_None, ck_us_configureMenu),
	_us_item(US_ITEM_Normal, 0, IN_SC_R, "", US_Comm_ReturnToGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_E, "END GAME", US_Comm_EndGame, null),
	_us_item(US_ITEM_Submenu, 0, IN_SC_P, "PADDLE WAR", US_Comm_None, ck_us_paddleWarMenu),
	_us_item(US_ITEM_Normal, 0, IN_SC_Q, "QUIT", US_Comm_Quit, null),
	_us_item_end()]

var ck_us_mainMenu: US_Card = _us_card(32, 4, "PIC_MENUCARD", 0, ck_us_mainMenuItems, &"", 0, 0, 0)
## The original eight MAIN items, by reference (the shell's CHEATS goes in after CONFIGURE).
var ck_us_mainOriginal: Array = ck_us_mainMenuItems.slice(0, 8)


func CK_US_ControlsMenuProc(msg: int, item: US_CardItem) -> bool:
	var which_control: int = 0
	var result: int = 0
	var print_x: int = 0
	var print_y: int = 0

	# (for a NULL item, C's pointer difference is garbage; find gives -1. Only
	# the item messages read it.)
	which_control = (ck_us_movementMenuItems.find(item) + in_key_button_controls) if us_currentCard == ck_us_movementMenu \
			else ck_us_buttonsMenuItems.find(item)

	match msg:
		US_MSG_CardEntered:
			# game_controller[0] = CTRL_KEYBOARD;
			pass

		US_MSG_DrawItem:
			# Draw the item Icon and the key's name
			VH_Bar(75, item.y, 159, 8, us_menu_backgroundColour)
			USL_DrawCardItemIcon(item)

			US_SetPrintColour(us_menu_disabledColour if (item.state & US_IS_Selected) != 0 else us_menu_foregroundColour)
			print_x = item.x + 8
			print_y = item.y + 1
			VH_DrawPropString(item.caption, print_x, print_y, 1, US_GetPrintColour())

			# Draw the outer green box
			VH_Bar(item.x + 90, item.y, 40, 8, US_GetPrintColour() ^ (us_menu_disabledColour ^ us_menu_foregroundColour))
			VH_Bar(item.x + 91, item.y + 1, 38, 6, us_menu_backgroundColour)

			print_x = item.x + 96
			print_y = item.y + 1
			VH_DrawPropString(IN_GetScanName(in_kbdControls[in_key_controls[which_control]]), print_x, print_y, 1, US_GetPrintColour())
			result = 1

		US_MSG_ItemEntered:
			CK_US_ControlsMenuProc(US_MSG_DrawItem, item)
			CK_US_SetKeyBinding(item, which_control)
			US_DrawCards()
			result = 1

		_:
			pass

	return result != 0


func CK_US_SetKeyBinding(item: US_CardItem, which_control: int) -> void:
	var cursor: bool = false
	var lasttime: int = 0    # uint32_t
	var state: IN_ControlFrame = IN_ControlFrame.new()
	var k: int = 0    # char
	var i: int = 0
	var used: int = 0

	# TODO: Should be global variables (as in vanilla Keen 5)?
	# (a char: a scan code from 0x80 up, such as Pause's 0xE1, turns negative)
	var last_scan: int = 0
	US_SetPrintColour(us_menu_disabledColour)

	IN_ClearKeysDown()

	# Prompt the user to press a key
	while true:    # do { ... } while ((k = last_scan) == 0)
		if quitting:
			return
		# CK_SetTicsPerFrame();
		IN_PumpEvents()

		# Flicker the cursor
		if SD_GetTimeCount() >= lasttime:
			# time_count
			cursor = not cursor

			# Draw the rectangle
			VH_Bar(item.x + 90, item.y, 40, 8, US_GetPrintColour() ^ (us_menu_disabledColour ^ us_menu_foregroundColour))
			VH_Bar(item.x + 91, item.y + 1, 38, 6, us_menu_backgroundColour)

			# Draw the cursor
			if cursor:
				VH_DrawTile8(item.x + 106, item.y, 100)

			VH_UpdateScreen()
			lasttime = (SD_GetTimeCount() + 35) & 0xFFFFFFFF    # time_count

		# A button push will cancel the key selection
		IN_ReadControls(0, state)
		last_scan = s8(IN_GetLastScan())
		while (state.jump or state.pogo) and not quitting:
			VL_Yield()    # Keep CPU usage low
			IN_PumpEvents()
			IN_ReadControls(0, state)
			last_scan = IN_SC_Escape

		# Disallow left shift for some reason
		# disable();
		if IN_GetLastScan() == IN_SC_LeftShift:
			last_scan = 0
		# enable();

		k = last_scan
		if k != 0:
			break

	# If they didn't cancel the process with ESC
	if last_scan != IN_SC_Escape:
		used = 0
		i = 0

		# Make sure the key they chose is not already used
		# (C compares the IN_ScanCode with the char k: a key from 0x80 up never matches)
		i = 0
		while i < in_key_button_controls + in_key_direction_controls:
			# Don't check the one we're setting
			if i != which_control:
				if int(in_kbdControls[in_key_controls[i]]) == k:
					used = 1
					break
			i += 1

		if used != 0:
			USL_CtlDialog("Key already used", "Press any key", "")
		else:
			in_kbdControls[in_key_controls[which_control]] = k

	IN_ClearKeysDown()


func CK_US_KeyboardMenuProc(msg: int, _item: US_CardItem) -> bool:
	# Set keyboard as game controller if this menu is entered
	if msg == US_MSG_CardEntered:
		IN_SetControlType(0, IN_ctrl_Keyboard1)
		CK_US_UpdateOptionsMenus()
	return false


func CK_US_Joystick1MenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg == US_MSG_CardEntered:
		IN_SetControlType(0, IN_ctrl_Joystick1)
		USL_CtlDialog("USING JOYSTICK #1", "PRESS ANY KEY", "")
		CK_US_UpdateOptionsMenus()
		return true
	return false


func CK_US_Joystick2MenuProc(msg: int, _item: US_CardItem) -> bool:
	if msg == US_MSG_CardEntered:
		IN_SetControlType(0, IN_ctrl_Joystick2)
		USL_CtlDialog("USING JOYSTICK #2", "PRESS ANY KEY", "")
		CK_US_UpdateOptionsMenus()
		return true
	return false


func CK_US_GamepadMenuProc(_msg: int, _item: US_CardItem) -> bool:
	return false


# (CK_US_JoyConfMenuProc and CK_US_SetJoyBinding are EXTRA_JOYSTICK_OPTIONS':
# not in the vanilla build.)


func CK_US_ConfigureMenuProc(_msg: int, _item: US_CardItem) -> bool:
	return false


func USL_DrawPaddleWarScore(keen_score: int, comp_score: int) -> void:
	# NOTE: This is modified a little from the original
	# exe in order to align the text and to set the proper font and color

	var print_color: int = s8(us_menu_disabledColour)    # int8_t
	var print_y: int = 52    # int16_t
	var w: int = 0    # uint16_t
	var _h: int = 0

	# uint16_t old_print_font = US_GetPrintFont();
	# uint16_t old_print_color = US_GetPrintColour();

	# US_SetPrintFont(4);
	US_SetPrintColour(print_color)

	# Draw keen's score
	var print_x: int = 80
	VH_Bar(print_x, print_y, 42, 6, us_menu_backgroundColour)
	var keenString: String = CK_STRING("ck_str_paddleWarKeen")
	var wh: PackedInt32Array = VH_MeasurePropString(keenString, 1)
	w = wh[0]
	_h = wh[1]
	VH_DrawPropString(keenString, print_x, print_y, 1, print_color)
	US_SetPrintX(print_x + w)
	US_SetPrintY(print_y)
	US_PrintF("%d", [s16(keen_score) & 0xFFFFFFFF])    # "%u" of the int the int16_t promotes to

	# Draw Comp score
	print_x = 182
	VH_Bar(print_x, print_y, 50, 6, us_menu_backgroundColour)
	var compString: String = CK_STRING("ck_str_paddleWarComp")
	wh = VH_MeasurePropString(compString, 1)
	w = wh[0]
	_h = wh[1]
	VH_DrawPropString(compString, print_x, print_y, 1, print_color)

	US_SetPrintX(print_x + w)
	US_SetPrintY(print_y)
	US_PrintF("%d", [s16(comp_score) & 0xFFFFFFFF])

	# US_SetPrintFont(old_print_font);
	# US_SetPrintColour(old_print_color);


func USL_PlayPaddleWar() -> void:
	var ball_visible: bool = false
	var new_round: bool = true
	var keen_won_last: bool = false
	var done: bool = false
	var y_bounce: int = 0
	var comp_move_counter: int = 0
	# int16_t; C leaves ball_y, bounce_point, speedup_delay, ball_x_speed,
	# start_delay and ball_x uninitialised (each is set before it is read)
	var ball_y: int = 0
	var keen_x: int = 0
	var comp_x: int = 0
	var bounce_point: int = 0
	var ball_real_x: int = 0
	var ball_real_y: int = 0
	var old_keen_x: int = 0
	var old_comp_x: int = 0
	var old_ball_x: int = 0
	var old_ball_y: int = 0
	var keen_score: int = 0
	var comp_score: int = 0
	var speedup_delay: int = 0
	var ball_x_speed: int = 0
	var start_delay: int = 0    # int32_t
	var lasttime: int = 0       # uint32_t
	var timediff: int = 0       # uint32_t
	var status: IN_ControlFrame = IN_ControlFrame.new()
	var ball_y_speed: int = 0
	var ball_x: int = 0

	keen_x = 148
	comp_x = 148
	ball_real_x = 0
	ball_real_y = 0
	ball_y_speed = 0
	old_ball_x = 78
	old_comp_x = 78
	old_keen_x = 78
	old_ball_y = 62
	USL_DrawPaddleWarScore(0, 0)
	lasttime = SD_GetTimeCount()

	while true:    # do { ... } while ((IN_GetLastScan() != IN_SC_Escape) && !done)
		if quitting:
			return
		# Delay Processing
		# TODO/FIXME: Better handling of this in the future
		while true:
			timediff = (SD_GetTimeCount() - lasttime) & 0xFFFFFFFF
			if timediff != 0 or quitting:
				break
			# The original code waits in a busy loop.
			# Bad idea for new code.
			# TODO: What about checking for input/graphics/other status?
			VL_Yield()
			# (the port's clock moves only as the machine runs: wait for its next tic)
			SD_WaitTick()
			# CK_SetTicsPerFrame();
			# IN_PumpEvents();
			# IN_ReadControls(0, &status );
		lasttime = SD_GetTimeCount()
		if timediff > 4:
			timediff = 4

		# Move the game elements
		while true:    # while (timediff-- && !done && (IN_GetLastScan() != IN_SC_Escape))
			var td: int = timediff
			timediff = (timediff - 1) & 0xFFFFFFFF
			if td == 0 or done or IN_GetLastScan() == IN_SC_Escape or quitting:
				break
			IN_PumpEvents()
			IN_ReadControls(0, status)
			# Move Keen's paddle
			if status.xDirection < 0 or IN_GetKeyState(IN_SC_LeftArrow):
				if keen_x > 78:
					keen_x = s16(keen_x - 2)
			elif status.xDirection > 0 or IN_GetKeyState(IN_SC_RightArrow):
				if keen_x < 219:
					keen_x = s16(keen_x + 2)

			# Start a new round if there was a point
			if new_round:
				ball_visible = false
				start_delay = 70
				speedup_delay = 10
				new_round = false

				# Erase the ball
				VH_Bar(old_ball_x, old_ball_y, 6, 5, us_menu_backgroundColour)

			if ball_visible:
				var counter: int = comp_move_counter
				comp_move_counter = s16(comp_move_counter + 1)
				if (counter % 3) != 0:
					ball_x = s16(ball_real_x / 4)
					if (ball_x & 1) == 0:
						ball_x = s16(ball_x + (US_RndT() & 1))

					# Move computer paddle to the ball
					if comp_x + 6 < ball_x and comp_x < 219:
						comp_x = s16(comp_x + 1)
					elif comp_x + 6 > ball_x and comp_x > 78:
						comp_x = s16(comp_x - 1)

			if not ball_visible:
				start_delay = s32(start_delay - 1)
				if start_delay == 0:
					ball_visible = true
					ball_x_speed = s16(1 - (US_RndT() % 3))
					ball_y_speed = 3
					if keen_won_last:
						ball_y_speed = s16(-ball_y_speed)
					ball_real_x = 612
					ball_real_y = 396
				else:
					# Wait until the ball has been served
					continue

			# Bounce ball off of side wall
			if (ball_real_x + ball_x_speed) / 4 > 228 or (ball_real_x + ball_x_speed) / 4 < 78:
				SD_PlaySound(CK_SOUNDNUM("SOUND_PONGWALL"))
				ball_x_speed = s16(-ball_x_speed)

			# Move ball in the X direction
			ball_real_x = s16(ball_real_x + ball_x_speed)

			# Check if computer scores a point
			if (ball_real_y + ball_y_speed) / 4 > 137:
				new_round = true
				keen_won_last = false
				comp_score = s16(comp_score + 1)
				SD_PlaySound(CK_SOUNDNUM("SOUND_COMPSCORE"))
				USL_DrawPaddleWarScore(keen_score, comp_score)
				if comp_score == 21:
					USL_CtlDialog(CK_STRING("ck_str_paddleWarDefeat"), CK_STRING("ck_str_paddleWarPressAKey"), "")
					done = true
					continue
			# Check if Keen scores a point
			elif (ball_real_y + ball_y_speed) / 4 < 62:
				new_round = true
				keen_won_last = true
				keen_score = s16(keen_score + 1)
				SD_PlaySound(CK_SOUNDNUM("SOUND_KEENSCORE"))    # play_sound
				USL_DrawPaddleWarScore(keen_score, comp_score)
				if keen_score == 21:
					USL_CtlDialog(CK_STRING("ck_str_paddleWarVictory"), CK_STRING("ck_str_paddleWarPressAKey"), "")
					done = true
					continue

			ball_real_y = s16(ball_real_y + ball_y_speed)
			ball_x = s16(ball_real_x / 4)
			ball_y = s16(ball_real_y / 4)

			if not new_round:
				# Check if ball hits comp paddle
				if ball_y_speed < 0 and ball_y >= 66 and ball_y < 69 and (comp_x - 5) <= ball_x and (comp_x + 11) > ball_x:
					bounce_point = comp_x
					y_bounce = 1
					SD_PlaySound(CK_SOUNDNUM("SOUND_COMPPADDLE"))
				elif ball_y_speed > 0 and ball_y >= 132 and ball_y < 135 and (keen_x - 5) <= ball_x and (keen_x + 11) > ball_x:
					if ball_y_speed / 4 < 3:
						speedup_delay = s16(speedup_delay - 1)
						if speedup_delay == 0:
							ball_y_speed = s16(ball_y_speed + 1)
							speedup_delay = 10
					bounce_point = keen_x
					y_bounce = 1
					SD_PlaySound(CK_SOUNDNUM("SOUND_KEENPADDLE"))

				if y_bounce != 0:
					ball_y_speed = s16(-ball_y_speed)
					ball_x_speed = s16((ball_x + 5 - bounce_point) / 2 - 4)    # or / 4?
					if ball_x_speed == 0:
						ball_x_speed = s16(ball_x_speed - 1)
					y_bounce = 0

		if ball_visible:
			VH_Bar(old_ball_x, old_ball_y, 6, 5, us_menu_backgroundColour)
			old_ball_x = ball_x
			old_ball_y = ball_y

			# draw_sprite?
			# Omnispeak doesn't emulate sprite shifts properly, so paddle war
			# (which works around this by having two sprites, one shifted one
			# pixel over) ends up shifted an extra pixel sometimes. By ignoring
			# the lower bit of ball_x here, we emulate the shift behaviour we need.
			VH_DrawSprite(ball_x & ~1, ball_y, CK_CHUNKNUM("SPR_BALL1") if (ball_x & 1) != 0 else CK_CHUNKNUM("SPR_BALL0"))

		# Draw Computer Paddle
		VH_Bar(old_comp_x - 3, 66, 16, 3, us_menu_backgroundColour)
		old_comp_x = comp_x
		VH_DrawSprite(comp_x, 66, CK_CHUNKNUM("SPR_PADDLE"))

		# Draw Keen paddle
		VH_Bar(old_keen_x - 3, 135, 16, 3, us_menu_backgroundColour)
		old_keen_x = keen_x
		VH_DrawSprite(keen_x, 135, CK_CHUNKNUM("SPR_PADDLE"))

		# sub_658();
		VL_Present()

		if not (IN_GetLastScan() != IN_SC_Escape and not done):
			break

	IN_ClearKeysDown()


func CK_PaddleWar(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered:
		return false

	# Draw the watch
	VH_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_WRISTWATCH"))

	# Draw the PaddleWar title
	VH_DrawBitmap(130, 48, CK_CHUNKNUM("PIC_PADDLEWAR"))

	# Draw a line above the playing area
	VH_HLine(77, 231, 60, us_menu_foregroundColour)

	# Draw a line below the playing area
	VH_HLine(77, 231, 143, us_menu_foregroundColour)

	# Play the game
	USL_PlayPaddleWar()
	return true


# (CK_US_SetJoystickName is EXTRA_JOYSTICK_OPTIONS': not in the vanilla build.)


func CK_US_UpdateOptionsMenus() -> void:
	(ck_us_optionsOriginal[0] as US_CardItem).caption = "SCORE BOX (ON)" if ck_scoreBoxEnabled else "SCORE BOX (OFF)"
	(ck_us_optionsOriginal[1] as US_CardItem).caption = "TWO-BUTTON FIRING (ON)" if ck_twoButtonFiring else "TWO-BUTTON FIRING (OFF)"
	(ck_us_optionsOriginal[2] as US_CardItem).caption = "FIX JERKY MOTION (ON)" if ck_fixJerkyMotion else "FIX JERKY MOTION (OFF)"
	(ck_us_optionsOriginal[3] as US_CardItem).caption = "SVGA COMPATIBILITY (ON)" if ck_svgaCompatibility else "SVGA COMPATIBILITY (OFF)"

	# Disable Two button firing selection if required
	(ck_us_buttonsMenuItems[2] as US_CardItem).state &= ~US_IS_Disabled
	if ck_twoButtonFiring:
		(ck_us_buttonsMenuItems[2] as US_CardItem).state |= US_IS_Disabled

	if IN_JoyPresent(0):
		(ck_us_joystickItems[0] as US_CardItem).state &= ~US_IS_Disabled
	else:
		(ck_us_joystickItems[0] as US_CardItem).state |= US_IS_Disabled
	if IN_JoyPresent(1):
		(ck_us_joystickItems[1] as US_CardItem).state &= ~US_IS_Disabled
	else:
		(ck_us_joystickItems[1] as US_CardItem).state |= US_IS_Disabled

	# Set up the gamepad menu item
	# (an #if 0 block in C)


class CK_CreatureType:
	var name: String = ""
	var sprite: int = 0
	var xofs: int = 0
	var yofs: int = 0


## (static in ck_us_2.c)
var currentCreature: int = -1
# (ck6_creatureQuestionDone: gal_ck.gd)

## time(&t); localtime(&t): the hour and the day of the month. No wall clock
## here (A8, A11): the shell sets them from the session, as us_randomSeed. Not state.
var localtime_tm_hour: int = 0
var localtime_tm_mday: int = 1


func CK6_CreatureQuestion() -> bool:
	if CK_INT("ck6_hasCreatureQuestion", 0) == 0:
		return true

	if ck6_creatureQuestionDone:
		return true

	# the shell's CREATURE QUESTION row turned off (a player at the controls; OPTIONS, Keen 6)
	if options != null and options.get_value("creature_question") == false:
		return true

	# /TEDLEVEL: the original goes straight into the level (keen6_level01_a .. 18_a show the level's
	# box first; omnispeak asks). Seen in the recordings; the v1.0 source is not to hand.
	if us_tedLevel:
		return true

	var numCreatures: int = CK_INT("ck6_numCopyCreatures", 12)

	var correct: bool = false
	if currentCreature == -1:
		currentCreature = (localtime_tm_hour + localtime_tm_mday) % numCreatures

	CA_UpLevel()
	var creature: CK_CreatureType = CK_CreatureType.new()
	creature.name = CK_STRINGELEMENT("ck6_copyCreatureNames", currentCreature)
	creature.sprite = CK_INTELEMENT("ck6_copyCreatureSprites", currentCreature)
	creature.xofs = CK_INTELEMENT("ck6_copyCreatureXOffsets", currentCreature)
	creature.yofs = CK_INTELEMENT("ck6_copyCreatureYOffsets", currentCreature)
	CA_ClearMarks()
	CA_MarkGrChunk(creature.sprite)
	CA_CacheMarks("")    # CA_CacheMarks(NULL)

	VH_Bar(0, 0, 320, 200, 8)
	var sprite: Dictionary = VH_GetSpriteTableEntry(creature.sprite - int(ca_gfxInfoE.offSprites))
	var w: int = sprite.width
	var h: int = sprite.height

	US_CenterWindow(30, (h + 41) / 8 + 1)
	US_SetPrintY(US_GetWindowY() + 2)
	US_CPrint(CK_STRING("ck6_str_creatureQuestion"))
	var x: int = US_GetWindowX() + (US_GetWindowW() - w) / 2 + (creature.xofs * 8)
	var y: int = US_GetWindowY() + 15

	if creature.sprite == CK_CHUNKNUM("ck6_copyCeilickSprite"):
		y += 1
	else:
		y += creature.yofs * 3

	VH_DrawSprite(x, y, creature.sprite)

	y = US_GetWindowY() + US_GetWindowH() - 0x10
	var varC: int = 100
	x = US_GetWindowX() + (US_GetWindowW() - 100) / 2
	VH_Bar(x, y, 100, 14, 0)
	VH_Bar(x + 1, y + 1, varC - 2, 12, 15)
	x += 2
	y += 2
	varC -= 8
	VL_Present()

	# char buf[16] (written only when Enter accepts the text)
	var typed: Array = US_LineInput(x, y, "", true, 16, varC)
	if typed[0]:
		var buf: String = typed[1]
		correct = true
		# In the disassembly, a loop which appears to do a  case-insensitve strcmp
		if CK_Cross_strcasecmp(buf, creature.name) != 0:
			VH_Bar(0, 0, 320, 200, 8)
			US_CenterWindow(35, 5)
			US_SetPrintY(US_GetPrintY() + 11)
			US_CPrint(CK_STRING("ck6_str_copyWrong1"))
			US_CPrint(CK_STRING("ck6_str_copyWrong2"))
			VL_Present()
			IN_WaitButton()
			correct = false

	VH_Bar(0, 0, 320, 200, 8)
	CA_DownLevel()
	ck6_creatureQuestionDone = correct
	return correct


# ===================================================================== id_us_2.c

# Card stack can have at most 7 cards
const US_MAX_CARDSTACK: int = 7

# Menu motion repeat rate when using a controller (lower value = faster)
const US_MENU_MOTION_SPEED: int = 40

# (ck_startingDifficulty: gal_ck.gd. game_unsaved, game_in_progress,
# quit_to_dos, load_game_error, us_currentCommand and command_confirmed:
# gal_us.gd.)

## (static in id_us_2.c)
var us_cardStackIndex: int = 0
var us_currentCard: US_Card = null
var us_cardStack: Array = [null, null, null, null, null, null, null]

# Index of the top menu item in a scrolled screen.
# (statics only the non-vanilla build's scrolling reads)
var us_menuScrollOffset: int = 0
var us_menuScrollDirty: bool = true
var us_menuScrollIconTop: bool = false
var us_menuScrollIconBottom: bool = false

var new_game_menu_items: Array = [
	_us_item(US_ITEM_Normal, 0, IN_SC_E, "BEGIN EASY GAME", US_Comm_NewEasyGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_N, "BEGIN NORMAL GAME", US_Comm_NewNormalGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_H, "BEGIN HARD GAME", US_Comm_NewHardGame, null),
	_us_item_end()]

var new_game_menu: US_Card = _us_card(8, 0, "PIC_NEWGAMECARD", 0, new_game_menu_items, &"", 0, 0, 0)

var main_menu_items: Array = [
	_us_item(US_ITEM_Submenu, 0, IN_SC_N, "NEW GAME", US_Comm_None, new_game_menu),
	_us_item(US_ITEM_Submenu, 0, IN_SC_L, "LOAD GAME", US_Comm_None, null),    # /*load_game_menu*/ NULL
	_us_item(US_ITEM_Submenu, 0, IN_SC_S, "SAVE GAME", US_Comm_None, null),    # /*save_game_menu*/ NULL
	_us_item(US_ITEM_Submenu, 0, IN_SC_C, "CONFIGURE", US_Comm_None, null),    # /*&configure_menu*/ NULL
	_us_item(US_ITEM_Normal, 0, IN_SC_R, "", US_Comm_ReturnToGame, null),
	_us_item(US_ITEM_Normal, 0, IN_SC_E, "END GAME", US_Comm_EndGame, null),
	_us_item(US_ITEM_Submenu, 0, IN_SC_P, "PADDLE WAR", US_Comm_None, null),   # /*paddlewar_menu*/ NULL
	_us_item(US_ITEM_Normal, 0, IN_SC_Q, "QUIT", US_Comm_Quit, null),
	_us_item_end()]

# AS:00A2
var main_menu: US_Card = _us_card(32, 4, "PIC_MENUCARD", 0, main_menu_items, &"", 0, 0, 0)


func US_SetupCards(initial: US_Card) -> void:
	us_cardStackIndex = 0
	us_cardStack[0] = initial
	us_currentCard = initial


func USL_PopCard() -> US_Card:
	# If the stack is empty, we're in trouble.
	if us_cardStackIndex == 0:
		return null

	us_cardStackIndex -= 1

	us_currentCard = us_cardStack[us_cardStackIndex]
	return us_currentCard


func USL_PushCard(card: US_Card) -> void:
	if us_cardStackIndex >= US_MAX_CARDSTACK:
		return

	# (at index 6, C stores past the end of its 7-card array; no path here goes
	# deeper than 3)
	us_cardStackIndex += 1
	us_currentCard = card
	us_cardStack[us_cardStackIndex] = card


func USL_DrawCardItemIcon(item: US_CardItem) -> void:
	# Send a US_MSG_DrawItemIcon message to the card.
	if us_currentCard.msgCallback != &"" and call(us_currentCard.msgCallback, US_MSG_DrawItemIcon, item):
		return

	var gfxChunk: int = 0

	if (item.state & US_IS_Disabled) != 0:
		if (item.state & US_IS_Selected) != 0:
			gfxChunk = CK_INT("us_menu_itemDisabledSelectedTile", 92 + 5)
		else:
			gfxChunk = CK_INT("us_menu_itemDisabledTile", 92 + 4)
	else:
		if item.type == US_ITEM_Radio and (item.state & US_IS_Checked) == 0:
			if (item.state & US_IS_Selected) != 0:
				gfxChunk = CK_INT("us_menu_itemCheckedSelectedTile", 92 + 3)
			else:
				gfxChunk = CK_INT("us_menu_itemCheckedTile", 92 + 2)
		else:
			if (item.state & US_IS_Selected) != 0:
				gfxChunk = CK_INT("us_menu_itemSelectedTile", 92 + 1)
			else:
				gfxChunk = CK_INT("us_menu_itemTile", 92 + 0)

	VHB_DrawTile8(item.x, item.y, gfxChunk)


func USL_DrawCardItem(item: US_CardItem) -> void:
	if (item.state & US_IS_Hidden) != 0:
		return

	# Send a US_MSG_DrawItemIcon message to the card.
	if us_currentCard.msgCallback != &"" and call(us_currentCard.msgCallback, US_MSG_DrawItem, item):
		return

	# Gray out the area underneath the text
	VHB_Bar(75, item.y, 159, 8, us_menu_backgroundColour)

	USL_DrawCardItemIcon(item)

	if (item.state & US_IS_Selected) == 0 or (item.state & US_IS_Disabled) != 0:
		US_SetPrintColour(us_menu_foregroundColour)
	else:
		US_SetPrintColour(us_menu_disabledColour)

	VHB_DrawPropString(item.caption, item.x + 8, item.y + 1, 1, US_GetPrintColour())

	US_SetPrintColour(15)


## const char *footer_str[3] ("" for NULL)
var footer_str: PackedStringArray = ["", "", ""]


func USL_DrawMenuFooter() -> void:
	var w: int = 0    # uint16_t
	var h: int = 0
	var wh: PackedInt32Array

	US_SetPrintColour(us_menu_foregroundColour)

	# "Arrows move"
	VHB_DrawPropString(footer_str[2], 78, 135, 1, US_GetPrintColour())

	# "Enter selects"
	wh = VH_MeasurePropString(footer_str[1], 1)
	w = wh[0]
	h = wh[1]
	VHB_DrawPropString(footer_str[1], 230 - w, 135, 1, US_GetPrintColour())

	# "Esc to quit/back out"
	wh = VH_MeasurePropString(footer_str[0], 1)
	w = wh[0]
	h = wh[1]
	VHB_DrawPropString(footer_str[0], 74 + ((160 - w) / 2), 135 + h + 1, 1, US_GetPrintColour())

	US_SetPrintColour(0)

	VHB_HLine(CK_INT("us_menu_horzLineX1", 77), CK_INT("us_menu_horzLineX2", 231), CK_INT("us_menu_horzLineY2", 133), us_menu_foregroundColour)


# (USL_DrawScrollIcons, USL_ScrollTo and USL_ScrollCardItems are the
# non-vanilla build's.)


func USL_DrawCard() -> void:
	# Run the custom draw procedure if it exists
	if us_currentCard.msgCallback != &"" and call(us_currentCard.msgCallback, US_MSG_Draw, null):
		return

	# Draw the header (if any))
	if us_currentCard.gfxChunk.begins_with("TEXT:"):
		# MENU-02: a card the shell adds has no picture: its title in the menu font, set into the line
		# as the pictures' titles are (a short dash, the title in the selected item's green, the line on)
		var line_y: int = CK_INT("us_menu_horzLineY1", 55)
		VHB_HLine(CK_INT("us_menu_horzLineX1", 77), CK_INT("us_menu_horzLineX2", 231), line_y, us_menu_foregroundColour)
		var title: String = us_currentCard.gfxChunk.substr(5)
		var tw: int = VH_MeasurePropString(title, 1)[0]
		VHB_Bar(82, line_y - 2, tw + 4, 9, us_menu_backgroundColour)
		VHB_DrawPropString(title, 84, line_y - 1, 1, us_menu_disabledColour)
	elif us_currentCard.gfxChunk != "":
		VHB_HLine(CK_INT("us_menu_horzLineX1", 77), CK_INT("us_menu_horzLineX2", 231), CK_INT("us_menu_horzLineY1", 55), us_menu_foregroundColour)
		VHB_DrawBitmap(80, 48, CK_LookupChunk(us_currentCard.gfxChunk))

	# Draw the Footer
	USL_DrawMenuFooter()

	# Draw each card item
	if not us_currentCard.items.is_empty():
		var itemX: int = us_currentCard.x + 74
		if itemX % 8 != 0:
			itemX += (8 - itemX % 8)

		var itemY: int = us_currentCard.y + 60

		var itemIndex: int = 0
		while (us_currentCard.items[itemIndex] as US_CardItem).type != US_ITEM_None:
			var item: US_CardItem = us_currentCard.items[itemIndex]

			if (item.state & US_IS_Gap) != 0:
				itemY += 8

			item.x = itemX
			item.y = itemY

			USL_DrawCardItem(item)
			itemY += 8
			itemIndex += 1

		if us_currentCard.msgCallback != &"":
			call(us_currentCard.msgCallback, US_MSG_PostDraw, null)


func US_DrawCards() -> void:
	# (no card yet: a level started straight from the shell or TED, where C's pointer is NULL; and the
	# shell's quicksave, which asks its question over the play: nothing of the watch is drawn)
	if us_currentCard == null:
		return
	# Draw the watch screen and the active card
	if not us_currentCard.items.is_empty() or us_currentCard.gfxChunk != "":
		VHB_DrawBitmap(0, 0, CK_CHUNKNUM("PIC_WRISTWATCH"))
		USL_DrawCard()

	VL_SetScrollCoords(0, 0)
	VH_UpdateScreen()


## Returns [x, y] (the C's out-parameters, uint16_t).
func USL_DialogSetup(w: int, h: int) -> PackedInt32Array:
	var x: int = 0
	var y: int = 0
	VHB_DrawMaskedBitmap(74, 48, CK_CHUNKNUM("MPIC_WRISTWATCHSCREEN"))

	# Calculate the position
	x = u16(74 + (160 - w) / 2)
	y = u16(48 + (102 - h) / 2)

	# Fill the background
	VHB_Bar(x, y, w + 1, h + 1, us_menu_backgroundColour)

	# Draw the border
	VHB_HLine(x - 1, x + w + 1, y - 1, us_menu_foregroundColour)
	VHB_HLine(x - 1, x + w + 1, y + h + 1, us_menu_foregroundColour)
	VHB_VLine(y - 1, y + h + 1, x - 1, us_menu_foregroundColour)
	VHB_VLine(y - 1, y + h + 1, x + w + 1, us_menu_foregroundColour)
	return PackedInt32Array([x, y])


func USL_LoadSaveMessage(s1: String, s2: String) -> void:
	var x: int = 0
	var y: int = 0
	var w2: int = 0
	var h: int = 0
	var w1: int = 0
	var window_w: int = 0
	var print_x: int = 0
	var print_y: int = 0
	var buf: String = ""    # char buf[36]
	var wh: PackedInt32Array

	buf = ("'%s'" % s2).substr(0, 35)

	wh = VH_MeasurePropString(s1, 1)
	w1 = wh[0]
	h = wh[1]
	wh = VH_MeasurePropString(buf, 1)
	w2 = wh[0]
	h = wh[1]

	window_w = w1 if w1 > w2 else w2
	window_w = u16(window_w + 6)
	var xy: PackedInt32Array = USL_DialogSetup(window_w, u16((h * 2) + 2))
	x = xy[0]
	y = xy[1]

	print_y = u16(y + 2)
	print_x = u16(x + (window_w - w1) / 2)
	VHB_DrawPropString(s1, print_x, print_y, 1, US_GetPrintColour())

	print_y = u16(print_y + h)
	print_x = u16(x + (window_w - w2) / 2)
	VHB_DrawPropString(buf, print_x, print_y, 1, US_GetPrintColour())

	VH_UpdateScreen()


## s3 "" is C's NULL (no caller passes an empty third line).
func USL_CtlDialog(s1: String, s2: String, s3: String) -> int:
	var w1: int = 0    # uint16_t
	var w2: int = 0
	var w3: int = 0
	var h: int = 0
	var sh: int = 0
	var window_w: int = 0
	var x: int = 0
	var y: int = 0
	var state: IN_ControlFrame = IN_ControlFrame.new()
	var k: int = 0    # char

	var print_x: int = 0
	var print_y: int = 0
	var wh: PackedInt32Array

	# Find the lengths of the strings
	wh = VH_MeasurePropString(s1, 1)
	w1 = wh[0]
	h = wh[1]
	wh = VH_MeasurePropString(s2, 1)
	w2 = wh[0]
	h = wh[1]
	if s3 != "":
		wh = VH_MeasurePropString(s3, 1)
		w3 = wh[0]
		h = wh[1]
	else:
		w3 = 0

	# Work out the window size and position and draw it
	# (as C: when w2 >= w1 the window takes w2, however long the third line is)
	window_w = ((w1 if w1 > w3 else w3) if w1 > w2 else w2)
	window_w = u16(window_w + 7)
	sh = h
	h = u16(h * (5 if s3 != "" else 4))
	var xy: PackedInt32Array = USL_DialogSetup(window_w, h)
	x = xy[0]
	y = xy[1]

	# Print the message
	US_SetPrintColour(us_menu_disabledColour)
	print_x = u16(x + (window_w - w1) / 2)
	print_y = u16(y + sh + 1)
	VHB_DrawPropString(s1, print_x, print_y, 1, US_GetPrintColour())

	print_y = u16(print_y + (sh * 2) - 1)
	VHB_HLine(x + 3, x + window_w - 3, print_y, us_menu_foregroundColour)

	# Print the OK prompt
	print_y = u16(print_y + 2)
	US_SetPrintColour(us_menu_foregroundColour)
	print_x = u16(x + (window_w - w2) / 2)
	VHB_DrawPropString(s2, print_x, print_y, 1, US_GetPrintColour())

	# Print the third string ( if any )
	print_y = u16(print_y + sh)
	if s3 != "":
		print_x = u16(x + (window_w - w3) / 2)
		VHB_DrawPropString(s3, print_x, print_y, 1, US_GetPrintColour())

	VH_UpdateScreen()

	# Wait for button1 or a key to be pressed
	IN_ClearKeysDown()
	while true:    # do { ... } while (k == IN_SC_None)
		k = IN_SC_None
		VL_Yield()    # Keep CPU usage low
		IN_PumpEvents()
		IN_ReadControls(0, state)
		if state.jump:
			k = IN_SC_Y
		elif state.pogo:
			k = IN_SC_Escape
		else:
			k = s8(IN_GetLastScan())
		VL_Present()
		if k != IN_SC_None or quitting:
			break

	# Wait for the button to be released
	while true:    # do { ... } while (state.jump || state.pogo)
		VL_Yield()    # Keep CPU usage low
		IN_PumpEvents()
		IN_ReadControls(0, state)
		VL_Present()
		if not (state.jump or state.pogo) or quitting:
			break
	IN_ClearKeysDown()

	US_DrawCards()

	# Return true or false based on the user's choice
	if k == IN_SC_Y:
		return 1
	else:
		return 0


func USL_ConfirmComm(command: int) -> int:
	var result: int = 0
	var s1: String = ""
	var s2: String = ""
	var s3: String = ""
	var ask_user: int = 0

	if command == US_Comm_None:
		Quit("USL_ConfirmComm() - empty comm")    # quit
		return 0

	result = 1
	ask_user = 0
	s3 = "ESC TO BACK OUT"
	match command:
		US_Comm_EndGame:
			s1 = "REALLY END CURRENT GAME?"
			s2 = "PRESS Y TO END IT"
			if game_in_progress != 0 and game_unsaved != 0:
				ask_user = 1

		US_Comm_Quit:
			s1 = "REALLY QUIT?"
			s2 = "PRESS Y TO QUIT"
			ask_user = 1

		4:    # (US_Comm_LoadGame)
			s1 = "YOU'RE IN A GAME"
			s2 = "PRESS Y TO LOAD GAME"
			if game_in_progress != 0 and game_unsaved != 0:
				ask_user = 1

		US_Comm_NewEasyGame, US_Comm_NewNormalGame, US_Comm_NewHardGame:
			s1 = "YOU'RE IN A GAME"
			s2 = "PRESS Y FOR NEW GAME"
			if game_in_progress != 0 and game_unsaved != 0:
				ask_user = 1

		_:
			pass

	result = USL_CtlDialog(s1, s2, s3) if ask_user != 0 else 1
	if result != 0:
		us_currentCommand = command
		command_confirmed = true
	return result


func USL_HandleError(_error: int) -> void:
	# FIXME
	pass


func USL_EnableMenuItems(card: US_Card) -> void:
	if not card.items.is_empty():
		var i: int = 0
		var item: US_CardItem = card.items[i]
		while item.type != US_ITEM_None:
			item.state &= ~US_IS_Disabled
			item.state &= ~US_IS_Selected
			item.state &= ~US_IS_Checked

			if item.subMenu != null:
				USL_EnableMenuItems(item.subMenu)
			i += 1
			item = card.items[i]


func USL_GetCheckedItem(card: US_Card) -> int:
	var index: int = 0

	index = 0
	var item: US_CardItem = card.items[index]
	while item.type != US_ITEM_None:
		if (item.state & US_IS_Checked) != 0:
			return index
		index += 1
		item = card.items[index]
	return -1


func USL_SelectCardItem(card: US_Card, index: int, redraw: int) -> void:
	var item: US_CardItem = null

	if card.selectedItem != index:
		item = card.items[card.selectedItem]
		item.state &= ~US_IS_Selected
		if redraw != 0:
			USL_DrawCardItem(item)
	card.selectedItem = index
	item = card.items[card.selectedItem]
	item.state |= US_IS_Selected
	if redraw != 0:
		USL_DrawCardItem(item)


func US_SelectItem(card: US_Card, itemIndex: int, redraw: bool) -> void:
	var item: US_CardItem = null

	# If the item is not already selected
	if card.selectedItem != itemIndex:
		# Unselect the old item
		var oldItem: US_CardItem = card.items[card.selectedItem]
		oldItem.state &= ~US_IS_Selected
		if redraw:
			USL_DrawCardItem(oldItem)

	# Select the new item.
	card.selectedItem = itemIndex
	item = card.items[card.selectedItem]
	item.state |= US_IS_Selected
	if redraw:
		USL_DrawCardItem(item)


func USL_CheckCardItem(card: US_Card, itemIndex: int, redraw: bool) -> void:
	var i: int = 0

	US_SelectItem(card, itemIndex, redraw)

	i = 0
	var cardItem: US_CardItem = card.items[i]
	while cardItem.type != US_ITEM_None:
		if cardItem.type == US_ITEM_Radio:
			if i == itemIndex:
				# Check the item that needs to be checked
				cardItem.state |= US_IS_Checked
				if redraw:
					USL_DrawCardItem(cardItem)
			elif (cardItem.state & US_IS_Checked) != 0:
				# Uncheck the previously checked item
				cardItem.state &= ~US_IS_Checked
				if redraw:
					USL_DrawCardItem(cardItem)
		i += 1
		cardItem = card.items[i]


func US_SelectNextItem() -> void:
	if (us_currentCard.items[us_currentCard.selectedItem + 1] as US_CardItem).type != US_ITEM_None:
		US_SelectItem(us_currentCard, us_currentCard.selectedItem + 1, true)


func US_SelectPrevItem() -> void:
	if us_currentCard.selectedItem > 0:
		US_SelectItem(us_currentCard, us_currentCard.selectedItem - 1, true)


func USL_SetMenuFooter() -> void:
	footer_str[2] = "Arrows move"
	footer_str[1] = "Enter selects"
	footer_str[0] = "ESC to back out" if us_cardStackIndex != 0 else "ESC to quit"
	USL_SelectCardItem(us_currentCard, us_currentCard.selectedItem, 0)
	US_DrawCards()


func USL_DownLevel(card: US_Card) -> void:
	if card == null:
		Quit("USL_DownLevel() - nil card")
		return

	USL_PushCard(card)

	if card.msgCallback != &"":
		if call(card.msgCallback, US_MSG_CardEntered, null):
			USL_PopCard()

	# TODO:  Handle Joystick/Kbd footer stuff
	USL_SetMenuFooter()


func USL_UpLevel() -> void:
	if us_cardStackIndex == 0:
		USL_ConfirmComm(US_Comm_Quit)
		return

	if not us_currentCard.items.is_empty():
		(us_currentCard.items[us_currentCard.selectedItem] as US_CardItem).state &= ~US_IS_Selected

	USL_PopCard()

	# TODO: Footer stuff
	USL_SetMenuFooter()


func US_SelectCurrentItem() -> void:
	var item: US_CardItem = us_currentCard.items[us_currentCard.selectedItem]

	# Play disallowed sound if menu item is disabled
	if (item.state & US_IS_Disabled) != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
		return

	# Handle the various Card item types
	match item.type:
		US_ITEM_Normal:
			if us_currentCard.msgCallback != &"":
				if call(us_currentCard.msgCallback, US_MSG_ItemEntered, item):
					return    # (break: nothing follows the switch)
			USL_ConfirmComm(item.command)
			return
		US_ITEM_Radio:
			USL_CheckCardItem(us_currentCard, us_currentCard.selectedItem, true)
			return
		US_ITEM_Submenu:
			USL_DownLevel(item.subMenu)
		_:
			pass


func USL_UpdateCards() -> void:
	var i: int = 0

	# SFX and Music menus
	i = SD_GetSoundMode()

	if i == sdm_AdLib and SD_GetQuietSfx():
		i += 1

	USL_CheckCardItem(ck_us_soundMenu, i, false)
	USL_CheckCardItem(ck_us_musicMenu, SD_GetMusicMode(), false)

	if not SD_IsAdlibPresent():
		# Disable adlib & sb menu items
		(ck_us_soundMenuItems[2] as US_CardItem).state |= US_IS_Disabled
		(ck_us_soundMenuItems[3] as US_CardItem).state |= US_IS_Disabled
		(ck_us_musicMenuItems[1] as US_CardItem).state |= US_IS_Disabled

	# Joystick and gamepad menu items
	if true:    # !joystick_present[0] )
		(ck_us_joystickItems[0] as US_CardItem).state |= US_IS_Disabled
	if true:    # !joystick_present[1] )
		(ck_us_joystickItems[1] as US_CardItem).state |= US_IS_Disabled
	(ck_us_mainOriginal[4] as US_CardItem).caption = "RETURN TO GAME" if game_in_progress != 0 else "RETURN TO DEMO"
	# Save game and end game items
	if game_in_progress == 0:
		(ck_us_mainOriginal[2] as US_CardItem).state |= US_IS_Disabled
		(ck_us_mainOriginal[5] as US_CardItem).state |= US_IS_Disabled

	# Hilite 'return to game' or 'new game' option
	ck_us_mainMenu.selectedItem = ck_us_mainMenuItems.find(ck_us_mainOriginal[4]) if game_in_progress != 0 else 0

	# Update the options menu
	CK_US_UpdateOptionsMenus()
	CK_US_ShellCaptions()


func USL_BeginCards() -> void:
	CA_UpLevel()

	# DOS (USL_SetUpCtlPanel): the controls' and paddle war's lumps, the watch
	# font and the menu's mask are marked and cached under the "Control Panel"
	# box (omnispeak caches every bitmap at once, with no box; keen4_level05_a
	# shows the box for 9 refreshes)
	var starts: PackedInt32Array = CK_VAR_GetIntArray("lumpStarts")
	var ends: PackedInt32Array = CK_VAR_GetIntArray("lumpEnds")
	for lump: String in ["LUMP_CONTROLS", "LUMP_PADDLE"]:
		var n: int = CK_INT(lump, -1)
		if n >= 0 and n < starts.size():
			for c: int in range(starts[n], ends[n] + 1):
				CA_MarkGrChunk(c)
	CA_MarkGrChunk(CK_CHUNKNUM("FON_WATCHFONT"))
	CA_MarkGrChunk(int(ca_gfxInfoE.offMasked))    # the wristwatch screen's mask
	CA_CacheMarks("Control Panel")

	# the tile8's (cached since the start; no work)
	CA_CacheGrChunk(int(ca_gfxInfoE.offTiles8))
	CA_CacheGrChunk(int(ca_gfxInfoE.offTiles8m))

	CA_LoadAllSounds()

	US_SetPrintFont(1)
	# US_SetPrintFunctions(VW_MeasurePropString, VWB_DrawPropString);
	US_SetPrintColour(15)

	VL_ClearScreen(3)
	# RF_Reset();

	us_currentCommand = US_Comm_None

	USL_EnableMenuItems(ck_us_mainMenu)

	USL_UpdateCards()

	US_SetupCards(ck_us_mainMenu)

	USL_SetMenuFooter()

	if game_in_progress != 0:
		game_unsaved = 1

	IN_ClearKeysDown()


func USL_HandleComm(command: int) -> void:
	match command:
		US_Comm_EndGame:    # end game
			load_game_error = 1
			return

		US_Comm_Quit:    # quit
			quit_to_dos = 1
			return

		US_Comm_NewEasyGame:    # easy game
			ck_startingDifficulty = D_Easy
			return

		US_Comm_NewNormalGame:    # normal game
			ck_startingDifficulty = D_Normal
			return

		US_Comm_NewHardGame:    # hard game
			ck_startingDifficulty = D_Hard
			return

		US_Comm_ReturnToGame, 4:    # return to game, ?
			return

		_:
			Quit("USL_HandleComm() - unknown")    # quit


func USL_SetSoundAndMusic() -> void:
	var i: int = 0

	i = USL_GetCheckedItem(ck_us_soundMenu)
	# Quiet AdLib sound effects
	if i == 3:
		SD_SetQuietSfx(true)
		i -= 1
	else:
		SD_SetQuietSfx(false)
	if i != SD_GetSoundMode():
		SD_SetSoundMode(i)
	i = USL_GetCheckedItem(ck_us_musicMenu)
	if i != SD_GetMusicMode():
		SD_SetMusicMode(i)


func USL_EndCards() -> void:
	USL_SetSoundAndMusic()

	if us_currentCommand != US_Comm_None:
		USL_HandleComm(us_currentCommand)

	US_SetPrintFont(0)
	US_SetPrintColour(15)

	if ck_startingDifficulty != 0 and p_exit_menu != &"":
		call(p_exit_menu)

	if quit_to_dos != 0:
		# This should be TEDDeath(), but we don't actually have TED.
		if us_tedLevel:
			Quit("")    # Quit(NULL)
			return
		US_CenterWindow(0x14, 3)
		US_SetPrintColour(3)
		US_PrintCentered("Quitting...")
		US_SetPrintColour(15)
		VH_UpdateScreen()
		Quit("")    # Quit(NULL)
		return

	IN_ClearKeysDown()
	SD_WaitSoundDone()
	# FIXME: Cyan should be drawn, but this results in a cyan background
	# for longer than expected (possibly due to legal of EGA features)
	# VL_ClearScreen(3); // Draw Cyan
	VL_ClearScreen(0)    # For now we draw black
	CA_DownLevel()
	CA_LoadAllSounds()


# What is this function for?
func USL_EnterCurrentItem() -> void:
	var item: US_CardItem = us_currentCard.items[us_currentCard.selectedItem]

	if (item.state & US_IS_Disabled) != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_NEEDKEYCARD"))
		return

	match item.type:
		US_ITEM_Normal:
			if us_currentCard.msgCallback != &"":
				if call(us_currentCard.msgCallback, US_MSG_ItemEntered, item):
					return    # (break: nothing follows the switch)

			USL_ConfirmComm(item.command)
			return
		US_ITEM_Radio:
			USL_CheckCardItem(us_currentCard, us_currentCard.selectedItem, true)
			return
		US_ITEM_Submenu:
			USL_PushCard(item.subMenu)
		_:
			pass


func US_RunCards() -> void:
	var controller_dy: int = 0              # int16_t
	var prev_controller_motion: int = 0     # int16_t
	var blink_time: int = 0                 # uint32_t (set before it is first read)
	var _last_cursor_time: int = 0          # uint32_t (only the non-vanilla build reads it)
	# ControlInfo status;
	var action_taken: bool = false

	var cursor: bool = false

	# clear all keys except for function keys
	if IN_GetLastScan() < IN_SC_F1 or IN_GetLastScan() > IN_SC_F10:
		IN_ClearKeysDown()

	CK_US_ShellCards()

	# load all menu stuff and draw main menu
	USL_BeginCards()
	US_DrawCards()
	vm.mark("menu")    # tests time their keys from the menu's first picture

	controller_dy = 0
	prev_controller_motion = 0
	command_confirmed = false
	cursor = true
	action_taken = true

	while not command_confirmed:
		# (C's Quit never returns; the port's leaves the menu where it stands)
		if quitting:
			return
		var item: US_CardItem = us_currentCard.items[us_currentCard.selectedItem]

		var lastScan: int = IN_GetLastScan()

		# Draw the icon for the current item highlighted or not
		if action_taken:
			blink_time = (SD_GetTimeCount() + 35) & 0xFFFFFFFF    # 1/2 second flashes
			action_taken = false

		# draw icon with cursor blink
		if SD_GetTimeCount() >= blink_time:
			cursor = not cursor
			action_taken = true

			if not cursor:
				item.state &= ~US_IS_Selected

			USL_DrawCardItemIcon(item)
			item.state |= US_IS_Selected

		VH_UpdateScreen()

		if lastScan != IN_SC_None:
			# switch (lastScan): F1 falls through to default in Keen 6
			var to_default: bool = false
			if lastScan == IN_SC_UpArrow:
				US_SelectPrevItem()
				action_taken = true
			elif lastScan == IN_SC_DownArrow:
				US_SelectNextItem()
				action_taken = true
			elif lastScan == IN_SC_Enter:
				US_SelectCurrentItem()
				action_taken = true
			elif lastScan == IN_SC_Escape:
				USL_UpLevel()
				action_taken = true
			elif lastScan == IN_SC_F1:
				# HAS_HELPSCREEN
				if ck_currentEpisode_ep != EP_CK6:
					HelpScreens()
					US_DrawCards()
					action_taken = true
				else:
					# Fall-through
					to_default = true
			else:
				to_default = true
			if to_default:
				if lastScan == int(in_kbdControls.jump) or lastScan == int(in_kbdControls.pogo):
					US_SelectCurrentItem()
					action_taken = true
				else:
					var i: int = 0
					while (us_currentCard.items[i] as US_CardItem).type != US_ITEM_None:
						if lastScan == (us_currentCard.items[i] as US_CardItem).shortcutKey:
							US_SelectItem(us_currentCard, i, true)
							action_taken = true
							break
						i += 1
			IN_ClearKeysDown()
		else:
			# (C names this IN_Cursor `cursor`, shadowing the blink flag)
			var in_cursor: IN_Cursor = IN_Cursor.new()
			IN_ReadCursor(in_cursor)

			controller_dy = s16(controller_dy + in_cursor.yMotion)
			prev_controller_motion = s16(in_cursor.yMotion)

			if in_cursor.button0:
				while in_cursor.button0 and not quitting:
					IN_ReadCursor(in_cursor)
					IN_PumpEvents()
					VL_Present()
				US_SelectCurrentItem()
				action_taken = true
			elif in_cursor.button1:
				while in_cursor.button1 and not quitting:
					IN_ReadCursor(in_cursor)
					IN_PumpEvents()
					VL_Present()
				USL_UpLevel()
				action_taken = true
			elif controller_dy < -US_MENU_MOTION_SPEED:
				controller_dy = s16(controller_dy + US_MENU_MOTION_SPEED)
				US_SelectPrevItem()
				action_taken = true
			elif controller_dy > US_MENU_MOTION_SPEED:
				controller_dy = s16(controller_dy - US_MENU_MOTION_SPEED)
				US_SelectNextItem()
				action_taken = true
		IN_PumpEvents()
		# CK_SetTicsPerFrame();
		VL_Present()

	if quitting:
		return
	USL_EndCards()


# ===================================================================== the shell's rows (MENU-02)

## The shell's Options rows (an OptionsModel) while a player is at the controls; null in headless runs
## and the oracle comparisons, which see the original cards.
var options: Object = null
var _shell_cards_built: bool = false
## A row's toggle card -> [the row's key, its item]
var _shell_toggles: Dictionary = {}
## The card the DISPLAY item opens.
var ck_us_displayMenu: US_Card = null


## MENU-02 (docs/MENUS.md): MODE first on the OPTIONS card (SVGA COMPATIBILITY gone), and a DISPLAY card
## on CONFIGURE after MUSIC; CHEAT-01: a CHEATS card on MAIN after CONFIGURE (the toggles, then MORE
## CHEATS for the one-shots). Each row is an item reading "LABEL (VALUE)" (a one-shot: its label) that,
## chosen, does its thing and says so, as the original OPTIONS items do.
func CK_US_ShellCards() -> void:
	if options == null or _shell_cards_built:
		return
	_shell_cards_built = true
	var mode_rows: Array = (options.page("options") as Array).filter(func(r: Dictionary) -> bool: return r.key == "mode")
	for r: Dictionary in mode_rows:
		ck_us_optionsMenuItems.insert(0, _shell_row_item(r.key, "option"))
	# SAVE-02: QUICKSAVE F5/F9 and QUICKSAVE ASKS after MODE
	var after_mode: int = 1
	for r: Dictionary in options.page("options"):
		if r.key in ["quicksave", "quicksave_confirm"]:
			ck_us_optionsMenuItems.insert(after_mode, _shell_row_item(r.key, "option"))
			after_mode += 1
	# Keen 6: CREATURE QUESTION last (on: the original asks before a new game)
	for r: Dictionary in options.page("options"):
		if r.key == "creature_question":
			ck_us_optionsMenuItems.insert(ck_us_optionsMenuItems.size() - 1, _shell_row_item(r.key, "option"))
	# SVGA COMPATIBILITY steers the original's EGA register writes, which the shell's display does not use
	ck_us_optionsMenuItems.erase(ck_us_optionsOriginal[3])
	var display_items: Array = []
	for r: Dictionary in options.page("display"):
		if r.kind == "value":
			display_items.append(_shell_row_item(r.key, "option"))
	display_items.append(_us_item_end())
	ck_us_displayMenu = _us_card(8, 0, "TEXT:DISPLAY", 0, display_items, &"", 0, 0, 0)
	ck_us_configureMenuItems.insert(2, _us_item(US_ITEM_Submenu, 0, IN_SC_D, "DISPLAY", US_Comm_None, ck_us_displayMenu))
	# FIX-01: FIXES after OPTIONS, when the game has any
	var fix_items: Array = []
	for r: Dictionary in options.page("fixes"):
		if r.kind == "value":
			fix_items.append(_shell_row_item(r.key, "option"))
	if not fix_items.is_empty():
		fix_items.append(_us_item_end())
		var fixes_card: US_Card = _us_card(8, 0, "TEXT:FIXES", 0, fix_items, &"", 0, 0, 0)
		ck_us_configureMenuItems.insert(ck_us_configureMenuItems.find(ck_us_optionsItem()) + 1,
			_us_item(US_ITEM_Submenu, 0, IN_SC_F, "FIXES", US_Comm_None, fixes_card))
	# the cheats: toggles on the CHEATS card, the one-shots a card below it
	var more_items: Array = []
	for r: Dictionary in CheatsModel.rows(self, "once"):
		more_items.append(_shell_row_item(r.key, "once"))
	if CheatsModel.rows(self, "pick").any(func(r: Dictionary) -> bool: return r.key == "level_select"):
		more_items.append(_us_item(US_ITEM_Submenu, 0, IN_SC_L, "LEVEL SELECT", US_Comm_None, _shell_level_cards()))
	# CHEAT-05: the originals' own codes, so they can be found (each says what it does when chosen)
	var code_items: Array = []
	for c: Array in CheatsModel.CODES.get("galaxy", []):
		var item: US_CardItem = _shell_row_item("code:" + str(c[0]), "info")
		item.caption = str(c[0])
		code_items.append(item)
	if not code_items.is_empty():
		code_items.append(_us_item_end())
		more_items.append(_us_item(US_ITEM_Submenu, 0, IN_SC_O, "ORIGINAL CODES", US_Comm_None,
			_us_card(8, 0, "TEXT:ORIGINAL CODES", 0, code_items, &"", 0, 0, 0)))
	var cheat_items: Array = []
	for r: Dictionary in CheatsModel.rows(self, "toggle"):
		cheat_items.append(_shell_row_item(r.key, "cheat"))
	if not more_items.is_empty():
		more_items.append(_us_item_end())
		var more: US_Card = _us_card(8, 0, "TEXT:MORE CHEATS", 0, more_items, &"", 0, 0, 0)
		cheat_items.append(_us_item(US_ITEM_Submenu, 0, IN_SC_M, "MORE CHEATS", US_Comm_None, more))
	if not cheat_items.is_empty():
		cheat_items.append(_us_item_end())
		ck_us_cheatsMenu = _us_card(8, 0, "TEXT:CHEATS", 0, cheat_items, &"", 0, 0, 0)
		ck_us_mainMenuItems.insert(ck_us_mainMenuItems.find(ck_us_mainOriginal[3]) + 1,
			_us_item(US_ITEM_Submenu, 0, IN_SC_None, "CHEATS", US_Comm_None, ck_us_cheatsMenu))
		# nine items: the card's items start where CONFIGURE's do, so QUIT clears the footer's line
		ck_us_mainMenu.y = 0
	CK_US_ShellCaptions()


## The card the CHEATS item opens.
var ck_us_cheatsMenu: US_Card = null


## CONFIGURE's OPTIONS item (the one whose card is OPTIONS').
func ck_us_optionsItem() -> US_CardItem:
	for item: US_CardItem in ck_us_configureMenuItems:
		if item.subMenu == ck_us_optionsMenu:
			return item
	return null


## LEVEL SELECT (CHEAT-04): the game's levels by their own names, eight to a card, each card's last
## item MORE LEVELS opening the next. Chosen in a game, a level is entered as F10+W enters it.
func _shell_level_cards() -> US_Card:
	var pages: Array = []
	var items: Array = []
	# the warp range, as far as the game names its levels (Keen 5's names stop short of its range)
	var names: PackedStringArray = CK_VAR_GetStringArray("ck_str_levelNames")
	for n: int in range(CK_INT("ck_minWarpLevel", 1), mini(CK_INT("ck_maxWarpLevel", 18), names.size() - 1) + 1):
		var item: US_CardItem = _shell_row_item("level:%d" % n, "warp")
		item.caption = names[n].replace("
", " ").to_upper().left(24)
		items.append(item)
		if items.size() == 8:
			pages.append(items)
			items = []
	if not items.is_empty():
		pages.append(items)
	var next: US_Card = null
	for i: int in range(pages.size() - 1, -1, -1):
		var page: Array = pages[i]
		if next != null:
			page.append(_us_item(US_ITEM_Submenu, 0, IN_SC_M, "MORE LEVELS", US_Comm_None, next))
		page.append(_us_item_end())
		next = _us_card(8, 0, "TEXT:LEVEL SELECT", 0, page, &"", 0, 0, 0)
	return next


func _shell_row_item(key: String, kind: String) -> US_CardItem:
	var card: US_Card = _us_card(0, 0, "", 0, [], &"CK_US_ShellRowProc", 0, 0, 0)
	var item: US_CardItem = _us_item(US_ITEM_Submenu, 0, IN_SC_None, "", US_Comm_None, card)
	_shell_toggles[card] = [key, item, kind]
	return item


## Every shell row's caption from the model's current values (and the engine's, for the cheats, which
## the originals' key combinations may have changed); the cheat rows greyed with no game in progress.
func CK_US_ShellCaptions() -> void:
	if options == null:
		return
	var rows: Dictionary = {}
	for page_name: String in ["options", "display", "fixes"]:
		for r: Dictionary in options.page(page_name):
			rows[r.key] = r
	for r: Dictionary in CheatsModel.rows(self):
		rows["cheat:" + r.key] = r
	for card: US_Card in _shell_toggles:
		var key: String = _shell_toggles[card][0]
		var kind: String = _shell_toggles[card][2]
		var item: US_CardItem = _shell_toggles[card][1]
		if kind == "info":
			continue
		if kind == "warp":
			if shell_in_game():
				item.state &= ~US_IS_Disabled
			else:
				item.state |= US_IS_Disabled
			continue
		var r: Dictionary = rows.get(key if kind == "option" else "cheat:" + key, {})
		if r.is_empty():
			continue
		match kind:
			"option":
				item.caption = "%s (%s)" % [str(r.label).to_upper(), str(r.value).to_upper()]
			"cheat":
				item.caption = "%s (%s)" % [str(r.label).to_upper(), "ON" if r.value else "OFF"]
			"once":
				item.caption = str(r.label).to_upper()
		if kind != "option":
			if r.enabled:
				item.state &= ~US_IS_Disabled
			else:
				item.state |= US_IS_Disabled


## A shell row chosen: its value moves on (a one-shot: applied), and what happened is said as the
## original toggles say theirs.
func CK_US_ShellRowProc(msg: int, _item: US_CardItem) -> bool:
	if msg != US_MSG_CardEntered or not _shell_toggles.has(us_currentCard):
		return false
	var key: String = _shell_toggles[us_currentCard][0]
	var kind: String = _shell_toggles[us_currentCard][2]
	var said: String = ""
	match kind:
		"option":
			options.step(key, 1)
		"cheat":
			CheatsModel.toggle(self, key)
		"once":
			said = shell_cheat_fire(key)
		"info":
			# an original code: what holding it does, in the toggles' dialog
			for c: Array in CheatsModel.CODES.get("galaxy", []):
				if "code:" + str(c[0]) == key:
					USL_CtlDialog(str(c[0]), str(c[1]), "")
			return true
		"warp":
			# as F10+W: the level is entered at once, leaving the menu for the game
			ck_gameState.currentLevel = s16(int(key.substr(6)))
			ck_gameState.levelState = LS_AboutToRecordDemo
			us_currentCommand = US_Comm_ReturnToGame
			command_confirmed = true
			return true
	CK_US_ShellCaptions()
	var caption: String = (_shell_toggles[us_currentCard][1] as US_CardItem).caption
	USL_CtlDialog(caption, said if said != "" else "Press any key", "")
	return true


# ===================================================================== the shell's cheats (CHEAT-01)

## The cheats this engine has so far (CheatsModel's keys).
func shell_cheat_supported() -> Array:
	return ["god", "infinite_ammo", "infinite_lives", "no_clip", "jump", "slow_motion", "reveal_secrets",
		"freeze_enemies", "free_items", "extra_lives", "skip_level", "level_select"]


func shell_in_game() -> bool:
	return game_in_progress != 0


func shell_cheat_get(key: String) -> bool:
	match key:
		"god": return ck_godMode
		"infinite_ammo": return cheat_infiniteAmmo
		"infinite_lives": return cheat_infiniteLives
		"no_clip": return cheat_noClip
		"jump": return ck_gameState.jumpCheat
		"slow_motion": return ck_slowMotionEnabled
		"freeze_enemies": return cheat_freezeEnemies
		"reveal_secrets": return cheat_revealSecrets
	return false


func shell_cheat_set(key: String, on: bool) -> void:
	match key:
		"god": ck_godMode = on
		"infinite_ammo": cheat_infiniteAmmo = on
		"infinite_lives": cheat_infiniteLives = on
		"no_clip":
			cheat_noClip = on
			# at once in a level, as F10+N does (the world map's Keen keeps walking on paths)
			if ck_keenObj != null and ck_keenObj.type == CT_Player and ck_gameState.currentLevel != 0:
				ck_keenObj.clipped = CLIP_not if on else CLIP_normal
		"jump": ck_gameState.jumpCheat = on
		"slow_motion": ck_slowMotionEnabled = on
		"freeze_enemies": cheat_freezeEnemies = on
		"reveal_secrets": cheat_revealSecrets = on


## A one-shot applied; what it did, for the dialog.
func shell_cheat_fire(key: String) -> String:
	match key:
		"free_items":
			# B+A+T's items, without its window and wait
			ck_gameState.numShots = 99
			ck_gameState.numLives = s16(ck_gameState.numLives + 1)
			ck_gameState.ck5_securityCard = 1
			for i: int in range(4):
				ck_gameState.keyGems[i] = 1
			return "All keys, 99 shots, 1 life"
		"extra_lives":
			var before: int = ck_gameState.numLives
			ck_gameState.numLives = s16(mini(before + CheatsModel.EXTRA_LIVES, CheatsModel.MAX_LIVES))
			return "%d lives" % ck_gameState.numLives if ck_gameState.numLives != before else "Lives are full"
		"skip_level":
			if ck_gameState.currentLevel == 0:
				return "Only inside a level"
			# as F10+E: the level ends as if Keen walked out of it
			ck_gameState.levelState = LS_LevelComplete
			return "Level skipped"
	return ""

