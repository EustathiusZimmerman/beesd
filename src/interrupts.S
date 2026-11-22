/* Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors */
/* SPDX-License-Identifier: GPL-3.0-or-later */

/*
 * I'm ashamed of how little I understand of what is going on, I'm vibecoding in a sense that I
 * deduct what I need to do based on the vibe and fix it until it somewhat works after 17 gazillion
 * searches on google and a dozen of osdev wiki forum posts, mixed with copypasting code from
 * abandoned projects that once tried to do what I'm doing but failed. But hey, ts works!
 */

.code32

.section .text
.altmacro

.macro ISR num
	.global isr\num
	.type isr\num, @function
isr\num:
	.if (\num == 8) || (\num == 10) || (\num == 11) || (\num == 12) || (\num == 13) || (\num == 14) || (\num == 17) || (\num == 21) || (\num == 29) || (\num == 30)
		/* The CPU already pushed an error code. */
	.else
		pushl $0
	.endif
	pushl $\num
	jmp isr_common
	.size isr\num, . - isr\num
.endm

.set vector, 0
.rept 256
	ISR %vector
	.set vector, vector + 1
.endr

.type isr_common, @function
isr_common:
	pushal
	pushl %ds
	pushl %es
	pushl %fs
	pushl %gs

	movw $0x10, %ax	/* gdt.KERNEL_DATA_OFFSET */
	movw %ax, %ds
	movw %ax, %es
	movw %ax, %fs
	movw %ax, %gs

	cld

	/* Align the stack before calling into Zig (SysV i386 ABI). */
	movl %esp, %ebx
	andl $-16, %esp
	subl $12, %esp
	pushl %ebx
	call interrupt_handler
	movl %ebx, %esp

	popl %gs
	popl %fs
	popl %es
	popl %ds
	popal
	addl $8, %esp
	iret
.size isr_common, . - isr_common

.section .rodata
.align 4
.global isr_stub_table
.type isr_stub_table, @object
isr_stub_table:
.macro TABLE_ENTRY num
	.long isr\num
.endm
.set vector, 0
.rept 256
	TABLE_ENTRY %vector
	.set vector, vector + 1
.endr
.size isr_stub_table, . - isr_stub_table

.section .note.GNU-stack,"",@progbits

/* FUCK GNU assembly, all ma homies HATE Gnu assembly */
