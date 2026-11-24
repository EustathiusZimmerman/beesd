// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const gdt = @import("gdt.zig");
const idt = @import("idt.zig");

/// Get a byte from a port
pub fn
inb(port: u16) u8
{
	return asm volatile (
		\\ inb %[port], %[ret]
		: [ret] "={al}" (-> u8),
		: [port] "{dx}" (port),
	);
}

/// Get a word from a port
pub fn
inw(port: u16) u16
{
	return asm volatile (
		\\ inw %[port], %[ret]
		: [ret] "={ax}" (-> u16),
		: [port] "{dx}" (port),
	);
}

/// Get a double word (long) from a port
pub fn
inl(port: u16) u32
{
	return asm volatile (
		\\ inl %[port], %[ret]
		: [ret] "={eax}" (-> u32),
		: [port] "{dx}" (port),
	);
}

/// Send a byte to a port
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

/// Send a word to a port
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

/// Send a double word (long) to a port
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

/// Load a GDT table
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

/// Load the TSS table offset relative to the GDT
pub fn
ltr(offset: u16) void {
	asm volatile(
		\\ ltr %[offset]
		:
		: [offset] "{ax}" (offset),
		: .{ .memory = true }
	);
}

/// Load an IDT table
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

/// Disable CPU interrupts
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

/// Enable CPU interrupts
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

/// Halt the CPU (duh)
pub fn 
halt_cpu() void
{
	asm volatile (
		\\ hlt
	);
}

/// Read control register 0
pub fn
read_cr0() u32
{
	return asm volatile (
		\\ movl %%cr0, %[ret]
		: [ret] "=r" (-> u32),
	);
}

/// Write control register 0
pub fn
write_cr0(value: u32) void
{
	asm volatile (
		\\ movl %[value], %%cr0
		:
		: [value] "r" (value),
		: .{ .memory = true }
	);
}

/// Read control register 2 (the faulting address after a page fault)
pub fn
read_cr2() u32
{
	return asm volatile (
		\\ movl %%cr2, %[ret]
		: [ret] "=r" (-> u32),
	);
}

/// Read control register 3 (the page directory base)
pub fn
read_cr3() u32
{
	return asm volatile (
		\\ movl %%cr3, %[ret]
		: [ret] "=r" (-> u32),
	);
}

/// Write control register 3 (the page directory base)
pub fn
write_cr3(value: u32) void
{
	asm volatile (
		\\ movl %[value], %%cr3
		:
		: [value] "r" (value),
		: .{ .memory = true }
	);
}

/// Read control register 4
pub fn
read_cr4() u32
{
	return asm volatile (
		\\ movl %%cr4, %[ret]
		: [ret] "=r" (-> u32),
	);
}

/// Write control register 4
pub fn
write_cr4(value: u32) void
{
	asm volatile (
		\\ movl %[value], %%cr4
		:
		: [value] "r" (value),
		: .{ .memory = true }
	);
}

/// Invalidate a single TLB entry for a virtual address
pub fn
invlpg(address: usize) void
{
	asm volatile (
		\\ invlpg (%[address])
		:
		: [address] "r" (address),
		: .{ .memory = true }
	);
}

/// Save the interrupt flag and disable interrupts
pub fn
irq_save() usize
{
	return asm volatile (
		\\ pushfl
		\\ popl %[ret]
		\\ cli
		: [ret] "=r" (-> usize),
		:
		: .{ .memory = true }
	);
}

/// Restore the interrupt flag that was saved previously
pub fn
irq_restore(flags: usize) void
{
	asm volatile (
		\\ testl $0x200, %[flags]
		\\ jz 1f
		\\ sti
		\\ 1:
		:
		: [flags] "r" (flags),
		: .{ .memory = true }
	);
}
