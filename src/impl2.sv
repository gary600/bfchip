`default_nettype none

module BF #(
  parameter ADDR_WIDTH = 15,
  parameter DATA_WIDTH = 8
)(
  // Bus interface
  output logic [ADDR_WIDTH-1:0] addr,
  output logic [DATA_WIDTH-1:0] val_out,
  input  logic [DATA_WIDTH-1:0] val_in,
  input  logic valid,

  // Bus control
  output logic read_prog,
  output logic read_data,
  output logic write_data,
  output logic read_io,
  output logic write_io,

  // Interpreter control
  output logic halted,
  input  logic clock,
  input  logic reset,
  input  logic enable
);

  logic [ADDR_WIDTH-1:0] pc;
  logic [7:0] instruction;

  logic [ADDR_WIDTH-1:0] cursor;
  logic [DATA_WIDTH-1:0] val;



  enum logic [2:0] {
    Fetch, // addr=pc, read_prog,
  } state;

endmodule