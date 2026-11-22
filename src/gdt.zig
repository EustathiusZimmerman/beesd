// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");
const tty = @import("tty.zig");
const common = @import("common.zig");

/// Access Bits of a GDT Entry
const AccessBits = packed struct {
	accessed: u1,
	read_write: u1,
	direction_conforming: u1,
	executable: u1,
	descriptor: u1,
	privilege: u2,
	present: u1,
};

/// Flag Bits of a GDT Entry
const FlagBits = packed struct {
	reserved_zero: u1,
	is_64bit: u1,
	is_32bit: u1,
	granularity: u1,
};

/// GDT entry representation (kernel segment code etc)
const GdtEntry = packed struct {
	limit_low: u16,
	base_low: u24,
	access: AccessBits,
	limit_high: u4,
	flags: FlagBits,
	base_high: u8,
};

/// TSS struct
const Tss = packed struct {
prev_tss: u16,
reserved1: u16,

/// Ring 0 32 bit stack pointer.
esp0: u32,

/// Ring 0 32 bit stack pointer.
ss0: u16,
reserved2: u16,

/// Ring 1 32 bit stack pointer.
esp1: u32,

/// Ring 1 32 bit stack pointer.
ss1: u16,
reserved3: u16,

/// Ring 2 32 bit stack pointer.
esp2: u32,

/// Ring 2 32 bit stack pointer.
ss2: u16,
reserved4: u16,

/// The CR3 control register 3.
cr3: u32,

/// 32 bit instruction pointer.
eip: u32,

/// 32 bit flags register.
eflags: u32,

/// 32 bit accumulator register.
eax: u32,

/// 32 bit counter register.
ecx: u32,

/// 32 bit data register.
edx: u32,

/// 32 bit base register.
ebx: u32,

/// 32 bit stack pointer register.
esp: u32,

/// 32 bit base pointer register.
ebp: u32,

/// 32 bit source register.
esi: u32,

/// 32 bit destination register.
edi: u32,

/// The extra segment.
es: u16,
reserved5: u16,

/// The code segment.
cs: u16,
reserved6: u16,

/// The stack segment.
ss: u16,
reserved7: u16,

/// The data segment.
ds: u16,
reserved8: u16,

/// A extra segment FS.
fs: u16,
reserved9: u16,

/// A extra segment GS.
gs: u16,
reserved10: u16,

/// The local descriptor table register.
ldtr: u16,
reserved11: u16,

/// ?
trap: u16,

/// A pointer to a I/O port bitmap for the current task which specifies individual ports the program should have access to.
io_permissions_base_offset: u16,
}; // Credits to the Pluto kernel, I wouldn't have the patience to document all of ts

/// Pointer to the GDT
pub const GdtPtr = packed struct {
	limit: u16, // Num of entries
	base: u32, // Entry for base addresses
};

/// The index of the NULL GDT entry.
const NULL_INDEX: u16 = 0x00;

/// The index of the kernel code GDT entry.
const KERNEL_CODE_INDEX: u16 = 0x01;

/// The index of the kernel data GDT entry.
const KERNEL_DATA_INDEX: u16 = 0x02;

/// The index of the user code GDT entry.
const USER_CODE_INDEX: u16 = 0x03;

/// The index of the user data GDT entry.
const USER_DATA_INDEX: u16 = 0x04;

/// The index of the task state segment GDT entry.
const TSS_INDEX: u16 = 0x05;

/// Null Segment - All the values should be set to 0
const NULL_SEGMENT: AccessBits = AccessBits{
	.accessed             = 0,
	.read_write           = 0,
	.direction_conforming = 0,
	.executable           = 0,
	.descriptor           = 0,
	.privilege            = 0,
	.present              = 0,
};

/// Kernel Segment Code part of the GDT
const KERNEL_SEGMENT_CODE: AccessBits = AccessBits{
	.accessed             = 0,
	.read_write           = 1,
	.direction_conforming = 0,
	.executable           = 1,
	.descriptor           = 1,
	.privilege            = 0,
	.present              = 1,
};

/// Kernel Segment Data part of the GDT
const KERNEL_SEGMENT_DATA: AccessBits = AccessBits{
	.accessed             = 0,
	.read_write           = 1,
	.direction_conforming = 0,
	.executable           = 0,
	.descriptor           = 1,
	.privilege            = 0,
	.present              = 1,
};

/// User Segment Code part of the GDT
const USER_SEGMENT_CODE: AccessBits = AccessBits{
	.accessed             = 0,
	.read_write           = 1,
	.direction_conforming = 0,
	.executable           = 1,
	.descriptor           = 1,
	.privilege            = 3,
	.present              = 1,
};

/// User Segment Data part of the GDT
const USER_SEGMENT_DATA: AccessBits = AccessBits{
	.accessed             = 0,
	.read_write           = 1,
	.direction_conforming = 0,
	.executable           = 0,
	.descriptor           = 1,
	.privilege            = 3,
	.present              = 1,
};

