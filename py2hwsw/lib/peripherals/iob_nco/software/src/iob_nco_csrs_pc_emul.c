/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

/* PC Emulation of nco peripheral */

#include <stdint.h>
#include <time.h>

#include "iob_nco_csrs.h"

#define FREQ 100000000

/* convert clock values from PC CLOCK FREQ to EMBEDDED FREQ */
#define PC_TO_FREQ_FACTOR ((1.0 * FREQ) / CLOCKS_PER_SEC)

static clock_t start, end, time_counter, counter_reg;
static int nco_enable;

static int base;
void iob_nco_csrs_init_baseaddr(uint32_t addr) {
  base = addr;
  return;
}

void iob_nco_csrs_set_soft_reset(uint8_t value) {
  // use only reg width
  int rst_int = (value & 0x01);
  if (rst_int) {
    start = end = 0;
    time_counter = 0;
    nco_enable = 0;
  }
  return;
}

void iob_nco_csrs_set_enable(uint8_t value) {
  // use only reg width
  int en_int = (value & 0x01);
  // manage transitions
  // 0 -> 1
  if (nco_enable == 0 && en_int == 1) {
    // start counting time
    start = clock();
  } else if (nco_enable == 1 && en_int == 0) {
    // accumulate enable interval
    end = clock();
    nco_enable += (end - start);
    start = end = 0; // reset aux clock values
  }
  // store enable en_int
  nco_enable = en_int;
  return;
}
