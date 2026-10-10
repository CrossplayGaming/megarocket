# Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
#
# Reference: K1n9_Duk3's reconstructed Keen 1-3 source (GPL v2), IDLIBC.C
# (RLEWCompress); omnispeak's id_ca.c (CAL_RLEWCompress, CAL_CarmackExpand,
# CAL_HuffExpand); TED5's CarmackCompress as documented by the modding
# community, checked here against every map of Keen 4, 5 and 6.
class_name LevelCodec
extends RefCounted
## The compressors the level writers need: word RLE (every engine), Carmack
## (Keen 4-6 maps) and Huffman with a fixed dictionary (Keen Dreams maps).
## The expanders are the games' own readers (VortData, GalData); only the
## packing direction lives here. Each one makes the same choices as the tool
## that made the original files, so a level saved unchanged is byte for byte
## the file it came from (prep01_levels proves this for every level).

const CARMACK_NEAR: int = 0xA7
const CARMACK_FAR: int = 0xA8


## Words to little-endian bytes.
static func words_to_bytes(words: PackedInt32Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(words.size() * 2)
	for i: int in range(words.size()):
		out.encode_u16(i * 2, words[i] & 0xFFFF)
	return out


## Little-endian bytes to words (an odd last byte is dropped).
static func bytes_to_words(bytes: PackedByteArray, from: int = 0, count: int = -1) -> PackedInt32Array:
	if count < 0:
		count = (bytes.size() - from) / 2
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(count)
	for i: int in range(count):
		out[i] = bytes.decode_u16(from + i * 2)
	return out


## Word RLE as RLEWCompress / CAL_RLEWCompress: a run of more than three equal
## words, or any word equal to the tag, becomes tag, count, value; everything
## else is copied. The caller adds whatever length prefix its format wants.
## A run stops at 65535 words, where the original's 16-bit count would wrap
## (no Keen level has a run that long; a made one might).
static func rlew_compress(words: PackedInt32Array, tag: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var n: int = words.size()
	var s: int = 0
	while s < n:
		var value: int = words[s]
		var count: int = 1
		s += 1
		while s < n and words[s] == value and count < 0xFFFF:
			count += 1
			s += 1
		if count > 3 or value == tag:
			out.append(tag)
			out.append(count)
			out.append(value)
		else:
			for k: int in range(count):
				out.append(value)
	return out


## Carmack compression as TED5's CarmackCompress. For each word it looks back
## for the longest earlier string of words that matches what follows (at most
## 255 words, never reaching into the words being encoded), preferring the
## nearest of equally long ones; two or more words within 255 back are sent
## as a near copy (tag A7, count, one-byte distance), three or more further
## back as a far copy (tag A8, count, word offset from the start), anything
## else as the word itself; a word whose high byte is a tag is escaped as the
## tag with count 0 and its low byte.
##
## The original scans every earlier word; this scans only earlier words that
## start with the same two words (a chain per pair), newest first, which finds
## the same string and so the same output, in a fraction of the time.
static func carmack_compress(src: PackedInt32Array) -> PackedByteArray:
	var n: int = src.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(n * 3 + 4)
	var o: int = 0
	var newest: Dictionary = {}           # (word, next word) -> latest position entered
	var older: PackedInt32Array = PackedInt32Array()   # position -> the previous one with the same pair
	older.resize(n)
	var entered: int = 0                  # positions below this are in the chains
	var inptr: int = 0
	while inptr < n:
		var length: int = n - inptr
		var ch: int = src[inptr]
		var best: int = 0
		var best_at: int = 0
		if length >= 2:
			# a string must lie wholly before inptr, so a match of two words starts at inptr - 2 or earlier
			while entered <= inptr - 2:
				var key: int = (src[entered] << 16) | src[entered + 1]
				older[entered] = newest.get(key, -1)
				newest[key] = entered
				entered += 1
			var cap: int = mini(length, 255)
			var scan: int = newest.get((ch << 16) | src[inptr + 1], -1)
			while scan >= 0:
				var most: int = mini(inptr - scan, cap)
				var run: int = 2
				while run < most and src[scan + run] == src[inptr + run]:
					run += 1
				if run > best:          # newest first, so a tie keeps the nearer one, as the original's >= does
					best = run
					best_at = scan
					if best >= cap:
						break
				scan = older[scan]
		if best > 1 and inptr - best_at <= 255:
			out.encode_u16(o, (CARMACK_NEAR << 8) | best)
			out[o + 2] = inptr - best_at
			o += 3
			inptr += best
		elif best > 2:
			out.encode_u16(o, (CARMACK_FAR << 8) | best)
			out.encode_u16(o + 2, best_at)
			o += 4
			inptr += best
		else:
			var high: int = ch >> 8
			if high == CARMACK_NEAR or high == CARMACK_FAR:
				out.encode_u16(o, high << 8)
				out[o + 2] = ch & 0xFF
				o += 3
			else:
				out.encode_u16(o, ch)
				o += 2
			inptr += 1
	out.resize(o)
	return out


## The bit string for every byte in a Huffman dictionary as id's CAL_HuffExpand
## walks it (256 nodes of two links, root 254, a link below 256 is a byte).
## Returns 256 PackedByteArrays of 0/1, empty for a byte the tree lacks.
static func huff_codes(dict: PackedInt32Array) -> Array[PackedByteArray]:
	var codes: Array[PackedByteArray] = []
	codes.resize(256)
	for b: int in range(256):
		codes[b] = PackedByteArray()
	# depth-first from the root; a stack of (node, path) instead of recursion
	var stack: Array = [[254, PackedByteArray()]]
	var visited: Dictionary = {}
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var node: int = top[0]
		if visited.has(node) or node * 2 + 1 >= dict.size():
			continue
		visited[node] = true
		for bit: int in [1, 0]:
			var link: int = dict[node * 2 + bit]
			var path: PackedByteArray = (top[1] as PackedByteArray).duplicate()
			path.append(bit)
			if link < 256:
				if codes[link].is_empty():
					codes[link] = path
			else:
				stack.append([link - 256, path])
	return codes


## Huffman-pack `data` with `codes` from huff_codes: bits fill each byte from
## its lowest bit up, and the last byte is padded with zeros. Empty if the
## data holds a byte the dictionary cannot say.
static func huff_compress(data: PackedByteArray, codes: Array[PackedByteArray]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var bits: int = 0
	for b: int in data:
		bits += codes[b].size()
		if codes[b].is_empty():
			return PackedByteArray()
	out.resize((bits + 7) / 8)
	var o: int = 0
	var cur: int = 0
	var nbits: int = 0
	for b: int in data:
		for bit: int in codes[b]:
			if bit != 0:
				cur |= 1 << nbits
			nbits += 1
			if nbits == 8:
				out[o] = cur
				o += 1
				cur = 0
				nbits = 0
	if nbits > 0:
		out[o] = cur
	return out
