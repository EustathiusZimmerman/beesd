// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");

const PIC1_COMMAND: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_COMMAND: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

const ICW1_INIT: u8 = 0x10;
const ICW1_ICW4: u8 = 0x01;
const ICW4_8086: u8 = 0x01;
const OCW3_READ_ISR: u8 = 0x0B;
const EOI: u8 = 0x20;

/// The IRQ line the slave PIC is cascaded into on the master PIC.
const CASCADE_IRQ: u8 = 2;

fn 
irq_bit(irq: u8) u8 
{
	return @as(u8, 1) << @intCast(irq & 7);
}

fn 
is_in_service(command_port: u16, irq: u3) bool 
{
	common.outb(command_port, OCW3_READ_ISR);
	return (common.inb(command_port) & (@as(u8, 1) << irq)) != 0;
}

/// Remap the master and slave PICs so that IRQ 0-15 become vectors
/// offset1..offset1+7 and offset2..offset2+7.
pub fn 
remap(offset1: u8, offset2: u8) void 
{
	const mask1 = common.inb(PIC1_DATA);
	const mask2 = common.inb(PIC2_DATA);

	common.outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
	common.io_wait();
	common.outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
	common.io_wait();

	common.outb(PIC1_DATA, offset1);
	common.io_wait();
	common.outb(PIC2_DATA, offset2);
	common.io_wait();

	// Tell the master that the slave is on IRQ2, and the slave its identity.
	common.outb(PIC1_DATA, @as(u8, 1) << CASCADE_IRQ);
	common.io_wait();
	common.outb(PIC2_DATA, CASCADE_IRQ);
	common.io_wait();

	common.outb(PIC1_DATA, ICW4_8086);
	common.io_wait();
	common.outb(PIC2_DATA, ICW4_8086);
	common.io_wait();

	common.outb(PIC1_DATA, mask1);
	common.outb(PIC2_DATA, mask2);
}

pub fn 
mask_all() void 
{
	common.outb(PIC1_DATA, 0xFF);
	common.outb(PIC2_DATA, 0xFF);
}

pub fn 
mask(irq: u8) void 
{
	if(irq >= 16) return;

	const data_port = if(irq < 8) PIC1_DATA else PIC2_DATA;
	common.outb(data_port, common.inb(data_port) | irq_bit(irq));
}

pub fn 
unmask(irq: u8) void 
{
	if(irq >= 16) return;

	const data_port = if(irq < 8) PIC1_DATA else PIC2_DATA;
	common.outb(data_port, common.inb(data_port) & ~irq_bit(irq));

	// IRQs 8-15 arrive through the cascade line on the master PIC.
	if(irq >= 8) {
		common.outb(PIC1_DATA, common.inb(PIC1_DATA) & ~irq_bit(CASCADE_IRQ));
	}
}

pub fn 
send_eoi(irq: u8) void 
{
	if(irq >= 8) {
		// A spurious IRQ15 was never actually raised by the slave.
		if(irq == 15 and !is_in_service(PIC2_COMMAND, 7)) {
			common.outb(PIC1_COMMAND, EOI);
			return;
		}

		common.outb(PIC2_COMMAND, EOI);
		common.outb(PIC1_COMMAND, EOI);
		return;
	}

	// A spurious IRQ7 must not be acknowledged on the master PIC.
	if(irq == 7 and !is_in_service(PIC1_COMMAND, 7)) {
		return;
	}

	common.outb(PIC1_COMMAND, EOI);
}
