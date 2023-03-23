import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from itertools import zip_longest
import os

def dbg(*args, **kwargs):
    if "BF_DEBUG" in os.environ:
        print(*args, **kwargs)

def write_mem(mem, val):
    if isinstance(val, str):
        val = val.encode("utf-8")
    for a, b in zip_longest(mem, val):
        if a is None:
            break
        if b is None:
            b = 0
        a.value = b

async def init_bf(dut, prog):
    # Load program and clear memory
    write_mem(dut.prog.mem, prog)
    write_mem(dut.data.mem, b"")

    # Reset DUT
    dut.clock.value = 0
    dut.reset.value = 1
    await Timer(1, units="ns")
    dut.reset.value = 0
    await Timer(1, units="ns")
    
    # Start clock
    await cocotb.start(gen_clock(dut))

async def assert_output_and_terminate(dut, correct, timeout=100_000_000):
    if isinstance(correct, str):
        correct = correct.encode("utf-8")
    out = b""
    for _ in range(timeout):
        await RisingEdge(dut.clock)
        dbg(f"({dut.ip.value.integer})={dut.instruction.value.buff} : [{dut.cursor.value.integer}]={dut.read_val.value.integer}", end="\r")
        await FallingEdge(dut.clock)
        if dut.out_enable.value.integer:
            out += dut.out.value.buff
        if dut.halted.value.integer:
            assert(out == correct)
            dbg()
            return
    raise AssertionError("Test did not finish within timeout")


async def gen_clock(dut):
    dut.clock.value = 0
    while (True):
        await Timer(0.5, units="us")
        dut.clock.value = 1
        await Timer(0.5, units="us")
        dut.clock.value = 0


@cocotb.test()
async def hello_world(dut):
    await init_bf(
        dut,
        "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    )

    await assert_output_and_terminate(dut, "Hello World!\n")

# Takes too long to run
@cocotb.test(skip=True)
async def cristofani_arraysize(dut):
    await init_bf(dut, "++++[>++++++<-]>[>+++++>+++++++<<-]>>++++<[[>[[>>+<<-]<]>>>-]>-[>+>+<<-]>]+++++[>+++++++<<++>-]>.<<.")
    await assert_output_and_terminate(dut, "#\n")

# Takes around 10 minutes to run
@cocotb.test(skip=True)
async def bosman_quine(dut):
    await init_bf(dut, "-->+++>+>+>+>+++++>++>++>->+++>++>+>>>>>>>>>>>>>>>>->++++>>>>->+++>+++>+++>+++>+++>+++>+>+>>>->->>++++>+>>>>->>++++>+>+>>->->++>++>++>++++>+>++>->++>++++>+>+>++>++>->->++>++>++++>+>+>>>>>->>->>++++>++>++>++++>>>>>->>>>>+++>->++++>->->->+++>>>+>+>+++>+>++++>>+++>->>>>>->>>++++>++>++>+>+++>->++++>>->->+++>+>+++>+>++++>>>+++>->++++>>->->++>++++>++>++++>>++[-[->>+[>]++[<]<]>>+[>]<--[++>++++>]+[<]<<++]>>>[>]++++>++++[--[+>+>++++<<[-->>--<<[->-<[--->>+<<[+>+++<[+>>++<<]]]]]]>+++[>+++++++++++++++<-]>--.<<<]")
    await assert_output_and_terminate(dut, "-->+++>+>+>+>+++++>++>++>->+++>++>+>>>>>>>>>>>>>>>>->++++>>>>->+++>+++>+++>+++>+++>+++>+>+>>>->->>++++>+>>>>->>++++>+>+>>->->++>++>++>++++>+>++>->++>++++>+>+>++>++>->->++>++>++++>+>+>>>>>->>->>++++>++>++>++++>>>>>->>>>>+++>->++++>->->->+++>>>+>+>+++>+>++++>>+++>->>>>>->>>++++>++>++>+>+++>->++++>>->->+++>+>+++>+>++++>>>+++>->++++>>->->++>++++>++>++++>>++[-[->>+[>]++[<]<]>>+[>]<--[++>++++>]+[<]<<++]>>>[>]++++>++++[--[+>+>++++<<[-->>--<<[->-<[--->>+<<[+>+++<[+>>++<<]]]]]]>+++[>+++++++++++++++<-]>--.<<<]")

@cocotb.test()
async def cristofani_h(dut):
    await init_bf(dut, """[]++++++++++[>>+>+>++++++[<<+<+++>>>-]<<<<-]
"A*$";?@![#>>+<<]>[>>]<<<<[>++<[-]]>.>.""")
    await assert_output_and_terminate(dut, "H\n")