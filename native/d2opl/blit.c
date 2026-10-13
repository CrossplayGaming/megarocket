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
