// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");
const serial = @import("serial.zig");
const tty = @import("tty.zig");
const idt = @import("idt.zig");
const gdt = @import("gdt.zig");

const MULTIBOOT_HEADER_MAGIC = 0x1BADB002;
const MULTIBOOT_FLAG_ALIGN = 1 << 0;
const MULTIBOOT_FLAG_MEMINFO = 1 << 1;
const FLAGS = MULTIBOOT_FLAG_ALIGN | MULTIBOOT_FLAG_MEMINFO;

const MultibootHeader = packed struct(u128) {
	magic:    u32 = MULTIBOOT_HEADER_MAGIC,
	flags:    u32 = FLAGS,
	checksum: u32,
	padding:  u32 = 0,
};

export var multiboot: MultibootHeader align(4) linksection(".multiboot") = .{
	.checksum = ~@as(u32, (MULTIBOOT_HEADER_MAGIC + FLAGS)) + 1,
};

var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

// Naked means no function prologue and epilogue
// cuz there ain't no stack yet
export fn 
_start() callconv(.naked) noreturn 
{
	asm volatile (
		\\ movl %[stack_top], %%esp
		\\ movl %%esp, %%ebp
		\\ call %[kmain:P]
		:
		: [stack_top] "i" (stack_bytes[stack_bytes.len..].ptr),
		  [kmain] "X" (&kmain),
	);
}

inline fn
print_logo() void
{
	tty.set_color(tty.ColorType.light_brown, tty.ColorType.black);
	tty.print(
	\\        ____
	\\ _--_  /*  *\  _--_
	\\(    \(      )/    )
	\\ \__  \)____(/  __/
	\\ /    /)____(\    \
	\\(_  _/(______)\_  _)
	\\  --   \____/   --
	\\
	, .{});
	
	tty.print("    ", .{});
	tty.print("{s} kernel\n", .{"BEESD"});
	for(0..20) |i| {
		_ = &i;
		tty.print("=", .{});
	}
	tty.print("\n", .{});
	tty.set_color(tty.ColorType.white, tty.ColorType.black);
}

noinline fn 
kmain() callconv(.c) noreturn 
{
	serial.init();
	tty.init();

	print_logo();

	gdt.init();
	idt.init();

	tty.print("hai :3\n", .{});
	tty.print(
		\\This program comes with ABSOLUTELY NO WARRANTY
		\\This is free software that is distributed under the terms of the GNU GPL v.3.0
		\\You should have recieved the text of it with your copy of the program
		, .{});

	while(true) {
		common.halt_cpu();
	}
}
