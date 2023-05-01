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
  BFState bfstate;

  BF bf (
    .addr,
    .val_in,
    .val_out,
    .bus_op,
    .halted,
    .clock,
    .reset,
    .enable(enable && bf_enable),
    .state(bfstate),
    .next_state()
  );

  BusOp op_cache;
  logic [15:0] addr_cache;
  logic [7:0] val_cache;

  // Control signals
  logic bf_enable;
  logic cache;

  always_comb begin
    bf_enable = 0;
    cache = 0;
    bus_out = '0;
    val_in = '0;

    case (state)
      IoNone: begin
        bf_enable = 1;
        cache = 1;
        bus_out = {bus_op, bfstate[4:0]};

        if (bus_op != BusNone)
          next_state = IoOpcode;
        else
          next_state = IoNone;
      end
      IoOpcode: begin
        bus_out = {5'b0, op_cache};

        next_state = IoAddrHi;
      end
      IoAddrHi: begin
        bus_out = {1'b0, addr_cache[14:8]};

        next_state = IoAddrLo;
      end
      IoAddrLo: begin
        bus_out = addr_cache[7:0];

        next_state = IoReadWrite;
      end
      IoReadWrite: begin
        bus_out = val_cache;
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
    if (reset) begin
      state <= IoNone;
      op_cache <= '0;
    end
    else if (enable) begin
      state <= next_state;
      if (cache) begin
        op_cache <= bus_op;
        addr_cache <= addr;
        val_cache <= val_out;
      end
    end

endmodule
