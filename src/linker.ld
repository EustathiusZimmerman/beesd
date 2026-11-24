/* Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors */
/* SPDX-License-Identifier: GPL-3.0-or-later */

ENTRY(_start)
SECTIONS {
	. = 2M;
	kernel_start = .;

	.text : ALIGN(4K) {
		KEEP(*(.multiboot))
		*(.text .text.*)
	}

	/* Read-only data. */
	.rodata : ALIGN(4K) {
		*(.rodata .rodata.*)
	}

	/* Read-write data (initialized) */
	.data : ALIGN(4K) {
		*(.data .data.*)
		*(.data.rel.ro*)
		*(.got .got.*)
	}

	/* Read-write data (uninitialized i.e. undefined) */
	.bss : ALIGN(4K) {
		__bss_start = .;
		*(COMMON)
		*(.bss .bss.*)
		__bss_end = .;
	}

	. = ALIGN(4K);
	kernel_end = .;

	/* Sections the compiler may emit that the kernel does not use. */
	/DISCARD/ : {
		*(.comment)
		*(.note*)
		*(.eh_frame*)
		*(.llvm_addrsig)
	}

	/* The compiler may produce other sections, by default it will put them
	   in a segment with the same name. Simply add stuff here as needed. */
}
