# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's id_sd.c (the timer service, PC speaker and AdLib sound
# effects, AdLib music) with its DOS back-end id_sd_dos.c, id_in.c (keys,
# controls, demos) with its DOS back-end id_in_dos.c, and the audio parts of
# id_ca.c (CA_CacheAudioChunk, CA_LoadAllSounds), by David Gow and the
# Omnispeak authors, GPL v2 or later. Names, order and arithmetic follow
# omnispeak upstream (A10); the hardware is the emulated machine's.
class_name GalIO
extends GalRF
## The Galaxy engine's input and timer (SIM-G-01c, part 1). SD_Startup
## reprograms the machine's timer to 140 Hz (560 Hz with AdLib music) and
## installs SDL_t0Service as its interrupt: the tic count (sd_timeCount) rises
## every second call (every eighth at 560 Hz), 70 a second either way. The
## keyboard interrupt is INL_KeyService. PC speaker sounds reach the machine's
## speaker ports; AdLib register writes go to `sd_alOutHook` (the shell's OPL
## emulator), and nowhere when none is attached.

# ===================================================================== id_ca (audio)

var ca_audInfoE: Dictionary = {}
## The cached audio chunks: PackedByteArray or null.
var CA_audio: Array = []


func CA_CacheAudioChunk(chunk: int) -> void:
	if CA_audio.size() == 0:
		CA_audio.resize(data.num_audio_chunks() + 1)
	if chunk < 0 or chunk >= CA_audio.size():
		return
	if CA_audio[chunk] != null:
		return
	var a: PackedByteArray = data.audio_chunk(chunk)
	if a.is_empty():
		return
	CA_audio[chunk] = a
	cost("audiochunk")    # reading and expanding it (TIME-G)
	cost_n("audiobyte", a.size())


## Every sound effect of the current sound mode, cached.
func CA_LoadAllSounds() -> void:
	var start: int = 0
	match sd_soundMode:
		sdm_Off:
			return
		sdm_PC:
			start = int(ca_audInfoE.startPCSounds)
		sdm_AdLib:
			start = int(ca_audInfoE.startAdlibSounds)
	for i: int in range(int(ca_audInfoE.numSounds)):
		CA_CacheAudioChunk(start + i)


# ===================================================================== id_sd

const sdm_Off: int = 0
const sdm_PC: int = 1
const sdm_AdLib: int = 2
const smm_Off: int = 0
const smm_AdLib: int = 1

const SD_SOUND_PART_RATE_BASE: int = 1192030
const SD_ADLIB_REG_CHAR: int = 0x20
const SD_ADLIB_REG_VOLUME: int = 0x40
const SD_ADLIB_REG_ATTACK: int = 0x60
const SD_ADLIB_REG_SUSPEND: int = 0x80
const SD_ADLIB_REG_WAVE: int = 0xe0
const SD_ADLIB_REG_NOTE_LO: int = 0xa0
const SD_ADLIB_REG_NOTE_HI: int = 0xb0
const SD_ADLIB_REG_CONNECTION: int = 0xc0
const SD_ADLIB_REG_EFFECTS: int = 0xbd
const SD_ADLIB_NUM_CHANNELS: int = 10

var sd_soundMode: int = sdm_Off
var sd_musicMode: int = smm_Off
var sd_sfxPartRate: int = 140
var sd_haveAdlib: bool = false
var sd_started: bool = false
## The BIOS clock under the game's timer handler (ID_SD.C's SDL_t0Service): each
## interrupt adds the timer's divisor to the 16-bit TimerCount, and on its carry
## the old BIOS service runs and counts a tick of the time of day (18.2 a second
## on average). sd_pitDivisor: what SD_DOS_SetTimer0 last programmed.
var sd_pitDivisor: int = 0
var sd_timerCount: int = 0
var sd_biosTicks: int = 0
## the machine's time when SD_Startup took the timer over; the BIOS counted its
## own ticks before that
var sd_startupNow: int = -1
var sd_quietAdlibSfx: bool = false
var sd_currentSfxId: int = 0
var sd_currentSfxPriority: int = 0
var sd_scaledPITTimerDivisor: int = 1
## The offset of the current mode's sound effects in CA_audio (C's sd_sfxChunkArray).
var sd_sfxChunkOffset: int = 0
## SDL_t0Service's static counter.
var sd_t0count: int = 1

# PC speaker effect state
var sd_pc_currentSfxData: PackedByteArray = PackedByteArray()    # the chunk; data begins at 6
var sd_pc_playing: bool = false
var sd_pc_lastFrequency: int = 0
var sd_pc_currentSfxIndex: int = 0
var sd_pc_currentSfxLength: int = 0

# AdLib effect state
var sd_al_currentSfxData: PackedByteArray = PackedByteArray()    # the chunk; data begins at 23
var sd_al_playing: bool = false
var sd_al_currentSfxHiFreqByte: int = 0
var sd_al_currentSfxIndex: int = 0
var sd_al_currentSfxLength: int = 0

# AdLib music state
var sd_music_data: PackedByteArray = PackedByteArray()           # the track; events begin at 2
var sd_music_currentIndex: int = 0
var sd_music_currentTime: int = 0
var sd_music_nextEventTime: int = 0
var sd_music_trackSize: int = 0
var sd_musicStarted: bool = false

