# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# A port of omnispeak's ck_phys.c, ck_obj.c, ck_misc.c and ck_map.c, by David Gow and the Omnispeak authors,
# GPL v2 or later. Names, order and arithmetic follow omnispeak upstream (A10).
class_name GalAct
extends GalCK
## The game core's physics, common objects, misc helpers and world map (SIM-G-01d).
##
## Every store wraps as its C type does (u16 for the uint16_t position and
## clip-rect fields, s16 for the int16_t ones). C's int16_t parameters are
## wrapped on entry, as the call converts the argument. C's Quit() never
## returns; here it only flags the quit, so each Quit is followed by a return.
## C's RF_SpriteDrawEntry ** arguments follow GalRF's rule (the new pointer is
## returned: `obj.sde = RF_AddSpriteDraw(obj.sde, ...)`).


# ===================================================================== ck_phys.c

const ck_physSlopeHeight: Array = [
	[0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100, 0x100],
	[0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000],
	[0x000, 0x08, 0x010, 0x018, 0x020, 0x028, 0x030, 0x038, 0x040, 0x048, 0x050, 0x058, 0x060, 0x068, 0x070, 0x078],
	[0x080, 0x088, 0x090, 0x098, 0x0a0, 0x0a8, 0x0b0, 0x0b8, 0x0c0, 0x0c8, 0x0d0, 0x0d8, 0x0e0, 0x0e8, 0x0f0, 0x0f8],
	[0x000, 0x010, 0x020, 0x030, 0x040, 0x050, 0x060, 0x070, 0x080, 0x090, 0x0a0, 0x0b0, 0x0c0, 0x0d0, 0x0e0, 0x0f0],
	[0x078, 0x070, 0x068, 0x060, 0x058, 0x050, 0x048, 0x040, 0x038, 0x030, 0x028, 0x020, 0x018, 0x010, 0x008, 0x000],
	[0x0F8, 0x0F0, 0x0E8, 0x0E0, 0x0D8, 0x0D0, 0x0C8, 0x0C0, 0x0B8, 0x0B0, 0x0A8, 0x0A0, 0x098, 0x090, 0x088, 0x080],
	[0x0F0, 0x0E0, 0x0D0, 0x0C0, 0x0B0, 0x0A0, 0x090, 0x080, 0x070, 0x060, 0x050, 0x040, 0x030, 0x020, 0x010, 0x000]]

# ck_oldRects, ck_deltaRects, ck_nextX, ck_nextY and ck_keenIgnoreVertClip are
# declared in gal_ck.gd (other C files use them).


func CK_ResetClipRects(obj: CK_object) -> void:
	# NOTE: As tile rects are rarely used, keen does not calculate them here.
	var spriteNumber: int = obj.gfxChunk - int(ca_gfxInfoE.offSprites)

	var ste: Dictionary = VH_GetSpriteTableEntry(spriteNumber)

	obj.clipRects.unitX1 = u16(obj.posX + ste.xl)
	obj.clipRects.unitX2 = u16(obj.posX + ste.xh)
	obj.clipRects.unitY1 = u16(obj.posY + ste.yl)
	obj.clipRects.unitY2 = u16(obj.posY + ste.yh)

	obj.clipRects.unitXmid = u16((obj.clipRects.unitX2 - obj.clipRects.unitX1) / 2 + obj.clipRects.unitX1)

	obj.clipRects.tileX1 = u16(RF_UnitToTile(obj.clipRects.unitX1))
	obj.clipRects.tileX2 = u16(RF_UnitToTile(obj.clipRects.unitX2))
	obj.clipRects.tileY1 = u16(RF_UnitToTile(obj.clipRects.unitY1))
	obj.clipRects.tileY2 = u16(RF_UnitToTile(obj.clipRects.unitY2))

	obj.clipRects.tileXmid = u16(RF_UnitToTile(obj.clipRects.unitXmid))


func CK_SetOldClipRects(obj: CK_object) -> void:
	ck_oldRects.unitX1 = obj.clipRects.unitX1
	ck_oldRects.unitX2 = obj.clipRects.unitX2
	ck_oldRects.unitY1 = obj.clipRects.unitY1
	ck_oldRects.unitY2 = obj.clipRects.unitY2

	ck_oldRects.unitXmid = obj.clipRects.unitXmid

	ck_oldRects.tileX1 = obj.clipRects.tileX1
	ck_oldRects.tileX2 = obj.clipRects.tileX2
	ck_oldRects.tileY1 = obj.clipRects.tileY1
	ck_oldRects.tileY2 = obj.clipRects.tileY2

	ck_oldRects.tileXmid = obj.clipRects.tileXmid


func CK_SetDeltaClipRects(obj: CK_object) -> void:
	ck_deltaRects.unitX1 = s16(obj.clipRects.unitX1 - ck_oldRects.unitX1)
	ck_deltaRects.unitY1 = s16(obj.clipRects.unitY1 - ck_oldRects.unitY1)
	ck_deltaRects.unitX2 = s16(obj.clipRects.unitX2 - ck_oldRects.unitX2)
	ck_deltaRects.unitY2 = s16(obj.clipRects.unitY2 - ck_oldRects.unitY2)

	ck_deltaRects.unitXmid = s16(obj.clipRects.unitXmid - ck_oldRects.unitXmid)

	# We don't calculate tile deltas.


func CK_PhysUpdateX(obj: CK_object, deltaUnitX: int) -> void:
	deltaUnitX = s16(deltaUnitX)
	obj.posX = u16(obj.posX + deltaUnitX)
	obj.clipRects.unitX1 = u16(obj.clipRects.unitX1 + deltaUnitX)
	obj.clipRects.unitX2 = u16(obj.clipRects.unitX2 + deltaUnitX)

	# It looks like only Keen 6 updates unitXmid here.
	if ck_currentEpisode_ep == EP_CK6:
		obj.clipRects.unitXmid = u16(obj.clipRects.unitXmid + deltaUnitX)

	# Now update the tile rect
	# WARNING: Keen _doesn't_ update tileXmid!

	obj.clipRects.tileX1 = u16(RF_UnitToTile(obj.clipRects.unitX1))
	obj.clipRects.tileX2 = u16(RF_UnitToTile(obj.clipRects.unitX2))


func CK_PhysUpdateY(obj: CK_object, deltaUnitY: int) -> void:
	deltaUnitY = s16(deltaUnitY)
	obj.posY = u16(obj.posY + deltaUnitY)
	obj.clipRects.unitY1 = u16(obj.clipRects.unitY1 + deltaUnitY)
	obj.clipRects.unitY2 = u16(obj.clipRects.unitY2 + deltaUnitY)

	obj.clipRects.tileY1 = u16(RF_UnitToTile(obj.clipRects.unitY1))
	obj.clipRects.tileY2 = u16(RF_UnitToTile(obj.clipRects.unitY2))


func CK_PhysKeenClipDown(obj: CK_object) -> void:
	# Amount we're moving in each direction.
	var deltaX: int
	# The part of the slope we care about (in px)
	var midTileXOffset: int
	# The top of the tile at Keen's feet.
	var topTI: int
	# Is there space above the slope?
	var spaceAbove: bool = false

	# Performing some special clipping for Keen.

	# If we're moving right:
	if obj.xDirection == 1:
		# We care about the lefthand-most side of any slope we're about to touch.
		midTileXOffset = 0
		deltaX = s16(obj.clipRects.unitX2 - obj.clipRects.unitXmid)
		spaceAbove = (TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2 - 1, 1)) == 0)
		topTI = TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2, 1))

		# If we're being blocked by something, return.
		if TI_ForeLeft(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2 - 2, 1)) != 0 or TI_ForeLeft(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2 - 1, 1)) != 0 or TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY2 - 1, 1)) != 0:
			return
	else: # We're moving left:
		# We care about the righthand-most side of the slope
		midTileXOffset = 15
		deltaX = s16(obj.clipRects.unitX1 - obj.clipRects.unitXmid)
		spaceAbove = (TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2 - 1, 1)) == 0)
		topTI = TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2, 1))

		# If we're being blocked, return.
		if TI_ForeRight(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2 - 2, 1)) != 0 or TI_ForeRight(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2 - 1, 1)) != 0 or TI_ForeTop(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY2 - 1, 1)) != 0:
			return

	# If we're about to land on something flat:
	# TODO: This doesn't make any sense. Why would we make sure we're not
	# on a slope before doing slope calculations. Something fishy, methinks.
	# (omnispeak's quirk, kept: only a flat top (1) is ever handled here)
	if spaceAbove and (topTI == 1):
		var slope: int = ck_physSlopeHeight[(topTI & 7)][midTileXOffset]
		var deltaY: int = s16(RF_TileToUnit(obj.clipRects.tileY2) + slope - 1 - obj.clipRects.unitY2)
		if deltaY <= 0 and -(ck_deltaRects.unitY2) <= deltaY:
			obj.topTI = topTI
			CK_PhysUpdateY(obj, deltaY)
			CK_PhysUpdateX(obj, deltaX)


func CK_PhysKeenClipUp(obj: CK_object) -> void:
	var deltaY: int
	var midTileXOffset: int
	var bottomTI: int
	var spaceBelow: bool

	if obj.xDirection == 1:
		midTileXOffset = 0
		bottomTI = TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1, 1))
		spaceBelow = (TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 + 1, 1)) == 0)
		if TI_ForeLeft(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 + 2, 1)) != 0 or TI_ForeLeft(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 + 3, 1)) != 0 or TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX2, obj.clipRects.tileY1 + 1, 1)) != 0:
			return
	else:
		midTileXOffset = 15
		bottomTI = TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1, 1))
		spaceBelow = (TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1 + 1, 1)) == 0)
		if TI_ForeRight(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1 + 2, 1)) != 0 or TI_ForeRight(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1 + 3, 1)) != 0 or TI_ForeBottom(CA_TileAtPos(obj.clipRects.tileX1, obj.clipRects.tileY1 + 1, 1)) != 0:
			return

	if spaceBelow and bottomTI != 0:
		var slopeAmt: int = ck_physSlopeHeight[bottomTI & 0x07][midTileXOffset]
		deltaY = s16(RF_TileToUnit(obj.clipRects.tileY1 + 1) - slopeAmt - obj.clipRects.unitY1)
		if deltaY >= 0 and (-ck_deltaRects.unitY1) >= deltaY:
			obj.bottomTI = bottomTI
			CK_PhysUpdateY(obj, deltaY)


func CK_NotStuckInWall(obj: CK_object) -> bool:
	# uint16_t loop counters, as in C
	var y: int = obj.clipRects.tileY1
	while y <= obj.clipRects.tileY2:
		var x: int = obj.clipRects.tileX1
		while x <= obj.clipRects.tileX2:
			var tile: int = CA_TileAtPos(s16(x), s16(y), 1)
			if TI_ForeTop(tile) != 0 or TI_ForeRight(tile) != 0 or TI_ForeBottom(tile) != 0 or TI_ForeLeft(tile) != 0:
				return false
			x = u16(x + 1)
		y = u16(y + 1)
	return true


## Similar to CK_ResetClipRects, but checks if new action will get object stuck in wall
## Only seems to be used in CK4 in a Bluebird think function
func CK_PreviewClipRects(obj: CK_object, act: CK_action) -> bool:
	obj.gfxChunk = u16(act.chunkLeft if obj.xDirection < 0 else act.chunkRight)
	var spriteNumber: int = obj.gfxChunk - int(ca_gfxInfoE.offSprites)

	var ste: Dictionary = VH_GetSpriteTableEntry(spriteNumber)

	obj.clipRects.unitX1 = u16(obj.posX + ste.xl)
	obj.clipRects.unitX2 = u16(obj.posX + ste.xh)
	obj.clipRects.unitY1 = u16(obj.posY + ste.yl)
	obj.clipRects.unitY2 = u16(obj.posY + ste.yh)

	obj.clipRects.unitXmid = u16((obj.clipRects.unitX2 - obj.clipRects.unitX1) / 2 + obj.clipRects.unitX1)

	obj.clipRects.tileX1 = u16(RF_UnitToTile(obj.clipRects.unitX1))
	obj.clipRects.tileX2 = u16(RF_UnitToTile(obj.clipRects.unitX2))
	obj.clipRects.tileY1 = u16(RF_UnitToTile(obj.clipRects.unitY1))
	obj.clipRects.tileY2 = u16(RF_UnitToTile(obj.clipRects.unitY2))

	obj.clipRects.tileXmid = u16(RF_UnitToTile(obj.clipRects.unitXmid))

	return CK_NotStuckInWall(obj)


