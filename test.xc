#include <xs1.h>
#include "test.h"

void set_up_transmit_port(out buffered port:32 p_ir_tx, port p_ir_tx_int,
                          clock b_ir_tx_1, clock b_ir_tx_2)
{
  // driving IR trasmit port at 76,444 Hz, double of carrier 38,222 Hz
  // cascade of clock blocks to produce very close to actual frequency
  // 100 MHz / (3*2) / (109*2) = 76,453 Hz

  set_clock_div(b_ir_tx_1, 3);
  set_clock_div(b_ir_tx_2, 109);
  set_port_clock(p_ir_tx_int, b_ir_tx_1);
  set_port_mode_clock(p_ir_tx_int);
  set_clock_src(b_ir_tx_2, p_ir_tx_int);
  set_port_clock(p_ir_tx, b_ir_tx_2);
  start_clock(b_ir_tx_1);
  start_clock(b_ir_tx_2);

  p_ir_tx <: 0;
  sync(p_ir_tx);
}

void send_one_test_command(out buffered port:32 p_ir_tx,
                           char address, char command)
{
  char symbols[4] = { address, ~address, command, ~command};

  // start with header already encoded
  char enc[200] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                   0, 0, 0, 0, 0, 0, 0, 0};
  int len = 24;

  // now encode address and data
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 8; j++) {
      enc[len++] = 1;
      enc[len++] = 0;
      if (symbols[i] & (1 << j)) {
        enc[len++] = 0;
      }
    }
  }

  // add footer and a gap
  enc[len++] = 1;
  for (int k = 0; k < 2; k++) {
    enc[len++] = 0;
  }

  // output encoded pulses and spaces
  for (int k = 0; k < len; k++) {
    p_ir_tx <: (int)enc[k] * 0x55555555;
    partout(p_ir_tx, 8, (int)enc[k] * 0x55);
  }
  sync(p_ir_tx);
}
