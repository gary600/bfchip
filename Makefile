SV2V = sv2v
YOSYS = yosys
YOSYS_OPTS = -q
CC = g++
CC_OPTS = -I$(shell $(YOSYS)-config --datdir)/include --std=c++17

SV_FILES = $(wildcard *.sv)
V_FILES = $(SV_FILES:.sv=.v)
C_FILES = $(wildcard *.cpp)

.PHONY: all clean
all: sim

clean:
	rm -f *.o *.v rtl.cpp rtl.h sim

%.v: %.sv
	$(SV2V) -w $@ $<

define RTL_SCRIPT
	read_verilog bfchip.v; \
	proc; \
	opt; \
	write_cxxrtl -header rtl.cpp;
endef
rtl.cpp: bfchip.v
	$(YOSYS) $(YOSYS_OPTS) -p "$(RTL_SCRIPT)"

%.o: %.cpp
	$(CC) $(CC_OPTS) -o $@ -c $<

sim: rtl.o sim.o
	$(CC) $(CC_OPTS) -o sim rtl.o sim.o