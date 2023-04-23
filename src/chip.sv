`default_nettype none

module Chip(
  output logic si, sck,
  input logic so,
  output logic data_cs_n, prog_cs_n,

  input logic rx,
  output logic tx,

  output logic halted,

  input logic run,
  input logic clock, reset
);

  localparam OPCODE_READ  = 8'b00000011;
  localparam OPCODE_WRITE = 8'b00000010;

  // SPI interface
  logic [31:0] write_data;
  logic [7:0] read_data;
  logic [2:0] write_len;
  logic read_len;

  logic send;
  logic done;

  SpiMaster spi(.*);

  // Memory buffers
  logic [15:0] loaded_ip;
  logic [15:0] loaded_cursor;

  logic instr_valid;
  assign instr_valid = (ip == loaded_ip);
  logic data_valid;
  assign data_valid = (cursor == loaded_cursor);

  // BF interpreter
  logic [15:0] ip;
  logic [7:0] instr;

  logic [15:0] cursor;
  logic [7:0] read_val;
  logic [7:0] write_val;
  logic write_enable;

  logic [7:0] out_val;
  logic out_enable;

  logic [7:0] in_val;
  logic in_valid;
  logic in_reading;

  logic enable;
  
  BF #(
    .PROG_ADDR_SIZE(16),
    .DATA_ADDR_SIZE(16)
  ) bf(.*);


  // State machine
  logic mem_op;

  always_ff @(posedge clock, posedge reset)
    if (reset) begin
      // Since the BF interpreter starts at ip=0 and cursor=0,
      // this will always load on the first cycle
      loaded_ip <= 16'hFFFF;
      loaded_cursor <= 16'hFFFFF;

      mem_op <= 0;
    end
    else begin
      if (!instr_valid) begin
        
    end

  // SPI setups
  always_comb begin
    write_data = '0;
    write_len = '0;
    read_len = '0;
    prog_cs_n = 1;
    data_cs_n = 1;
    send = 0;

    if (!mem_op) begin
      if (!instr_valid) begin
        prog_cs_n = 0; // Select the program memory
        write_data = {OPCODE_READ, ip, '0}; // MSB-first
        write_len = 3'd3; // 8-bit opcode plus 16-bit address
        read_len = 1; // receive 8 bit
        send = 1; // Begin operation
      end
      else if (!data_valid) begin
        data_cs_n = 0; // Select the data memory
        write_data = {OPCODE_READ, cursor, '0}; // MSB-first
        write_len = 3'd3; // 8-bit opcode plus 16-bit address
        read_len = 1; // receive 8 bit
        send = 1; // Begin operation
      end
      else if (write_enable) begin
        data_cs_n = 0; // Select the data memory
        write_data = {OPCODE_WRITE, cursor, write_val}; // MSB-first
        write_len = 3'd4; // 8-bit opcode plus 16-bit address plus 8-bit data
        read_len = 0; // receive nothing
        send = 1; // Begin operation
      end
    end
  end

  // Only enable BF if all requested memory is valid
  assign enable = instr_valid && data_valid;

endmodule