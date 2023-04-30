`default_nettype none

module BF #(
  parameter DATA_ADDR_WIDTH = 15,
  parameter PROG_ADDR_WIDTH = 15,
  parameter DATA_WIDTH = 8,
  parameter DEPTH_WIDTH = 12,
  parameter ADDR_WIDTH = max(DATA_ADDR_WIDTH, PROG_ADDR_WIDTH),
  parameter BUS_WIDTH = max(DATA_WIDTH, 8)
)(
  // Bus interface
  output logic [ADDR_WIDTH-1:0] addr,
  output logic [BUS_WIDTH-1:0] val_out,
  input  logic [BUS_WIDTH-1:0] val_in,

  // Bus control
  output BusOp bus_op,

  // Interpreter control
  output logic halted,
  input  logic clock,
  input  logic reset,
  input  logic enable
);

  // Program memory interface
  logic [PROG_ADDR_WIDTH-1:0] pc;

  // Data memory interface
  logic [DATA_ADDR_WIDTH-1:0] cursor;
  logic [DATA_WIDTH-1:0] acc;

  // Loop depth register
  logic [DEPTH_WIDTH-1:0] depth;
  
  // Current microcode instruction
  Ucode ucode;

  // Bus operation
  assign bus_op = ucode.bus_op;

  // Address source
  always_comb case (ucode.addr_src)
    AddrNone: addr = '0;
    AddrPc: addr = pc;
    AddrCursor: addr = cursor;
    default: addr = '0;
  endcase 

  // Bus val source
  always_comb case (ucode.val_src)
    ValNone: val_out = '0;
    ValAcc: val_out = acc;
    ValAccInc: val_out = acc + 1;
    ValAccDec: val_out = acc - 1;
    default: val_out = '0;
  endcase

  // Sequential logic
  always_ff @(posedge clock, posedge reset)
    if (reset) begin
      pc <= '0;
      cursor <= '0;
      acc <= '0;
      depth <= '0;

      state <= Fetch;
    end
    else if (enable) begin
      case (ucode.pc_op)
        PcInc: pc <= pc + 1;
        PcDec: pc <= pc - 1;
        default: ;
      endcase

      case (ucode.cursor_op)
        CursorInc: cursor <= cursor + 1;
        CursorDec: cursor <= cursor - 1;
        default: ;
      endcase

      case (ucode.acc_op)
        AccLoad: acc <= val_in;
        default: ;
      endcase

      case (ucode.depth_op)
        DepthClear: depth <= '0;
        DepthInc: depth <= depth + 1;
        DepthDec: depth <= depth - 1;
        default: ;
      endcase

      state <= next_state;
    end

  enum logic [5:0] {
    Fetch,
    Decode,
    Halt,

    IncFetch,
    IncLoad,
    IncStore,

    DecFetch,
    DecLoad,
    DecStore,

    Right,

    Left,

    PrintFetch,
    PrintLoad,
    PrintStore,

    ReadFetch,
    ReadLoad,
    ReadStore,

    BrzFetchVal,
    BrzDecodeVal,
    BrzFetchInstr,
    BrzDecodeInstr,
    BrzInc,
    BrzDec,

    BrnzFetchVal,
    BrnzDecodeVal,
    BrnzPcDec1,
    BrnzPcDec2,
    BrnzFetchInstr,
    BrnzDecodeInstr,
    BrnzInc,
    BrnzDec,
    BrnzPcInc1,
    BrnzPcInc2
  } state, next_state;

  always_comb begin
    // default values
    halted = 0;
    next_state = Halt;

    case (state)
      /// Misc states ///
      // Request instruction
      Fetch: begin
        ucode = {BusReadProg, AddrPc, ValNone, PcInc, CursorKeep, AccKeep, DepthClear};
        next_state = Decode;
      end
      // Receive instruction and decode
      Decode: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        case (val_in)
          "+": next_state = IncFetch;     // "Inc"
          "-": next_state = DecFetch;     // "Dec"
          ">": next_state = Right;        // "Right"
          "<": next_state = Left;         // "Left"
          ".": next_state = PrintFetch;   // "Print"
          ",": next_state = ReadFetch;    // "Read"
          "[": next_state = BrzFetchVal;  // "Brz"
          "]": next_state = BrnzFetchVal; // "Brnz"
          8'h00: next_state = Halt;
          default: next_state = Fetch; // "comments"
        endcase
      end
      // Do nothing forever
      Halt: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = Halt;
        halted = 1;
      end

      /// Instruction "+" (Inc) ///
      // Request cell value
      IncFetch: begin
        ucode = {BusReadData, AddrCursor, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = IncLoad;
      end
      // Load cell value into accumulator
      IncLoad: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccLoad, DepthClear};
        next_state = IncStore;
      end
      // Write modified value back into cell
      IncStore: begin
        ucode = {BusWriteData, AddrCursor, ValAccInc, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = Fetch;
      end

      /// Instruction "-" (Dec) ///
      // Request cell value
      DecFetch: begin
        ucode = {BusReadData, AddrCursor, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = DecLoad;
      end
      // Load cell value into accumulator
      DecLoad: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccLoad, DepthClear};
        next_state = DecStore;
      end
      // Write modified value back into cell
      DecStore: begin
        ucode = {BusWriteData, AddrCursor, ValAccDec, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = Fetch;
      end
      
      /// Instruction ">" (Right) ///
      Right: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorInc, AccKeep, DepthClear};
        next_state = Fetch;
      end

      /// Instruction "<" (Left) ///
      Left: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorDec, AccKeep, DepthClear};
        next_state = Fetch;
      end

      /// Instruction "." (Print) ///
      // Request cell value
      PrintFetch: begin
        ucode = {BusReadData, AddrCursor, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = PrintLoad;
      end
      // Load cell value into accumulator
      PrintLoad: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccLoad, DepthClear};
        next_state = PrintStore;
      end
      // Write cell value to IO
      PrintStore: begin
        ucode = {BusWriteIo, AddrNone, ValAcc, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = Fetch;
      end
      
      /// Instruction "," (Read) ///
      // Request value from IO
      ReadFetch: begin
        ucode = {BusReadIo, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = ReadLoad;
      end
      // Load value into accumulator
      ReadLoad: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccLoad, DepthClear};
        next_state = ReadStore;
      end
      // Write value into cell
      ReadStore: begin
        ucode = {BusWriteData, AddrCursor, ValAcc, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = Fetch;
      end

      /// Instruction "[" (Brz) ///
      // Request cell value to check
      BrzFetchVal: begin
        ucode = {BusReadData, AddrCursor, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = BrzDecodeVal;
      end
      // Branch forward if zero
      BrzDecodeVal: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        if (val_in == '0)
          next_state = BrzFetchInstr;
        else
          next_state = Fetch;
      end
      // Request instruction to check
      BrzFetchInstr: begin
        ucode = {BusReadProg, AddrPc, ValNone, PcInc, CursorKeep, AccKeep, DepthKeep};
        next_state = BrzDecodeInstr;
      end
      // Receive instruction and decode
      // TODO: optimize? if I make it Mealy then this is way simpler
      BrzDecodeInstr: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthKeep};
        case (val_in)
          "[": next_state = BrzInc;
          "]":
            if (depth == '0)
              next_state = Fetch;
            else
              next_state = BrzDec;
          8'h00: next_state = Halt;
          default: next_state = BrzFetchInstr;
        endcase
      end
      // Increment depth
      BrzInc: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthInc};
        next_state = BrzFetchInstr;
      end
      // Decrement depth
      BrzDec: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthDec};
        next_state = BrzFetchInstr;
      end
      
      /// Instruction "]" (Brnz) ///
      // Request cell value to check
      BrnzFetchVal: begin
        ucode = {BusReadData, AddrCursor, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        next_state = BrnzDecodeVal;
      end
      // Branch forward if zero
      BrnzDecodeVal: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthClear};
        if (val_in == '0)
          next_state = Fetch;
        else
          next_state = BrnzPcDec1;
      end
      // Move PC to instruction before the ]
      BrnzPcDec1: begin
        ucode = {BusNone, AddrNone, ValNone, PcDec, CursorKeep, AccKeep, DepthClear};
        next_state = BrnzPcDec2;
      end
      BrnzPcDec2: begin
        ucode = {BusNone, AddrNone, ValNone, PcDec, CursorKeep, AccKeep, DepthClear};
        next_state = BrnzFetchInstr;
      end
      // Request instruction to check
      BrnzFetchInstr: begin
        ucode = {BusReadProg, AddrPc, ValNone, PcDec, CursorKeep, AccKeep, DepthKeep};
        next_state = BrnzDecodeInstr;
      end
      // Receive instruction and decode
      BrnzDecodeInstr: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthKeep};
        case (val_in)
          "[":
            if (depth == '0)
              next_state = BrnzPcInc1;
            else
              next_state = BrnzDec;
          "]": next_state = BrnzInc;
          8'h00: next_state = Halt;
          default: next_state = BrnzFetchInstr;
        endcase
      end
      // Increment depth
      BrnzInc: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthInc};
        next_state = BrnzFetchInstr;
      end
      // Decrement depth
      BrnzDec: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthDec};
        next_state = BrnzFetchInstr;
      end
      // Move PC to instruction after the [
      BrnzPcInc1: begin
        ucode = {BusNone, AddrNone, ValNone, PcInc, CursorKeep, AccKeep, DepthClear};
        next_state = BrnzPcInc2;
      end
      BrnzPcInc2: begin
        ucode = {BusNone, AddrNone, ValNone, PcInc, CursorKeep, AccKeep, DepthClear};
        next_state = Fetch;
      end
    
      // should be unreachable
      default: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthKeep};
        next_state = Halt;
      end

    endcase
  end

endmodule