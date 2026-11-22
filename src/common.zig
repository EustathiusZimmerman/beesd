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
		\\ outl %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{eax}" (data),
	);
}

/// Write to an unused I/O port to give older devices time to react.
pub fn
io_wait() void
{
	outb(0x80, 0);
}

pub fn
lgdt(pgdt: *const gdt.GdtPtr) void
{
	// Load the GDT and all data segments, then reload CS with a far jump.
	asm volatile (
		\\ lgdt (%[pgdt])
		\\ movw %[data_selector], %%ds
		\\ movw %[data_selector], %%es
		\\ movw %[data_selector], %%fs
		\\ movw %[data_selector], %%gs
		\\ movw %[data_selector], %%ss
		\\ ljmp %[code_selector], $1f
		\\ 1:
		:
		: [pgdt] "{eax}" (pgdt),
		  [data_selector] "{bx}" (gdt.KERNEL_DATA_OFFSET),
		  [code_selector] "i" (gdt.KERNEL_CODE_OFFSET),
		: .{ .memory = true }
	);
}

pub fn
ltr(offset: u16) void {
	asm volatile(
		\\ ltr %[offset]
		:
		: [offset] "{ax}" (offset),
		: .{ .memory = true }
	);
}

pub fn
lidt(idt_ptr: *const idt.IdtPtr) void
{
	asm volatile(
		\\ lidt (%[idt_ptr])
		:
		: [idt_ptr] "{eax}" (idt_ptr),
		: .{ .memory = true }
	);
}

pub fn 
disable_interrupts() void
{
	asm volatile (
		\\ cli
		:
		:
		: .{ .memory = true }
	);
}

pub fn 
enable_interrupts() void
{
	asm volatile (
		\\ sti
		:
		:
		: .{ .memory = true }
	);
}

pub fn 
halt_cpu() void
{
	asm volatile (
		\\ hlt
	);
}
