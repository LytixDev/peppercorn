.section .text.init
.globl _start
_start:
    la   sp, _stack_top

    /* zero BSS */
    la   a0, _bss_start
    la   a1, _bss_end
    bgeu a0, a1, .Lbss_done
.Lbss_loop:
    sw   zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, .Lbss_loop
.Lbss_done:

    call main

/* main() commits tohost via portable_fini and never returns; guard anyway */
1:  j    1b
