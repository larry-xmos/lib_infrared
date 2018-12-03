#include <xs1.h>
#include <stdio.h>
#include <print.h>
#include "ir.h"

void ir_setup(in buffered port:32 p_ir_rx, clock b_ir_rx)
{
  // divider 164 means sampling at 304.9kHz
  // 8x carrier rate is 305.8kHz so this is very close
  set_clock_div(b_ir_rx, 164);
  set_port_clock(p_ir_rx, b_ir_rx);
  start_clock(b_ir_rx);
}

[[combinable]] void ir_demodulate(in buffered port:32 p_ir_rx,
                                  client interface i_ir_pulses i_ir_pulses)
{
  enum { SPACE, PULSE } last = SPACE;
  int start = 0;

  while (1) {
    select {
      case p_ir_rx :> unsigned nibble @ int end: // 9.56kHz ~ 105us
        if (last == SPACE && nibble == 0) {
          i_ir_pulses.pulse(end - start);
          last = PULSE;
          start = end;
        }
        else if (last == PULSE && nibble != 0) {
          i_ir_pulses.space(end - start);
          last = SPACE;
          start = end;
        }
        break;
    }
  }
}

[[combinable]] void ir_protocol(server interface i_ir_pulses i_ir_pulses)
{
  while (1) {
    select {
      case i_ir_pulses.pulse(int width):
        printstr("pulse ");
        printintln(width);
        break;

      case i_ir_pulses.space(int width):
        printstr("space ");
        printintln(width);
        break;
    }
  }
}
