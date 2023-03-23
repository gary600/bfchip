BUILD_DIR ?= $(PWD)/build
SRC_DIR ?= $(PWD)/src

SV2V ?= sv2v

SV_FILES += $(wildcard $(SRC_DIR)/*.sv)

DIR_GUARD = mkdir -p $(@D)
export PYTHONDONTWRITEBYTECODE=1

.PHONY: all clean test
all: sim

test: $(BUILD_DIR)/all.v
	$(MAKE) --no-print-directory -f cocotb.mk

clean:
	rm -f *.o *.v rtl.cpp rtl.h sim

$(BUILD_DIR)/all.v: $(SV_FILES)
	$(DIR_GUARD)
	$(SV2V) -w $(BUILD_DIR)/all.v $(SV_FILES)
