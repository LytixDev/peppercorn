COREMARK = ../third_party/coremark
BUILD    = ../build

CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -O2 -nostdlib -nostartfiles \
         -fno-builtin -fno-tree-loop-distribute-patterns \
         -DITERATIONS=1 \
         -DPERFORMANCE_RUN=1 \
         -DCOMPILER_VERSION='"GCC"' \
         -DCOMPILER_FLAGS='"rv32i -O2"' \
         -I$(COREMARK) -I.

SRCS = crt0.S \
       core_portme.c \
       $(COREMARK)/core_main.c \
       $(COREMARK)/core_list_join.c \
       $(COREMARK)/core_matrix.c \
       $(COREMARK)/core_state.c \
       $(COREMARK)/core_util.c

.PHONY: all clean

all: $(BUILD)/coremark.hex

$(BUILD)/coremark.elf: $(SRCS) link.ld | $(BUILD)
	$(CC) $(CFLAGS) -T link.ld -o $@ $(SRCS) -lgcc

$(BUILD)/coremark.bin: $(BUILD)/coremark.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/coremark.hex: $(BUILD)/coremark.bin
	python3 ../tests/bin2hex.py $< > $@

$(BUILD):
	mkdir -p $@

clean:
	rm -f $(BUILD)/coremark.*
