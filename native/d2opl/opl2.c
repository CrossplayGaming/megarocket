/* Copyright (C) 2026 the Sidescroller Recomps contributors.
 *
 * An emulation of the Yamaha YM3812 (OPL2) sound chip of the AdLib card: the
 * nine two-operator melodic channels. Rhythm mode is not implemented; none of
 * the music this project plays uses it.
 *
 * The behaviour implemented here follows Nuked OPL3, Copyright (C) 2013-2020
 * Nuke.YKT, which is licensed under the GNU Lesser General Public License
 * version 2.1 or later, and which is itself based on the measurements of the
 * real chip by Matthew Gambrell and Olli Niemitalo (the ROM tables), by
 * siliconpr0n.org (decapsulated chip images) and others. This file is
 * distributed under the same terms as the rest of this project, the GNU
 * General Public License v2 or later. See LICENSE.md.
 */
#include "opl2.h"

#include <math.h>
#include <string.h>

enum { EG_ATTACK, EG_DECAY, EG_SUSTAIN, EG_RELEASE };

/* The chip's two ROMs, computed once: -log2(sin) of a quarter wave, and 2^x. */
static uint16_t logsin_rom[256];
static uint16_t exp_rom[256];
static int roms_ready = 0;

/* Frequency multiplier, times two. */
static const uint8_t mult_table[16] = { 1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30 };

/* Key scale level. */
static const uint8_t ksl_rom[16] = { 0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64 };
static const uint8_t ksl_shift[4] = { 8, 1, 2, 0 };

/* Envelope step pattern for the fast rates. */
static const uint8_t eg_incstep[4][4] = { { 0, 0, 0, 0 }, { 1, 0, 0, 0 }, { 1, 0, 1, 0 }, { 1, 1, 1, 0 } };

/* Operator register offset (0..21) to channel and slot; -1 where there is none. */
static const int8_t slot_channel[32] = {
	0, 1, 2, 0, 1, 2, -1, -1, 3, 4, 5, 3, 4, 5, -1, -1, 6, 7, 8, 6, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
};
static const int8_t slot_index[32] = {
	0, 0, 0, 1, 1, 1, -1, -1, 0, 0, 0, 1, 1, 1, -1, -1, 0, 0, 0, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
};

static void make_roms(void) {
	const double pi = 3.14159265358979323846;
	for (int i = 0; i < 256; i++) {
		logsin_rom[i] = (uint16_t)floor(-log2(sin((i + 0.5) * pi / 512.0)) * 256.0 + 0.5);
		exp_rom[i] = (uint16_t)floor(pow(2.0, (255 - i) / 256.0) * 1024.0 + 0.5);
	}
	roms_ready = 1;
}

static int16_t exp_level(uint32_t level) {
	if (level > 0x1fff) {
		level = 0x1fff;
	}
	return (int16_t)((exp_rom[level & 0xff] << 1) >> (level >> 8));
}

/* The four waveforms of the OPL2. `phase` is 10 bits, `envelope` the attenuation. */
static int16_t waveform(uint8_t wf, uint16_t phase, uint16_t envelope) {
	uint16_t out;
	uint16_t neg = 0;
	phase &= 0x3ff;
	switch (wf) {
		default:
		case 0: /* sine */
			if (phase & 0x200) {
				neg = 0xffff;
			}
			out = (phase & 0x100) ? logsin_rom[(phase & 0xff) ^ 0xff] : logsin_rom[phase & 0xff];
			break;
		case 1: /* half sine */
			if (phase & 0x200) {
				out = 0x1000;
			} else {
				out = (phase & 0x100) ? logsin_rom[(phase & 0xff) ^ 0xff] : logsin_rom[phase & 0xff];
			}
			break;
		case 2: /* rectified sine */
			out = (phase & 0x100) ? logsin_rom[(phase & 0xff) ^ 0xff] : logsin_rom[phase & 0xff];
			break;
		case 3: /* quarter sine pulses */
			out = (phase & 0x100) ? 0x1000 : logsin_rom[phase & 0xff];
			break;
	}
	return (int16_t)(exp_level(out + ((uint32_t)envelope << 3)) ^ neg);
}

static void update_ksl(Opl2Channel *channel) {
	int16_t ksl = (int16_t)((ksl_rom[channel->f_num >> 6] << 2) - ((0x08 - channel->block) << 5));
	if (ksl < 0) {
		ksl = 0;
	}
	channel->slot[0].eg_ksl = (uint8_t)ksl;
	channel->slot[1].eg_ksl = (uint8_t)ksl;
}