## (C keeps the tile in an int16_t and passes it back to the uint16_t TI_*
## accessors: the round trip is the identity, so the tile stays unsigned here.)
func CK_PhysClipVert(obj: CK_object) -> void:
	var midTileXOffset: int = s16(RF_UnitToPixel(obj.clipRects.unitXmid) & 0x0F)

	var vertDisplace: int = s16(-absi(ck_deltaRects.unitXmid) - ck_deltaRects.unitY2 - 16) # Move above slope first.

	# for (uint16_t y = ck_oldRects.tileY2 - 1; obj->clipRects.tileY2 >= y; ++y)
	var y: int = u16(ck_oldRects.tileY2 - 1)
	while obj.clipRects.tileY2 >= y:
		var tile: int = CA_TileAtPos(obj.clipRects.tileXmid, s16(y), 1)
		if TI_ForeTop(tile) != 0:
			var slopeAmt: int = ck_physSlopeHeight[TI_ForeTop(tile) & 0x07][midTileXOffset]

			var objYOffset: int = s16(obj.clipRects.unitY2 - (y * 256))

			var dy: int = s16((slopeAmt - objYOffset) - 1)
			if (dy < 0) and (dy >= vertDisplace):
				obj.topTI = TI_ForeTop(tile)

				CK_PhysUpdateY(obj, dy) # -objYOffset+slopeAmt-1);
				return
		y = u16(y + 1)
	vertDisplace = s16(absi(ck_deltaRects.unitXmid) - ck_deltaRects.unitY1 + 16)

	# for (uint16_t y = ck_oldRects.tileY1 + 1; y >= obj->clipRects.tileY1; --y)
	# (C quirk, kept: with tileY1 == 0 the uint16_t counter wraps and the loop never ends)
	y = u16(ck_oldRects.tileY1 + 1)
	while y >= obj.clipRects.tileY1:
		var tile: int = CA_TileAtPos(obj.clipRects.tileXmid, s16(y), 1)

		if TI_ForeBottom(tile) != 0:
			var objYOffset: int = s16(obj.clipRects.unitY1 - RF_TileToUnit(y + 1))

			var slopeAmt: int = s16(-ck_physSlopeHeight[TI_ForeBottom(tile) & 0x07][midTileXOffset])

			if (slopeAmt - objYOffset > 0) and ((slopeAmt - objYOffset) <= vertDisplace) and ((ck_nextY + slopeAmt - objYOffset) < 256) and ((ck_nextY + slopeAmt - objYOffset) > -256):
				obj.bottomTI = TI_ForeBottom(tile)
				CK_PhysUpdateY(obj, -objYOffset + slopeAmt)
		y = u16(y - 1)


func CK_PhysClipHorz(obj: CK_object) -> void:
	var tileY1: int = obj.clipRects.tileY1
	var tileY2: int = obj.clipRects.tileY2

	# TODO: Increment on topFlags, bottomFlags.
	if obj.topTI > 1: # If we're on a slope
		tileY2 = u16(tileY2 - 1) # Collide horizontally
	if obj.bottomTI > 1:
		tileY1 = u16(tileY1 + 1)

	# Check if our left side is intersecting with a wall.
	var y: int = tileY1
	while y <= tileY2:
		var tile: int = CA_TileAtPos(obj.clipRects.tileX1, s16(y), 1)
		obj.rightTI = TI_ForeRight(tile)
		if obj.rightTI != 0:
			# Clipping right
			# Push us right until we're no-longer intersecting.
			CK_PhysUpdateX(obj, RF_TileToUnit(obj.clipRects.tileX1 + 1) - obj.clipRects.unitX1)
			return
		y = u16(y + 1)

	# Similarly for the right side (left side of instersecting tile).
	y = tileY1
	while y <= tileY2:
		var tile: int = CA_TileAtPos(obj.clipRects.tileX2, s16(y), 1)
		obj.leftTI = TI_ForeLeft(tile)
		if obj.leftTI != 0:
			# Push us left until we're no-longer intersecting.
			CK_PhysUpdateX(obj, RF_TileToUnit(obj.clipRects.tileX2) - 1 - obj.clipRects.unitX2)
			return
		y = u16(y + 1)


# TODO: Finish

func CK_PhysUpdateNormalObj(obj: CK_object) -> void:
	var oldUnitX: int
	var oldUnitY: int
	var wasNotOnPlatform: bool = false
	oldUnitX = obj.posX
	oldUnitY = obj.posY

	if obj.currentAction.stickToGround != 0: # unknown1)
		# If the object is resting on a platform
		if obj.topTI == 0x19:
			ck_nextY = 145
		else:
			if ck_nextX > 0:
				ck_nextY = s16((ck_nextX) + 16)
			else:
				ck_nextY = s16(-(ck_nextX) + 16)
			wasNotOnPlatform = true

	if ck_nextX > 240 - 1:
		ck_nextX = 240 - 1
	elif ck_nextX < -240 + 1:
		ck_nextX = -240 + 1

	if ck_nextY > 255:
		ck_nextY = 255
	elif ck_nextY < -239:
		ck_nextY = -239

	obj.posX = u16(obj.posX + ck_nextX)
	obj.posY = u16(obj.posY + ck_nextY)

	obj.visible = true

	if obj.gfxChunk != 0:
		CK_SetOldClipRects(obj)

		CK_ResetClipRects(obj)

		# Reset the tile clipping vars.
		obj.topTI = 0
		obj.bottomTI = 0
		obj.leftTI = 0
		obj.rightTI = 0

		if obj.clipped != 0:
			# NOTE: Keen calculates a clip-rect delta here.

			CK_SetDeltaClipRects(obj)

			CK_PhysClipVert(obj)

			# TODO: Handle keen NOT being pushed.
			if obj == ck_keenObj and (ck_currentEpisode_ep != EP_CK6 or not ck_keenIgnoreVertClip):
				if obj.topTI == 0 and ck_deltaRects.unitY2 > 0:
					CK_PhysKeenClipDown(obj)
				if obj.bottomTI == 0 and ck_deltaRects.unitY1 < 0:
					CK_PhysKeenClipUp(obj)

			CK_PhysClipHorz(obj)

			# Present only in the Keen 6 EXE - Handle the case Keen is pushed towards a wall (with right/left key) while standing on a sloped floor (see levels 6-8).
			if (ck_currentEpisode_ep == EP_CK6) and (obj == ck_keenObj) and ((obj.topTI & 7) > 1) and (obj.rightTI != 0 or obj.leftTI != 0):
				# Based on code from CK_PhysClipVert
				var midTileXOffset: int = s16(RF_UnitToPixel(obj.clipRects.unitXmid) & 0x0F)

				# for (uint16_t y = ck_oldRects.tileY2; obj->clipRects.tileY2 + 1 >= y; ++y)
				var y: int = ck_oldRects.tileY2
				while obj.clipRects.tileY2 + 1 >= y:
					var tile: int = CA_TileAtPos(obj.clipRects.tileXmid, s16(y), 1)
					if TI_ForeTop(tile) != 0:
						var slopeAmt: int = ck_physSlopeHeight[TI_ForeTop(tile) & 0x07][midTileXOffset]
						var objYOffset: int = s16(obj.clipRects.unitY2 - (y * 256))
						var dy: int = s16((slopeAmt - objYOffset) - 1)

						obj.topTI = TI_ForeTop(tile)
						CK_PhysUpdateY(obj, dy) # -objYOffset+slopeAmt-1);
						# (C returns here, skipping the deltaPos update below)
						return
					y = u16(y + 1)

		# TODO: Something strange about reseting if falling?

		if obj.topTI == 0 and wasNotOnPlatform:
			obj.posX = u16(oldUnitX + ck_nextX)
			obj.posY = oldUnitY
			CK_ResetClipRects(obj)

		obj.deltaPosX = s16(obj.deltaPosX + (obj.posX - oldUnitX))
		obj.deltaPosY = s16(obj.deltaPosY + (obj.posY - oldUnitY))


# TODO: Finish Implementing!!!!

func CK_PhysFullClipToWalls(obj: CK_object) -> void:
	var oldUnitX: int = obj.posX
	var oldUnitY: int = obj.posY

	if ck_nextX > 239:
		ck_nextX = 239
	elif ck_nextX < -239:
		ck_nextX = -239
	if ck_nextY > 239:
		ck_nextY = 239
	elif ck_nextY < -239:
		ck_nextY = -239

	obj.posX = u16(obj.posX + ck_nextX)
	obj.posY = u16(obj.posY + ck_nextY)
	obj.visible = true

	# TODO: Verify object class (need callback to episode struct)
	var delX: int = 0
	var delY: int = 0
	var badobjclass: bool = false

	match ck_currentEpisode_ep:
		EP_CK4:
			if obj.type == CT4_Schoolfish:
				delX = 0x100
				delY = 0x80
			elif obj.type == CT4_Dopefish:
				delX = 0x580
				delY = 0x400
			elif obj.type == CT4_Bird:
				delX = 0x400
				delY = 0x200
			elif obj.type == CT_Player:
				# Scubakeen
				delX = 0x280
				delY = 0x180
			else:
				badobjclass = true
		EP_CK5:
			if obj.type == CT5_SliceStar or obj.type == CT5_Sphereful:
				delX = 512
				delY = 512
			else:
				badobjclass = true
		EP_CK6:
			if obj.type == CT6_Blorb:
				delX = 0x200
				delY = 0x200
			else:
				badobjclass = true
		_:
			# Fallthrough, as if no episode is set, all obclasses are bad.
			badobjclass = true
	if badobjclass:
		Quit("FullClipToWalls: Bad obclass")
		return

	obj.clipRects.unitX2 = u16(obj.posX + delX)
	obj.clipRects.unitX1 = obj.posX
	obj.clipRects.unitY1 = obj.posY
	obj.clipRects.unitY2 = u16(obj.posY + delY)
	obj.clipRects.tileX1 = u16(RF_UnitToTile(obj.clipRects.unitX1))
	obj.clipRects.tileX2 = u16(RF_UnitToTile(obj.clipRects.unitX2))
	obj.clipRects.tileY1 = u16(RF_UnitToTile(obj.clipRects.unitY1))
	obj.clipRects.tileY2 = u16(RF_UnitToTile(obj.clipRects.unitY2))
	# Reset the tile clipping vars.
	obj.topTI = 0
	obj.bottomTI = 0
	obj.leftTI = 0
	obj.rightTI = 0

	if not CK_NotStuckInWall(obj):
		CK_PhysUpdateX(obj, -ck_nextX)
		if CK_NotStuckInWall(obj):
			if ck_nextX > 0:
				obj.leftTI = 1
			else:
				obj.rightTI = 1
		else:
			if ck_nextY > 0:
				obj.topTI = 1
			else:
				obj.bottomTI = 1

			CK_PhysUpdateX(obj, ck_nextX)
			CK_PhysUpdateY(obj, -ck_nextY)
			if not CK_NotStuckInWall(obj):
				CK_PhysUpdateX(obj, -ck_nextX)
				if ck_nextX > 0:
					obj.leftTI = 1
				else:
					obj.rightTI = 1
	obj.deltaPosX = s16(obj.deltaPosX + (obj.posX - oldUnitX))
	obj.deltaPosY = s16(obj.deltaPosY + (obj.posY - oldUnitY))

	# We explicitly don't call ResetClipRects() here, as the tile rects should not be updated.
	var spriteNumber: int = obj.gfxChunk - int(ca_gfxInfoE.offSprites)
	var ste: Dictionary = VH_GetSpriteTableEntry(spriteNumber)

	obj.clipRects.unitX1 = u16(obj.posX + ste.xl)
	obj.clipRects.unitX2 = u16(obj.posX + ste.xh)
	obj.clipRects.unitY1 = u16(obj.posY + ste.yl)
	obj.clipRects.unitY2 = u16(obj.posY + ste.yh)

	obj.clipRects.unitXmid = u16((obj.clipRects.unitX2 - obj.clipRects.unitX1) / 2 + obj.clipRects.unitX1)


