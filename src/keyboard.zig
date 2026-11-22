const common = @import("common.zig");
const tty = @import("tty.zig");

const PS2_DATA_PORT: u16 = 0x60;
const PIC1_COMMAND: u16 = 0x20;
const PIC_EOI: u8 = 0x20;

// PS/2 Scan Code Set 1 values for Spacebar
const SPACE_PRESSED: u8 = 0x39;
const SPACE_RELEASED: u8 = 0xB9; // 0x39 | 0x80

pub fn
init() void
{
	const current_mask = common.inb(0x21);
	common.outb(0x21, current_mask & ~@as(u8, 1 << 1));
}

pub fn
handler() void
{
	const scancode = common.inb(PS2_DATA_PORT);

	if(scancode == SPACE_PRESSED) {
		common.disable_interrupts();
		tty.print("Disabled interruts: Goodbye!\n", .{});
	}

	common.outb(PIC1_COMMAND, PIC_EOI);
}

