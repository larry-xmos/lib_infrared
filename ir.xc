// Copyright (c) 2018, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <print.h>
#include "ir.h"

#define DEBUG 0

void ir_setup(in buffered port:32 p_ir_rx, clock b_ir_rx)
{
  // divider 82 means sampling at 609.8kHz
  // very close to 16x carrier rate, which is 611.552kHz
  set_clock_div(b_ir_rx, 82);
  set_port_clock(p_ir_rx, b_ir_rx);
  start_clock(b_ir_rx);
}

enum { SPACE, PULSE };

[[combinable]] void ir_demodulate(in buffered port:32 p_ir_rx,
                                  client interface i_ir_pulses i_ir_pulses)
{
  int last = SPACE;
  short start = 0;

  while (1) {
    select {
      case p_ir_rx :> unsigned treg @ int end: // 19.06kHz/52.48us
        if (last == SPACE && treg == 0) {
          i_ir_pulses.pulse((short)(end - start));
          last = PULSE;
          start = end;
        }
        else if (last == PULSE && treg != 0) {
          i_ir_pulses.space((short)(end - start));
          last = SPACE;
          start = end;
        }
        break;
    }
  }
}

// if sampling at 16x carrier frequency, for instance, then n pulses correspond
// to 16n port time cycles
//
// typical pulse burst or space is 20 pulses, so 320 port clock cycles
// leading pulse burst is 320 pulses, so 5120 port cycles
// similarly for leading space, which is half of that
#define LEADING_PULSE 5120
#define LEADING_SPACE 2560
#define TYPICAL 320

static int event(int sp, int w, int bytes[4])
{
  // TODO represent state with symbols, eg as a C structure
  static enum {
    // header parsing has number 4 at offset 8
    // idle state is also the final state
    IDLE = 0b10000, P1 = 0b10001, S1 = 0b10010,

    // byte parsing has byte number at offset 8
    // substate at offset 0, either 0, 1 or 2
    PA = 0b0000, SA0 = 0b0001, SA1 = 0b0010,
    PAI = 0b0100, SAI0 = 0b0101, SAI1 = 0b0110,
    PC = 0b1000, SC0 = 0b1001, SC1 = 0b1010,
    PCI = 0b1100, SCI0 = 0b1101, SCI1 = 0b1110,
  } state = IDLE, next;

#if DEBUG
  char str[65][5];

  if (str[IDLE][0] != 'I') {
    strcpy(str[IDLE], "IDLE");
    strcpy(str[P1], "P1");
    strcpy(str[S1], "S1");
    strcpy(str[PA], "PA");
    strcpy(str[SA0], "SA0");
    strcpy(str[SA1], "SA1");
    strcpy(str[PAI], "PAI");
    strcpy(str[SAI0], "SAI0");
    strcpy(str[SAI1], "SAI1");
    strcpy(str[PC], "PC");
    strcpy(str[SC0], "SC0");
    strcpy(str[SC1], "SC1");
    strcpy(str[PCI], "PCI");
    strcpy(str[SCI0], "SCI0");
    strcpy(str[SCI1], "SCI1");
  }

  printstr(sp == PULSE ? "pulse " : "space ");
  printintln(w);
#endif

  static int bitcount = 0;
  static int byte = 0;
  int done = 0;

  next = IDLE;

  // TODO repeat codes
  if (state == IDLE) {
    if (sp == PULSE && w >= LEADING_PULSE - 32 && w <= LEADING_PULSE + 32)
      next = P1;
  } else if (state == P1) {
    if (sp == SPACE && w >= LEADING_SPACE - 32 && w <= LEADING_SPACE + 32)
      next = S1;
  }
  else if (state == S1) {
    if (sp == PULSE && w >= TYPICAL - 32 && w <= TYPICAL + 32) {
      next = PA;
      bitcount = 8;
      byte = 0;
    }
  }
  else if ((state >> 2) < 4 && (state & 3) == 0) { // PA PAI PC PCI
    if (sp == SPACE) {
      if (w >= 640 - 32 && w <= 640 + 32) {
        next = state + 2;
        byte = (byte >> 1) | 0x80;
      }
      else if (w >= TYPICAL - 32 && w <= TYPICAL + 32) {
        next = state + 1;
        byte = (byte >> 1);
      }
    }
  }
  else if ((state >> 2) < 4 && (state & 3) > 0) { // SA0 SA1 SAI0 SAI1
                                                  // SC0 SC1 SCI0 SCI1
    if (sp == PULSE && w >= TYPICAL - 32 && w <= TYPICAL + 32) {
      bitcount--;
      if (bitcount > 0) {
        next = state & 0xC; // current PA PAI PC PCI
      }
      else {
        next = ((state >> 2) + 1) << 2; // the following PA PAI PC PCI
#if DEBUG
        printhexln(byte);
#endif
        bytes[state >> 2] = byte;
        bitcount = 8;
        byte = 0;
        done = state == SCI0 || state == SCI1;
      }
    }
  }
  
  if (next != state) {
#if DEBUG
    printstr(str[state]);
    printstr(" -> ");
    printstrln(str[next]);
#endif
    state = next;
  }

  return done;
}

[[combinable]] void ir_protocol(server interface i_ir_pulses i_ir_pulses,
                                client interface i_ir i_ir)
{
  int bytes[4];

  while (1) {
    select {
      case i_ir_pulses.pulse(int width):
        if (event(1, width, bytes)) {
          // discard commands where error checking failed on either byte
          if (bytes[0] == (~bytes[1] & 0xFF) && bytes[2] == (~bytes[3] & 0xFF))
            i_ir.command(bytes[0], bytes[2]);
        }
        break;

      case i_ir_pulses.space(int width):
        event(0, width, bytes);
        break;
    }
  }
}
