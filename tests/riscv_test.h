// riscv-tests environment for peppercorn.
// tohost == 1               -> PASS
// tohost == (TESTNUM<<1)|1  -> FAIL at test number TESTNUM
#ifndef _ENV_PEPPERCORN_H
#define _ENV_PEPPERCORN_H

// Empty
#define RVTEST_RV32U .macro init; .endm
#define RVTEST_RV64U .macro init; .endm

#define TESTNUM gp

#define RVTEST_CODE_BEGIN \
        .section .text.init; \
        .globl _start; \
_start: \
        li TESTNUM, 0;

// Spins, but should never be reached.
#define RVTEST_CODE_END \
1:      j 1b

// tohost idea inherited from spike
#define RVTEST_PASS \
        li TESTNUM, 1; \
        la t0, tohost; \
        sw TESTNUM, 0(t0); \
1:      j 1b;

#define RVTEST_FAIL \
        sll TESTNUM, TESTNUM, 1; \
        or  TESTNUM, TESTNUM, 1; \
        la t0, tohost; \
        sw TESTNUM, 0(t0); \
1:      j 1b;

// Data section
#define RVTEST_DATA_BEGIN \
        .pushsection .tohost,"aw",@progbits; \
        .align 6; .global tohost; tohost: .dword 0; \
        .popsection; \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif // _ENV_PEPPERCORN_H
