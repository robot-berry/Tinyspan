ENTRY(_start)

MEMORY
{
  OCM (rwx) : ORIGIN = 0xFFFC0000, LENGTH = 0x00010000
}

SECTIONS
{
  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
  } > OCM

  .data : {
    *(.data*)
  } > OCM

  .bss : {
    *(.bss*)
    *(COMMON)
  } > OCM

  _stack_top = ORIGIN(OCM) + LENGTH(OCM);
}
