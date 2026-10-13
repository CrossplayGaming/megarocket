/* Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
 *
 * The loop of d2_blit_planes: the same bit order as the GDScript fallback in
 * gal_lib.gd's _write_rows (pixel k of the eight at bit 7 - k, the card's
 * order), one byte per plane per group of eight pixels.
 */
#include "blit.h"

int d2_blit_planes(const uint8_t *src, int64_t src_off, int64_t pitch, int64_t rows, uint8_t *out) {
	if (rows < 0 || src == NULL || out == NULL) {
		return -1;
	}
	int64_t r;
	for (r = 0; r < rows; r++) {
		const uint8_t *s = src + src_off + r * pitch;
		int64_t bx;
		for (bx = 0; bx < D2_BLIT_ROW_BYTES; bx++) {
			uint8_t b0 = 0, b1 = 0, b2 = 0, b3 = 0;
			int k;
			for (k = 0; k < 8; k++) {
				uint8_t c = s[bx * 8 + k];
				uint8_t bit = (uint8_t)(0x80 >> k);
				if (c & 1) {
					b0 |= bit;
				}
				if (c & 2) {
					b1 |= bit;
				}
				if (c & 4) {
					b2 |= bit;
				}
				if (c & 8) {
					b3 |= bit;
				}
			}
			out[r * D2_BLIT_ROW_BYTES + bx] = b0;
			out[rows * D2_BLIT_ROW_BYTES + r * D2_BLIT_ROW_BYTES + bx] = b1;
			out[2 * rows * D2_BLIT_ROW_BYTES + r * D2_BLIT_ROW_BYTES + bx] = b2;
			out[3 * rows * D2_BLIT_ROW_BYTES + r * D2_BLIT_ROW_BYTES + bx] = b3;
		}
	}
	return 0;
}

int d2_blit_compose(const uint8_t *p0, const uint8_t *p1, const uint8_t *p2, const uint8_t *p3,
		int64_t display_start, int64_t stride, int64_t split, int64_t pan, int64_t compat,
		int64_t y0, int64_t y1, uint8_t *out) {
	if (y0 < 0 || y1 > 200 || y1 <= y0 || p0 == NULL || p1 == NULL || p2 == NULL || p3 == NULL
			|| out == NULL) {
		return -1;
	}
	int64_t y;
	for (y = y0; y < y1; y++) {
		int64_t row_pan = pan;
		int64_t address;
		if (y >= split) {
			/* The split screen: the rows below the line compare are shown from
			 * address 0, and with the compatibility bit set the panning is
			 * dropped for them too. */
			address = ((y - split) * stride) & 0xFFFF;
			if (compat != 0) {
				row_pan = 0;
			}
		} else {
			address = (display_start + y * stride) & 0xFFFF;
		}
		uint8_t *row = out + (y - y0) * D2_BLIT_WIDTH;
		int64_t x;
		for (x = 0; x < D2_BLIT_WIDTH; x++) {
			/* The card's bit order (ega_card.gd's _spread) puts pixel 0 at the
			 * high bit of the byte, so pixel x is bit 7 - ((x + pan) & 7) of
			 * the row's byte; the card does not stop at the end of a row, so
			 * the right edge reads the start of the next row's bytes. */
			int64_t a = (address + ((x + row_pan) >> 3)) & 0xFFFF;
			int64_t bit = 7 - ((x + row_pan) & 7);
			row[x] = (uint8_t)((p0[a] >> bit) & 1)
					| ((p1[a] >> bit) & 1) << 1
					| ((p2[a] >> bit) & 1) << 2
					| ((p3[a] >> bit) & 1) << 3;
		}
	}
	return 0;
}
