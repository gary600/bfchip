`default_nettype none

module SpiMaster(
  // Physical IO
  output logic si, sck,
  input logic so,

  // Data registers
  input logic [31:0] write_data,
  output logic [7:0] read_data,
  // Lengths to read and write, in bytes
  input logic [2:0] write_len, // 0-4 bytes
  input logic read_len, // either 0 or 1 byte

  // Assert Send to send
  input logic send,
  // Read data is valid when Done asserted
  output logic done,
  input logic clock, reset
);

  logic [31:0] write_buf;
  logic [4:0] write_count;

  enum logic [1:0] {Wait, Write, Read, Done} state;

  always_ff @(posedge clock, posedge reset)
    if (reset) begin
      state <= Wait;
      read_data <= '0;
    end
    else
      case (state)
        Wait:
          if (send) begin
            state <= Write;
            write_buf <= write_data;
            write_count <= write_len;
          end
        Write:
          ;
      endcase

  always_comb begin
    sck = 0;
    si = 0;
    done = 0;
    
    case (state)
      Write: sck = clock;
      Read: sck = clock;
      Done: done = 1;
      default: ;
    endcase
  end

endmodule