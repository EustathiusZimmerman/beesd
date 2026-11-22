const tty = @import("tty.zig");
const common = @import("common.zig");

pub const IdtEntry = packed struct {
	base_low: u16,
	selector: u16,
	zero: u8,
	gate_type: u4,
	storage_segment: u1,
	privilege: u2,
	present: u1,
	base_high: u16,
};

pub const IdtPtr = packed struct {
	limit: u16,
	base: u32,
};

const TABLE_SIZE: u16 = @sizeOf(IdtEntry) * NUMBER_OF_ENTRIES - 1;

pub const NUMBER_OF_ENTRIES: u16 = 256;

var idt_ptr: IdtPtr = IdtPtr{
	.limit = TABLE_SIZE,
	.base = 0,
};

var idt_entries: [NUMBER_OF_ENTRIES]IdtEntry = @splat(.{
	.base_low = 0,
	.selector = 0,
	.zero = 0,
	.gate_type = 0,
	.storage_segment = 0,
	.privilege = 0,
	.present = 0,
	.base_high = 0,
});

pub fn
init() void
{
	tty.print("Loading IDT... ", .{});
	defer tty.print("Done\n", .{});

	idt_ptr.base = @intFromPtr(&idt_entries);

	common.lidt(&idt_ptr);
}