static void envelope_calc(Opl2Chip *chip, Opl2Channel *channel, Opl2Slot *slot) {
	uint8_t reg_rate = 0;
	uint8_t reset = 0;
	uint8_t shift = 0;
	uint16_t eg_rout;
	int16_t eg_inc = 0;
	uint8_t eg_off = 0;

	slot->eg_out = slot->eg_rout + (slot->tl << 2) + (slot->eg_ksl >> ksl_shift[slot->ksl])
			+ (slot->am ? chip->tremolo : 0);

	if (slot->key && slot->eg_gen == EG_RELEASE) {
		reset = 1;
		reg_rate = slot->ar;
	} else {
		switch (slot->eg_gen) {
			case EG_ATTACK:
				reg_rate = slot->ar;
				break;
			case EG_DECAY:
				reg_rate = slot->dr;
				break;
			case EG_SUSTAIN:
				if (!slot->egt) {
					reg_rate = slot->rr;
				}
				break;
			case EG_RELEASE:
				reg_rate = slot->rr;
				break;
		}
	}
	slot->pg_reset = reset;

	uint8_t ks = channel->ksv >> ((slot->ksr ^ 1) << 1);
	uint8_t nonzero = (reg_rate != 0);
	uint8_t rate = ks + (reg_rate << 2);
	uint8_t rate_hi = rate >> 2;
	uint8_t rate_lo = rate & 0x03;
	if (rate_hi & 0x10) {
		rate_hi = 0x0f;
	}
	uint8_t eg_shift = rate_hi + chip->eg_add;
	if (nonzero) {
		if (rate_hi < 12) {
			if (chip->eg_state) {
				switch (eg_shift) {
					case 12:
						shift = 1;
						break;
					case 13:
						shift = (rate_lo >> 1) & 0x01;
						break;
					case 14:
						shift = rate_lo & 0x01;
						break;
					default:
						break;
				}
			}
		} else {
			shift = (rate_hi & 0x03) + eg_incstep[rate_lo][chip->timer & 0x03];
			if (shift & 0x04) {
				shift = 0x03;
			}
			if (!shift) {
				shift = chip->eg_state;
			}
		}
	}

	eg_rout = slot->eg_rout;
	/* Instant attack */
	if (reset && rate_hi == 0x0f) {
		eg_rout = 0x00;
	}
	/* Envelope off */
	if ((slot->eg_rout & 0x1f8) == 0x1f8) {
		eg_off = 1;
	}
	if (slot->eg_gen != EG_ATTACK && !reset && eg_off) {
		eg_rout = 0x1ff;
	}
	switch (slot->eg_gen) {
		case EG_ATTACK:
			if (!slot->eg_rout) {
				slot->eg_gen = EG_DECAY;
			} else if (slot->key && shift > 0 && rate_hi != 0x0f) {
				eg_inc = (int16_t)(~slot->eg_rout >> (4 - shift));
			}
			break;
		case EG_DECAY:
			if ((slot->eg_rout >> 4) == slot->sl) {
				slot->eg_gen = EG_SUSTAIN;
			} else if (!eg_off && !reset && shift > 0) {
				eg_inc = 1 << (shift - 1);
			}
			break;
		case EG_SUSTAIN:
		case EG_RELEASE:
			if (!eg_off && !reset && shift > 0) {
				eg_inc = 1 << (shift - 1);
			}
			break;
	}
	slot->eg_rout = (eg_rout + eg_inc) & 0x1ff;
	/* Key off */
	if (reset) {
		slot->eg_gen = EG_ATTACK;
	}
	if (!slot->key) {
		slot->eg_gen = EG_RELEASE;
	}
}

static void phase_generate(Opl2Chip *chip, Opl2Channel *channel, Opl2Slot *slot) {
	uint16_t f_num = channel->f_num;
	if (slot->vib) {
		int8_t range = (f_num >> 7) & 7;
		uint8_t vibpos = chip->vibpos;
		if (!(vibpos & 3)) {
			range = 0;
		} else if (vibpos & 1) {
			range >>= 1;
		}
		range >>= chip->vibshift;
		if (vibpos & 4) {
			range = -range;
		}
		f_num += range;
	}
	uint32_t basefreq = ((uint32_t)f_num << channel->block) >> 1;
	uint16_t phase = (uint16_t)(slot->pg_phase >> 9);
	if (slot->pg_reset) {
		slot->pg_phase = 0;
	}
	slot->pg_phase += (basefreq * mult_table[slot->mult]) >> 1;
	slot->pg_phase_out = phase;
}

static void process_slot(Opl2Chip *chip, Opl2Channel *channel, Opl2Slot *slot, int16_t modulation) {
	uint8_t wf = chip->wse ? slot->wf : 0;
	envelope_calc(chip, channel, slot);
	phase_generate(chip, channel, slot);
	slot->out = waveform(wf, (uint16_t)(slot->pg_phase_out + modulation), slot->eg_out);
}

