// Copyright (c) 2018, XMOS Ltd, All rights reserved
//
// Usage: xsim --vcd-tracing \
           '-o /tmp/trace.vcd -tile tile[0] -ports -ports-detailed' \
           --plugin LoopbackPort.dll \
           '-port tile[0] XS1_PORT_1B 1 0 -port tile[0] XS1_PORT_1A 1 0' \
           bin/basic.xe

#include <xs1.h>
#include <stdlib.h>
#include <syscall.h>
#include <print.h>
#include "ir.h"
#include "test.h"

in buffered port:32 p_ir_rx = XS1_PORT_1A;
clock b_ir_rx = XS1_CLKBLK_1;

out buffered port:32 p_ir_tx = XS1_PORT_1B;
port p_ir_tx_int = XS1_PORT_1C;
clock b_ir_tx_1 = XS1_CLKBLK_2;
clock b_ir_tx_2 = XS1_CLKBLK_3;

void monitor(server interface i_ir i_ir)
{
  while (1) {
    select {
      case i_ir.command(int addr, int cmd):
        printhex(addr);
        printstr(" ");
        printhexln(cmd);
        break;
    }
  }
}

int main(void)
{
  interface i_ir_pulses i_ir_pulses;
  interface i_ir i_ir;

  ir_setup(p_ir_rx, b_ir_rx);
  set_up_transmit_port(p_ir_tx, p_ir_tx_int, b_ir_tx_1, b_ir_tx_2);
  par {
    [[combine]] par {
      ir_demodulate(p_ir_rx, i_ir_pulses);
      ir_protocol(i_ir_pulses, i_ir);
    }

    { send_one_test_command(p_ir_tx, 0, 0);
      send_one_test_command(p_ir_tx, 0x12, 0x34);
      send_one_test_command(p_ir_tx, 0x56, 0x78);
      _exit(0);
    }
    monitor(i_ir);
  }

  return 0;
}
