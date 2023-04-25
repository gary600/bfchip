`default_nettype none

module BF #(
  parameter ADDR_WIDTH = 15,
  parameter DATA_WIDTH = 8,
  parameter DEPTH_WIDTH = 12
)(
  // Bus interface
  output logic [ADDR_WIDTH-1:0] addr,
  output logic [DATA_WIDTH-1:0] val_out,
  input  logic [DATA_WIDTH-1:0] val_in,
  // input  logic valid,

  // Bus control
  output BusOp bus_op,

  // Interpreter control
  output logic halted,
  input  logic clock,
  input  logic reset,
  input  logic enable
);

  // Program memory interface
  logic [ADDR_WIDTH-1:0] pc;

  // Data memory interface
  logic [ADDR_WIDTH-1:0] cursor;
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

  // Register controls
  always_ff @(posedge clock)
    if ()

  enum logic [4:0] {
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
    ReadStore
  } state, next_state;


  always_comb begin
    halted = 0;

    case (state)
      /// Misc states ///
      // Request instruction
      Fetch: begin
        ucode = {ReadProg, AddrPc, ValNone, PcInc, AccKeep, DepthClear};
        next_state = Decode;
      end
      // Receive instruction and decode
      Decode: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, AccKeep, DepthClear}
        case (val_in)
          "+": next_state = IncFetch;     // "Inc"
          "-": next_state = DecFetch;     // "Dec"
          ">": next_state = Right;        // "Right"
          "<": next_state = Left;         // "Left"
          ".": next_state = PrintFetch;   // "Print"
          ",": next_state = ReadFetch;    // "Read"
          "[": next_state = BrzFetch;     // "Brz"
          "]": next_state = BrnzFetch;    // "Brnz"
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
      // Request instruction to check
      BrzFetch: begin
        ucode = {BusReadProg, AddrPc, ValNone, PcInc, CursorKeep, AccKeep, DepthKeep};
        next_state = BrzDecode;
      end
      // Receive instruction and decode
      // TODO: optimize? if I make it Mealy then this is way simpler
      BrzDecode: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthKeep};
        case (val_in)
          "[": next_state = BrzInc;
          "]": next_state = (depth == '0) ? Fetch : BrzDec;
          8'h00: next_state = Halt;
          default: next_state = BrzFetch;
        endcase
      end
      // Increment depth
      BrzInc: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthInc};
        next_state = BrzFetch;
      end
      // Decrement depth
      BrzDec: begin
        ucode = {BusNone, AddrNone, ValNone, PcKeep, CursorKeep, AccKeep, DepthDec};
        next_state = BrzFetch;
      end

    endcase
  end

endmodule