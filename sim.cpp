#include <iostream>
#include <stdio.h>
#include <stdint.h>

#include "rtl.h"

// const char* program = ">+>++>+++>++++>[-]+[]";
// const char program[] = "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++.[-][++++]";
const char program[] = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";
const uint8_t program_size = (uint8_t) sizeof(program);

uint8_t opcode(char instr) {
    switch (instr) {
        case '>': return 0;
        case '<': return 1;
        case '+': return 2;
        case '-': return 3;
        case '.': return 4;
        case ',': return 5;
        case '[': return 6;
        case ']': return 7;
    }
    return 0;
}

int main() {
    printf("sim starting\n");

    cxxrtl_design::p_BF bf;
    bf.p_clock.set<bool>(false);

    // Load program into
    printf("loading program\n");
    for (uint8_t addr = 0; addr < program_size-1; addr++) {
        bf.p_instr__addr.set<uint8_t>(addr);
        bf.p_instr__in.set<uint8_t>(opcode(program[addr]));
        bf.p_instr__write.set<bool>(true);
        bf.step();
        bf.p_instr__write.set<bool>(false);
        bf.step();
    }
    bf.p_instr__addr.set<uint8_t>(0);
    bf.p_instr__in.set<uint8_t>(0);

    // Verify program
    printf("verifying program:\n");
    for (size_t addr = 0; addr < bf.memory_p_prog.depth; addr++) {
        std::cout << bf.memory_p_prog[addr].str() << ' ';
    }
    printf("\n");

    // Run simulation
    printf("running simulation\n");
    uint8_t prev_output = 0;
    bf.p_in.set<uint8_t>(0);
    while (true) {
        uint8_t ip = bf.p_ip.get<uint8_t>();
        uint8_t current_instr = bf.p_current__instr.get<uint8_t>();
        uint8_t cursor = bf.p_cursor.get<uint8_t>();
        uint8_t memval = bf.p_current__cell.get<uint8_t>();
        uint8_t state = bf.p_state.get<uint8_t>();
        uint8_t depth = bf.p_depth.get<uint8_t>();
        printf("state: %hhx, depth: %hhx, ip: %hhx, instruction: %hhx, cusor: %hhx, val: %hhx\n",
                state, depth, ip, current_instr, cursor, memval);
        
        // Clock
        bf.p_clock.set<bool>(true);
        bf.step();
        bf.p_clock.set<bool>(false);
        bf.step();

        uint8_t output = bf.p_out.get<uint8_t>();
        if (output != prev_output) {
            printf("%c", (char)output);
            prev_output = output;
        }
    }
    printf("\n");

    return 0;
}