## The shell's OPL emulator: called with (register, value). Not game state.
var sd_alOutHook: Callable = Callable()


func SD_DOS_alOut(reg: int, val: int) -> void:
	if sd_alOutHook.is_valid():
		sd_alOutHook.call(reg & 0xFF, val & 0xFF)


func SD_DOS_PCSpkOn(on: bool, freq: int) -> void:
	if on:
		vm.out8(0x43, 0xb6)
		vm.out8(0x42, freq & 0xFF)
		vm.out8(0x42, (freq >> 8) & 0xFF)
		vm.out8(0x61, vm.in8(0x61) | 3)
	else:
		vm.out8(0x61, vm.in8(0x61) & 0xFC)


func SD_DOS_SetTimer0(int_8_divisor: int) -> void:
	sd_pitDivisor = int_8_divisor & 0xFFFF
	vm.out8(0x43, 0x36)
	vm.out8(0x40, int_8_divisor & 0xFF)
	vm.out8(0x40, (int_8_divisor >> 8) & 0xFF)


func SD_SetIntsPerSecond(tickrate: int) -> void:
	sd_scaledPITTimerDivisor = (SD_SOUND_PART_RATE_BASE / tickrate) & 0xFFFF
	SD_DOS_SetTimer0(sd_scaledPITTimerDivisor)


func SD_SetTimerSpeed() -> void:
	var scaleFactor: int = 4 if sd_musicMode == smm_AdLib else 1
	SD_SetIntsPerSecond(sd_sfxPartRate * scaleFactor)
	sd_scaledPITTimerDivisor = (sd_scaledPITTimerDivisor * 2 * scaleFactor) & 0xFFFF


func SD_SoundFinished() -> void:
	sd_currentSfxId = 0
	sd_currentSfxPriority = 0


# ---- PC speaker

func SD_PC_PlaySound(sound: PackedByteArray) -> void:
	sd_pc_lastFrequency = 255
	sd_pc_currentSfxLength = GalData.u32(sound, 0)
	sd_pc_currentSfxData = sound
	sd_pc_playing = true
	sd_pc_currentSfxIndex = 0


func SD_PC_StopSound() -> void:
	sd_pc_playing = false
	SD_DOS_PCSpkOn(false, 0)


func SD_PC_SoundService() -> void:
	if not sd_pc_playing:
		return
	var i: int = 6 + sd_pc_currentSfxIndex
	var currentFrequency: int = sd_pc_currentSfxData[i] if i < sd_pc_currentSfxData.size() else 0
	sd_pc_currentSfxIndex += 1
	if currentFrequency != sd_pc_lastFrequency:
		sd_pc_lastFrequency = currentFrequency
		if currentFrequency != 0:
			SD_DOS_PCSpkOn(true, currentFrequency * 60)
		else:
			SD_DOS_PCSpkOn(false, 0)
	if sd_pc_currentSfxIndex >= sd_pc_currentSfxLength:
		SD_DOS_PCSpkOn(false, 0)
		sd_pc_playing = false
		sd_pc_currentSfxIndex = 0
		SD_SoundFinished()


# ---- AdLib effects (the chunk: length 4, priority 2, instrument 16, block 1, data)

func SD_AL_SetAdlibSfxInstrument(inst: PackedByteArray, o: int) -> void:
	var m: int = 0
	var c: int = 3
	SD_DOS_alOut(m + SD_ADLIB_REG_CHAR, inst[o + 0])
	SD_DOS_alOut(m + SD_ADLIB_REG_VOLUME, inst[o + 2])
	SD_DOS_alOut(m + SD_ADLIB_REG_ATTACK, inst[o + 4])
	SD_DOS_alOut(m + SD_ADLIB_REG_SUSPEND, inst[o + 6])
	SD_DOS_alOut(m + SD_ADLIB_REG_WAVE, inst[o + 8])
	SD_DOS_alOut(c + SD_ADLIB_REG_CHAR, inst[o + 1])
	var cScale: int = inst[o + 3]
	if sd_quietAdlibSfx:
		cScale = 0x3F - cScale
		cScale = ((cScale >> 1) + (cScale >> 2)) & 0xFF
		cScale = 0x3F - cScale
	SD_DOS_alOut(c + SD_ADLIB_REG_VOLUME, cScale)
	SD_DOS_alOut(c + SD_ADLIB_REG_ATTACK, inst[o + 5])
	SD_DOS_alOut(c + SD_ADLIB_REG_SUSPEND, inst[o + 7])
	SD_DOS_alOut(c + SD_ADLIB_REG_WAVE, inst[o + 9])


func SD_AL_StopSound() -> void:
	SD_DOS_alOut(SD_ADLIB_REG_NOTE_HI, 0)
	sd_al_playing = false
	sd_al_currentSfxIndex = 0


func SD_AL_PlaySound(sound: PackedByteArray) -> void:
	SD_AL_StopSound()
	sd_al_currentSfxLength = GalData.u32(sound, 0)
	sd_al_currentSfxData = sound
	sd_al_playing = true
	sd_al_currentSfxIndex = 0
	var block: int = sound[22]
	sd_al_currentSfxHiFreqByte = ((block & 7) << 2) | 0x20
	if (sound[6 + 6] | sound[6 + 7]) == 0:
		Quit("SDL_ALPlaySound() - Bad instrument")
		return
	SD_AL_SetAdlibSfxInstrument(sound, 6)


