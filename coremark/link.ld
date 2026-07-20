OUTPUT_ARCH(riscv)
ENTRY(_start)

/*
 * 64 KB memory (mem.sv NUM_WORDS=16384).
 * text/rodata/data/bss laid out from 0; tohost pinned at 0x8000 (above all
 * sections, polled by the testbench); stack grows down from the top.
 */
SECTIONS
{
    . = 0x00000000;
    .text.init : { *(.text.init) }
    .text      : { *(.text*) }

    . = ALIGN(4);
    .rodata    : { *(.rodata*) *(.srodata*) }

    . = ALIGN(4);
    .data      : { *(.data* .sdata*) }

    . = ALIGN(4);
    _bss_start = .;
    .bss       : { *(.bss* .sbss*) *(COMMON) }
    . = ALIGN(4);
    _bss_end   = .;

    ASSERT(_bss_end < 0x8000, "coremark image overflows tohost at 0x8000")

    _stack_top = 0x0000FFF0;
}