func CK_PhysUpdateSimpleObj(obj: CK_object) -> void:
	var oldUnitX: int
	var oldUnitY: int
	oldUnitX = obj.posX
	oldUnitY = obj.posY

	obj.posX = u16(obj.posX + ck_nextX)
	obj.posY = u16(obj.posY + ck_nextY)

	obj.visible = true

	if obj.gfxChunk != 0:
		CK_SetOldClipRects(obj)

		CK_ResetClipRects(obj)

		# Reset the tile clipping vars.
		# obj->topTI = 0;
		# obj->bottomTI = 0;
		# obj->leftTI = 0;
		# obj->rightTI = 0;

		if obj.clipped != 0:
			CK_SetDeltaClipRects(obj)
			CK_PhysClipVert(obj)
			CK_PhysClipHorz(obj)

		obj.deltaPosX = s16(obj.deltaPosX + (obj.posX - oldUnitX))
		obj.deltaPosY = s16(obj.deltaPosY + (obj.posY - oldUnitY))


func CK_PhysPushX(pushee: CK_object, pusher: CK_object) -> void:
	var deltaPosX: int = s16(pusher.deltaPosX - pushee.deltaPosX)
	var deltaX_1: int = s16(pusher.clipRects.unitX2 - pushee.clipRects.unitX1)
	var deltaX_2: int = s16(pushee.clipRects.unitX2 - pusher.clipRects.unitX1)

	# Push object to the right
	if (deltaX_1 > 0) and (deltaX_1 <= deltaPosX):
		ck_nextX = deltaX_1
		if pushee.currentAction.stickToGround != 0:
			ck_nextY = s16(-deltaX_1 + 16)
		CK_PhysUpdateNormalObj(pushee)
		pushee.rightTI = 1
		return

	# Push object to the left
	if (deltaX_2 > 0) and (-deltaPosX >= deltaX_2):
		ck_nextX = s16(-deltaX_2)
		if pushee.currentAction.stickToGround != 0:
			ck_nextY = s16(deltaX_2 + 16)
		CK_PhysUpdateNormalObj(pushee)
		pushee.leftTI = 1
		return


func CK_PhysPushY(pushee: CK_object, pusher: CK_object) -> void:
	var deltaDeltaY: int = s16(pushee.deltaPosY - pusher.deltaPosY)
	var deltaClipY: int = s16(pushee.clipRects.unitY2 - pusher.clipRects.unitY1)

	if (deltaClipY >= 0) and (deltaClipY <= deltaDeltaY):
		# If the pushee is keen, set ck_keenState.currentPlatform to pusher
		# (I'm not sure I like this)
		if pushee == ck_keenObj:
			ck_keenState.platform = pusher

		ck_nextY = s16(-deltaClipY)
		var pusheeSticksToGround: bool = pushee.currentAction.stickToGround != 0
		pushee.currentAction.stickToGround = 0
		CK_PhysUpdateNormalObj(pushee)
		# (C quirk, kept: the int16_t field is restored through a bool, so any
		# nonzero value comes back as 1)
		pushee.currentAction.stickToGround = 1 if pusheeSticksToGround else 0

		if pushee.bottomTI == 0:
			pushee.topTI = 0x19 # Platform?


func CK_PhysPushXY(passenger: CK_object, platform: CK_object, squish: bool) -> void:
	var dx: int = s16(platform.deltaPosX - passenger.deltaPosX)
	ck_nextY = 0
	ck_nextX = 0
	var dLeft: int = s16(platform.clipRects.unitX2 - passenger.clipRects.unitX1)
	var dRight: int = s16(passenger.clipRects.unitX2 - platform.clipRects.unitX1)

	# Push in all four directions

	if dLeft > 0 and dx + 1 >= dLeft:
		ck_nextX = dLeft
		passenger.velX = 0
		CK_PhysUpdateSimpleObj(passenger)

		if squish and passenger.leftTI != 0:
			CK_KillKeen()

		passenger.rightTI = 1
		return

	if dRight > 0 and -dx + 1 >= dRight:
		ck_nextX = s16(-dRight)
		passenger.velX = 0
		CK_PhysUpdateSimpleObj(passenger)

		if squish and passenger.rightTI != 0:
			CK_KillKeen()

		passenger.leftTI = 1
		return

	var dy: int = s16(passenger.deltaPosY - platform.deltaPosY)
	var dTop: int = s16(platform.clipRects.unitY2 - passenger.clipRects.unitY1)
	var dBottom: int = s16(passenger.clipRects.unitY2 - platform.clipRects.unitY1)

	if dBottom >= 0 and dBottom <= dy:
		if passenger == ck_keenObj:
			ck_keenState.platform = platform

		ck_nextY = s16(-dBottom)
		CK_PhysUpdateSimpleObj(passenger)

		if squish and passenger.bottomTI != 0:
			CK_KillKeen()

		# Riding the platform, unless passenger hits its head
		if passenger.bottomTI == 0:
			passenger.topTI = 0x19

		return

	if dTop >= 0 and dTop <= dy:
		ck_nextY = dTop
		CK_PhysUpdateNormalObj(passenger)
		if squish and passenger.topTI != 0:
			CK_KillKeen()

		passenger.bottomTI = 0x19
		return


func CK_SetAction(obj: CK_object, act: CK_action) -> void:
	obj.currentAction = act

	if act.chunkRight != 0 and obj.xDirection > 0:
		obj.gfxChunk = u16(act.chunkRight)
	elif act.chunkLeft != 0:
		obj.gfxChunk = u16(act.chunkLeft)

	if obj.gfxChunk == 0xFFFF: # (uint16_t)-1
		obj.gfxChunk = 0

	ck_nextX = 0
	ck_nextY = 0

	# TODO: Support clipped enums.
	var oldClipping: int = obj.clipped
	obj.clipped = CLIP_not
	CK_PhysUpdateNormalObj(obj)
	obj.clipped = oldClipping

	# TODO: Handle platforms
	if obj.clipped == CLIP_simple:
		CK_PhysFullClipToWalls(obj)
	elif obj.clipped == CLIP_normal:
		CK_PhysUpdateNormalObj(obj)


## (C dereferences act unchecked: a NULL act crashes there and errors here.)
func CK_SetAction2(obj: CK_object, act: CK_action) -> void:
	obj.currentAction = act
	obj.actionTimer = 0

	if act.chunkRight != 0:
		obj.gfxChunk = u16(act.chunkRight if (obj.xDirection > 0) else act.chunkLeft)
	if obj.gfxChunk == 0xFFFF: # (uint16_t)-1
		obj.gfxChunk = 0

	obj.visible = true
	ck_nextX = 0
	ck_nextY = 0

	if obj.topTI != 0x19:
		CK_PhysUpdateNormalObj(obj)


func CK_ObjectVisible(obj: CK_object) -> bool:
	# TODO: Use ScrollX0_T,  ScrollX1_T and co. directly?
	if obj.clipRects.tileX2 < RF_UnitToTile(rf_scrollXUnit) or obj.clipRects.tileY2 < RF_UnitToTile(rf_scrollYUnit) or obj.clipRects.tileX1 > (RF_UnitToTile(rf_scrollXUnit) + RF_PixelToTile(320)) or obj.clipRects.tileY1 > (RF_UnitToTile(rf_scrollYUnit) + RF_PixelToTile(208)):
		return false

	return true


func CK_PhysGravityHigh(obj: CK_object) -> void:
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			if obj.velY < 0 and obj.velY >= -4:
				ck_nextY = s16(ck_nextY + obj.velY)
				obj.velY = 0
				return
			obj.velY = s16(obj.velY + 4)
			if obj.velY > 70:
				obj.velY = 70
		ck_nextY = s16(ck_nextY + obj.velY)
		tickCount += 1


func CK_PhysGravityMid(obj: CK_object) -> void:
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			if obj.velY < 0 and obj.velY >= -3:
				ck_nextY = s16(ck_nextY + obj.velY)
				obj.velY = 0
				return
			obj.velY = s16(obj.velY + 3)
			if obj.velY > 70:
				obj.velY = 70
		ck_nextY = s16(ck_nextY + obj.velY)
		tickCount += 1


func CK_PhysGravityLow(obj: CK_object) -> void:
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# TODO: recheck this condition
		# if ((tickCount & 3) == 1)
		# (omnispeak's condition, kept: true only on tic 0)
		if ((0 if tickCount != 0 else 1) & 3) != 0:
			# if (tickCount == 0)	// This condition is seriously fucked up.
			obj.velY = s16(obj.velY + 1)
			if obj.velY > 70:
				obj.velY = 70
		ck_nextY = s16(ck_nextY + obj.velY)
		tickCount += 1


func CK_PhysDampHorz(obj: CK_object) -> void:
	var movingLeft: bool = (obj.velX < 0)
	var xAdj: int
	if obj.velX > 0:
		xAdj = -1
	elif obj.velX < 0:
		xAdj = 1
	else:
		xAdj = 0

	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			obj.velX = s16(obj.velX + xAdj)
			if (obj.velX < 0) != movingLeft:
				obj.velX = 0
		ck_nextX = s16(ck_nextX + obj.velX)
		tickCount += 1


func CK_PhysAccelHorz(obj: CK_object, accX: int, velLimit: int) -> void:
	accX = s16(accX)
	velLimit = s16(velLimit)
	var isNegative: bool = (obj.velX < 0)
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			obj.velX = s16(obj.velX + accX)
			if (obj.velX < 0) != isNegative:
				isNegative = (obj.velX < 0)
				obj.xDirection = -1 if isNegative else 1

			if obj.velX > velLimit:
				obj.velX = velLimit
			elif obj.velX < -velLimit:
				obj.velX = s16(-velLimit)
		ck_nextX = s16(ck_nextX + obj.velX)
		tickCount += 1


func CK_PhysAccelHorz2(obj: CK_object, accX: int, velLimit: int) -> void:
	accX = s16(accX)
	velLimit = s16(velLimit)
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			obj.velX = s16(obj.velX + accX)

			if obj.velX > velLimit:
				obj.velX = velLimit
			elif obj.velX < -velLimit:
				obj.velX = s16(-velLimit)
		ck_nextX = s16(ck_nextX + obj.velX)
		tickCount += 1


func CK_PhysAccelVert1(obj: CK_object, accY: int, velLimit: int) -> void:
	accY = s16(accY)
	velLimit = s16(velLimit)
	var lastTimeCount: int = SD_GetLastTimeCount()
	var tickCount: int = s32(lastTimeCount - SD_GetSpriteSync())
	while tickCount < lastTimeCount:
		# Every odd tic...
		if (tickCount & 1) != 0:
			obj.velY = s16(obj.velY + accY)

			if obj.velY > velLimit:
				obj.velY = velLimit
			elif obj.velY < -velLimit:
				obj.velY = s16(-velLimit)
		ck_nextY = s16(ck_nextY + obj.velY)
		tickCount += 1


# ===================================================================== ck_obj.c
# This file contains some object functions (think, etc) which are common to
# several episodes.
# AFAIK, There never was a "ck_obj.c" in the DOS source

## The maximum height of a gem door. Note that this is the height of the
## _full_ door, including the two ground tiles, not just the main portion
## stored in user1.
const CK_MAX_DOOR_HEIGHT: int = 50


