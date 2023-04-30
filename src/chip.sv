`default_nettype none

module my_chip (
  input logic [11:0] io_in, // Inputs to your chip
  output logic [11:0] io_out, // Outputs from your chip
  input logic clock,
  input logic reset // Important: Reset is ACTIVE-HIGH
);

  // Outputs / inputs
  logic [7:0] bus_out;
  IoOp state, next_state;
  assign io_out = {halted, state, bus_out};

  logic [7:0] bus_in = io_in[7:0];
  logic op_done = io_in[8];
  logic enable = io_in[9];

  // BF interface
  logic [14:0] addr;
  logic [7:0] val_in, val_out;
  BusOp bus_op;
  logic halted;

  BF bf (
    .addr,
    .val_in,
    .val_out,
    .bus_op,
    .halted,
    .clock,
    .reset,
    .enable(enable && bf_enable)
  );

  // Control signals
  logic bf_enable;

  always_comb begin
    bf_enable = 0;
    bus_out = '0;
    val_in = '0;

    case (state)
      IoNone: begin
        bf_enable = 1;

        if (bus_op != BusNone)
          next_state = IoOpcode;
        else
          next_state = IoNone;
      end
      IoOpcode: begin
        bus_out = {5'b0, bus_op};

        next_state = IoAddrHi;
      end
      IoAddrHi: begin
        bus_out = {1'b0, addr[14:8]};

        next_state = IoAddrLo;
      end
      IoAddrLo: begin
        bus_out = addr[7:0];

        next_state = IoReadWrite;
      end
      IoReadWrite: begin
        bus_out = val_out;
        val_in = bus_in;

        if (op_done) begin
          bf_enable = 1;

          next_state = IoNone;
        end
        else 
          next_state = IoReadWrite;
      end
      default: next_state = IoNone;
    endcase
  end

  always_ff @(posedge clock, posedge reset)
    if (reset) state <= IoNone;
    else state <= next_state;

endmodule