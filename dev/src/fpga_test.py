# Runs the Hello World program on the FPGA

from interface import Chip

IoNone          = 0b000
IoOpcode        = 0b001
IoAddrHi        = 0b010
IoAddrLo        = 0b011
IoReadWrite     = 0b100
BusNone         = 0b000
BusReadProg     = 0b010
BusReadData     = 0b100
BusWriteData    = 0b101
BusReadIo       = 0b110
BusWriteIo      = 0b111

class Inputs:
  def __init__(self, chip):
    self.bus_in = 0
    self.op_done = 0
    self.enable = 0
    self.chip = chip

  def set(self):
    val = (self.enable << 9) | (self.op_done << 8) | self.bus_in
    self.chip.set_all_inputs(val)

  def __repr__(self):
    return f"bus_in={self.bus_in:08b}, " \
            "op_done={self.op_done:b}, enable={self.enable:b}"

class Outputs:
  def __init__(self, chip):
    self.bus_out = 0
    self.state = 0
    self.halted = 0
    self.chip = chip

  def get(self):
    out = self.chip.get_all_outputs()
    self.bus_out = out & 0x0FF
    self.state = (out & 0x700) >> 8
    self.halted = (out & 0x800) >> 11

  def __repr__(self):
    return f"bus_out={self.bus_out:08b}, "\
        "state={self.state:03b}, halted={self.halted:b}"


chip = Chip("/dev/ttyUSB1")
inputs = Inputs(chip)
outputs = Outputs(chip)

print("resetting")
chip.set_reset(1)
chip.step_clock()
chip.set_reset(0)

inputs.enable = 1
inputs.set()
outputs.get()

# pseudo-registers
opcode = 0
addr_hi = 0
addr_lo = 0

# memory
prog = bytearray(b"++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.")
data = bytearray(65536)
output = bytearray()

cycles = 0

while not outputs.halted:
  outputs.get()
  # print(outputs)
  if outputs.state == IoOpcode:
    opcode = outputs.bus_out
  elif outputs.state == IoAddrHi:
    addr_hi = outputs.bus_out
  elif outputs.state == IoAddrLo:
    addr_lo = outputs.bus_out
  elif outputs.state == IoReadWrite:
    addr = (addr_hi << 8) | addr_lo
    if opcode == BusReadProg:
      if addr >= len(prog):
        inputs.bus_in = 0
      else:
        inputs.bus_in = prog[addr]
      print(f"reading program [{addr:04x}]: {chr(inputs.bus_in)}")
    elif opcode == BusReadData:
      inputs.bus_in = data[addr]
      print(f"reading data    [{addr:04x}]: {inputs.bus_in}")
    elif opcode == BusWriteData:
      data[addr] = outputs.bus_out
      print(f"writing data    [{addr:04x}]: {outputs.bus_out}")
    elif opcode == BusReadIo:
      inputs.bus_in = 0 #TODO:
      print(f"reading io (unimplemented)")
    elif opcode == BusWriteIo:
      print(f"writing io                  : {chr(outputs.bus_out)}")
      output.append(outputs.bus_out)
    inputs.op_done = 1
    inputs.set()
  # print(inputs)
  chip.step_clock()
  cycles += 1

print(f"halted, ran {cycles} cycles. output: {output}")
