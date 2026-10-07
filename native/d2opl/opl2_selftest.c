/* Copyright (C) 2026 the Sidescroller Recomps contributors.
 * Licensed under the GNU General Public License v2 or later. See LICENSE.md.
 *
 * A check that the chip emulation gives the same samples wherever it is
 * built: a fixed list of register writes is played and a fingerprint of the
 * resulting samples is printed. tools/build_native.py builds and runs this on
 * each system it can reach and compares the fingerprints.
 *
 * The writes use every part of the emulation: all four waveforms, feedback,
 * both ways of connecting a voice's operators, tremolo and vibrato at both
 * depths, key scaling, sustained and decaying envelopes, key-off, and all
 * nine voices at once.
 */
#include <stdio.h>
#include <stdint.h>

#include "opl2.h"

static uint64_t fingerprint = 1469598103934665603ULL;
static long loudest = 0;

static void run(Opl2Chip *chip, int samples) {
	for (int i = 0; i < samples; i++) {
		int16_t s = opl2_sample(chip);
		long magnitude = s < 0 ? -(long)s : (long)s;
		if (magnitude > loudest) {
			loudest = magnitude;
		}
		fingerprint ^= (uint8_t)(s & 0xff);
		fingerprint *= 1099511628211ULL;
		fingerprint ^= (uint8_t)((s >> 8) & 0xff);
		fingerprint *= 1099511628211ULL;
	}
}

/* Operator register offsets of the nine voices' first operators. */
static const uint8_t first_op[9] = {0x00, 0x01, 0x02, 0x08, 0x09, 0x0a, 0x10, 0x11, 0x12};

int main(void) {
	Opl2Chip chip;
	opl2_reset(&chip);
	run(&chip, 1000);

	opl2_write(&chip, 0x01, 0x20);      /* waveform select allowed */
	for (int v = 0; v < 9; v++) {
		uint8_t m = first_op[v];
		uint8_t c = (uint8_t)(m + 3);
		opl2_write(&chip, 0x20 + m, (uint8_t)(0x01 + v + ((v & 1) ? 0x80 : 0) + ((v & 2) ? 0x40 : 0)
				+ ((v & 4) ? 0x20 : 0) + ((v % 3 == 0) ? 0x10 : 0)));
		opl2_write(&chip, 0x20 + c, (uint8_t)(0x21 + ((v & 1) ? 0x40 : 0)));
		opl2_write(&chip, 0x40 + m, (uint8_t)(0x10 + v * 3 + ((v & 3) << 6)));
		opl2_write(&chip, 0x40 + c, (uint8_t)(v));
		opl2_write(&chip, 0x60 + m, (uint8_t)(0xf0 - v * 0x10 + 4 + v));
		opl2_write(&chip, 0x60 + c, (uint8_t)(0xa0 + v + (v << 4 & 0x30)));
		opl2_write(&chip, 0x80 + m, (uint8_t)(0x20 + v * 0x10 + 5));
		opl2_write(&chip, 0x80 + c, (uint8_t)(0x10 * (v % 4) + 3 + v));
		opl2_write(&chip, 0xe0 + m, (uint8_t)(v & 3));
		opl2_write(&chip, 0xe0 + c, (uint8_t)((v + 1) & 3));
		opl2_write(&chip, 0xc0 + v, (uint8_t)(((v % 8) << 1) | (v & 1)));
	}
	for (int v = 0; v < 9; v++) {
		int f_num = 300 + v * 77;
		int block = 1 + (v % 6);
		opl2_write(&chip, 0xa0 + v, (uint8_t)(f_num & 0xff));
		opl2_write(&chip, 0xb0 + v, (uint8_t)(0x20 | (block << 2) | (f_num >> 8)));
		run(&chip, 3000);
	}
	opl2_write(&chip, 0xbd, 0xc0);      /* deep tremolo and vibrato */
	run(&chip, 20000);
	opl2_write(&chip, 0x08, 0x40);      /* the other key-scaling rule */
	opl2_write(&chip, 0xbd, 0x00);
	run(&chip, 10000);
	for (int v = 0; v < 9; v++) {
		int f_num = 300 + v * 77;
		int block = 1 + (v % 6);
		opl2_write(&chip, 0xb0 + v, (uint8_t)((block << 2) | (f_num >> 8)));    /* key off */
		run(&chip, 2000);
	}
	run(&chip, 30000);

	printf("%016llx loudest %ld\n", (unsigned long long)fingerprint, loudest);
	return loudest > 1000 ? 0 : 1;
}
