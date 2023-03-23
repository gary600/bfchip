`default_nettype none

module BF #(
  parameter PROG_ADDR_SIZE = 16,
  parameter DATA_ADDR_SIZE = 16
)(
  output logic [PROG_ADDR_SIZE-1:0] ip, // Instruction pointer
  input logic [7:0] instruction, // Current instruction

  output logic [DATA_ADDR_SIZE-1:0] cursor, // Data pointer
  input logic [7:0] read_val, // The value currently at the cursor
  output logic [7:0] write_val, // The value to write to the cursor
  output logic write_enable, // On the next clock pulse, write

  output logic [7:0] out, // The value being output
  output logic out_enable, // On the next clock pulse, the output is valid

  input logic [7:0] in, // The value of the next input byte
  input logic in_valid, // The input byte is valid
  output logic in_reading, // On the next clock pulse, the processor has taken the input

  output logic halted, // The processor is halted
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
    // wait for in_valid to be 1, read value, and go back to Exec
    WaitInput,
    // do nothing (execution finished)
    Halt
  } state;
  // Loop depth, for matching up brackets
  logic [15:0] depth;

  always_ff @(posedge clock, posedge reset) begin
    if (reset) begin
      ip <= '0;
      cursor <= '0;
      
      state <= Exec;
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

          // logic for { + - . } handled by the always_comb
          "+", "-", ".": ip <= ip + 1;

          // If input is queued, then stay in Exec, otherwise wait
          ",": if (in_valid)
            ip <= ip + 1;
          else
            state <= WaitInput;

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

      // Waiting for input: if input is ready, then go back to Exec and go to next instruction
      // otherwise, keep waiting
      WaitInput: if (in_valid) begin
        state <= Exec;
        ip <= ip + 1;
      end

      Halt: ; // do nothing, machine is halted
    endcase
  end

  always_comb begin
    write_val = '0;
    out = '0;
    write_enable = 0;
    out_enable = 0;
    in_reading = 0;

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
        ",": if (in_valid) begin
          write_val = in;
          write_enable = 1;
          in_reading = 1;
        end
        default: ;
      endcase

      WaitInput: if (in_valid) begin
        write_val = in;
        write_enable = 1;
        in_reading = 1;
      end
      
      default: ;
    endcase
  end

  assign halted = (state == Halt);

endmodule