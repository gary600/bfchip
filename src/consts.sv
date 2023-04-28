`default_nettype none

typedef enum logic [2:0] {
  BusNone       = 3'b000,
  BusReadProg   = 3'b010,
  BusReadData   = 3'b100,
  BusWriteData  = 3'b101,
  BusReadIo     = 3'b110,
  BusWriteIo    = 3'b111
} BusOp;

typedef enum logic [1:0] {
  AddrNone,
  AddrPc,
  AddrCursor
} AddrSrc;

typedef enum logic [1:0] {
  ValNone,
  ValAcc,
  ValAccInc,
  ValAccDec
} ValSrc;

typedef enum logic [1:0] {
  PcKeep,
  PcInc,
  PcDec
} PcOp;

typedef enum logic [1:0] {
  CursorKeep,
  CursorInc,
  CursorDec
} CursorOp;

typedef enum logic {
  AccKeep,
  AccLoad
} AccOp;

typedef enum logic [1:0] {
  DepthKeep,
  DepthClear,
  DepthInc,
  DepthDec
} DepthOp;

typedef struct packed {
  BusOp bus_op;
  AddrSrc addr_src;
  ValSrc val_src;
  PcOp pc_op;
  CursorOp cursor_op;
  AccOp acc_op;
  DepthOp depth_op;
} Ucode;

function int max(int a, int b);
  max = (a > b) ? a : b;
endfunction