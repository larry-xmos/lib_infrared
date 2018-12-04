#include <xs1.h>

void set_up_transmit_port(out buffered port:32 p_ir_tx, port p_ir_tx_int,
                          clock b_ir_tx_1, clock b_ir_tx_2);

void send_one_test_command(out buffered port:32 p_ir_tx,
                           char address, char command);
