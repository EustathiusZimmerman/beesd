// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");
const idt = @import("idt.zig");

const PIT_CHANNEL0: u16 = 0x40;
const PIT_COMMAND: u16 = 0x43;

/// The PIT input clock runs at 1.193182 MHz.
const PIT_BASE_FREQUENCY: u32 = 1193182;

const PIT_IRQ: u8 = 0;

var ticks: u32 = 0;

fn 
on_tick(frame: *idt.InterruptFrame) void 
{
	_ = frame;

	const counter: *volatile u32 = &ticks;
	counter.* +%= 1;
}

/// Program PIT channel 0 to fire IRQ 0 at approximately `frequency` Hz.
pub fn 
init(frequency: u32) void 
{
	const divisor: u16 = @intCast(@min(PIT_BASE_FREQUENCY / @max(frequency, 1), 0xFFFF));

	idt.register_irq(PIT_IRQ, on_tick);

	common.outb(PIT_COMMAND, 0x36); // Channel 0, lo/hi byte, mode 3, binary
	common.outb(PIT_CHANNEL0, @truncate(divisor));
	common.outb(PIT_CHANNEL0, @truncate(divisor >> 8));
}

pub fn 
get_ticks() u32 
{
	const counter: *volatile u32 = &ticks;
	return counter.*;
}