func SD_AL_SoundService() -> void:
	if not sd_al_playing:
		return
	var i: int = 23 + sd_al_currentSfxIndex
	var currentFrequency: int = sd_al_currentSfxData[i] if i < sd_al_currentSfxData.size() else 0
	sd_al_currentSfxIndex += 1
	if currentFrequency == 0:
		SD_DOS_alOut(SD_ADLIB_REG_NOTE_HI, 0)
	else:
		SD_DOS_alOut(SD_ADLIB_REG_NOTE_LO, currentFrequency)
		SD_DOS_alOut(SD_ADLIB_REG_NOTE_HI, sd_al_currentSfxHiFreqByte)
	if sd_al_currentSfxIndex >= sd_al_currentSfxLength:
		SD_DOS_alOut(SD_ADLIB_REG_NOTE_HI, 0)
		sd_al_playing = false
		sd_al_currentSfxIndex = 0
		SD_SoundFinished()


# ---- AdLib music (a track: length 2, then reg, val, delay16 events)

func SD_AL_Reset() -> void:
	for i: int in range(255):
		SD_DOS_alOut(i, 0)
	SD_DOS_alOut(1, 0x20)


func SD_AL_MusicService() -> void:
	if not sd_musicStarted:
		return
	while sd_music_currentIndex < sd_music_trackSize:
		if sd_music_nextEventTime > sd_music_currentTime:
			break
		var o: int = 2 + sd_music_currentIndex
		var reg: int = sd_music_data[o] if o < sd_music_data.size() else 0
		var val: int = sd_music_data[o + 1] if o + 1 < sd_music_data.size() else 0
		var timeDelta: int = (sd_music_data[o + 2] if o + 2 < sd_music_data.size() else 0) | \
			((sd_music_data[o + 3] if o + 3 < sd_music_data.size() else 0) << 8)
		sd_music_currentIndex += 4
		SD_DOS_alOut(reg, val)
		sd_music_nextEventTime += timeDelta
	sd_music_currentTime += 1
	if sd_music_currentIndex >= sd_music_trackSize:
		sd_music_currentIndex = 0
		sd_music_currentTime = 0
		sd_music_nextEventTime = 0


func SD_SetSoundMode(mode: int) -> bool:
	var soundAvailable: bool = false
	var sfxChunkOffset: int = 0
	SD_StopSound()
	match mode:
		sdm_Off:
			soundAvailable = true
		sdm_PC:
			sfxChunkOffset = 0
			soundAvailable = true
		sdm_AdLib:
			if sd_haveAdlib:
				sfxChunkOffset = int(ca_audInfoE.numSounds)
				soundAvailable = true
	if soundAvailable and mode != sd_soundMode:
		sd_soundMode = mode
		sd_sfxChunkOffset = sfxChunkOffset
		SD_AL_Reset()
	SD_SetTimerSpeed()
	return soundAvailable


func SD_SetMusicMode(mode: int) -> bool:
	var musicAvailable: bool = false
	SD_MusicOff()
	match mode:
		smm_Off:
			musicAvailable = true
		smm_AdLib:
			if sd_haveAdlib:
				musicAvailable = true
	if musicAvailable:
		sd_musicMode = mode
	SD_SetTimerSpeed()
	return musicAvailable


func SD_GetSoundMode() -> int:
	return sd_soundMode


func SD_GetMusicMode() -> int:
	return sd_musicMode


func SD_SetQuietSfx(value: bool) -> void:
	sd_quietAdlibSfx = value


func SD_GetQuietSfx() -> bool:
	return sd_quietAdlibSfx


func SD_IsAdlibPresent() -> bool:
	return true


func SD_Startup() -> void:
	if sd_started:
		return
	ca_audInfoE = data.aud
	sd_sfxPartRate = CFG_GetConfigInt("sd_sfxPartRate", 140)
	vm.int8 = Callable(self, "SD_DOS_t0InterruptProxy")
	sd_startupNow = vm.now
	sd_haveAdlib = true
	SD_SetTimeCount(0)
	SD_SetSoundMode(sdm_Off)
	SD_SetMusicMode(smm_Off)
	sd_started = true


func SD_Default(gotit: bool, sd: int, sm: int) -> void:
	if not gotit:
		sd = sdm_AdLib
		sm = smm_AdLib
	if not sd_haveAdlib:
		sd = sdm_PC if sd == sdm_AdLib else sd
		sm = smm_Off
	if sd != sd_soundMode:
		SD_SetSoundMode(sd)
	if sm != sd_musicMode:
		SD_SetMusicMode(sm)


func SD_Shutdown() -> void:
	if not sd_started:
		return
	SD_MusicOff()
	SD_AL_Reset()
	SD_DOS_PCSpkOn(false, 0)
	vm.int8 = Callable()
	sd_started = false


func SD_PlaySound(sound: int) -> void:
	if sd_soundMode == sdm_Off:
		return
	var chunk: int = sd_sfxChunkOffset + sound
	var s: Variant = CA_audio[chunk] if chunk >= 0 and chunk < CA_audio.size() else null
	if s == null:
		Quit("SD_PlaySound() - Uncached sound")
		return
	var length: int = GalData.u32(s, 0)
	if length == 0:
		Quit("SD_PlaySound() - Zero length sound")
		return
	var priority: int = GalData.u16(s, 4)
	if priority < sd_currentSfxPriority:
		return
	match sd_soundMode:
		sdm_PC:
			SD_PC_PlaySound(s)
		sdm_AdLib:
			SD_AL_PlaySound(s)
	sd_currentSfxId = sound
	sd_currentSfxPriority = priority


