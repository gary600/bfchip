#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "rtl.h"

#define PROG_ADDR_TYPE uint16_t
#define PROG_ADDR_PLACEHOLDER "04h"

#define DATA_ADDR_TYPE uint16_t
#define DATA_ADDR_PLACEHOLDER "04h"


int main(int argc, char** argv) {
    if (argc <= 1) {
        printf("must supply BF program file on command line\n");
        return 1;
    }
    bool debug = false;
    if (argc >= 3 && strcmp(argv[2], "debug") == 0) debug = true;

    // Create machine
    cxxrtl_design::p_SimTop machine;
    machine.p_clock.set<bool>(false);
    machine.p_reset.set<bool>(false);
    machine.p_in.set<uint8_t>(0);
    machine.p_in__clock.set<bool>(false);

    // Read program into memory
    size_t program_index = 0;
    printf("Reading program:\n");
    FILE* program_file = fopen(argv[1], "r");
    if (program_file == nullptr) {
        perror("unable to open program file");
        return 1;
    }
    while (program_index < machine.memory_p_prog_2e_mem.depth - 1) {
        int prog_char = fgetc(program_file);
        if (prog_char == -1) {
            if (feof(program_file)) break;
            perror("failed to read from file");
            return 1;
        }
        printf("%c", (char)prog_char);
        machine.memory_p_prog_2e_mem[program_index].set<uint8_t>((uint8_t)prog_char);
        program_index++;
    }
    fclose(program_file);
    printf("\nRead %lu program bytes\n", program_index - 1);
    // Add null byte at the end so programs terminate
    machine.memory_p_prog_2e_mem[machine.memory_p_prog_2e_mem.depth - 1].set<uint8_t>(0);

    // Start simulation
    printf("Sim starting:\n");
    machine.p_reset.set<bool>(true);
    machine.step();
    machine.p_reset.set<bool>(false);
    machine.step();

    // Run simulation
    uint32_t cycle = 0;
    while (!machine.p_halted.get<bool>()) {
        uint8_t instr = machine.p_instruction.get<uint8_t>();
        uint8_t val = machine.p_read__val.get<uint8_t>();
        if (debug)
            printf("state %02hhx (depth %04hx): program[%" PROG_ADDR_PLACEHOLDER "x]=%02hhx ('%c'), mem[%" DATA_ADDR_PLACEHOLDER "x]=%02hhx ('%c')\n",
                machine.p_bf_2e_state.get<uint8_t>(),
                machine.p_bf_2e_depth.get<uint16_t>(),
                machine.p_ip.get<PROG_ADDR_TYPE>(),
                instr,
                isprint(instr) ? (char) instr : ' ',
                machine.p_cursor.get<DATA_ADDR_TYPE>(),
                val,
                isprint(val) ? (char)val : ' ');
        
        // Rising edge
        machine.p_clock.set<bool>(true);
        machine.step();

        // If the output has been clocked then print the output char
        if (machine.p_out__enable.get<bool>())
            printf("%c", (char)machine.p_out.get<uint8_t>());

        // Falling edge
        machine.p_clock.set<bool>(false);
        machine.step();

        cycle++;
    }
    printf("\nHalted. Ran %u cycles\n", cycle-1);

    return 0;
}