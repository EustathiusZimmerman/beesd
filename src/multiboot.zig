// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");
const tty = @import("tty.zig");

/// Magic value the bootloader leaves in EAX when it jumps to the kernel
pub const BOOTLOADER_MAGIC: u32 = 0x2BADB002;

/// Multiboot info flag bits
pub const FLAG_MEMORY: u32 = 1 << 0;
pub const FLAG_BOOT_DEVICE: u32 = 1 << 1;
pub const FLAG_CMDLINE: u32 = 1 << 2;
pub const FLAG_MODULES: u32 = 1 << 3;
pub const FLAG_SYMBOLS_AOUT: u32 = 1 << 4;
pub const FLAG_SYMBOLS_ELF: u32 = 1 << 5;
pub const FLAG_MMAP: u32 = 1 << 6;
pub const FLAG_DRIVES: u32 = 1 << 7;
pub const FLAG_CONFIG_TABLE: u32 = 1 << 8;
pub const FLAG_BOOT_LOADER_NAME: u32 = 1 << 9;
pub const FLAG_APM_TABLE: u32 = 1 << 10;
pub const FLAG_VBE: u32 = 1 << 11;
pub const FLAG_FRAMEBUFFER: u32 = 1 << 12;

/// Multiboot v1 information structure
pub const Info = packed struct {
	flags: u32,
	mem_lower: u32,
	mem_upper: u32,
	boot_device: u32,
	cmdline: u32,
	mods_count: u32,
	mods_addr: u32,
	syms0: u32,
	syms1: u32,
	syms2: u32,
	syms3: u32,
	mmap_length: u32,
	mmap_addr: u32,
	drives_length: u32,
	drives_addr: u32,
	config_table: u32,
	boot_loader_name: u32,
	apm_table: u32,
	vbe_control_info: u32,
	vbe_mode_info: u32,
	vbe_mode: u16,
	vbe_interface_seg: u16,
	vbe_interface_off: u16,
	vbe_interface_len: u16,
	framebuffer_addr: u64,
	framebuffer_pitch: u32,
	framebuffer_width: u32,
	framebuffer_height: u32,
	framebuffer_bpp: u8,
	framebuffer_type: u8,
	color_info0: u8,
	color_info1: u8,
	color_info2: u8,
	color_info3: u8,
	color_info4: u8,
	color_info5: u8,
};

/// An entry in the Multiboot memory map.
pub const MmapEntry = packed struct {
	/// Size of this entry, not including this field itself.
	size: u32,
	base: u64,
	length: u64,
	kind: u32,
};

/// A boot module loaded by the bootloader.
pub const Module = packed struct {
	mod_start: u32,
	mod_end: u32,
	/// Command line associated with this module.
	string: u32,
	reserved: u32,
};

comptime {
	if(@sizeOf(Info) != 116) {
		@compileError("Multiboot info must be exactly 116 bytes");
	}
	if(@sizeOf(MmapEntry) != 24) {
		@compileError("Multiboot memory map entry must be exactly 24 bytes");
	}
	if(@sizeOf(Module) != 16) {
		@compileError("Multiboot module must be exactly 16 bytes");
	}
}

/// The values the Multiboot memory map 
pub const MemoryType = enum(u32) {
	available = 1,
	reserved = 2,
	acpi_reclaimable = 3,
	acpi_nvs = 4,
	bad = 5,
	_,
};

/// Pointer to the Multiboot info structure, valid after initialization
pub var info: ?*const Info = null;

/// Validate the bootloader handoff and remember where the info structure is
pub fn 
init(magic: u32, address: u32) bool {
	if(magic != BOOTLOADER_MAGIC or address == 0) return false;
	info = @ptrFromInt(@as(usize, address));
	return true;
}

/// Iterates over the entries of the Multiboot memory map
pub const MmapIterator = struct {
	cursor: [*]const u8,
	remaining: u32,

	pub fn next(self: *MmapIterator) ?MmapEntry {
		if(self.remaining < @sizeOf(MmapEntry)) return null;

		const entry: *const MmapEntry = @ptrCast(@alignCast(self.cursor));
		if(entry.size < 20) return null;

		const step = std.math.add(u32, entry.size, @sizeOf(u32)) catch return null;
		if(step > self.remaining) return null;

		self.cursor += @as(usize, step);
		self.remaining -= step;
		return entry.*;
	}
};

/// Returns an iterator over the memory map or null
pub fn 
mmap_iterator() ?MmapIterator {
	const inf = info orelse return null;
	if (inf.flags & FLAG_MMAP == 0) return null;
	if (inf.mmap_addr == 0 or inf.mmap_length == 0) return null;
	return .{
		.cursor = @ptrFromInt(@as(usize, inf.mmap_addr)),
		.remaining = inf.mmap_length,
	};
}

fn 
kind_name(kind: u32) []const u8 {
	return switch (kind) {
		1 => "available",
		2 => "reserved",
		3 => "ACPI reclaimable",
		4 => "ACPI NVS",
		5 => "bad memory",
		else => "unknown",
	};
}

/// Print the bootloader handoff information and the physical memory map
pub fn 
print_info() void {
	const inf = info orelse {
		tty.set_color(.light_red, .black);
		tty.print("ERROR: no Multiboot information available\n", .{});
		tty.set_color(.white, .black);
		return;
	};

	tty.print("Multiboot info @ 0x{x} (flags 0x{x})\n", .{ @intFromPtr(inf), inf.flags });

	if (inf.flags & FLAG_BOOT_LOADER_NAME != 0 and inf.boot_loader_name != 0) {
		const name: [*:0]const u8 = @ptrFromInt(@as(usize, inf.boot_loader_name));
		tty.print("  bootloader: {s}\n", .{std.mem.span(name)});
	}

	if (inf.flags & FLAG_CMDLINE != 0 and inf.cmdline != 0) {
		const cmdline: [*:0]const u8 = @ptrFromInt(@as(usize, inf.cmdline));
		tty.print("  command line: {s}\n", .{std.mem.span(cmdline)});
	}

	if (inf.flags & FLAG_MEMORY != 0) {
		tty.print("  lower memory: {} KiB\n", .{inf.mem_lower});
		tty.print("  upper memory: {} KiB\n", .{inf.mem_upper});
	}

	var it = mmap_iterator() orelse {
		tty.print("  memory map: unavailable\n", .{});
		return;
	};

	tty.print("  memory map @ 0x{x}, {} bytes:\n", .{ inf.mmap_addr, inf.mmap_length });

	var usable: u64 = 0;
	while(it.next()) |entry| {
		const end = entry.base +| entry.length;
		tty.print("    0x{x:0>8} - 0x{x:0>8}  {s} ({} KiB)\n", .{
			entry.base,
			end,
			kind_name(entry.kind),
			entry.length / 1024,
		});
		if(entry.kind == @intFromEnum(MemoryType.available)) {
			usable +|= entry.length;
		}
	}

	tty.print("  usable memory: {} MiB\n", .{usable / (1024 * 1024)});
}