func CK_DoorOpen(obj: CK_object) -> void:
	var tilesToReplace: PackedInt32Array = PackedInt32Array()
	tilesToReplace.resize(CK_MAX_DOOR_HEIGHT)

	if obj.user1 + 2 > CK_MAX_DOOR_HEIGHT:
		Quit("Door too tall!")
		return

	for i: int in range(obj.user1 + 2):
		tilesToReplace[i] = u16(CA_TileAtPos(s16(obj.posX), s16(obj.posY + i), 1) + 1)

	RF_ReplaceTiles(tilesToReplace, 0, 1, obj.posX, obj.posY, 1, obj.user1 + 2)


# (WITH_KEEN5)
func CK_SecurityDoorOpen(obj: CK_object) -> void:
	var tilesToReplace: PackedInt32Array = PackedInt32Array()
	tilesToReplace.resize(0x30)
	for y: int in range(4):
		for x: int in range(4):
			tilesToReplace[y * 4 + x] = u16(CA_TileAtPos(s16(obj.posX + x), s16(obj.posY + y), 1) - 4)

	RF_ReplaceTiles(tilesToReplace, 0, 1, obj.posX, obj.posY, 4, 4)
	obj.user1 = s16(obj.user1 + 1)
	if obj.user1 == 3:
		obj.currentAction = null


## chunk_id_t: chunk names, looked up with CK_LookupChunk. (Also used by ck6_obj1.c.)
const CK_ItemSpriteChunks: PackedStringArray = [
	"SPR_GEM_A1",
	"SPR_GEM_B1",
	"SPR_GEM_C1",
	"SPR_GEM_D1",
	"SPR_100_PTS1",
	"SPR_200_PTS1",
	"SPR_500_PTS1",
	"SPR_1000_PTS1",
	"SPR_2000_PTS1",
	"SPR_5000_PTS1",
	"SPR_1UP1",
	"SPR_STUNNER1",
	# (WITH_KEEN5)
	"SPR_SECURITYCARD_1",
]


# Object and Centilife functions "should" be in ckx_obj1.c
# but they are similar enough between episodes to put them all here
func CK_SpawnItem(tileX: int, tileY: int, itemNumber: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.clipped = CLIP_not
	# obj->active = OBJ_ACTIVE;
	obj.zLayer = 2
	obj.type = CT_CLASS("Item")
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.yDirection = -1
	obj.user1 = s16(itemNumber)
	obj.gfxChunk = u16(CK_LookupChunk(CK_ItemSpriteChunks[itemNumber]))
	obj.user2 = s16(obj.gfxChunk)
	obj.user3 = s16(obj.gfxChunk + 2)
	CK_SetAction(obj, CK_GetActionByName("CK_ACT_item"))


func CK_SpawnCentilifeNotify(tileX: int, tileY: int) -> void:
	var notify: CK_object = CK_GetNewObj(true)
	notify.type = 1
	notify.clipped = CLIP_not
	notify.zLayer = 3
	notify.posX = u16(RF_TileToUnit(tileX))
	notify.posY = u16(RF_TileToUnit(tileY))

	CK_SetAction(notify, CK_GetActionByName("CK_ACT_CentilifeNotify1"))


func CK_PointItem(obj: CK_object) -> void:
	# obj->timeUntillThink = 20;
	obj.visible = true
	obj.gfxChunk = u16(obj.gfxChunk + 1)
	if obj.gfxChunk == obj.user3:
		obj.gfxChunk = u16(obj.user2)


## Keen 6 specific (but also appears to be present in the Keen 5 EXE)
func CK_FallingItem(obj: CK_object) -> void:
	if obj.topTI != 0:
		CK_SetAction(obj, CK_GetActionByName("CK_ACT_item"))
	obj.gfxChunk = u16(obj.gfxChunk + 1)
	if obj.gfxChunk == obj.user3:
		obj.gfxChunk = u16(obj.user2)
	CK_PhysGravityHigh(obj)


# Platforms

# CK4: ck4_obj2.c
# CK5: ck5_obj?.c - This is the RED axis platform
# CK6  ck_obj1.c

## Note that Keen 5 was the only keen to have the purple parameter, but
## it is added here for the other Keens in order to reuse code
func CK_SpawnAxisPlatform(tileX: int, tileY: int, direction: int, purple: bool) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT_CLASS("Platform")
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.zLayer = 0
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))

	match direction:
		0:
			obj.xDirection = 0
			obj.yDirection = -1
		1:
			obj.xDirection = 1
			obj.yDirection = 0
		2:
			obj.xDirection = 0
			obj.yDirection = 1
		3:
			obj.xDirection = -1
			obj.yDirection = 0

	# (WITH_KEEN5)
	if purple:
		obj.posX = u16(obj.posX + 0x40)
		obj.posY = u16(obj.posY + 0x40)
		CK_SetAction(obj, CK_GetActionByName("CK5_ACT_purpleAxisPlatform"))
	else:
		CK_SetAction(obj, CK_GetActionByName("CK_ACT_AxisPlatform"))
	# TODO: These should *not* be done here.
	obj.gfxChunk = u16(obj.currentAction.chunkLeft)
	# (omnispeak caches obj.gfxChunk here; the original does not, and its memory map shows
	# the difference at a level's load: keen5_mem01_a. The level's marks cache every sprite.)
	# CK_ResetClipRects(obj);


func CK_AxisPlatform(obj: CK_object) -> void:
	var nextPosUnit: int
	var nextPosTile: int

	if ck_nextX != 0 or ck_nextY != 0:
		return
	# TODO: Implement properly.
	ck_nextX = s16(obj.xDirection * 12 * SD_GetSpriteSync())
	ck_nextY = s16(obj.yDirection * 12 * SD_GetSpriteSync())

	if obj.xDirection == 1:
		nextPosUnit = u16(obj.clipRects.unitX2 + ck_nextX)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileX2 != nextPosTile and CA_TileAtPos(s16(nextPosTile), obj.clipRects.tileY1, 2) == 0x1F:
			obj.xDirection = -1
			# TODO: Change DeltaVelocity
			ck_nextX = s16(ck_nextX - (nextPosUnit & 255))
	elif obj.xDirection == -1:
		nextPosUnit = u16(obj.clipRects.unitX1 + ck_nextX)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileX1 != nextPosTile and CA_TileAtPos(s16(nextPosTile), obj.clipRects.tileY1, 2) == 0x1F:
			obj.xDirection = 1
			# TODO: Change DeltaVelocity
			# CK_PhysUpdateX(obj, 256 - nextPosUnit&255);
			ck_nextX = s16(ck_nextX + ((256 - nextPosUnit) & 255))
	elif obj.yDirection == 1:
		nextPosUnit = u16(obj.clipRects.unitY2 + ck_nextY)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileY2 != nextPosTile and CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile), 2) == 0x1F:
			if CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile - 2), 2) == 0x1F:
				# Stop the platform.
				obj.visible = true
				ck_nextY = 0
			else:
				obj.yDirection = -1
				# TODO: Change DeltaVelocity
				ck_nextY = s16(ck_nextY - (nextPosUnit & 255))
	elif obj.yDirection == -1:
		nextPosUnit = u16(obj.clipRects.unitY1 + ck_nextY)
		nextPosTile = u16(RF_UnitToTile(nextPosUnit))
		if obj.clipRects.tileY1 != nextPosTile and CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile), 2) == 0x1F:
			if CA_TileAtPos(obj.clipRects.tileX1, s16(nextPosTile + 2), 2) == 0x1F:
				# Stop the platform.
				obj.visible = true
				ck_nextY = 0
			else:
				obj.yDirection = 1
				# TODO: Change DeltaVelocity
				ck_nextY = s16(ck_nextY + 256 - (nextPosUnit & 255))


func CK_SpawnFallPlat(tileX: int, tileY: int) -> void:
	var new_object: CK_object = CK_GetNewObj(false)
	new_object.type = CT_CLASS("Platform")
	new_object.active = OBJ_ALWAYS_ACTIVE
	new_object.zLayer = 0
	new_object.posX = u16(RF_TileToUnit(tileX))
	# new_object->user1 = new_object->posY = RF_TileToUnit(tileY);
	new_object.posY = u16(RF_TileToUnit(tileY))
	new_object.user1 = s16(new_object.posY)
	new_object.xDirection = IN_motion_None
	new_object.yDirection = IN_motion_Down
	new_object.clipped = CLIP_not
	CK_SetAction(new_object, CK_GetActionByName("CK_ACT_FallPlat0"))


func CK_FallPlatSit(obj: CK_object) -> void:
	if obj == ck_keenState.platform:
		ck_nextY = s16(SD_GetSpriteSync() * 16)
		obj.velY = 0
		# (unsigned)(obj->posY + ck_nextY - obj->user1) >= 0x80
		if ((obj.posY + ck_nextY - obj.user1) & 0xFFFFFFFF) >= 0x80:
			obj.currentAction = CK_GetActionByName("CK_ACT_FallPlat1")


func CK_FallPlatFall(obj: CK_object) -> void:
	var newY: int
	var newYT: int

	CK_PhysGravityHigh(obj)
	newY = u16(obj.clipRects.unitY2 + ck_nextY)
	newYT = u16(RF_UnitToTile(newY))

	# Stop falling if platform hits a block
	if (obj.clipRects.tileY2 != newYT) and (CA_TileAtPos(obj.clipRects.tileX1, s16(newYT), 2) == 0x1F):
		ck_nextY = s16(0xFF - (obj.clipRects.unitY2 & 0xFF))
		if ck_keenState.platform != obj:
			obj.currentAction = CK_GetActionByName("CK_ACT_FallPlat2")


func CK_FallPlatRise(obj: CK_object) -> void:
	if ck_keenState.platform == obj:
		obj.velY = 0
		obj.currentAction = CK_GetActionByName("CK_ACT_FallPlat1")
	elif obj.posY <= (obj.user1 & 0xFFFFFFFF): # (unsigned)obj->posY <= (unsigned)obj->user1
		ck_nextY = s16(obj.user1 - obj.posY)
		obj.currentAction = CK_GetActionByName("CK_ACT_FallPlat0")


# (WITH_KEEN5 || WITH_KEEN6)

func CK_SpawnStandPlatform(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT_CLASS("Platform")
	obj.active = OBJ_ACTIVE
	obj.zLayer = 0
	obj.posX = u16(RF_TileToUnit(tileX))
	# obj->posY = obj->user1 = RF_TileToUnit(tileY);
	obj.user1 = s16(RF_TileToUnit(tileY))
	obj.posY = u16(obj.user1)
	obj.xDirection = 0
	obj.yDirection = 1
	obj.clipped = CLIP_not
	CK_SetAction(obj, CK_GetActionByName("CK_ACT_StandPlatform"))
	obj.gfxChunk = u16(obj.currentAction.chunkLeft)
	# (omnispeak caches obj.gfxChunk here; the original does not, and its memory map shows
	# the difference at a level's load: keen5_mem01_a. The level's marks cache every sprite.)


## Spawn a GoPlat
func CK_SpawnGoPlat(tileX: int, tileY: int, direction: int, purple: bool) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT_CLASS("Platform")
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.zLayer = 0
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = IN_motion_None
	obj.yDirection = IN_motion_Down
	obj.clipped = CLIP_not

	# (WITH_KEEN5)
	if purple:
		obj.posX = u16(obj.posX + 0x40)
		obj.posY = u16(obj.posY + 0x40)
		CK_SetAction(obj, CK_GetActionByName("CK5_ACT_purpleGoPlat"))
	else:
		CK_SetAction(obj, CK_GetActionByName("CK_ACT_GoPlat0"))

	CA_SetTileAtPos(s16(tileX), s16(tileY), 2, direction + 0x5B)

	obj.user1 = s16(direction)
	obj.user2 = 256


# ck_infoplaneArrowsX / ck_infoplaneArrowsY are declared in gal_ck.gd.

## (C indexes the 8-entry arrow tables with user1, which the check below lets
## reach 8: C then reads past the array; here that index is an error.)
func CK_GoPlatThink(obj: CK_object) -> void:
	if ck_nextX != 0 or ck_nextY != 0:
		return

	var delta: int = s16(SD_GetSpriteSync() * 12)

	# Will we reach a new tile?
	if obj.user2 > delta:
		# No... keep moving in the same direction.
		obj.user2 = s16(obj.user2 - delta)

		var dirX: int = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		var dirY: int = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)
	else:
		# Move to next tile.
		var dirX: int = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + obj.user2)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - obj.user2)

		var dirY: int = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + obj.user2)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - obj.user2)

		var tileX: int = RF_UnitToTile(u16(obj.posX + ck_nextX))
		var tileY: int = RF_UnitToTile(u16(obj.posY + ck_nextY))

		obj.user1 = s16(CA_TileAtPos(tileX, tileY, 2) - 0x5B)

		if (obj.user1 < 0) or (obj.user1 > 8):
			Quit("Goplat moved to a bad spot.")
			return

		delta = s16(delta - obj.user2)
		obj.user2 = s16(256 - delta)

		# Move in the new direction.
		dirX = ck_infoplaneArrowsX[obj.user1]
		if dirX == 1:
			# Moving right.
			ck_nextX = s16(ck_nextX + delta)
		elif dirX == -1:
			# Moving left
			ck_nextX = s16(ck_nextX - delta)

		dirY = ck_infoplaneArrowsY[obj.user1]
		if dirY == 1:
			# Moving down
			ck_nextY = s16(ck_nextY + delta)
		elif dirY == -1:
			# Moving up
			ck_nextY = s16(ck_nextY - delta)


