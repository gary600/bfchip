SV2V = sv2v
YOSYS = yosys
YOSYS_OPTS = -q
VERILATOR = verilator
VERILATOR_OPTS = 
CC = g++
CC_OPTS = -I$(shell $(YOSYS)-config --datdir)/include --std=c++17

SV_FILES = $(wildcard *.sv)
C_FILES = $(wildcard *.cpp)

.PHONY: all clean
all: sim

clean:
	rm -f *.o *.v rtl.cpp rtl.h sim

all.v: $(SV_FILES)
	$(SV2V) -w all.v $(SV_FILES)

verilated.cpp: $(SV_FILES)
	$(VERILATOR) --cc -j 0 $(SV_FILES) -o

define RTL_SCRIPT
	read_verilog all.v; \
	proc; \
	opt; \
	write_cxxrtl -header rtl.cpp;
endef
rtl.cpp: all.v
	$(YOSYS) $(YOSYS_OPTS) -p "$(RTL_SCRIPT)"

%.o: %.cpp
	$(CC) $(CC_OPTS) -o $@ -c $<

sim: rtl.o sim.o
	$(CC) $(CC_OPTS) -o sim rtl.o sim.o