int16_t opl2_sample(Opl2Chip *chip) {
	int32_t mix = 0;

	for (int c = 0; c < 9; c++) {
		Opl2Channel *channel = &chip->channel[c];
		Opl2Slot *mod = &channel->slot[0];
		Opl2Slot *car = &channel->slot[1];

		/* Feedback of the first operator onto itself. */
		if (channel->fb != 0) {
			mod->fbmod = (int16_t)((mod->prout + mod->out) >> (0x09 - channel->fb));
		} else {
			mod->fbmod = 0;
		}
		mod->prout = mod->out;

		process_slot(chip, channel, mod, mod->fbmod);
		if (channel->con) {
			/* Additive: both operators are heard. */
			process_slot(chip, channel, car, 0);
			mix += mod->out + car->out;
		} else {
			/* Frequency modulation: the first operator bends the second. */
			process_slot(chip, channel, car, mod->out);
			mix += car->out;
		}
	}

	/* Tremolo and vibrato. */
	if ((chip->timer & 0x3f) == 0x3f) {
		chip->tremolopos = (chip->tremolopos + 1) % 210;
	}
	if (chip->tremolopos < 105) {
		chip->tremolo = chip->tremolopos >> chip->tremoloshift;
	} else {
		chip->tremolo = (210 - chip->tremolopos) >> chip->tremoloshift;
	}
	if ((chip->timer & 0x3ff) == 0x3ff) {
		chip->vibpos = (chip->vibpos + 1) & 7;
	}
	chip->timer++;

	/* The envelope generators' shared counter. */
	if (chip->eg_state) {
		uint8_t shift = 0;
		while (shift < 36 && ((chip->eg_timer >> shift) & 1) == 0) {
			shift++;
		}
		chip->eg_add = (shift > 12) ? 0 : shift + 1;
	}
	if (chip->eg_timerrem || chip->eg_state) {
		if (chip->eg_timer == 0xfffffffffULL) {
			chip->eg_timer = 0;
			chip->eg_timerrem = 1;
		} else {
			chip->eg_timer++;
			chip->eg_timerrem = 0;
		}
	}
	chip->eg_state ^= 1;

	if (mix > 32767) {
		mix = 32767;
	} else if (mix < -32768) {
		mix = -32768;
	}
	return (int16_t)mix;
}

void opl2_reset(Opl2Chip *chip) {
	if (!roms_ready) {
		make_roms();
	}
	memset(chip, 0, sizeof(*chip));
	for (int c = 0; c < 9; c++) {
		for (int s = 0; s < 2; s++) {
			Opl2Slot *slot = &chip->channel[c].slot[s];
			slot->eg_rout = 0x1ff;
			slot->eg_out = 0x1ff;
			slot->eg_gen = EG_RELEASE;
		}
	}
	chip->tremoloshift = 4;
	chip->vibshift = 1;
}

void opl2_write(Opl2Chip *chip, uint8_t reg, uint8_t value) {
	uint8_t group = reg & 0xe0;
	uint8_t low = reg & 0x1f;

	if (reg == 0x01) {
		chip->wse = (value >> 5) & 1;
		return;
	}
	if (reg == 0x08) {
		chip->nts = (value >> 6) & 1;
		return;
	}
	if (reg == 0xbd) {
		chip->tremoloshift = (((value >> 7) ^ 1) << 1) + 2;
		chip->vibshift = ((value >> 6) & 1) ^ 1;
		return;
	}

	if (group == 0x20 || group == 0x40 || group == 0x60 || group == 0x80 || group == 0xe0) {
		if (slot_channel[low] < 0) {
			return;
		}
		Opl2Slot *slot = &chip->channel[slot_channel[low]].slot[slot_index[low]];
		switch (group) {
			case 0x20:
				slot->am = (value >> 7) & 1;
				slot->vib = (value >> 6) & 1;
				slot->egt = (value >> 5) & 1;
				slot->ksr = (value >> 4) & 1;
				slot->mult = value & 0x0f;
				break;
			case 0x40:
				slot->ksl = (value >> 6) & 3;
				slot->tl = value & 0x3f;
				break;
			case 0x60:
				slot->ar = (value >> 4) & 0x0f;
				slot->dr = value & 0x0f;
				break;
			case 0x80:
				slot->sl = (value >> 4) & 0x0f;
				if (slot->sl == 0x0f) {
					slot->sl = 0x1f;
				}
				slot->rr = value & 0x0f;
				break;
			case 0xe0:
				slot->wf = value & 0x03;
				break;
		}
		return;
	}

	if (reg >= 0xa0 && reg <= 0xa8) {
		Opl2Channel *channel = &chip->channel[reg - 0xa0];
		channel->f_num = (channel->f_num & 0x300) | value;
		channel->ksv = (channel->block << 1) | ((channel->f_num >> (0x09 - chip->nts)) & 0x01);
		update_ksl(channel);
		return;
	}
	if (reg >= 0xb0 && reg <= 0xb8) {
		Opl2Channel *channel = &chip->channel[reg - 0xb0];
		channel->f_num = (channel->f_num & 0xff) | ((uint16_t)(value & 0x03) << 8);
		channel->block = (value >> 2) & 0x07;
		channel->ksv = (channel->block << 1) | ((channel->f_num >> (0x09 - chip->nts)) & 0x01);
		update_ksl(channel);
		uint8_t key = (value >> 5) & 1;
		channel->slot[0].key = key;
		channel->slot[1].key = key;
		return;
	}
	if (reg >= 0xc0 && reg <= 0xc8) {
		Opl2Channel *channel = &chip->channel[reg - 0xc0];
		channel->fb = (value >> 1) & 0x07;
		channel->con = value & 0x01;
		return;
	}
}