## Spawn a "Sneak Plat".
func CK_SneakPlatSpawn(tileX: int, tileY: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT_CLASS("Platform")
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.zLayer = 0
	# obj->user1 = obj->posX = RF_TileToUnit(tileX);
	obj.posX = u16(RF_TileToUnit(tileX))
	obj.user1 = s16(obj.posX)
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.xDirection = 0
	obj.yDirection = 1
	obj.clipped = CLIP_not

	CK_SetAction(obj, CK_GetActionByName("CK_ACT_sneakPlatWait"))
	# (omnispeak caches obj.gfxChunk here; the original does not, and its memory map shows
	# the difference at a level's load: keen5_mem01_a. The level's marks cache every sprite.)


func CK_SneakPlatThink(obj: CK_object) -> void:
	if ck_keenObj.currentAction == CK_GetActionByName("CK_ACT_keenJump1"):
		if ck_keenObj.xDirection == 1:
			var dist: int = obj.clipRects.unitX1 - ck_keenObj.clipRects.unitX2
			if dist > 0x400 or dist < 0:
				return
		else:
			var dist: int = ck_keenObj.clipRects.unitX1 - obj.clipRects.unitX2
			if dist > 0x400 or dist < 0:
				return

		var vertDist: int = ck_keenObj.posY - obj.posY
		if vertDist < -0x600 or vertDist > 0x600:
			return

		obj.xDirection = ck_keenObj.xDirection
		obj.currentAction = CK_GetActionByName("CK_ACT_sneakPlatSneak")


# TURRETS

func CK_TurretSpawn(tileX: int, tileY: int, direction: int) -> void:
	var obj: CK_object = CK_GetNewObj(false)

	obj.type = CT_CLASS("Turret")
	obj.active = OBJ_ACTIVE
	obj.clipRects.tileX2 = u16(tileX)
	obj.clipRects.tileX1 = obj.clipRects.tileX2
	obj.clipRects.tileY2 = u16(tileY)
	obj.clipRects.tileY1 = obj.clipRects.tileY2

	obj.posX = u16(RF_TileToUnit(tileX))
	obj.posY = u16(RF_TileToUnit(tileY))
	obj.clipRects.unitX2 = u16(RF_TileToUnit(tileX))
	obj.clipRects.unitX1 = obj.clipRects.unitX2
	obj.clipRects.unitY2 = u16(RF_TileToUnit(tileY))
	obj.clipRects.unitY1 = obj.clipRects.unitY2

	obj.user1 = s16(direction)

	CK_SetAction(obj, CK_GetActionByName("CK_ACT_turretWait"))


func CK_TurretShoot(obj: CK_object) -> void:
	var shot: CK_object = CK_GetNewObj(true)

	shot.type = CT5_EnemyShot # TurretShot (C uses Keen 5's class number in every episode)
	if CFG_GetConfigBool("ck_turretShotsPersist", CK_INT("ck_turretShotsPersist", 1 if ck_currentEpisode_ep == EP_CK6 else 0) != 0):
		shot.active = OBJ_ACTIVE
	else:
		shot.active = OBJ_EXISTS_ONLY_ONSCREEN
	shot.clipped = CLIP_normal
	shot.posX = obj.posX
	shot.posY = obj.posY

	match obj.user1:
		0:
			shot.velY = -64
		1:
			shot.velX = 64
		2:
			shot.velY = 64
		3:
			shot.velX = -64

	CK_SetAction(shot, CK_GetActionByName("CK_ACT_turretShot1"))
	SD_PlaySound(CK_SOUNDNUM("SOUND_ENEMYSHOOT"))


func CK_TurretShotCol(me: CK_object, other: CK_object) -> void:
	if other.type == CT_Player:
		CK_KillKeen()
		CK_SetAction2(me, CK_GetActionByName("CK_ACT_turretShotHit1"))


func CK_TurretShotDraw(obj: CK_object) -> void:
	if obj.topTI != 0 or obj.bottomTI != 0 or obj.leftTI != 0 or obj.rightTI != 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_ENEMYSHOTHIT"))
		# obj->clipped=false;
		CK_SetAction2(obj, CK_GetActionByName("CK_ACT_turretShotHit1"))

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.currentAction.chunkLeft, false, obj.zLayer)


func CK_OBJ_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK_DoorOpen", &"CK_DoorOpen")
	# (WITH_KEEN5)
	CK_ACT_AddFunction("CK_SecurityDoorOpen", &"CK_SecurityDoorOpen")
	CK_ACT_AddFunction("CK_PointItem", &"CK_PointItem")
	CK_ACT_AddFunction("CK_FallingItem", &"CK_FallingItem")

	CK_ACT_AddFunction("CK_AxisPlatform", &"CK_AxisPlatform")

	CK_ACT_AddFunction("CK_FallPlatSit", &"CK_FallPlatSit")
	CK_ACT_AddFunction("CK_FallPlatFall", &"CK_FallPlatFall")
	CK_ACT_AddFunction("CK_FallPlatRise", &"CK_FallPlatRise")
	# (WITH_KEEN5 || WITH_KEEN6)
	CK_ACT_AddFunction("CK_GoPlatThink", &"CK_GoPlatThink")
	CK_ACT_AddFunction("CK_SneakPlatThink", &"CK_SneakPlatThink")

	CK_ACT_AddFunction("CK_TurretShoot", &"CK_TurretShoot")
	CK_ACT_AddColFunction("CK_TurretShotCol", &"CK_TurretShotCol")
	CK_ACT_AddFunction("CK_TurretShotDraw", &"CK_TurretShotDraw")


# ===================================================================== ck_misc.c

func CK_SetDraw(obj: CK_object) -> void:
	obj.visible = true


## Think function for adding gravity
func CK_Fall(obj: CK_object) -> void:
	CK_PhysGravityHigh(obj)
	ck_nextX = s16(obj.velX * SD_GetSpriteSync())


## Think function for adding a slightly lower amount of gravity
func CK_Fall2(obj: CK_object) -> void:
	CK_PhysGravityMid(obj)
	ck_nextX = s16(obj.velX * SD_GetSpriteSync())


func CK_Glide(obj: CK_object) -> void:
	ck_nextX = s16(obj.velX * SD_GetSpriteSync())
	ck_nextY = s16(obj.velY * SD_GetSpriteSync())


func CK_BasicDrawFunc1(obj: CK_object) -> void:
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## For walking and turning around at edges
func CK_BasicDrawFunc2(obj: CK_object) -> void:
	# Hit wall walking right; turn around and go left
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Walked off of ledge; turn around
	elif obj.topTI == 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = s16(-obj.xDirection)
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## For slugs  (and maybe others???)
func CK_BasicDrawFunc3(obj: CK_object) -> void:
	# Hit wall walking right; turn around and go left
	if obj.xDirection == IN_motion_Right and obj.leftTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Left
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Hit wall walking left; turn around and go right
	elif obj.xDirection == IN_motion_Left and obj.rightTI != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX)
		obj.xDirection = IN_motion_Right
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)
	# Walked off of ledge; turn around
	elif obj.topTI == 0 or (obj.topTI & ~SLOPEMASK) != 0:
		obj.posX = u16(obj.posX - obj.deltaPosX * 2)
		obj.xDirection = s16(-obj.xDirection)
		obj.timeUntillThink = u16(US_RndT() / 32)
		CK_SetAction2(obj, obj.currentAction)

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## Some weird placeholder
func CK_ObjBadstate(_obj: CK_object) -> void:
	Quit("Object with bad state!")


## Think function for stunned creatures
func CK_BasicDrawFunc4(obj: CK_object) -> void:
	var starsX: int
	var starsY: int

	# Handle physics
	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.velX = 0

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.velY = 0
		obj.velX = 0
		if obj.currentAction.next != null:
			CK_SetAction2(obj, obj.currentAction.next)

	# Draw the primary chunk
	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# Draw the stunner stars, offset based on the initial type of the stunned
	# critter

	starsY = 0
	starsX = 0

	if ck_currentEpisode_ep == EP_CK4:
		match obj.user4:
			CT4_Slug:
				starsY = -0x80
			CT4_Egg:
				starsX = 0x80
				starsY = -0x80
			CT4_Wormmouth:
				starsX = 0x40
				starsY = -350
			CT4_Bounder:
				starsX = 0x40
				starsY = -0x80
			CT4_Inchworm:
				starsX = -0x40
				starsY = -0x80
			CT4_Lick:
				starsY = -0x80
			CT4_Smirky:
				starsX = 0x80
	elif ck_currentEpisode_ep == EP_CK5:
		match obj.user4:
			CT5_Sparky:
				starsX += 0x40
			CT5_Ampton:
				starsY -= 0x80
			CT5_Korath:
				starsY -= 0x80
	elif ck_currentEpisode_ep == EP_CK6:
		match obj.user4:
			CT6_Bloogguard:
				starsX = 0x100
				starsY = -0x40
			CT6_Flect:
				starsX = 0x40
				starsY = -0x40
			CT6_Bloog, CT6_Nospike:
				starsX = 0x80
				starsY = -0x40
			CT6_Blooglet, CT6_Babobba:
				starsY = -0x80
			CT6_Fleex:
				starsX = 0x100
				starsY = 0x80
			CT6_Ceilick:
				starsY = 0xC0
			_:
				Quit("No star spec for object!")
				return

	# Tick the star 3-frame animation forward
	obj.user1 = s16(obj.user1 + SD_GetSpriteSync())
	if obj.user1 > 10:
		obj.user1 = s16(obj.user1 - 10)
		obj.user2 = s16(obj.user2 + 1)
		if obj.user2 >= 3:
			obj.user2 = 0

	obj.user3 = RF_AddSpriteDrawUsing16BitOffset(obj.user3, obj.posX + starsX, obj.posY + starsY, obj.user2 + CK_CHUNKNUM("SPR_STARS1"), false, 3)


func CK_StunCreature(creature: CK_object, stunner: CK_object, new_creature_act: CK_action) -> void:
	# Kill the stunner shot
	CK_ShotHit(stunner)

	# Set stunned creature action
	creature.user3 = 0
	creature.user2 = 0
	creature.user1 = 0
	creature.user4 = s16(creature.type)
	CK_SetAction2(creature, new_creature_act)
	creature.type = CT_CLASS("StunnedCreature")

	# Make the creature jump up a bit
	creature.velY = s16(creature.velY - 0x18)
	if creature.velY < -0x30:
		creature.velY = -0x30


