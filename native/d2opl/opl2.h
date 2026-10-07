/* Copyright (C) 2026 the Sidescroller Recomps contributors.
 *
 * The behaviour implemented here follows Nuked OPL3, Copyright (C) 2013-2020
 * Nuke.YKT, which is licensed under the GNU Lesser General Public License
 * version 2.1 or later; this file is distributed under the same terms as the
 * rest of this project, the GNU General Public License v2 or later. See
 * LICENSE.md.
 */
#ifndef D2_OPL2_H
#define D2_OPL2_H

#include <stdint.h>

/* The sample rate of the real chip: its 3.579545 MHz clock divided by 72. */
#define OPL2_SAMPLE_RATE 49716

typedef struct {
	/* register fields */
	uint8_t am, vib, egt, ksr, mult, ksl, tl, ar, dr, sl, rr, wf;
	/* phase generator */
	uint32_t pg_phase;
	uint16_t pg_phase_out;
	uint8_t pg_reset;
	/* envelope generator */
	uint16_t eg_rout, eg_out;
	uint8_t eg_gen, eg_ksl, key;
	/* output and feedback */
	int16_t out, prout, fbmod;
} Opl2Slot;

typedef struct {
	Opl2Slot slot[2];
	uint16_t f_num;
	uint8_t block, fb, con, ksv;
} Opl2Channel;

typedef struct {
	Opl2Channel channel[9];
	uint64_t eg_timer;
	uint8_t eg_timerrem, eg_state, eg_add;
	uint16_t timer;
	uint8_t nts, wse;
	uint8_t tremolo, tremolopos, tremoloshift;
	uint8_t vibpos, vibshift;
} Opl2Chip;

void opl2_reset(Opl2Chip *chip);
void opl2_write(Opl2Chip *chip, uint8_t reg, uint8_t value);

/* One output sample at OPL2_SAMPLE_RATE, as a signed 16-bit value. */
int16_t opl2_sample(Opl2Chip *chip);

#endif