/// The TSS segment of the GDT
const TSS_SEGMENT: AccessBits = AccessBits{
	.accessed             = 1,
	.read_write           = 0,
	.direction_conforming = 0,
	.executable           = 1,
	.descriptor           = 0,
	.privilege            = 0,
	.present              = 1,
};

/// Null flags
const NULL_FLAGS: FlagBits = FlagBits{
	.reserved_zero = 0,
	.is_64bit      = 0,
	.is_32bit      = 0,
	.granularity   = 0,
};

/// Flags for 32 bit paging
const PAGING_32_BIT: FlagBits = FlagBits{
	.reserved_zero = 0,
	.is_64bit      = 0,
	.is_32bit      = 1,
	.granularity   = 1,
};

/// The offset of the NULL GDT entry.
pub const NULL_OFFSET: u16 = 0x00;

/// The offset of the kernel code GDT entry.
pub const KERNEL_CODE_OFFSET: u16 = 0x08;

/// The offset of the kernel data GDT entry.
pub const KERNEL_DATA_OFFSET: u16 = 0x10;

/// The offset of the user code GDT entry.
pub const USER_CODE_OFFSET: u16 = 0x18;

/// The offset of the user data GDT entry.
pub const USER_DATA_OFFSET: u16 = 0x20;

/// The offset of the TTS GDT entry.
pub const TSS_OFFSET: u16 = 0x28;

const NUMBER_OF_ENTRIES: u16 = 0x06;

/// Size of the GDT
// GDT entries array starts from 0, because of that we deincrement 1 from the number of entries
const TABLE_SIZE: u16 = @sizeOf(GdtEntry) * NUMBER_OF_ENTRIES - 1;

/// Array contraining the info of the entirety of GDT
var gdt_entries: [NUMBER_OF_ENTRIES]GdtEntry = init: {
	var gdt_entries_temp: [NUMBER_OF_ENTRIES]GdtEntry = undefined;

	gdt_entries_temp[0] = make_gdt_entry(0, 0, NULL_SEGMENT, NULL_FLAGS);

	gdt_entries_temp[1] = make_gdt_entry(0, 0xFFFFF, KERNEL_SEGMENT_CODE, PAGING_32_BIT);

	gdt_entries_temp[2] = make_gdt_entry(0, 0xFFFFF, KERNEL_SEGMENT_DATA, PAGING_32_BIT);

	gdt_entries_temp[3] = make_gdt_entry(0, 0xFFFFF, USER_SEGMENT_CODE, PAGING_32_BIT);

	gdt_entries_temp[4] = make_gdt_entry(0, 0xFFFFF, USER_SEGMENT_DATA, PAGING_32_BIT);

	// TSS will be initialized at runtime
	gdt_entries_temp[5] = make_gdt_entry(0, 0, NULL_SEGMENT, NULL_FLAGS);
	break :init gdt_entries_temp;
};

var gdt_ptr: GdtPtr = GdtPtr{
	.limit = TABLE_SIZE,
	.base = undefined,
};

pub var main_tss_entry: Tss = init: {
	var tss_temp = std.mem.zeroes(Tss);
	tss_temp.ss0 = KERNEL_DATA_OFFSET;
	tss_temp.io_permissions_base_offset = @sizeOf(Tss);
	break :init tss_temp;
};

/// Makes a GDT entry: Takes in the GDT entry properties and returns an GdtEntry struct
fn 
make_gdt_entry(base: u32, limit: u20, access: AccessBits, flags: FlagBits) GdtEntry 
{
	return .{
		.limit_low = @truncate(limit),
		.base_low = @truncate(base),
		.access = .{
			.accessed = access.accessed,
			.read_write = access.read_write,
			.direction_conforming = access.direction_conforming,
			.executable = access.executable,
			.descriptor = access.descriptor,
			.privilege = access.privilege,
			.present = access.present,
		},
		.limit_high = @truncate(limit >> 16),
		.flags = .{
			.reserved_zero = flags.reserved_zero,
			.is_64bit = flags.is_64bit,
			.is_32bit = flags.is_32bit,
			.granularity = flags.granularity,
		},
		.base_high = @truncate(base >> 24),
	};
}

/// Initializes the GDT
pub fn
init() void
{
	tty.print("Loading GDT... ", .{});
	defer tty.print("Done\n", .{});

	gdt_entries[TSS_INDEX] = make_gdt_entry(@intFromPtr(&main_tss_entry), @sizeOf(Tss) - 1, TSS_SEGMENT, NULL_FLAGS);

	gdt_ptr.base = @intFromPtr(&gdt_entries[0]);

	common.lgdt(&gdt_ptr);

	common.ltr(TSS_OFFSET);
}