func CK_DeadlyCol(_o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Stunner:
		CK_ShotHit(o2)
	elif o2.type == CT_Player:
		CK_KillKeen()


func CK_LethalCol(_o1: CK_object, o2: CK_object) -> void:
	if o2.type == CT_Player:
		CK_KillKeen()


## This comes before DieOnContactDraw in the CK6 Disassembly
## Even though it is  only used for Giks, it is  not placed next to
## the rest of the Gik code
## Maybe leftover melon cart code?
func CK_PushKeenCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		ck_keenIgnoreVertClip = true
		CK_PhysPushX(b, a)
		ck_keenIgnoreVertClip = false


func CK_CarryKeenCol(a: CK_object, b: CK_object) -> void:
	if b.type == CT_Player:
		CK_PhysPushY(b, a)


## This comes right before ShrapnelTileCol in the CK6 Disassembly
## The use of the "currenAction->next" pattern suggests that it was another
## episode-independent Draw function, even though it is apparently only used for the
## bipship. Perhaps another remnant from Keen Dreams
## (C quirk, kept: it checks currentAction, not currentAction->next, so a NULL
## next reaches CK_SetAction2, which crashes in C and errors here.)
func CK_DieOnContactDraw(obj: CK_object) -> void:
	if obj.rightTI != 0 or obj.leftTI != 0:
		obj.velX = 0

	if obj.bottomTI != 0:
		obj.velY = 0

	if obj.topTI != 0:
		obj.velY = 0
		if obj.currentAction != null:
			CK_SetAction2(obj, obj.currentAction.next)
		else:
			CK_RemoveObj(obj)
			return

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)


## CK_ShrapnelTileCol's static bouncearray.
const bouncearray: Array = [
	[0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0],
	[0x7, 0x6, 0x5, 0x4, 0x3, 0x2, 0x1, 0x0],
	[0x5, 0x4, 0x3, 0x2, 0x1, 0x0, 0xF, 0xE],
	[0x5, 0x4, 0x3, 0x2, 0x1, 0x0, 0xF, 0xE],
	[0x3, 0x2, 0x1, 0x0, 0xF, 0xE, 0xD, 0xC],
	[0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2],
	[0x9, 0x8, 0x7, 0x6, 0x5, 0x4, 0x3, 0x2],
	[0xB, 0xA, 0x9, 0x8, 0x7, 0x6, 0x5, 0x4],
]


## Tile collision for making the mine and shelley bits bounce, as well as the
## babobba shot
## It was also used in Keen Dreams for the flower power
func CK_ShrapnelTileCol(obj: CK_object) -> void:
	var bouncePower: int # uint32_t: is long in keen source
	var topflags_0: int # uint16_t
	var velY: int # uint16_t
	var absvelX: int # uint16_t
	var d: int # uint16_t
	var motion: int # uint16_t

	obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)

	# Bounce backwards if a side wall is hit
	if obj.leftTI != 0 or obj.rightTI != 0:
		obj.velX = s16(-obj.velX / 2)

	# Bounce down if a top wall is hit
	if obj.bottomTI != 0:
		obj.velY = s16(-obj.velY / 2)
		return

	# Bounce sideways if a slope floor is hit
	# ORIGINAL GAME BUG: We only want the collision info for this, not anything else,
	# as this needs to be in the range 0-7 for the array access. Mask it off here.
	topflags_0 = u16(obj.topTI & 7)
	if topflags_0 == 0:
		return

	if obj.velY < 0:
		obj.velY = 0

	# CK_Cross_abs(x): ((x) > 0 ? (x) : (-(x)))
	absvelX = u16(obj.velX if obj.velX > 0 else -obj.velX)
	velY = u16(obj.velY)

	if absvelX > velY:
		if absvelX > velY * 2:
			d = 0
			bouncePower = (absvelX * 286) & 0xFFFFFFFF
		else:
			d = 1
			bouncePower = (absvelX * 362) & 0xFFFFFFFF
	else:
		if velY > absvelX * 2:
			d = 3
			bouncePower = (velY * 256) & 0xFFFFFFFF
		else:
			d = 2
			bouncePower = (velY * 286) & 0xFFFFFFFF

	if obj.velX > 0: # mirror around y-axis
		d = u16(7 - d)

	bouncePower /= 2 # absorb energy

	motion = bouncearray[topflags_0][d]

	# (bouncePower is unsigned: -(bouncePower / n) wraps as uint32_t, and its
	# low 16 bits, which the int16_t store keeps, are those of the negation)
	match motion:
		0:
			obj.velX = s16(bouncePower / 286)
			obj.velY = s16(-obj.velX / 2)
		1:
			obj.velX = s16(bouncePower / 362)
			obj.velY = s16(-obj.velX)
		2:
			obj.velY = s16(-(bouncePower / 286))
			obj.velX = s16(-obj.velY / 2)
		3, 4:
			obj.velX = 0
			obj.velY = s16(-(bouncePower / 256))
		5:
			obj.velY = s16(-(bouncePower / 286))
			obj.velX = s16(obj.velY / 2)
		6:
			obj.velY = s16(-(bouncePower / 362))
			obj.velX = obj.velY
		7:
			obj.velX = s16(-(bouncePower / 286))
			obj.velY = s16(obj.velX / 2)
		8:
			obj.velX = s16(-(bouncePower / 286))
			obj.velY = s16(-obj.velX / 2)
		9:
			obj.velX = s16(-(bouncePower / 362))
			obj.velY = s16(-obj.velX)
		0xA:
			obj.velY = s16(bouncePower / 286)
			obj.velX = s16(-obj.velY / 2)
		0xB, 0xC:
			obj.velX = 0
			obj.velY = s16(-(bouncePower / 256))
		0xD:
			obj.velY = s16(bouncePower / 286)
			obj.velX = s16(obj.velY / 2)
		0xE:
			obj.velX = s16(bouncePower / 362)
			obj.velY = s16(bouncePower / 362)
		0xF:
			obj.velX = s16(bouncePower / 256)
			obj.velY = s16(obj.velX / 2)
		_:
			pass

	# if speed is lower than threshhold, then disappear
	if bouncePower < 0x1000:
		# The babobba shot DOES have a next action, whereas the CK5 shrapnel doesn't
		# The original .exe has no check for a  NULL action here
		# we can't advance to a NULL action, because omnispeak will segfault (Keen5 wouldn't)
		# so we need to check if the next action is NULL

		if obj.currentAction.next != null:
			CK_SetAction2(obj, obj.currentAction.next)
		else:
			# In order to get dumps to match properly, though, we
			# need obj->currentAction to be NULL.
			# In Keen5, oftern obj->visible is set, too, as
			# the object has moved (even if it is now invalid.
			obj.currentAction = null
			obj.visible = true
			# These are more bizarre, but needed for the K5 High Scores shelley bits.
			obj.deltaPosY = 0
			obj.deltaPosX = 0
			obj.actionTimer = 3
			obj.sde = RF_RemoveSpriteDraw(obj.sde)
			CK_RemoveObj(obj)


func CK_Misc_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK_SetDraw", &"CK_SetDraw")
	CK_ACT_AddFunction("CK_Fall", &"CK_Fall")
	CK_ACT_AddFunction("CK_Fall2", &"CK_Fall2")
	CK_ACT_AddFunction("CK_Glide", &"CK_Glide")
	CK_ACT_AddFunction("CK_BasicDrawFunc1", &"CK_BasicDrawFunc1")
	CK_ACT_AddFunction("CK_BasicDrawFunc2", &"CK_BasicDrawFunc2")
	CK_ACT_AddFunction("CK_BasicDrawFunc3", &"CK_BasicDrawFunc3")
	CK_ACT_AddFunction("CK_ObjBadstate", &"CK_ObjBadstate")
	CK_ACT_AddFunction("CK_BasicDrawFunc4", &"CK_BasicDrawFunc4")
	CK_ACT_AddColFunction("CK_DeadlyCol", &"CK_DeadlyCol")
	CK_ACT_AddColFunction("CK_LethalCol", &"CK_LethalCol")

	CK_ACT_AddColFunction("CK_PushKeenCol", &"CK_PushKeenCol")
	CK_ACT_AddColFunction("CK_CarryKeenCol", &"CK_CarryKeenCol")
	CK_ACT_AddFunction("CK_ShrapnelTileCol", &"CK_ShrapnelTileCol")
	CK_ACT_AddFunction("CK_DieOnContactDraw", &"CK_DieOnContactDraw")


# ===================================================================== ck_map.c

# =========================================================================

func CK_DemoSignSpawn() -> void:
	ck_scoreBoxObj.type = CT_Friendly
	ck_scoreBoxObj.zLayer = 3
	ck_scoreBoxObj.active = OBJ_ALWAYS_ACTIVE
	ck_scoreBoxObj.clipped = CLIP_not

	# Set all user vars to -1 to force scorebox redraw
	ck_scoreBoxObj.user4 = -1
	ck_scoreBoxObj.user3 = -1
	ck_scoreBoxObj.user2 = -1
	ck_scoreBoxObj.user1 = -1

	if ck_inHighScores:
		# Don't display anything in the high scores
		ck_scoreBoxObj.currentAction = CK_GetActionByName("CK_ACT_NULL")
	elif IN_DemoGetMode() != 0:
		# If this is a demo, display the DEMO banner
		CK_SetAction(ck_scoreBoxObj, CK_GetActionByName("CK_ACT_DemoSign"))
		CA_MarkGrChunk(CK_CHUNKNUM("SPR_DEMOSIGN"))
	else:
		# If a normal game, display the scorebox
		CK_SetAction(ck_scoreBoxObj, CK_GetActionByName("CK_ACT_ScoreBox"))


func CK_DemoSign(demo: CK_object) -> void:
	if demo.posX == rf_scrollXUnit and demo.posY == rf_scrollYUnit:
		return
	demo.posX = u16(rf_scrollXUnit)
	demo.posY = u16(rf_scrollYUnit)

	# place demo sprite in center top
	demo.sde = RF_AddSpriteDraw(demo.sde, demo.posX + 0x0A00 - 0x200, demo.posY + 0x80, CK_CHUNKNUM("SPR_DEMOSIGN"), false, 3)


# ScoreBox update
# Scorebox works by drawing tile8s over the sprite that has been cached in
# memory.
#
# Because vanilla keen cached four shifts of the scorebox, this redraw
# procedure would have to be repeated for each shift.
#
# This is not the case for omnispeak, which just caches one copy of
# each sprite.

## Draws a Tile8 to an unmasked planar graphic.
## `dest` is C's uint8_t *dest as an offset into SPR_SCOREBOX's cached
## VH_ShiftedSprite data, the only buffer the C ever points it into.
func CK_ScoreBoxDrawTile8(tilenum: int, dest: int, destWidth: int, planeSize: int) -> void:
	var src: PackedByteArray = CA_GetGrChunk(int(ca_gfxInfoE.offTiles8), 0, "ScoreBox", true)
	var s: int = 32 * tilenum
	var spr: VH_ShiftedSprite = CA_GetGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"), 0, "ScoreBox", true)
	var buf: PackedByteArray = spr.data

	# Copy the tile to the target bitmap
	for plane: int in range(4):
		var d: int = dest
		for row: int in range(8):
			buf[d] = src[s]
			s += 1
			d += destWidth
		dest += planeSize


