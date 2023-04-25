`default_nettype none

typedef enum logic [3:0] {
  BusNone,
  BusReadProg,
  BusReadData,
  BusWriteData,
  BusReadIo,
  BusWriteIo
} BusOp;

typedef enum logic [1:0] {
  AddrNone,
  AddrPc,
  AddrCursor,
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

typedef enum logic {
  CursorKeep,
  CursorInc,
  CursorDec
} CursorOp;

typedef enum logic {
  AccKeep,
  AccLoad
} AccOp;

typedef enum loigc {
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