# emilia.ld

This document explains `emilia.ld`, the linker script used to build
`emilia`, the kernel image for this project. It covers the memory layout
and exported symbols specific to the kernel.

For a general explanation of what a linker script is, why the sections
are structured the way they are, and how the shared conventions in
`memmap.ld` work, see the sibling repo
[jny.ld](https://github.com/scala-systems/jny.ld), that README covers
those concepts in depth and this one won't repeat them.

## Relationship to jny.ld

`jny` (the bootloader) and `emilia` (the kernel) are two separate images
linked from two separate scripts, but they agree on one shared memory
map, defined once in `memmap.ld` and duplicated identically into both
repos so neither can drift out of sync with the other:

```ld
RAM_SIZE = 128M;
BOOT_ORIGIN = 0x80000000;
BOOT_LENGTH = 16K;
KERNEL_ORIGIN = BOOT_ORIGIN + BOOT_LENGTH;
KERNEL_LENGTH = RAM_SIZE - BOOT_LENGTH;
```

`jny.ld`'s `RAM` region covers `BOOT_ORIGIN...BOOT_ORIGIN+BOOT_LENGTH` (the
first 16K). `emilia.ld`'s `RAM` region covers everything after that,
`KERNEL_ORIGIN...KERNEL_ORIGIN+KERNEL_LENGTH`. The two regions are
adjacent and non-overlapping by construction: `KERNEL_ORIGIN` is defined
as `BOOT_ORIGIN + BOOT_LENGTH`, so the kernel begins exactly where the
boot region ends. `jny.ld` exposes this boundary as `_kstart`
(`PROVIDE(_kstart = KERNEL_ORIGIN)`), which is what the bootloader jumps
to once it's done its own setup, that's the handoff between the two
images.

## Memory map

| Constant        | Value                                       | Meaning                           |
| ---------------- | -------------------------------------------- | ---------------------------------- |
| `KERNEL_ORIGIN`  | `0x80004000` (`BOOT_ORIGIN + BOOT_LENGTH`)   | Start of RAM this script may use  |
| `KERNEL_LENGTH`  | `128M - 16K`                                 | Size of RAM this script may use   |

Declared in the script as:

```ld
MEMORY
{
    RAM (rwx) : ORIGIN = KERNEL_ORIGIN, LENGTH = KERNEL_LENGTH
}
```

Same as `jny.ld`, this isn't just documentation, the linker refuses to
build an image that overflows `KERNEL_LENGTH`, catching a class of bug at
build time.

## Resulting memory layout

```ld
                KERNEL_ORIGIN ┌──────────────────────┐
                              │ .text.init (_kstart) │
                              ├──────────────────────┤
                              │ .text                │
                              ├──────────────────────┤
                              │ .rodata              │
                              ├──────────────────────┤  (4096-aligned)
                              │ .data                │  _data_start.._data_end
                              ├──────────────────────┤  (4096-aligned)
                              │ .bss                 │  _bss_start.._bss_end
                              ├──────────────────────┤  (4096-aligned)
                              │ (free memory)        │  starts at _end
                              │        ...           │
                              │        ...           │  stack grows downward
KERNEL_ORIGIN + KERNEL_LENGTH └──────────────────────┘ _stack_top (top of kernel RAM)
```

## Symbols exported for use in `emilia_init.s` / C code

| Symbol                    | Meaning                                      | Used for                                   |
| -------------------------- | ---------------------------------------------- | -------------------------------------------- |
| `_kstart`                  | First instruction, entry point                 | `ENTRY()`, jump target from the bootloader   |
| `_data_start`/`_data_end`  | Bounds of initialized data                     | Reserved for future flash→RAM copy step      |
| `_bss_start`/`_bss_end`    | Bounds of uninitialized data                   | Zeroing loop in `_kstart`                    |
| `_end`                     | First free address after the static image      | Heap/bump allocator base                     |
| `_stack_top`               | Top of kernel RAM (`KERNEL_ORIGIN + LENGTH`)   | Initial stack pointer (`sp`) in `_kstart`    |

## Known limitations (intentional, for this stage)

- **Single stack, no trap/main split.** Unlike `jny.ld`, which reserves a
  dedicated 4K trap stack separate from the main stack, this script
  defines only one `_stack_top`. Whether the kernel needs its own
  trap/main split (and where it should live, given the kernel owns a
  much larger RAM window than the bootloader) hasn't been decided yet.
- **No link-time stack-overflow `ASSERT`.** `jny.ld` asserts
  `_stack_bottom < _stack_top` at link time to catch static sections
  growing large enough to collide with the stack. This script doesn't
  define `_stack_bottom` or perform an equivalent check, so that class
  of bug currently isn't caught at build time here.
- **Single flat memory region, no MMU/paging.** Same status as
  `jny.ld`, see that README for the reasoning; nothing kernel-specific
  changes this yet.

These will be revisited as the project grows, this script covers exactly
what's needed for a minimal bare-metal kernel image today.