func SD_SoundPlaying() -> int:
	return sd_currentSfxId


func SD_StopSound() -> void:
	match sd_soundMode:
		sdm_PC:
			SD_PC_StopSound()
		sdm_AdLib:
			SD_AL_StopSound()
	SD_SoundFinished()


func SD_WaitSoundDone() -> void:
	while SD_SoundPlaying() != 0 and not quitting:
		SD_WaitTick()


func SD_MusicOn() -> void:
	sd_musicStarted = true


func SD_MusicOff() -> void:
	sd_musicStarted = false
	if sd_musicMode == smm_AdLib:
		SD_DOS_alOut(SD_ADLIB_REG_EFFECTS, 0)
		for i: int in range(1, SD_ADLIB_NUM_CHANNELS):
			SD_DOS_alOut(SD_ADLIB_REG_NOTE_HI + i, 0)


## music: the track chunk (length word, then events).
func SD_StartMusic(music: PackedByteArray) -> void:
	SD_MusicOff()
	if sd_musicMode == smm_AdLib:
		sd_music_data = music
		sd_music_trackSize = GalData.u16(music, 0)
		sd_music_currentIndex = 0
		sd_music_nextEventTime = 0
		sd_music_currentTime = 0
		if not in_Paused:
			SD_MusicOn()


func SD_FadeOutMusic() -> void:
	SD_MusicOff()


func SD_MusicPlaying() -> bool:
	return sd_musicStarted


## The timer interrupt (140 Hz, or 560 Hz with AdLib music).
func SDL_t0Service() -> void:
	if sd_musicMode == smm_AdLib:
		SD_AL_MusicService()
		sd_t0count = (sd_t0count + 1) & 0xFFFF
		if (sd_t0count & 7) == 0:
			sd_timeCount = (sd_timeCount + 1) & 0xFFFFFFFF
		if (sd_t0count & 3) == 0:
			match sd_soundMode:
				sdm_PC:
					SD_PC_SoundService()
				sdm_AdLib:
					SD_AL_SoundService()
	else:
		sd_t0count = (sd_t0count + 1) & 0xFFFF
		if (sd_t0count & 1) == 0:
			sd_timeCount = (sd_timeCount + 1) & 0xFFFFFFFF
		match sd_soundMode:
			sdm_PC:
				SD_PC_SoundService()
			sdm_AdLib:
				SD_AL_SoundService()


func SD_DOS_t0InterruptProxy() -> void:
	SDL_t0Service()
	sd_timerCount += sd_pitDivisor
	if sd_timerCount > 0xFFFF:
		sd_timerCount &= 0xFFFF
		sd_biosTicks += 1    # t0OldService(): the BIOS counts a tick
	vm.out8(0x20, 0x20)


## The DOS back-end has no wait: a loop calling this spins until the timer
## interrupt changes what it watches. The machine runs to its next event.
func SD_WaitTick() -> void:
	vm.poll()


# ===================================================================== id_in

const IN_SC_None: int = 0x00
const IN_SC_Invalid: int = 0xff
const IN_SC_Escape: int = 0x01
const IN_SC_Backspace: int = 0x0e
const IN_SC_Tab: int = 0x0f
const IN_SC_Enter: int = 0x1c
const IN_SC_Control: int = 0x1d
const IN_SC_LeftShift: int = 0x2a
const IN_SC_RightShift: int = 0x36
const IN_SC_Alt: int = 0x38
const IN_SC_Space: int = 0x39
const IN_SC_CapsLock: int = 0x3a
const IN_SC_NumLock: int = 0x45
const IN_SC_ScrollLock: int = 0x46
const IN_SC_UpArrow: int = 0x48
const IN_SC_LeftArrow: int = 0x4b
const IN_SC_RightArrow: int = 0x4d
const IN_SC_DownArrow: int = 0x50
const IN_SC_Home: int = 0x47
const IN_SC_End: int = 0x4f
const IN_SC_PgUp: int = 0x49
const IN_SC_PgDown: int = 0x51
const IN_SC_Insert: int = 0x52
const IN_SC_Delete: int = 0x53
const IN_SC_Pause: int = 0xe1
const IN_SC_F1: int = 0x3b
const IN_SC_F2: int = 0x3c
const IN_SC_F3: int = 0x3d
const IN_SC_F4: int = 0x3e
const IN_SC_F5: int = 0x3f
const IN_SC_F6: int = 0x40
const IN_SC_F7: int = 0x41
const IN_SC_F8: int = 0x42
const IN_SC_F9: int = 0x43
const IN_SC_F10: int = 0x44
const IN_SC_F11: int = 0x57
const IN_SC_F12: int = 0x58
const IN_SC_A: int = 0x1e
const IN_SC_B: int = 0x30
const IN_SC_C: int = 0x2e
const IN_SC_D: int = 0x20
const IN_SC_E: int = 0x12
const IN_SC_F: int = 0x21
const IN_SC_G: int = 0x22
const IN_SC_H: int = 0x23
const IN_SC_I: int = 0x17
const IN_SC_J: int = 0x24
const IN_SC_K: int = 0x25
const IN_SC_L: int = 0x26
const IN_SC_M: int = 0x32
const IN_SC_N: int = 0x31
const IN_SC_O: int = 0x18
const IN_SC_P: int = 0x19
const IN_SC_Q: int = 0x10
const IN_SC_R: int = 0x13
const IN_SC_S: int = 0x1f
const IN_SC_T: int = 0x14
const IN_SC_U: int = 0x16
const IN_SC_V: int = 0x2f
const IN_SC_W: int = 0x11
const IN_SC_X: int = 0x2d
const IN_SC_Y: int = 0x15
const IN_SC_Z: int = 0x2c
const IN_KP_None: int = 0

