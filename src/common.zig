// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const gdt = @import("gdt.zig");
const idt = @import("idt.zig");

pub fn
inb(port: u16) u8
{
	return asm volatile (
		\\ inb %[port], %[ret]
		: [ret] "={al}" (-> u8),
		: [port] "{dx}" (port),
	);
}

pub fn
inw(port: u16) u16
{
	return asm volatile (
		\\ inw %[port], %[ret]
		: [ret] "={ax}" (-> u16),
		: [port] "{dx}" (port),
	);
}

pub fn
inl(port: u16) u32
{
	return asm volatile (
		\\ inl %[port], %[ret]
		: [ret] "={eax}" (-> u32),
		: [port] "{dx}" (port),
	);
}

pub fn 
outb(port: u16, data: u8) void 
{
	asm volatile (
		\\ outb %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{al}" (data),
	);
}

pub fn 
outw(port: u16, data: u16) void 
{
	asm volatile (
		\\ outw %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{ax}" (data),
	);
}


pub fn 
outl(port: u16, data: u32) void 
{
	asm volatile (
		\\ outw %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{eax}" (data),
	);
}

pub fn
lgdt(pgdt: *const gdt.GdtPtr) void
{
	// Load gdt into CPU
	asm volatile(
		\\ lgdt (%%eax)
		:
		: [pgdt] "{eax}" (pgdt),
	);

	// Load the kernel data segment
	asm volatile(
		\\ mov %%bx, %%ds
		:
		: [KERNEL_DATA_OFFSET] "{bx}" (gdt.KERNEL_DATA_OFFSET),
	);

	asm volatile ("mov %%bx, %%es");
	asm volatile ("mov %%bx, %%fs");
	asm volatile ("mov %%bx, %%gs");
	asm volatile ("mov %%bx, %%ss");

	asm volatile (
		\\ ljmp $0x08, $1f
		\\ 1:
	);
}

pub fn
ltr(offset: u16) void {
	asm volatile(
		\\ ltr %%ax
		:
		: [offset] "{ax}" (offset),
	);
}

pub fn
lidt(idt_ptr: *const idt.IdtPtr) void
{
	asm volatile(
		\\ lidt (%%eax)
		:
		: [idt_ptr] "{eax}" (idt_ptr),
	);
}

pub fn 
disable_interrupts() void
{
	asm volatile (
		\\ cli
	);
}

pub fn 
enable_interrupts() void
{
	asm volatile (
		\\ sti
	);
}

pub fn 
halt_cpu() void
{
	asm volatile (
		\\ hlt
	);
}
