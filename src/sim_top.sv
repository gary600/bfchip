`default_nettype none

module ProgramMemory #(
  parameter PROG_ADDR_SIZE = 16
)(
  output logic [7:0] instr,
  input logic [PROG_ADDR_SIZE-1:0] ip
);

  // Preloaded by the simulator
  reg [7:0] mem [0:(1<<PROG_ADDR_SIZE)-1];

  assign instr = mem[ip];

endmodule

module DataMemory #(
  parameter DATA_ADDR_SIZE = 16
)(
  output logic [7:0] read_val,
  input logic [DATA_ADDR_SIZE-1:0] cursor,
  input logic [7:0] write_val,
  input logic write_enable, clock
);

  logic [7:0] mem [0:(1<<DATA_ADDR_SIZE)-1];

  assign read_val = mem[cursor];

  always_ff @(posedge clock)
    if (write_enable)
      mem[cursor] <= write_val; // TODO: impl clearing

endmodule

module SimTop #(
  parameter PROG_ADDR_SIZE = 16,
  parameter DATA_ADDR_SIZE = 16
)(
  output logic [PROG_ADDR_SIZE-1:0] ip,
  output logic [7:0] instr,
  output logic instr_valid,

  output logic [DATA_ADDR_SIZE-1:0] cursor,
  output logic [7:0] read_val,
  output logic [7:0] write_val,
  output logic write_enable,

  output logic [7:0] out_val,
  output logic out_enable,

  input logic [7:0] in_val,
  input logic in_valid,
  output logic in_reading,

  output logic halted,
  output logic enable,
  input logic clock, reset
);

  assign instr_valid = 1;
  assign enable = 1;

  ProgramMemory #(.PROG_ADDR_SIZE(PROG_ADDR_SIZE)) prog(.*);
  DataMemory #(.DATA_ADDR_SIZE(DATA_ADDR_SIZE)) data(.*);
  BF #(.PROG_ADDR_SIZE(PROG_ADDR_SIZE), .DATA_ADDR_SIZE(DATA_ADDR_SIZE)) bf(.*);

  // initial begin
  //   forever begin
  //     clock = 1;
  //     #5;
  //     clock = 0;
  //     #5;
  //   end
  // end
  
  // the "macro" to dump signals
  `ifdef COCOTB_SIM
  initial begin
    $dumpfile("build/sim_top.vcd");
    $dumpvars(0, SimTop);
    #1;
  end
  `endif

endmodule