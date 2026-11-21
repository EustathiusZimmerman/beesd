// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");

const COM1: u16 = 0x3F8;
const BAUD_DIVISOR: u16 = 1; // 115200 baud

pub fn
init() void
{
	common.outb(COM1 + 1, 0x00); // Disable interrupts
	common.outb(COM1 + 3, 0x80); // Enable DLAB (set baud rate divisor)
	common.outb(COM1 + 0, @truncate(BAUD_DIVISOR)); // Divisor low byte
	common.outb(COM1 + 1, @truncate(BAUD_DIVISOR >> 8)); // Divisor high byte
	common.outb(COM1 + 3, 0x03); // 8 bits, no parity, one stop bit
	common.outb(COM1 + 2, 0xC7); // Enable FIFO, clear it, 14-byte threshold
	common.outb(COM1 + 4, 0x0B); // IRQs enabled, RTS/DSR set
}

pub fn
write_char(char: u8) void
{
	if(char == '\n') {
		write_raw('\r');
	}
	write_raw(char);
}

pub fn
write_string(str: []const u8) void
{
	for(str) |char| {
		write_char(char);
	}
}

fn
write_raw(char: u8) void
{
	while((common.inb(COM1 + 5) & 0x20) == 0) {}
	common.outb(COM1, char);
}