const IN_Demo_Record: int = 1
const IN_Demo_Playback: int = 2
const IN_Demo_PlayDone: int = 3

const IN_motion_Left: int = -1
const IN_motion_Up: int = -1
const IN_motion_None: int = 0
const IN_motion_Right: int = 1
const IN_motion_Down: int = 1

const IN_dir_North: int = 0
const IN_dir_NorthEast: int = 1
const IN_dir_East: int = 2
const IN_dir_SouthEast: int = 3
const IN_dir_South: int = 4
const IN_dir_SouthWest: int = 5
const IN_dir_West: int = 6
const IN_dir_NorthWest: int = 7
const IN_dir_None: int = 8

const IN_ctrl_Keyboard1: int = 0
const IN_ctrl_Keyboard2: int = 1
const IN_ctrl_Joystick1: int = 2
const IN_ctrl_Joystick2: int = 3
const IN_ctrl_Mouse: int = 4
const IN_ctrl_All: int = 5

const nonchar_keys: PackedByteArray = [0x01, 0x0E, 0x0F, 0x1D, 0x2A, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
	0x40, 0x41, 0x42, 0x43, 0x44, 0x57, 0x59, 0x46, 0x1C, 0x36, 0x37, 0x38, 0x47, 0x49, 0x4F, 0x51,
	0x52, 0x53, 0x45, 0x48, 0x50, 0x4B, 0x4D, 0x00]
const nonchar_key_strings: PackedStringArray = ["Esc", "Bksp", "Tab", "Ctrl", "LShft", "Space", "CapsLk", "F1",
	"F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "ScrlLk",
	"Enter", "RShft", "PrtSc", "Alt", "Home", "PgUp", "End", "PgDn", "Ins", "Del", "NumLk", "Up",
	"Down", "Left", "Right", ""]
const char_key_strings: PackedStringArray = [
	"?", "?", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "+", "?", "?",
	"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "|", "?", "A", "S",
	"D", "F", "G", "H", "J", "K", "L", ";", "\"", "?", "?", "?", "Z", "X", "C", "V",
	"B", "N", "M", ",", ".", "/", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "\u000F", "?", "-", "\u0015", "5", "\u0011", "+", "?",
	"\u0013", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?",
	"?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?"]
