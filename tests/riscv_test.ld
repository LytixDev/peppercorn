OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    .text.init : { *(.text.init) }     /* _start must be at the reset PC (0) */
    .text      : { *(.text*) }

    . = ALIGN(4);
    .data      : { *(.data*) *(.rodata*) *(.sdata*) }

    /* tohost pinned at a fixed address so the testbench can poll it. */
    . = 0x00002000;
    .tohost    : { *(.tohost) }
}
