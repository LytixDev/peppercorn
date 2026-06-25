    .section .text
    .globl _start
_start:
    addi x1, x0, 8
    addi x2, x0, 34
    add  x3, x1, x2
halt:
    jal  x0, halt