## Unshifted, shifted and 0xE0-prefixed ASCII for each scan code.
const in_ASCIINames: PackedByteArray = [
	0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9,
	113, 119, 101, 114, 116, 121, 117, 105, 111, 112, 91, 93, 13, 0, 97, 115,
	100, 102, 103, 104, 106, 107, 108, 59, 39, 96, 0, 92, 122, 120, 99, 118,
	98, 110, 109, 44, 46, 47, 0, 42, 0, 32, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 55, 56, 57, 45, 52, 53, 54, 43, 49,
	50, 51, 48, 127, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const in_shiftNames: PackedByteArray = [
	0, 27, 33, 64, 35, 36, 37, 94, 38, 42, 40, 41, 95, 43, 8, 9,
	81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 123, 125, 13, 0, 65, 83,
	68, 70, 71, 72, 74, 75, 76, 58, 34, 126, 0, 124, 90, 88, 67, 86,
	66, 78, 77, 60, 62, 63, 0, 42, 0, 32, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 55, 56, 57, 45, 52, 53, 54, 43, 49,
	50, 51, 48, 127, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const in_specialNames: PackedByteArray = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
## 3 * (y + 1) + x + 1 -> direction
const in_dirTable: PackedInt32Array = [IN_dir_NorthWest, IN_dir_North, IN_dir_NorthEast,
	IN_dir_West, IN_dir_None, IN_dir_East, IN_dir_SouthWest, IN_dir_South, IN_dir_SouthEast]


## IN_ControlFrame
class IN_ControlFrame:
	var jump: bool = false
	var pogo: bool = false
	var button2: bool = false
	var button3: bool = false
	var x: int = 0
	var y: int = 0
	var xDirection: int = 0
	var yDirection: int = 0
	var dir: int = 8

	func copy_from(o: IN_ControlFrame) -> void:
		jump = o.jump
		pogo = o.pogo
		button2 = o.button2
		button3 = o.button3
		x = o.x
		y = o.y
		xDirection = o.xDirection
		yDirection = o.yDirection
		dir = o.dir


class IN_Cursor:
	var button0: bool = false
	var button1: bool = false
	var xMotion: int = 0
	var yMotion: int = 0


var in_Paused: bool = false
var in_PausedMessage: String = "PAUSED"
var in_controlType: int = IN_ctrl_Keyboard1
var in_backupControlType: int = IN_ctrl_Keyboard1
var in_keyStates: PackedByteArray = PackedByteArray()
var in_lastKeyScanned: int = IN_SC_None
var in_useTextEvents: bool = false
var in_lastASCII: int = 0
var in_disableJoysticks: bool = false
var in_gamepadButtons: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var CapsLock: bool = false
## INL_KeyService's static isSpecial.
var in_isSpecial: bool = false
## in_kbdControls (IN_KeyMapping), by field name.
var in_kbdControls: Dictionary = {}

# demos
var in_demoBuf: PackedByteArray = PackedByteArray()
var in_demoBufOff: int = 0       # where the demo's frames begin in in_demoBuf
var in_demoPtr: int = 0
var in_demoBytes: int = 0


func IN_HandleKeyUp(sc: int, _special: bool) -> void:
	in_keyStates[sc] = 0


func IN_HandleKeyDown(sc: int, special: bool) -> void:
	in_keyStates[sc] = 1
	in_lastKeyScanned = sc
	var c: int = 0
	if sc == 0xe0:
		special = true
	elif sc == IN_SC_Pause:
		in_Paused = true
	else:
		if (sc & 0x80) != 0:
			sc &= 0x7f
			in_keyStates[sc] = 0
		else:
			if special:
				c = in_specialNames[sc]
			else:
				if sc == IN_SC_CapsLock:
					CapsLock = not CapsLock
				if in_keyStates[IN_SC_LeftShift] != 0 or in_keyStates[IN_SC_RightShift] != 0:
					c = in_shiftNames[sc]
					if c >= 65 and c <= 90 and CapsLock:
						c += 32
				else:
					c = in_ASCIINames[sc]
					if c >= 97 and c <= 122 and CapsLock:
						c -= 32
			if not in_useTextEvents and c != 0:
				in_lastASCII = c


## The keyboard interrupt (id_in_dos.c's INL_KeyService).
func INL_KeyService() -> void:
	var scanCode: int = vm.port60
	# clear the key in the XT keyboard controller
	var temp: int = vm.in8(0x61)
	vm.out8(0x61, temp | 0x80)
	vm.out8(0x61, temp)
	if scanCode == 0xE0:
		in_isSpecial = true
	elif (scanCode & 0x80) != 0:
		IN_HandleKeyUp(scanCode & 0x7F, in_isSpecial)
		in_isSpecial = false
	else:
		IN_HandleKeyDown(scanCode, in_isSpecial)
		in_isSpecial = false
	vm.out8(0x20, 0x20)


func IN_SetupKbdControls() -> void:
	in_kbdControls = {
		"jump": CFG_GetConfigInt("in_kbd_jump", IN_SC_Control),
		"pogo": CFG_GetConfigInt("in_kbd_pogo", IN_SC_Alt),
		"fire": CFG_GetConfigInt("in_kbd_fire", IN_SC_Space),
		"up": CFG_GetConfigInt("in_kbd_up", IN_SC_UpArrow),
		"down": CFG_GetConfigInt("in_kbd_down", IN_SC_DownArrow),
		"left": CFG_GetConfigInt("in_kbd_left", IN_SC_LeftArrow),
		"right": CFG_GetConfigInt("in_kbd_right", IN_SC_RightArrow),
		"upLeft": CFG_GetConfigInt("in_kbd_upLeft", IN_SC_Home),
		"upRight": CFG_GetConfigInt("in_kbd_upRight", IN_SC_PgUp),
		"downRight": CFG_GetConfigInt("in_kbd_downRight", IN_SC_PgDown),
		"downLeft": CFG_GetConfigInt("in_kbd_downLeft", IN_SC_End),
	}


## Keys arrive by interrupt; a loop that pumps runs the machine to its next
## event (a tic, a refresh or a key), which is the soonest anything can change.
func IN_PumpEvents() -> void:
	vm.poll()


func IN_GetScanName(scan: int) -> String:
	for i: int in range(nonchar_keys.size()):
		if nonchar_keys[i] == 0:
			break
		if nonchar_keys[i] == scan:
			return nonchar_key_strings[i]
	if scan < char_key_strings.size():
		return char_key_strings[scan]
	return "?"


func IN_WaitKey() -> void:
	pass


func IN_WaitForButtonPress() -> void:
	while not quitting:
		IN_PumpEvents()
		if in_lastKeyScanned != 0:
			in_keyStates[in_lastKeyScanned] = 0
			in_lastKeyScanned = 0
			return
		VL_Present()


func IN_GetKeyState(scanCode: int) -> bool:
	return in_keyStates[scanCode & 0xFF] != 0


func IN_GetLastScan() -> int:
	return in_lastKeyScanned


func IN_SetLastScan(scanCode: int) -> void:
	in_lastKeyScanned = scanCode & 0xFF


func IN_GetLastASCII() -> int:
	return in_lastASCII


func IN_SetLastASCII(c: int) -> void:
	in_lastASCII = c & 0xFF


func IN_StartTextInput(_reason: String, _existing: String) -> void:
	pass


func IN_StopTextInput() -> void:
	pass


func IN_Startup() -> void:
	in_keyStates = PackedByteArray()
	in_keyStates.resize(256)
	in_useTextEvents = false
	IN_SetupKbdControls()
	vm.int9 = Callable(self, "INL_KeyService")


func IN_Default(_gotit: bool, inputChoice: int) -> void:
	in_controlType = inputChoice
	if inputChoice != IN_ctrl_All:
		in_backupControlType = inputChoice


func IN_DemoStartRecording(bufferSize: int) -> bool:
	if bufferSize == 0:
		return false
	in_demoBuf = PackedByteArray()
	in_demoBuf.resize(bufferSize)
	in_demoBufOff = 0
	in_demoState = IN_Demo_Record
	in_demoBytes = bufferSize & ~1
	in_demoPtr = 0
	in_demoBuf[0] = 0
	in_demoBuf[1] = 0
	return true


## data: the demo's frames from `off` (C's pointer into the cached chunk;
## playback counts each frame's delay down in place, as the original does).
func IN_DemoStartPlaying(demo: PackedByteArray, off: int, length: int) -> void:
	in_demoBuf = demo
	in_demoBufOff = off
	in_demoBytes = length
	in_demoPtr = 0
	in_demoState = IN_Demo_Playback


func IN_DemoStopPlaying() -> void:
	if in_demoState == IN_Demo_Record and in_demoPtr != 0:
		in_demoPtr += 2
	in_demoState = IN_Demo_Off


func IN_DemoGetMode() -> int:
	return in_demoState


func IN_DemoFreeBuffer() -> void:
	in_demoBuf = PackedByteArray()


func IN_ClearKeysDown() -> void:
	in_lastKeyScanned = IN_SC_None
	in_lastASCII = IN_KP_None
	in_keyStates.fill(0)


func IN_ClearKey(key: int) -> void:
	if in_lastKeyScanned == key:
		in_lastKeyScanned = IN_SC_None
	in_keyStates[key & 0xFF] = 0


## No joystick on the machine (the original's joystick port reads absent).
func IN_JoyPresent(_joystick: int) -> bool:
	return false


func IN_GetJoyButtonsDB(_joystick: int) -> int:
	return 0


func IN_SetControlType(_player: int, type: int) -> void:
	in_controlType = type


func IN_ReadCursor(cursor: IN_Cursor) -> void:
	cursor.button0 = false
	cursor.button1 = false
	cursor.xMotion = IN_motion_None
	cursor.yMotion = IN_motion_None


func IN_ReadControls(_player: int, controls: IN_ControlFrame) -> void:
	controls.xDirection = IN_motion_None
	controls.yDirection = IN_motion_None
	controls.jump = false
	controls.pogo = false
	controls.button2 = false
	controls.button3 = false
	if in_demoState == IN_Demo_Playback:
		var p: int = in_demoBufOff + in_demoPtr
		var ctrlByte: int = in_demoBuf[p + 1]
		controls.yDirection = (ctrlByte & 3) - 1
		controls.xDirection = ((ctrlByte >> 2) & 3) - 1
		controls.jump = ((ctrlByte >> 4) & 1) != 0
		controls.pogo = ((ctrlByte >> 5) & 1) != 0
		# this input lasts for n frames
		in_demoBuf[p] = (in_demoBuf[p] - 1) & 0xFF
		if in_demoBuf[p] == 0:
			in_demoPtr += 2
			if in_demoPtr >= in_demoBytes:
				in_demoState = IN_Demo_PlayDone
	elif in_demoState == IN_Demo_PlayDone:
		Quit("Demo playback exceeded")
		return
	else:
		if in_controlType == IN_ctrl_Keyboard1 or in_controlType == IN_ctrl_Keyboard2 or in_controlType == IN_ctrl_All:
			if IN_GetKeyState(in_kbdControls.upLeft):
				controls.xDirection = IN_motion_Left
				controls.yDirection = IN_motion_Up
			elif IN_GetKeyState(in_kbdControls.upRight):
				controls.xDirection = IN_motion_Right
				controls.yDirection = IN_motion_Up
			elif IN_GetKeyState(in_kbdControls.downLeft):
				controls.xDirection = IN_motion_Left
				controls.yDirection = IN_motion_Down
			elif IN_GetKeyState(in_kbdControls.downRight):
				controls.xDirection = IN_motion_Right
				controls.yDirection = IN_motion_Down
			if IN_GetKeyState(in_kbdControls.up):
				controls.yDirection = IN_motion_Up
			elif IN_GetKeyState(in_kbdControls.down):
				controls.yDirection = IN_motion_Down
			if IN_GetKeyState(in_kbdControls.left):
				controls.xDirection = IN_motion_Left
			elif IN_GetKeyState(in_kbdControls.right):
				controls.xDirection = IN_motion_Right
			if IN_GetKeyState(in_kbdControls.jump):
				controls.jump = true
			if IN_GetKeyState(in_kbdControls.pogo):
				controls.pogo = true
			if IN_GetKeyState(in_kbdControls.fire):
				controls.button2 = true
		controls.dir = in_dirTable[3 * (controls.yDirection + 1) + controls.xDirection + 1]
	if in_demoState == IN_Demo_Record:
		var ctrlByte: int = 0
		ctrlByte |= controls.yDirection + 1
		ctrlByte |= (controls.xDirection + 1) << 2
		ctrlByte |= int(controls.jump) << 4
		ctrlByte |= int(controls.pogo) << 5
		if in_demoBuf[in_demoPtr + 1] == ctrlByte and in_demoBuf[in_demoPtr] < 254 and in_demoPtr != 0:
			in_demoBuf[in_demoPtr] += 1
		else:
			if in_demoPtr != 0 or in_demoBuf[in_demoPtr] != 0:
				in_demoPtr += 2
			if in_demoPtr >= in_demoBytes:
				Quit("Demo buffer overflow")
				return
			in_demoBuf[in_demoPtr] = 1
			in_demoBuf[in_demoPtr + 1] = ctrlByte


func IN_WaitButton() -> void:
	IN_PumpEvents()
	in_keyStates[in_lastKeyScanned] = 0
	in_lastKeyScanned = 0
	IN_WaitForButtonPress()


func IN_CheckAck() -> int:
	return IN_GetLastScan()


func IN_UserInput(tics: int, waitPress: bool) -> bool:
	var lasttime: int = SD_GetTimeCount()
	while not quitting:
		IN_PumpEvents()
		if IN_CheckAck() != 0:
			if waitPress:
				IN_WaitForButtonPress()
			return true
		VL_Present()
		if SD_GetTimeCount() - lasttime >= tics:
			break
	return false


## id_us: redraws the menu cards (a later script defines it).
func US_DrawCards() -> void:
	pass


func IN_YesNo() -> bool:
	var k: int = IN_SC_None
	var state: IN_ControlFrame = IN_ControlFrame.new()
	IN_ClearKeysDown()
	while not quitting:
		k = IN_SC_None
		VL_Yield()
		IN_PumpEvents()
		IN_ReadControls(0, state)
		if state.jump:
			k = IN_SC_Y
		elif state.pogo:
			k = IN_SC_N
		else:
			k = IN_GetLastScan()
		VL_Present()
		if k != IN_SC_None:
			break
	while not quitting:
		VL_Yield()
		IN_PumpEvents()
		IN_ReadControls(0, state)
		VL_Present()
		if not (state.jump or state.pogo):
			break
	IN_ClearKeysDown()
	US_DrawCards()
	return k == IN_SC_Y


# ===================================================================== id_in pieces the game layer needs
# (written with the ck_* ports, moved here by SIM-G-01j)


## id_in.h: a scan code gal_io.gd's table lacks.
const IN_SC_Two: int = 0x03


## id_in.h: IN_JoyConfItem (the vanilla build: no quickload/quicksave items).
const IN_joy_jump: int = 0


const IN_joy_pogo: int = 1


const IN_joy_fire: int = 2


const IN_joy_menu: int = 3


const IN_joy_status: int = 4


const IN_joy_deadzone: int = 5


const IN_joy_modern: int = 6


## id_in.c
const IN_MAX_JOYSTICKS: int = 2


const IN_JoyConfNames: PackedStringArray = [
	"in_joy_jump",
	"in_joy_pogo",
	"in_joy_fire",
	"in_joy_menu",
	"in_joy_status",
	"in_joy_quickload",
	"in_joy_quicksave",
	"in_joy_deadzone",
	"in_joy_modern",
]


func IN_GetJoyConf(item: int) -> int:
	return CFG_GetConfigInt(IN_JoyConfNames[item], item)


func IN_GetJoyButtonFromMask(mask: int, btn: int) -> bool:
	var btn_id: int = IN_GetJoyConf(btn)
	return false if (btn_id < 0) else (((u16(mask) >> btn_id) & 1) != 0)


func IN_IsJoyButtonDown(btn: int) -> bool:
	var joy: int = in_controlType - IN_ctrl_Joystick1
	if joy < 0 or joy >= IN_MAX_JOYSTICKS:
		joy = 0
	var mask: int = u16(IN_GetJoyButtonsDB(joy))
	return IN_GetJoyButtonFromMask(mask, btn)


## The demo files IN_DemoSaveToFile wrote, by name (the shell keeps them; no file system here).
var in_savedDemos: Dictionary = {}


## id_in.c: the map number, the demo's size, then the recorded frames.
func IN_DemoSaveToFile(fileName: String, mapNumber: int) -> void:
	var demoSize: int = u16(in_demoPtr)
	var demoFile: PackedByteArray = PackedByteArray()
	demoFile.resize(4)
	demoFile.encode_u16(0, u16(mapNumber))
	demoFile.encode_u16(2, demoSize)

	demoFile.append_array(in_demoBuf.slice(0, in_demoPtr))

	in_savedDemos[fileName] = demoFile


## id_in.h: scan codes gal_io.gd's table lacks (IN_SC_Two: gal_play.gd).
const IN_SC_One: int = 0x02


const IN_SC_Three: int = 0x04


const IN_SC_Four: int = 0x05


const IN_SC_Five: int = 0x06


const IN_SC_Six: int = 0x07


## id_in.c: in_key_controls (pointers into in_kbdControls: here its keys), the
## vanilla build's (no EXTRA_KEYBOARD_OPTIONS or QUICKSAVE_ENABLED entries).
const in_key_controls: PackedStringArray = [
	"jump", "pogo", "fire",
	"upLeft", "up", "upRight",
	"right", "downRight", "down",
	"downLeft", "left"]


const in_key_button_controls: int = 3


const in_key_direction_controls: int = 8
