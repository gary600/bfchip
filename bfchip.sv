`default_nettype none

module BF(
  // output logic [7:0] ip,
  // input logic [7:0] instruction,

  // output logic [7:0] cursor,
  // output logic write,
  // input logic cell,

  // output logic [7:0] out,
  // output logic out_clock,

  // input logic [7:0] in,
  // input logic in_clock,

  // input logic clock, reset

  output logic [7:0] out,
  output logic [3:0] current_instr,
  output logic [7:0] current_cell,
  input logic [7:0] in,
  input logic [7:0] instr_addr,
  // input logic [3:0] instr_addr,
  input logic [3:0] instr_in,
  input logic instr_write,
  input logic clock, reset
);

  // 256 3-bit instructions
  enum logic [2:0] {
    Next  = 3'h0, Prev    = 3'h1,
    Inc   = 3'h2, Dec     = 3'h3,
    Print = 3'h4, Read    = 3'h5,
    Loop  = 3'h6, EndLoop = 3'h7
  } prog [0:255];
  // } prog [0:15];
  logic [7:0] ip;
  // logic [3:0] ip;

  assign current_instr = prog[ip];

  // 256 bytes of memory
  logic [7:0] mem [0:255];
  logic [7:0] cursor;
  // logic [7:0] mem [0:15];
  // logic [3:0] cursor;

  assign current_cell = mem[cursor];

  // Machine state:
  // Exec: on clock, read the current instruction and eval it
  // SeekForward: on clock, seek forward an instruction, returning to Exec if it is a matching ]
  // SeekBackward: on clock, seek backward an instruction, returning to Exec if it is a matching [
  enum logic [1:0] {Exec, SeekForward, SeekBackward} state;
  logic [3:0] depth;

  // Allow writing instructions
  always_ff @(posedge instr_write)
    prog[instr_addr] <= instr_in;

  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      ip <= '0;

      mem <= '0;
      cursor <= '0;
      
      state <= Exec;
      depth <= '0;
    end
    else unique case (state)
      // Regular execution: evaluate instructions
      Exec:
        case (prog[ip])
          Next: begin
            cursor <= cursor + 1;
            ip <= ip + 1;
          end

          Prev: begin
            cursor <= cursor - 1;
            ip <= ip + 1;
          end

          Inc: begin
            mem[cursor] <= mem[cursor] + 1;
            ip <= ip + 1;
          end

          Dec: begin
            mem[cursor] <= mem[cursor] - 1;
            ip <= ip + 1;
          end

          Print: begin
            out <= mem[cursor];
            ip <= ip + 1;
          end

          Read: begin
            mem[cursor] <= in;
            ip <= ip + 1;
          end

          Loop: begin
            if (mem[cursor] == '0) begin
              state <= SeekForward;
              depth <= '0;
            end
            ip <= ip + 1;
          end

          EndLoop:
            if (mem[cursor] != '0) begin
              state <= SeekBackward;
              depth <= '0;
              ip <= ip - 1;
            end
            else
              ip <= ip + 1;
        endcase

      // Seek forward to the matching ], ending with ip on the instruction after the ]
      SeekForward: begin
        case (prog[ip])
          Loop: depth <= depth + 1;
          EndLoop:
            if (depth == 0)
              state <= Exec;
            else
              depth <= depth - 1;
        endcase
        ip <= ip + 1;
      end

      // Seek backward to the matching [, ending with ip on the instruction after the [
      SeekBackward: begin
        case (prog[ip])
          Loop:
            if (depth == 0) begin
              state <= Exec;
              ip <= ip + 1;
            end
            else begin
              depth <= depth - 1;
              ip <= ip - 1;
            end
          EndLoop: begin
            depth <= depth - 1;
            ip <= ip - 1;
          end
          default: ip <= ip - 1;
        endcase
      end
    endcase
  end

endmodule