/* Linker script */
INCLUDE memmap.ld

OUTPUT_ARCH(riscv) /* tells the linker which instruction set architecture the output file is for */ 
ENTRY(_kstart) /* sets the entry point of the program */

/* Declaring the physical memory regions available to the linker */
MEMORY
{
    RAM (rwx) : ORIGIN = KERNEL_ORIGIN, LENGTH = KERNEL_LENGTH
    /* RAM with read, write and execute */
    /* Origin starts at KERNEL_ORIGIN (see memmap.ld) */
    /* Length set at KERNEL_LENGTH (see memmap.ld)  */
}

SECTIONS
{
    /* Starts the sections from the start of the RAM */
    . = ORIGIN(RAM);

    /* Section .text.init */
    .text.init : {
        /* Get the .text.init sections for all the object files */
        *(.text.init) 
    } > RAM /* Put them in the ram */

    /* Section .text */
    /* They would be aligned to 4 bytes (RISC-V requirements) */
    .text : ALIGN(4) {
        /* Get the .text.* sections for all the object files */
        *(.text .text.*)
    } > RAM /* Put them in the ram */

    /* Section .rodata */
    /* They would be aligned to 4 bytes (RISC-V requirements) */
    .rodata : ALIGN(4) {
        /* Get the .rodata.* sections for all the object files */
        *(.rodata .rodata.*)
    } > RAM /* Put them in the ram */

    /* Section .data */
    /* They would be aligned to 4096 bytes */
    .data : ALIGN(4096) {
        /* Data section starts at the current position in the RAM */
        _data_start = .;
        /* Get the .data.* sections for all the object files */
        *(.data .data.*)
        /* Get the .sdata.* sections for all the object files */
        *(.sdata .sdata.*)
        /* Data section ends at the current position in the RAM */
        _data_end = .;
    } > RAM /* Put them in the ram */

    /* Section .bss */
    /* They would be aligned to 4096 bytes */
    .bss : ALIGN(4096) {
        /* BSS section starts at the current position in the RAM */
        _bss_start = .;
        /* Get the .bss.* sections for all the object files */
        *(.bss .bss.*)
        /* Get the .sbss.* sections for all the object files */
        *(.sbss .sbss.*)
        /* All the common symbols (uninitialized ones) are put into the BSS */
        *(COMMON)
        /* BSS section ends at the current position in the RAM */
        _bss_end = .;
    } > RAM

    /* Align current position to the next 4096-byte boundary before marking _end */
    . = ALIGN(4096);
    /* _end marks the first free address after everything statically linked */
    _end = .;

    /* Provide the _stack_top symbol */
    /* The stack starts from highest address, that is equal to the RAM origin plus the size of the RAM itself */ 
    PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));
}