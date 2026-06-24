.section .text.start, "ax"
.global _start
_start:
    ldr x0, =_stack_top
    mov sp, x0
    bl main
1:
    wfe
    b 1b
