ENTRY(_start)
SECTIONS {
	. = 2M;

	.text : ALIGN(4K) {
		KEEP(*(.multiboot))
		*(.text)
	}

	/* Read-only data. */
	.rodata : ALIGN(4K) {
		*(.rodata)
	}

	/* Read-write data (initialized) */
	.data : ALIGN(4K) {
		*(.data)
	}

	/* Read-write data (uninitialized i.e. undefined) */
	.bss : ALIGN(4K) {
		*(COMMON)
		*(.bss)
	}

	/* The compiler may produce other sections, by default it will put them
	   in a segment with the same name. Simply add stuff here as needed. */
}