import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.clock import Clock
import os

def dbg(*args, **kwargs):
    if "BF_DEBUG" in os.environ:
        print(*args, **kwargs)

async def test_program(dut, prog, stdin=b"", stdout=b"", failread=None):
    if isinstance(prog, str):
        prog = prog.encode("ascii")
    if isinstance(stdin, str):
        stdin = stdin.encode("ascii")
    if isinstance(stdout, str):
        stdout = stdout.encode("ascii")
    if isinstance(stdout, str):
        failread = failread.encode("ascii")
    stdin = bytearray(stdin)

    actual_stdout = bytearray()
    
    memory = [0] * 65536

    # Reset and initial values
    dut.clock.value = 0
    dut.val_in.value = 0
    dut.reset.value = 1
    await Timer(10, "ns")
    dut.reset.value = 0
    dut.enable.value = 1
    await Timer(10, "ns")

    entered_loop = False
    while not dut.halted.value.integer:
        entered_loop = True
        dut.clock.value = 1
        # Get values right before they vanish
        bus_op = dut.bus_op.value
        addr = dut.addr.value
        val_out = dut.val_out.value
        await Timer(10, "ns")
        dut.clock.value = 0
        if bus_op == 0b010: # BusReadProg
            if addr.integer < len(prog):
                dut.val_in.value = prog[addr.integer]
            else:
                dut.val_in.value = 0
            dbg("reading program")
        elif bus_op == 0b100: # BusReadData
            dut.val_in.value = memory[addr.integer]
            dbg("reading data")
        elif bus_op == 0b101: # BusWriteData
            memory[addr.integer] = val_out.integer
            dbg("writing data")
        elif bus_op == 0b110: # BusReadIo
            if len(stdin) > 0:
                char = stdin.pop(0)
            elif failread is None:
                raise ValueError("reading on empty input is failure")
            else:
                char = failread
            dut.val_in.value = char
            dbg("reading io")
        elif bus_op == 0b111: # BusWriteIo
            actual_stdout.append(val_out.integer)
            dbg("writing io")
            
        await Timer(10, "ns")
    
    assert(entered_loop)
    dbg(stdout, actual_stdout)
    assert(stdout == actual_stdout)

@cocotb.test()
async def hello_world(dut):
    await test_program(
        dut,
        "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.",
        "",
        "Hello World!\n"
    )

@cocotb.test()
async def cristofani_word_count(dut):
    wc_prog = """
>>>+>>>>>+>>+>>+[<<],[
    -[-[-[-[-[-[-[-[<+>-[>+<-[>-<-[-[-[<++[<++++++>-]<
        [>>[-<]<[>]<-]>>[<+>-[<->[-]]]]]]]]]]]]]]]]
    <[-<<[-]+>]<<[>>>>>>+<<<<<<-]>[>]>>>>>>>+>[
        <+[
            >+++++++++<-[>-<-]++>[<+++++++>-[<->-]+[+>>>>>>]]
            <[>+<-]>[>>>>>++>[-]]+<
        ]>[-<<<<<<]>>>>
    ],
]+<++>>>[[+++++>>>>>>]<+>+[[<++++++++>-]<.<<<<<]>>>>>>>>]
[Counts lines, words, bytes. Assumes no-change-on-EOF or EOF->0.
Daniel B Cristofani (cristofdathevanetdotcom)
http://www.hevanet.com/cristofd/brainfuck/]"""
    await test_program(
        dut,
        wc_prog,
        "example 123\nasdf",
        "\t1\t3\t16\n",
        failread=0
    )

# Takes too long to run
@cocotb.test(skip=True)
async def bosman_quine(dut):
    prog = "-->+++>+>+>+>+++++>++>++>->+++>++>+>>>>>>>>>>>>>>>>->++++>>>>->+++>+++>+++>+++>+++>+++>+>+>>>->->>++++>+>>>>->>++++>+>+>>->->++>++>++>++++>+>++>->++>++++>+>+>++>++>->->++>++>++++>+>+>>>>>->>->>++++>++>++>++++>>>>>->>>>>+++>->++++>->->->+++>>>+>+>+++>+>++++>>+++>->>>>>->>>++++>++>++>+>+++>->++++>>->->+++>+>+++>+>++++>>>+++>->++++>>->->++>++++>++>++++>>++[-[->>+[>]++[<]<]>>+[>]<--[++>++++>]+[<]<<++]>>>[>]++++>++++[--[+>+>++++<<[-->>--<<[->-<[--->>+<<[+>+++<[+>>++<<]]]]]]>+++[>+++++++++++++++<-]>--.<<<]"
    await test_program(dut, prog, "", prog)

# "Tests for several obscure problems"
@cocotb.test()
async def cristofani_h(dut):
    await test_program(
        dut,
        """[]++++++++++[>>+>+>++++++[<<+<+++>>>-]<<<<-]
"A*$";?@![#>>+<<]>[>>]<<<<[>++<[-]]>.>.""",
        "",
        "H\n"
    )

@cocotb.test()
async def cristofani_rot13(dut):
    await test_program(
        dut,
        """,
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>++++++++++++++<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>>+++++[<----->-]<<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>++++++++++++++<-
[>+<-[>+<-[>+<-[>+<-[>+<-
[>++++++++++++++<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>>+++++[<----->-]<<-
[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-
[>++++++++++++++<-
[>+<-]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]
]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]>.[-]<,]

of course any function char f(char) can be made easily on the same principle

[Daniel B Cristofani (cristofdathevanetdotcom)
http://www.hevanet.com/cristofd/brainfuck/]
""",
        "This is aTest of the rot13",
        "Guvf vf nGrfg bs gur ebg13",
        failread=0
    )
