`default_nettype none

module BF #(
  parameter ADDR_WIDTH = 15,
  parameter DATA_WIDTH = 8
)(
  // Bus interface
  output logic [ADDR_WIDTH-1:0] addr,
  output logic [DATA_WIDTH-1:0] val_out,
  input  logic [DATA_WIDTH-1:0] val_in,
  // input  logic valid,

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

  // Program memory interface
  logic [ADDR_WIDTH-1:0] pc;
  logic [7:0] instruction;

  // Data memory interface
  logic [ADDR_WIDTH-1:0] cursor;
  logic [DATA_WIDTH-1:0] acc;
  
  // Control Signals
  logic acc_in, acc_out, acc_out_up, acc_out_down;

  always_comb
    if (read_prog)
      addr = pc;
    else
      addr = cursor;


  enum logic [2:0] {
    Fetch,
    Decode,
    IncLoad,
    IncStore,
    DecLoad,
    DecStore,
  } state, next_state;

  // Next state
  always_comb case (state)
    Fetch: next_state = Decode;
    Decode: case (val_in)
      "+": next_state = IncLoad;
      "-": next_state = DecLoad;
      ".": next_state = Print;
      ".": next_state = Read;
      "[": next_state = AddLoad;
      "]": next_state = AddLoad;
      default: next_state = Fetch;
    endcase
    IncLoad: next_state = IncStore;
    IncStore: next_state = Fetch;
    DecLoad: next_state = DecStore;
    DecStore: next_state = Fetch;
  endcase

  // Output logic
  always_comb begin
    read_prog = 0;
    read_data = 0;
    write_data = 0;
    read_io = 0;
    write_io = 0;

    acc_in = 0;
    acc_out = 0;
    acc_out_up = 0;
    acc_out_down = 0;

    case (state)
      Fetch: read_prog = 1;
      Decode: case (val_in)
        "+", "-", ".": read_data = 1;
        ",": read_io = 1;
      endcase
      IncLoad: begin
        read_data = 1;
        
      end
    endcase
  end

endmodule