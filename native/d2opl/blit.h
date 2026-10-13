/* Copyright (C) 2026 the Megarocket contributors. GPL v2 or later. See LICENSE.md.
 *
 * The screen-to-card conversion of the Galaxy engine's VL_Present: a run of
 * rows of the 320 x 200 screen (one byte per pixel, EGA colour 0-15) into
 * the four planes of the EGA card model, plane-major (plane 0's rows first,
 * then plane 1, plane 2, plane 3; 40 bytes a row).
 */
#ifndef D2_BLIT_H
#define D2_BLIT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* The width of the screen in pixels, and the bytes of one card row. */
#define D2_BLIT_WIDTH 320
#define D2_BLIT_ROW_BYTES (D2_BLIT_WIDTH / 8)

/* Converts `rows` rows of `src` (row r at src[src_off + r * pitch], 320
 * pixel bytes each) into `out`, which must hold 4 * rows * D2_BLIT_ROW_BYTES
 * bytes. Byte bx (0..39) of plane p has bit 0x80 >> k set when pixel
 * 8*bx + k has bit 1 << p set (k = 0..7).
 *
 * Returns 0 on success, -1 when the rows are not all inside `src` (nothing
 * is written then). */
int d2_blit_planes(const uint8_t *src, int64_t src_off, int64_t pitch, int64_t rows, uint8_t *out);

/* The card-to-screen conversion of the EGA card's compose_rows: rows y0..y1-1
 * of the 320 x 200 picture from the four 64 KiB planes (each 65536 bytes),
 * one byte per pixel (a palette index 0-15), row y at out + (y - y0) * 320.
 *
 * `display_start` is the CRTC start address, `stride` the bytes between rows
 * (twice the CRTC offset), `split` the first row shown from address 0 (HEIGHT
 * when there is no split), `pan` the pel panning (0-7), `compat` the
 * attribute controller's pel-panning-compatibility bit (0 or 1: when set and
 * the row is below the split, the panning is dropped).
 *
 * `out` must hold (y1 - y0) * D2_BLIT_WIDTH bytes. Returns 0 on success, -1
 * when the request makes no sense (nothing is written then). */
int d2_blit_compose(const uint8_t *p0, const uint8_t *p1, const uint8_t *p2, const uint8_t *p3,
		int64_t display_start, int64_t stride, int64_t split, int64_t pan, int64_t compat,
		int64_t y0, int64_t y1, uint8_t *out);

#ifdef __cplusplus
}
#endif

#endif /* D2_BLIT_H */
