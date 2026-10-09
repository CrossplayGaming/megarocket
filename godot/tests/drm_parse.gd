# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
extends SceneTree
## SIM-D-01: the Dreams port's scripts parse and the declarations instantiate.

var t: T = T.new()


func _init() -> void:
	var d: DrmDecl = DrmDecl.new()
	t.ok("DrmDecl instantiates", d != null)
	t.ok("constants: NUMCHUNKS %d, STARTSPRITES %d, MAXSPRITES %d" % [d.NUMCHUNKS, d.STARTSPRITES, d.MAXSPRITES],
		d.NUMCHUNKS == 3016 and d.STARTSPRITES == 71 and d.MAXSPRITES == 100)
	t.ok("a stub per function (InitGame, RF_NewMap, VW_DrawPic)", d.has_method("InitGame") and d.has_method("RF_NewMap") and d.has_method("VW_DrawPic"))
	# the machine layer on an emulated EGA card: a plane write, a latch copy and a colour fill read back
	var be: DrmBE = DrmBE.new()
	be.vm = DosMachine.new()
	be.BE_ST_SetScreenMode(0x0D)
	be.BE_ST_EGAUpdateGFXByteInPlane(100, 0xA5, 2)
	be.BE_ST_EGAUpdateGFXByteInAllPlanesScrToScr(200, 100)
	be.BE_ST_EGAUpdateGFXBitsFrom4bitsPixel(300, 0b0101, 0xF0)
	t.ok("DrmBE: plane write %02x, latch copy %02x, colour bits %02x/%02x" % [be.BE_ST_EGAFetchGFXByteFromPlane(100, 2),
		be.BE_ST_EGAFetchGFXByteFromPlane(200, 2), be.BE_ST_EGAFetchGFXByteFromPlane(300, 0), be.BE_ST_EGAFetchGFXByteFromPlane(300, 1)],
		be.BE_ST_EGAFetchGFXByteFromPlane(100, 2) == 0xA5 and be.BE_ST_EGAFetchGFXByteFromPlane(200, 2) == 0xA5
		and be.BE_ST_EGAFetchGFXByteFromPlane(300, 0) == 0xF0 and be.BE_ST_EGAFetchGFXByteFromPlane(300, 1) == 0)
	t.finish(self)