func CK_UpdateScoreBox(scorebox: CK_object) -> void:
	var updated: bool = false

	# Don't draw anything for the high score level
	if ck_inHighScores:
		return

	# Show the demo sign for the demo mode
	if IN_DemoGetMode() != 0:
		CK_DemoSign(scorebox)
		return

	if not ck_scoreBoxEnabled:
		return

	var box: Dictionary = VH_GetSpriteTableEntry(CK_CHUNKNUM("SPR_SCOREBOX") - int(ca_gfxInfoE.offSprites))

	var spr: VH_ShiftedSprite = CA_GetGrChunk(CK_CHUNKNUM("SPR_SCOREBOX"), 0, "ScoreBox", true)

	# Draw the score if it's changed
	# (user2 is int16_t: a low word >= 0x8000 never compares equal, so the
	# score redraws every frame then, as in C)
	if (scorebox.user1 != (ck_gameState.keenScore >> 16)) or (scorebox.user2 != (ck_gameState.keenScore & 0xFFFF)):
		var place: int
		var len_: int # C: len (renamed: len is a GDScript builtin)
		var planeSize: int
		var buf: String
		var dest: int

		# Start drawing the tiles after the mask plane,
		# and four rows from the top
		dest = 0
		planeSize = spr.sprShiftByteWidths[0] * int(box.height)
		dest += planeSize
		dest += int(box.width) * 4 + 1

		buf = "%d" % s32(ck_gameState.keenScore)
		len_ = buf.length()

		# Draw the leading emptiness
		place = 9
		while place > len_:
			CK_ScoreBoxDrawTile8(0x29, dest, box.width, planeSize)
			dest += 1
			place -= 1

		# Draw the score
		for c: int in range(buf.length()):
			CK_ScoreBoxDrawTile8(buf.unicode_at(c) - 6, dest, box.width, planeSize)
			dest += 1

		scorebox.user1 = s16(ck_gameState.keenScore >> 16)
		scorebox.user2 = s16(ck_gameState.keenScore & 0xFFFF)
		updated = true

	# Draw the number of shots if it's changed
	if scorebox.user3 != ck_gameState.numShots:
		var place: int
		var len_: int # C: len (renamed: len is a GDScript builtin)
		var planeSize: int
		var buf: String
		var dest: int

		# Start drawing the tiles after the mask plane,
		# and 12 rows from the top
		dest = 0
		planeSize = int(box.width) * int(box.height)
		dest += planeSize
		dest += int(box.width) * 20 + 8

		if ck_gameState.numShots >= 99:
			buf = "99"
		else:
			buf = "%d" % ck_gameState.numShots

		len_ = buf.length()

		# Draw the leading emptiness
		place = 2
		while place > len_:
			CK_ScoreBoxDrawTile8(0x29, dest, box.width, planeSize)
			dest += 1
			place -= 1

		# Draw the score
		for c: int in range(buf.length()):
			CK_ScoreBoxDrawTile8(buf.unicode_at(c) - 6, dest, box.width, planeSize)
			dest += 1

		scorebox.user3 = s16(ck_gameState.numShots)

		updated = true

	# Draw the number of lives if it's changed
	if scorebox.user4 != ck_gameState.numLives:
		var place: int
		var len_: int # C: len (renamed: len is a GDScript builtin)
		var planeSize: int
		var buf: String
		var dest: int

		# Start drawing the tiles after the mask plane,
		# and 12 rows from the top
		dest = 0
		planeSize = int(box.width) * int(box.height)
		dest += planeSize
		dest += int(box.width) * 20 + 3

		if ck_gameState.numLives >= 99:
			buf = "99"
		else:
			buf = "%d" % ck_gameState.numLives

		len_ = buf.length()

		# Draw the leading emptiness
		place = 2
		while place > len_:
			CK_ScoreBoxDrawTile8(0x29, dest, box.width, planeSize)
			dest += 1
			place -= 1

		# Draw the score
		for c: int in range(buf.length()):
			CK_ScoreBoxDrawTile8(buf.unicode_at(c) - 6, dest, box.width, planeSize)
			dest += 1

		scorebox.user4 = s16(ck_gameState.numLives)
		updated = true

	# Now draw the scorebox to the screen
	if scorebox.posX != rf_scrollXUnit or scorebox.posY != rf_scrollYUnit:
		scorebox.posX = u16(rf_scrollXUnit)
		scorebox.posY = u16(rf_scrollYUnit)
		updated = true

	if updated:
		CAL_ShiftSprite(spr.data, spr.data, spr.sprShiftOffset[1], box.width, box.height, 2)
		CAL_ShiftSprite(spr.data, spr.data, spr.sprShiftOffset[2], box.width, box.height, 4)
		CAL_ShiftSprite(spr.data, spr.data, spr.sprShiftOffset[3], box.width, box.height, 6)
		scorebox.sde = RF_AddSpriteDraw(scorebox.sde, scorebox.posX + 0x40, scorebox.posY + 0x40, CK_CHUNKNUM("SPR_SCOREBOX"), false, 3)


# =========================================================================

# MapKeen Thinks
# user1 stores compass direction
# user2 stores animation frame counter
# user3 stores some sort of velocity

## Note that, in the original game uses these values -1, then has an extra +1 in the anim frame
## array below (and elsewhere where updated). (chunk_id_t: chunk names.)
const ck_mapKeenBaseFrame: PackedStringArray = [
	"SPR_MAPKEEN_WALK1_N",
	"SPR_MAPKEEN_WALK1_NE",
	"SPR_MAPKEEN_WALK1_E",
	"SPR_MAPKEEN_WALK1_SE",
	"SPR_MAPKEEN_WALK1_S",
	"SPR_MAPKEEN_WALK1_SW",
	"SPR_MAPKEEN_WALK1_W",
	"SPR_MAPKEEN_WALK1_NW",
]

const ck_mapKeenAnimFrame: PackedInt32Array = [1, 2, 0, 2]


func CK_SpawnMapKeen(tileX: int, tileY: int) -> void:
	# (WITH_KEEN4)
	if ck_currentEpisode_ep == EP_CK4 and ck_gameState.levelState == LS_Foot:
		ck_keenObj.clipped = CLIP_not
		ck_keenObj.type = CT_Player
		ck_keenObj.posX = u16(ck_gameState.mapPosX)
		ck_keenObj.posY = u16(ck_gameState.mapPosY)
		ck_keenObj.active = OBJ_ALWAYS_ACTIVE
		ck_keenObj.zLayer = PRIORITIES - 1
		ck_keenObj.yDirection = IN_motion_None
		ck_keenObj.xDirection = IN_motion_None

		if ck_gameState.mapPosX < 0x1400:
			# Going to pyramid of forbidden at 1E, 37
			ck_keenObj.user1 = 280
			ck_keenObj.velX = s16((0x1E00 - ck_keenObj.posX) / 280 + 1)
			ck_keenObj.velY = s16((0x3700 - ck_keenObj.posY) / 280 + 1)
		else:
			# Return flight to 0x10, 0x2F
			ck_keenObj.user1 = 140
			ck_keenObj.velX = s16((0x1000 - ck_keenObj.posX) / 140 + 1)
			ck_keenObj.velY = s16((0x2F00 - ck_keenObj.posY) / 140 + 1)

		CK_SetAction(ck_keenObj, CK_GetActionByName("CK4_ACT_MapKeenFoot0"))
		return

	ck_keenObj.type = 2
	if ck_gameState.mapPosX == 0:
		ck_keenObj.posX = u16(tileX << 8)
		ck_keenObj.posY = u16(tileY << 8)
	else:
		ck_keenObj.posX = u16(ck_gameState.mapPosX)
		ck_keenObj.posY = u16(ck_gameState.mapPosY)

	ck_keenObj.active = OBJ_ALWAYS_ACTIVE
	ck_keenObj.zLayer = 1
	ck_keenObj.yDirection = IN_motion_None
	ck_keenObj.xDirection = IN_motion_None
	ck_keenObj.user1 = 6
	ck_keenObj.user2 = 3
	ck_keenObj.user3 = 0
	ck_keenObj.gfxChunk = u16(CK_CHUNKNUM("SPR_MAPKEEN_STAND_W"))
	CK_SetAction(ck_keenObj, CK_GetActionByName("CK_ACT_MapKeenStart"))


# look for level entrry

func CK_ScanForLevelEntry(obj: CK_object) -> void:
	var ty: int = obj.clipRects.tileY1
	while ty <= obj.clipRects.tileY2:
		var tx: int = obj.clipRects.tileX1
		while tx <= obj.clipRects.tileX2:
			var infotile: int = CA_TileAtPos(s16(tx), s16(ty), 2)
			if infotile >= (0xC000 + CK_INT("ck_minEnterLevel", 1)) and infotile <= (0xC000 + CK_INT("ck_maxEnterLevel", 18)):
				# Vanilla keen stores the current map loaded in the cache manager
				# and the "current_map" variable stored in the gamestate
				# would have been changed here.
				ck_gameState.mapPosX = obj.posX
				ck_gameState.mapPosY = obj.posY
				ck_gameState.currentLevel = s16(infotile - 0xC000)
				ck_gameState.levelState = LS_LevelComplete
				SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN12"))
				return
			tx += 1
		ty += 1


func CK_MapKeenStill(obj: CK_object) -> void:
	if ck_inputFrame.dir != IN_dir_None:
		obj.currentAction = CK_GetActionByName("CK_ACT_MapKeenWalk0")
		obj.user2 = 0
		CK_MapKeenWalk(obj)

	if ck_keenState.jumpIsPressed or ck_keenState.pogoIsPressed or ck_keenState.shootIsPressed:
		CK_ScanForLevelEntry(obj)


func CK_MapKeenWalk(obj: CK_object) -> void:
	if obj.user3 == 0:
		obj.xDirection = s16(ck_inputFrame.xDirection)
		obj.yDirection = s16(ck_inputFrame.yDirection)
		if ck_keenState.pogoIsPressed or ck_keenState.jumpIsPressed or ck_keenState.shootIsPressed:
			CK_ScanForLevelEntry(obj)

		# Go back to standing if no arrows pressed
		if ck_inputFrame.dir == IN_dir_None:
			obj.currentAction = CK_GetActionByName("CK_ACT_MapKeenStart")
			obj.gfxChunk = u16(CK_LookupChunk(ck_mapKeenBaseFrame[obj.user1]) + 2)
			return
		else:
			obj.user1 = s16(ck_inputFrame.dir)
	else:
		obj.user3 = s16(obj.user3 - 4)
		if obj.user3 < 0:
			obj.user3 = 0

	# Advance Walking Frame Animation
	obj.user2 = s16(obj.user2 + 1)
	if obj.user2 == 4:
		obj.user2 = 0
	obj.gfxChunk = u16(CK_LookupChunk(ck_mapKeenBaseFrame[obj.user1]) + ck_mapKeenAnimFrame[obj.user2])

	# walk hi lo sound
	if obj.user2 == 1:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK0"))
	elif obj.user2 == 3:
		SD_PlaySound(CK_SOUNDNUM("SOUND_KEENWALK1"))


# =========================================================================

