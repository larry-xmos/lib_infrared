#include <xs1.h>

void set_up_transmit_port(out buffered port:32 p_ir_tx, clock b_ir_tx)
{
  // divider 255 produces IR carrier frequency of 196kHz
  set_clock_div(b_ir_tx, 255);
  set_port_clock(p_ir_tx, b_ir_tx);
  start_clock(b_ir_tx);

  p_ir_tx <: 0;
  sync(p_ir_tx);
}

void send_one_test_command(out buffered port:32 p_ir_tx,
                           char address, char command)
{
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  p_ir_tx <: 0x55555555;
  p_ir_tx <: 0;
  return;

  char symbols[4] = { address, ~address, command, ~command};

  // start with header already encoded
  int enc[128] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
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

  // output encoded pulses and spaces
  for (int k = 0; k < len; k++) {
    p_ir_tx <: enc[k] * 0x55555555;
    partout(p_ir_tx, 16, enc[k] * 0x5555);
  }
  sync(p_ir_tx);
}
