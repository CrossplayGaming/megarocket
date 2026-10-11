# Keen Dreams' memory under DOSBox (SCR-01, 2026-10-11)

Keen Dreams v1.00's start screen shows the memory its manager got ("Memory Available to Game"), and whether a
mouse was found. Under the oracle the original shows the mouse and 435 KB (434 KB in cases with more than about
28 keys); the port used to show no mouse and 440 KB, from a provisional layout. Both now follow the machine.

## The mouse

DOSBox Staging installs its own mouse driver: INT 33h is set and MReset answers 0FFFFh, so INL_StartMouse
finds a mouse. The port's machine now has it too (`drm_io.gd` INL_StartMouse); nothing moves it or presses its
buttons, so only the start screen's tick changes.

## DOS's memory blocks

A probe program run in the game's place by the runner's DOSBox (same configuration as the recordings) listed
DOS's memory control blocks:

| | the program's environment | its PSP | its block | PSP:[2] |
|---|---|---|---|---|
| without KEYFEED.COM | 0x188 (10 paragraphs) | 0x193 | 0x9E6C paragraphs | 0x9FFF |
| with KEYFEED.COM (3 keys) | 0x1B2 | 0x1BD | 0x9E42 | 0x9FFF |

KEYFEED.COM keeps its resident block (its PSP, the interrupt routine and the key schedule: 30 paragraphs for
3 keys, more for more keys), its copy of the environment (10 paragraphs) and the two blocks' headers: 42
paragraphs for the 3-key case. `tools/keyfeed.py dos_paragraphs` computes it for any case; the runners pass it
(`drm_boot --tsr_paras`).

## What the program makes of it

Read from the programs themselves (v1.00 unpacked from PKLITE, v1.93 from LZEXE; disassembled):

- Borland's start-up (C0): `mov dx,DGROUP` gives DGROUP's paragraph in the load image (v1.00 0x2238, v1.93
  0x23A8); `add di,offset edata@` the end of the uninitialised data (0xEA86, 0xE9CE); `_heaplen` is 0, so DGROUP
  grows to 64K with the stack at its top (SP 0) and the far heap starts at DGROUP + 0x1000.
- The start-up routines run before main: the stdio one calls setvbuf for stdin and stdout. stdin, a terminal,
  gets a 512-byte buffer from malloc (a 516-byte block with malloc's header); stdout is unbuffered. So the near
  heap's top is edata + 516 when MM_Startup runs. setargv copies "C:\KDREAMS.EXE" and argv onto the stack.
- coreleft() is `(SP - __brklvl - 0x220) & 0xFFF0`. At its call SP is 0xFFC0 (C0's three pushes and setargv's
  copy, main's call, InitGame's call and `push si`, MM_Startup's frame: 12 bytes of locals, si, di, the far
  call), so coreleft = 4368 (v1.00) or 4544 (v1.93).
- malloc's block starts 4 bytes above the top, so MM_Startup's `16 - (FP_OFF(start) & 15)` takes 2 (v1.00) or
  10 (v1.93); SAVENEARHEAP takes 1024: the near heap is 3342 or 3510 bytes.
- farcoreleft() is the far heap less a paragraph, rounded to 16; farmalloc's block starts at offset 4 (12 bytes
  lost): the far heap is `(0x9FFF - (PSP + 0x10 + DGROUP + 0x1000) - 1) * 16 - 12` bytes.

v1.00 with the 3-key KEYFEED (PSP 0x1BD): 3342 + 442,244 = 445,586 bytes, 435 KB, as the recording shows. The
same sum predicts 434 KB once KEYFEED holds 52 paragraphs or more (about 30 keys): the 35-key case
(kdreams scr_game, 54 paragraphs) shows 434 KB in its recording, and the port too. `drm_ca.gd` mm_layout now
computes the layout this way (the near heap's block, the stack between, the far heap; the misc buffer no longer
fits the near heap and goes to the far heap). TIME-D's report over the 32 level sessions is unchanged by it
(6965 pictures matched, drift 198, session by session the same).

## Two things the oracle does not do as its configuration says

- The runner's autoexec sets `date 01-01-1991`, but DOSBox Staging 0.83 keeps the host's date: a probe read
  INT 21h 2Ah as 2026-10-11 (TIME 00:00:00 does take). v1.00's finale shows its fifth window ("Goodbye,
  Galaxy!") only after 29 July 1991, so the recordings show it, as the port always has.
- v1.00's warp to a map it lacks (6, 8, 11, 13) does not stop with "CA_CacheMap: Tried to load a non existant
  map!" in the original: the header offset is 0 (not -1), so it reads a 0-byte header and Huffman-expands
  whatever the misc buffer last held, loads a garbage map behind a plain Loading box (up 4 refreshes), and
  quits with "GetNewObj: No free spots in objarray!" (recorded: oracle_runs/kdreams_scr_nomap_a, case below).
  The port still quits at CA_CacheMap at once (ReflectionHLE's "non-vanilla check"): reproducing the garbage
  load needs the misc buffer's bytes and every read past a buffer the C makes (the memory model J-16 left
  out). Not a screen a player reaches without the debug keys.

The missing-map case, for the record (not in tools/cases: SCR-01D would fail on it):

    {"seconds": 20, "keyfeed": true, "may_exit": true,
     "held": [[4.0, "space", 0.2], [6.0, "enter", 0.2], [10.0, "f10", 0.8], [10.3, "w", 0.15],
              [11.6, "6", 0.15], [12.6, "enter", 0.15]]}