# TELEPORTERS
# (WITH_KEEN5 || WITH_KEEN6)
func CK_AnimateMapTeleporter(tileX: int, tileY: int) -> void:
	var unitX: int
	var unitY: int
	var timer: int # uint16_t
	var animTile: int # uint16_t
	var ticsx2: int # uint16_t

	var boltTile: int = 0xA7F if ck_currentEpisode_ep == EP_CK5 else (0xA35 if ck_currentEpisode_ep == EP_CK6 else 0)
	var doneTile: int = 0x427 if ck_currentEpisode_ep == EP_CK5 else (0xA45 if ck_currentEpisode_ep == EP_CK6 else 0)
	var doneTile2: int = 0 if ck_currentEpisode_ep == EP_CK5 else (0xA45 if ck_currentEpisode_ep == EP_CK6 else 0)

	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN41"))

	unitX = (tileX << 8)
	unitY = (tileY << 8)

	# Teleport Out
	timer = 0
	while timer < 130:
		# NOTE: I think that the original keen game used
		# RF_Refresh() to delay this loop
		# Simulate this by adding a 1/35 second delay

		# UPDATE (Feb 19 2014): Not done anymore, but VL_Present is called.

		RF_Refresh()
		# VL_DelayTics(2);
		# CK_SetTicsPerFrame();
		VL_Present()

		ticsx2 = u16(SD_GetSpriteSync() * 2)
		timer = u16(timer + SD_GetSpriteSync())
		if ck_keenObj.posX == unitX and ck_keenObj.posY == unitY:
			break

		# Move Keen closer to the target on every loop
		if ck_keenObj.posY < unitY:
			ck_keenObj.posY = u16(ck_keenObj.posY + ticsx2)
			if ck_keenObj.posY > unitY:
				ck_keenObj.posY = u16(unitY)
		elif ck_keenObj.posY > unitY:
			ck_keenObj.posY = u16(ck_keenObj.posY - ticsx2)
			if ck_keenObj.posY < unitY:
				ck_keenObj.posY = u16(unitY)

		if ck_keenObj.posX < unitX:
			ck_keenObj.posX = u16(ck_keenObj.posX + ticsx2)
			if ck_keenObj.posX > unitX:
				ck_keenObj.posX = u16(unitX)
		elif ck_keenObj.posX > unitX:
			ck_keenObj.posX = u16(ck_keenObj.posX - ticsx2)
			if ck_keenObj.posX < unitX:
				ck_keenObj.posX = u16(unitX)

		# Draw Keen walking into target
		ck_keenObj.gfxChunk = u16(((SD_GetTimeCount() >> 3) % 3) + CK_CHUNKNUM("SPR_MAPKEEN_WALK1_N"))
		ck_keenObj.sde = RF_AddSpriteDraw(ck_keenObj.sde, ck_keenObj.posX, ck_keenObj.posY, ck_keenObj.gfxChunk, false, ck_keenObj.zLayer)

		animTile = u16(((SD_GetTimeCount() >> 2) & 1) + boltTile) # lighting bolt tile

		RF_ReplaceTiles(PackedInt32Array([animTile]), 0, 1, tileX, tileY, 1, 1)

	# Done Teleporting; Move keen to destination
	animTile = u16(doneTile)
	RF_ReplaceTiles(PackedInt32Array([animTile]), 0, 1, tileX, tileY, 1, 1)

	# Destination is set in Infoplane above teleporter
	animTile = CA_TileAtPos(s16(tileX), s16(tileY), 2)

	tileX = animTile >> 8
	tileY = animTile & 0xFF # 0x7F in disasm, should be 0xFF?
	ck_keenObj.posX = u16(tileX << 8)
	ck_keenObj.posY = u16(tileY << 8)
	ck_keenObj.xDirection = IN_motion_None
	ck_keenObj.yDirection = IN_motion_Down
	ck_keenObj.user1 = 4
	CK_SetAction(ck_keenObj, ck_keenObj.currentAction)
	CK_CentreCamera(ck_keenObj)
	# 0xef for the X-direction to match EGA keen's 2px horz scrolling.
	VL_SetScrollCoords((rf_scrollXUnit & 0xef) >> 4, (rf_scrollYUnit & 0xff) >> 4)

	# Set objects to be active if they're inside the screen
	var obj: CK_object = ck_keenObj.next
	while obj != null:
		if obj.active != 0 or obj.type != 8 or obj.clipRects.tileX2 < (rf_scrollXUnit >> 8) - 1 or obj.clipRects.tileX1 > (rf_scrollXUnit >> 8) + (320 >> 4) + 1 or obj.clipRects.tileY2 < (rf_scrollYUnit >> 8) - 1 or obj.clipRects.tileY1 > (rf_scrollYUnit >> 8) + (208 >> 4) + 1:
			obj = obj.next
			continue

		obj.visible = true
		obj.active = OBJ_ACTIVE
		obj.sde = RF_AddSpriteDraw(obj.sde, obj.posX, obj.posY, obj.gfxChunk, false, obj.zLayer)
		obj = obj.next

	CK_UpdateScoreBox(ck_scoreBoxObj)
	RF_Refresh()
	RF_Refresh()
	SD_PlaySound(CK_SOUNDNUM("SOUND_UNKNOWN41"))

	timer = 0
	while timer < 90:
		# NOTE: Same delay tactic used here too
		# UPDATE (Feb 19 2014): Again not
		RF_Refresh()
		# VL_DelayTics(2);
		# CK_SetTicsPerFrame();

		timer = u16(timer + SD_GetSpriteSync())
		ck_keenObj.posY = u16(ck_keenObj.posY + SD_GetSpriteSync() * 3)
		ck_keenObj.gfxChunk = u16((SD_GetTimeCount() >> 3) % 3 + CK_CHUNKNUM("SPR_MAPKEEN_WALK1_S"))
		ck_keenObj.sde = RF_AddSpriteDraw(ck_keenObj.sde, ck_keenObj.posX, ck_keenObj.posY, ck_keenObj.gfxChunk, false, ck_keenObj.zLayer)
		animTile = u16(((SD_GetTimeCount() >> 2) & 1) + boltTile) # animate return lighting bolt
		RF_ReplaceTiles(PackedInt32Array([animTile]), 0, 1, tileX, tileY, 1, 1)

	animTile = u16(doneTile2)
	RF_ReplaceTiles(PackedInt32Array([animTile]), 0, 1, tileX, tileY, 1, 1)
	ck_nextY = 0
	ck_nextX = 0
	CK_PhysUpdateNormalObj(ck_keenObj)


# =========================================================================
# Map Flags

class CK_FlagPoint:
	var x: int = 0 # uint16_t
	var y: int = 0 # uint16_t


var ck_flagPoints: Array = _new_flag_points()


static func _new_flag_points() -> Array:
	var a: Array = []
	for i: int in range(30):
		a.append(CK_FlagPoint.new())
	return a


func CK_MapFlagSpawn(tileX: int, tileY: int) -> void:
	var flag: CK_object = CK_GetNewObj(false)

	flag.clipped = CLIP_not
	flag.zLayer = 3
	flag.type = CT_CLASS("MapFlag")
	flag.active = OBJ_ACTIVE
	var xofs: int = 0x60 if ck_currentEpisode_ep == EP_CK4 else (-0x50 if ck_currentEpisode_ep == EP_CK5 else (0xE0 if ck_currentEpisode_ep == EP_CK6 else 0))
	var yofs: int = -0x1E0 if ck_currentEpisode_ep == EP_CK4 else (-0x1E0 if ck_currentEpisode_ep == EP_CK5 else (-0x1A0 if ck_currentEpisode_ep == EP_CK6 else 0))

	flag.posX = u16((tileX << 8) + xofs)
	flag.posY = u16((tileY << 8) + yofs)
	flag.actionTimer = s16(US_RndT() / 16)

	if ck_currentEpisode_ep == EP_CK6:
		var tile: int = u16(CA_TileAtPos(s16(tileX), s16(tileY), 1) + 1)
		RF_ReplaceTiles(PackedInt32Array([tile]), 0, 1, tileX, tileY, 1, 1)

	CK_SetAction(flag, CK_GetActionByName("CK_ACT_MapFlag0"))


# (WITH_KEEN4 || WITH_KEEN6)

var ck_flagTileSpotX: int = 0
var ck_flagTileSpotY: int = 0


func CK_FlippingFlagSpawn(tileX: int, tileY: int) -> void:
	var dx: int # int32_t
	var dy: int # int32_t

	var obj: CK_object = CK_GetNewObj(false)
	obj.clipped = CLIP_not
	obj.zLayer = PRIORITIES - 1
	obj.type = CT_CLASS("MapFlag")
	obj.active = OBJ_ALWAYS_ACTIVE
	obj.posX = u16(ck_gameState.mapPosX - 0x100)
	obj.posY = u16(ck_gameState.mapPosY - 0x100)

	ck_flagTileSpotX = tileX
	ck_flagTileSpotY = tileY

	# Destination coords
	var xofs: int = 0x60 if ck_currentEpisode_ep == EP_CK4 else (0xE0 if ck_currentEpisode_ep == EP_CK6 else 0)
	var yofs: int = -0x260 if ck_currentEpisode_ep == EP_CK4 else (-0x220 if ck_currentEpisode_ep == EP_CK6 else 0)

	obj.user1 = s16((tileX << G_T_SHIFT) + xofs)
	obj.user2 = s16((tileY << G_T_SHIFT) + yofs)

	dx = s32(obj.user1 - obj.posX)
	dy = s32(obj.user2 - obj.posY)

	# Make a table of coordinates for the flag's path
	# (WITH_KEEN4)
	if ck_currentEpisode_ep == EP_CK4:
		for i: int in range(30):
			var p: CK_FlagPoint = ck_flagPoints[i]
			# Draw points in a straight line between keen and the holster
			p.x = u16(obj.posX + s32(dx * (i if i < 24 else 24)) / 24)
			p.y = u16(obj.posY + s32(dy * i) / 30)

			# Offset th eY points to mimic a parabolic trajectory
			if i < 10:
				p.y = u16(p.y - i * 0x30) # going up
			elif i < 15:
				p.y = u16(p.y - (i * 16 + 0x140))
			elif i < 20:
				p.y = u16(p.y - ((20 - i) * 16 + 0x1E0))
			else:
				p.y = u16(p.y - (29 - i) * 0x30)
	# (WITH_KEEN6)
	if ck_currentEpisode_ep == EP_CK6:
		# I think this is just the same code from CK4 that's been optimized differently
		# by the compiler
		var point0: int = 0
		var point1: int = 0x140
		var point2: int = 0x320
		var point3: int = 0x570

		var i: int = 0
		while true:
			var p: CK_FlagPoint = ck_flagPoints[i]
			# Draw points in a straight line between keen and the holster
			p.x = u16(obj.posX + s32(dx * (i if i < 24 else 24)) / 24)
			p.y = u16(obj.posY + s32(dy * i) / 30)

			# Offset th eY points to mimic a parabolic trajectory
			if i < 10:
				p.y = u16(p.y - point0)
			elif i < 15:
				p.y = u16(p.y - point1)
			elif i < 20:
				p.y = u16(p.y - point2)
			else:
				p.y = u16(p.y - point3)

			point0 += 0x30
			point1 += 0x10
			point2 -= 0x10
			point3 -= 0x30
			i += 1
			if i == 30:
				break
	CK_SetAction(obj, CK_GetActionByName("CK_ACT_MapFlagFlips0"))


func CK_MapFlagThrown(obj: CK_object) -> void:
	# Might this be a source of non-determinism?
	# (if screen unfades at different rates based on diff architecture)
	if not vl_screenFaded:
		SD_StopSound()
		SD_PlaySound(CK_SOUNDNUM("SOUND_FLAGFLIP"))
		obj.currentAction = obj.currentAction.next


func CK_MapFlagFall(obj: CK_object) -> void:
	obj.user3 = s16(obj.user3 + SD_GetSpriteSync())

	var timer: int = 50 if ck_currentEpisode_ep == EP_CK4 else (58 if ck_currentEpisode_ep == EP_CK6 else 0)

	if obj.user3 > timer:
		obj.user3 = timer

	obj.posX = (ck_flagPoints[obj.user3 / 2] as CK_FlagPoint).x
	obj.posY = (ck_flagPoints[obj.user3 / 2] as CK_FlagPoint).y

	obj.visible = true
	if obj.user1 == 0:
		SD_PlaySound(CK_SOUNDNUM("SOUND_FLAGFLIP"))


func CK_MapFlagLand(obj: CK_object) -> void:
	# Plop the flag in its holster
	obj.posX = u16(obj.user1)
	obj.posY = u16(obj.user2 + 0x80)
	obj.zLayer = PRIORITIES - 1

	SD_PlaySound(CK_SOUNDNUM("SOUND_FLAGLAND"))
	if ck_currentEpisode_ep == EP_CK6:
		var tile: int = u16(CA_TileAtPos(s16(ck_flagTileSpotX), s16(ck_flagTileSpotY), 1) + 1)
		RF_ReplaceTiles(PackedInt32Array([tile]), 0, 1, ck_flagTileSpotX, ck_flagTileSpotY, 1, 1)


## Setup all of the functions in this file.
func CK_Map_SetupFunctions() -> void:
	CK_ACT_AddFunction("CK_MapKeenStill", &"CK_MapKeenStill")
	CK_ACT_AddFunction("CK_MapKeenWalk", &"CK_MapKeenWalk")
	# (WITH_KEEN4 || WITH_KEEN6)
	CK_ACT_AddFunction("CK_MapFlagThrown", &"CK_MapFlagThrown")
	CK_ACT_AddFunction("CK_MapFlagFall", &"CK_MapFlagFall")
	CK_ACT_AddFunction("CK_MapFlagLand", &"CK_MapFlagLand")
