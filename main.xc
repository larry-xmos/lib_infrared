#include <xs1.h>
#include <stdlib.h>
#include <syscall.h>
#include "ir.h"
#include "test.h"

in buffered port:32 p_ir_rx = XS1_PORT_1A;
clock b_ir_rx = XS1_CLKBLK_1;

out buffered port:32 p_ir_tx = XS1_PORT_1B;
clock b_ir_tx = XS1_CLKBLK_2;

int main(void)
{
  interface i_ir_pulses i_ir_pulses;

  ir_setup(p_ir_rx, b_ir_rx);
  set_up_transmit_port(p_ir_tx, b_ir_tx);
  par {
    [[combine]] par {
      ir_demodulate(p_ir_rx, i_ir_pulses);
      ir_protocol(i_ir_pulses);
    }
    { send_one_test_command(p_ir_tx, 0, 0);
      _exit(0);
    }
  }

  return 0;
}
