`default_nettype none

module BF #(
  parameter PROG_ADDR_SIZE = 8,
  parameter DATA_ADDR_SIZE = 8
)(
  output logic [PROG_ADDR_SIZE-1:0] ip,
  input logic [7:0] instruction,

  output logic [DATA_ADDR_SIZE-1:0] cursor,
  output logic [7:0] write_val,
  output logic write_enable,
  input logic [7:0] read_val,

  output logic [7:0] out,
  output logic out_enable,

  input logic [7:0] in,
  input logic in_clock,

  output logic halted,
  input logic clock, reset
);
  // Machine state
  enum logic [2:0] {
    // on clock, read the current instruction and eval it
    Exec,
    // on clock, seek forward an instruction, returning to Exec if it is a matching ]
    SeekForward,
    // on clock, seek backward an instruction, returning to Exec if it is a matching [
    SeekBackward,
    // do nothing (execution finished)
    Halt,
    // Clear memory
    Clear
    // TODO: wait for input
  } state;
  // Loop depth, for matching up brackets
  logic [15:0] depth;

  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      ip <= '0;
      cursor <= '0;
      
      state <= Clear;
      depth <= '0;
    end
    else unique case (state)
      // Regular execution: evaluate instructions
      Exec:
        case (instruction)
          ">": begin
            cursor <= cursor + 1;
            ip <= ip + 1;
          end

          "<": begin
            cursor <= cursor - 1;
            ip <= ip + 1;
          end

          // logic for { + - . , } handled by the always_comb
          "+", "-", ".", ",": ip <= ip + 1;

          "[": begin
            if (read_val == '0) begin
              state <= SeekForward;
              depth <= '0;
            end
            ip <= ip + 1;
          end

          "]":
            if (read_val != '0) begin
              state <= SeekBackward;
              depth <= '0;
              ip <= ip - 1;
            end
            else
              ip <= ip + 1;
          
          // Null byte halts machine
          8'h00: state <= Halt;

          default: ip <= ip + 1;
        endcase
      
      // TODO: some issue with loops

      // Seek forward to the matching ], ending with ip on the instruction after the ]
      SeekForward: begin
        case (instruction)
          "[": depth <= depth + 1;
          "]":
            if (depth == 0)
              state <= Exec;
            else
              depth <= depth - 1;
          8'h00: state <= Halt;
          default: ;
        endcase
        ip <= ip + 1;
      end

      // Seek backward to the matching [, ending with ip on the instruction after the [
      SeekBackward: begin
        case (instruction)
          "[":
            if (depth == 0) begin
              state <= Exec;
              ip <= ip + 1;
            end
            else begin
              depth <= depth - 1;
              ip <= ip - 1;
            end
          "]": begin
            depth <= depth + 1;
            ip <= ip - 1;
          end
          8'h00: state <= Halt;
          default: ip <= ip - 1;
        endcase
      end

      Halt: ; // do nothing, machine is halted

      // Clear all memory, then go to Exec with cursor at cell 0
      // Actual memory writing occurs in the always_comb block
      Clear: begin
        if (cursor == (1<<DATA_ADDR_SIZE)-1)
          State <= Exec;
        cursor <= cursor + 1;
      end
    endcase
  end

  always_comb begin
    write_val = '0;
    out = '0;
    write_enable = 0;
    out_enable = 0;

    case (state)
      Exec: case (instruction)
        "+": begin
          write_val = read_val + 1;
          write_enable = 1;
        end
        "-": begin
          write_val = read_val - 1;
          write_enable = 1;
        end
        ".": begin
          out = read_val;
          out_enable = 1;
        end
        ",": begin
          write_val = in; // TODO: wait for ready
          write_enable = 1;
        end
        default: ;
      endcase
      
      Clear: begin
        write_val = '0;
        write_enable = 1;
      end

      default: ;
    endcase

  assign halted = (state == Halt);

endmodule