// Copyright (c) 2018, XMOS Ltd, All rights reserved
#ifndef __ir_h__
#define __ir_h__

#include <xs1.h>

interface i_ir_pulses {
  void pulse(int width);
  void space(int width);
};

interface i_ir {
  void command(int addr, int cmd);
};

void ir_setup(in buffered port:32 p_ir_rx, clock b_ir_rx);

[[combinable]] void ir_demodulate(in buffered port:32 p_ir_rx,
                                  client interface i_ir_pulses i_ir_pulses);

[[combinable]] void ir_protocol(server interface i_ir_pulses i_ir_pulses,
                                client interface i_ir i_ir);

#endif
