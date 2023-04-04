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

async def assert_bf(dut, stdout, stdin=b"", timeout=100_000_000):
    if isinstance(stdout, str):
        stdout = stdout.encode("utf-8")
    if isinstance(stdin, str):
        stdin = stdin.encode("utf-8")

    out = b""

    # Set up initial input
    dut.in_valid.value = 1
    if stdin:
        dut.in_val.value = stdin[0]
        stdin = stdin[1:]
    else:
        dut.in_val.value = 0

    for _ in range(timeout):
        await RisingEdge(dut.clock)
        dbg(f"({dut.ip.value.integer})={dut.instr.value.buff} : [{dut.cursor.value.integer}]={dut.read_val.value.integer}", end="\r")
        
        # Retrieve output
        if dut.out_enable.value.integer:
            dbg(f"printing value: {dut.out_val.value}")
            out += dut.out_val.value.buff
        
        # Update input
        if (dut.in_reading.value.integer):
            dbg(f"reading value: {dut.in_val.value}")
            if stdin:
                dut.in_val.value = stdin[0]
                stdin = stdin[1:]
            else:
                dut.in_val.value = 0

        # Exit if halted
        if dut.halted.value.integer:
            assert(out == stdout)
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

    await assert_bf(dut, "Hello World!\n")

# Takes too long to run
@cocotb.test(skip=True)
async def cristofani_arraysize(dut):
    await init_bf(dut, "++++[>++++++<-]>[>+++++>+++++++<<-]>>++++<[[>[[>>+<<-]<]>>>-]>-[>+>+<<-]>]+++++[>+++++++<<++>-]>.<<.")
    await assert_bf(dut, "#\n")

# Takes around 10 minutes to run
@cocotb.test(skip=True)
async def bosman_quine(dut):
    quine = "-->+++>+>+>+>+++++>++>++>->+++>++>+>>>>>>>>>>>>>>>>->++++>>>>->+++>+++>+++>+++>+++>+++>+>+>>>->->>++++>+>>>>->>++++>+>+>>->->++>++>++>++++>+>++>->++>++++>+>+>++>++>->->++>++>++++>+>+>>>>>->>->>++++>++>++>++++>>>>>->>>>>+++>->++++>->->->+++>>>+>+>+++>+>++++>>+++>->>>>>->>>++++>++>++>+>+++>->++++>>->->+++>+>+++>+>++++>>>+++>->++++>>->->++>++++>++>++++>>++[-[->>+[>]++[<]<]>>+[>]<--[++>++++>]+[<]<<++]>>>[>]++++>++++[--[+>+>++++<<[-->>--<<[->-<[--->>+<<[+>+++<[+>>++<<]]]]]]>+++[>+++++++++++++++<-]>--.<<<]"
    await init_bf(dut, quine)
    await assert_bf(dut, quine)

@cocotb.test()
async def cristofani_h(dut):
    await init_bf(dut, """[]++++++++++[>>+>+>++++++[<<+<+++>>>-]<<<<-]
"A*$";?@![#>>+<<]>[>>]<<<<[>++<[-]]>.>.""")
    await assert_bf(dut, "H\n")

@cocotb.test()
async def cristofani_input_test(dut):
    await init_bf(dut, ">,>+++++++++,>+++++++++++[<++++++<++++++<+>>>-]<<.>.<<-.>.>.<<.")
    await assert_bf(dut, "LB\nLB\n", stdin="\n")

# TODO: test does not terminate
@cocotb.test(skip=True)
async def self_hello_world(dut):
    await init_bf(dut, """>>>+[[-]>>[-]++>+>+++++++[<++++>>++<-]++>>+>+>+++++[>++>++++++<<-]+>>>,<++[[>[
->>]<[>>]<<-]<[<]<+>>[>]>[<+>-[[<+>-]>]<[[[-]<]++<-[<+++++++++>[<->-]>>]>>]]<<
]<]<[[<]>[[>]>>[>>]+[<<]<[<]<+>>-]>[>]+[->>]<<<<[[<<]<[<]+<<[+>+<<-[>-->+<<-[>
+<[>>+<<-]]]>[<+>-]<]++>>-->[>]>>[>>]]<<[>>+<[[<]<]>[[<<]<[<]+[-<+>>-[<<+>++>-
[<->[<<+>>-]]]<[>+<-]>]>[>]>]>[>>]>>]<<[>>+>>+>>]<<[->>>>>>>>]<<[>.>>>>>>>]<<[
>->>>>>]<<[>,>>>]<<[>+>]<<[+<<]<]""")
    await assert_bf(dut, "Hello World!", stdin="++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.!")