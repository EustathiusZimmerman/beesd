// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");
const memory = @import("memory.zig");
const multiboot = @import("multiboot.zig");
const tty = @import("tty.zig");

/// The size of a physical frame
pub const FRAME_SIZE: usize = memory.PAGE_SIZE;

/// A full 4 GiB address space contains 2^20 frames.
pub const MAX_FRAMES: usize = 1 << 20;

/// The largest physical address a 32-bit kernel can reach
pub const MAX_PHYSICAL_ADDRESS: u64 = 4 * 1024 * 1024 * 1024;

/// Frames per MiB, used when printing sizes
const FRAMES_PER_MIB: usize = (1024 * 1024) / FRAME_SIZE;

const BITS_PER_WORD = 32;
const BITMAP_WORDS = MAX_FRAMES / BITS_PER_WORD;

/// One bit per frame: 0 - free, 1 - used 
var bitmap: [BITMAP_WORDS]u32 align(FRAME_SIZE) linksection(".bss") = undefined;

/// First frame the next allocation attempt looks at
var next_hint: usize = 0;

/// Number of frames that were usable when the allocator was made
var total_frames: usize = 0;

pub const Stats = struct {
	total: usize,
	used: usize,
	free: usize,
};

const FrameRange = struct {
	start: usize,
	end: usize,
};

fn
frame_mask(index: usize) u32
{
	return @as(u32, 1) << @as(u5, @intCast(index % BITS_PER_WORD));
}

fn
frame_is_free(index: usize) bool
{
	return bitmap[index / BITS_PER_WORD] & frame_mask(index) == 0;
}

fn
set_frame_free(index: usize) void
{
	if(index >= MAX_FRAMES) return;
	bitmap[index / BITS_PER_WORD] &= ~frame_mask(index);
}

fn
set_frame_used(index: usize) void
{
	if(index >= MAX_FRAMES) return;
	bitmap[index / BITS_PER_WORD] |= frame_mask(index);
}

fn
align_down(address: u64) u64
{
	return address & ~@as(u64, FRAME_SIZE - 1);
}

fn
align_up(address: u64) u64
{
	return align_down(address + FRAME_SIZE - 1);
}

/// Clamp a physical region to the addressable range and turn it into frame indices 
fn
clamp_region(base: u64, length: u64, inward: bool) ?FrameRange
{
	if(length == 0) return null;
	if(base >= MAX_PHYSICAL_ADDRESS) return null;

	const end = @min(base +| length, MAX_PHYSICAL_ADDRESS);
	if(end <= base) return null;

	const start = if(inward) align_up(base) else align_down(base);
	const stop = if(inward) align_down(end) else align_up(end);
	if(stop <= start) return null;

	return .{
		.start = @intCast(start / FRAME_SIZE),
		.end = @intCast(stop / FRAME_SIZE),
	};
}

fn
free_region(base: u64, length: u64) void
{
	const range = clamp_region(base, length, true) orelse return;
	var frame = range.start;
	while(frame < range.end) : (frame += 1) {
		set_frame_free(frame);
	}
}

fn
reserve_region(base: u64, length: u64) void
{
	const range = clamp_region(base, length, false) orelse return;
	var frame = range.start;
	while(frame < range.end) : (frame += 1) {
		set_frame_used(frame);
	}
}

fn
count_free() usize
{
	var free: usize = 0;
	for(&bitmap) |*word| {
		free += @as(usize, @popCount(~word.*));
	}
	return free;
}

fn
find_run(from: usize, to: usize, count: usize) ?usize
{
	if(from >= to or count > to - from) return null;

	var run: usize = 0;
	var frame = from;
	while(frame < to) : (frame += 1) {
		if(frame_is_free(frame)) {
			run += 1;
			if(run == count) return frame + 1 - count;
		} else {
			run = 0;
		}
	}
	return null;
}

/// Initialize the frame allocator from the Multiboot information structure
pub fn
init(mbi: ?*const multiboot.Info) bool
{
	// Mark everything used
	@memset(&bitmap, 0xFFFF_FFFF);
	next_hint = 0;
	total_frames = 0;

	const info = mbi orelse {
		tty.set_color(.light_red, .black);
		tty.print("PMM: no Multiboot information, no memory available\n", .{});
		tty.set_color(.white, .black);
		return false;
	};

	if(info.flags & multiboot.FLAG_MMAP == 0 or info.mmap_addr == 0 or info.mmap_length == 0) {
		tty.set_color(.light_red, .black);
		tty.print("PMM: no Multiboot memory map, no memory available\n", .{});
		tty.set_color(.white, .black);
		return false;
	}

	var it = multiboot.MmapIterator{
		.cursor = @ptrFromInt(@as(usize, info.mmap_addr)),
		.remaining = info.mmap_length,
	};

	while(it.next()) |entry| {
		if(entry.kind != @intFromEnum(multiboot.MemoryType.available)) continue;
		free_region(entry.base, entry.length);
	}

	reserve_region(0, 1024 * 1024);

	// The kernel image, including its BSS (and therefore this bitmap and the
	// boot stack).
	const kernel = memory.bounds();
	reserve_region(@intCast(kernel.start), @intCast(kernel.size()));

	// The Multiboot structure and memory map are still read by the kernel.
	reserve_region(@intFromPtr(info), @sizeOf(multiboot.Info));
	if(info.flags & multiboot.FLAG_MMAP != 0) {
		reserve_region(info.mmap_addr, info.mmap_length);
	}

	// Boot modules and the array describing them.
	if(info.flags & multiboot.FLAG_MODULES != 0 and info.mods_count != 0 and info.mods_addr != 0) {
		reserve_region(info.mods_addr, @as(u64, info.mods_count) * @sizeOf(multiboot.Module));

		const modules: [*]const multiboot.Module = @ptrFromInt(@as(usize, info.mods_addr));
		var index: u32 = 0;
		while(index < info.mods_count) : (index += 1) {
			const module = modules[index];
			reserve_region(module.mod_start, module.mod_end -| module.mod_start);
		}
	}

	total_frames = count_free();
	return true;
}

/// Allocate physically contiguous frames and return the phys address of the 1st one
pub fn
alloc_frames(count: usize) ?u32
{
	if(count == 0 or count > MAX_FRAMES) return null;

	const flags = common.irq_save();
	defer common.irq_restore(flags);

	const start = find_run(next_hint, MAX_FRAMES, count) orelse
		find_run(0, next_hint, count) orelse return null;

	var frame = start;
	while(frame < start + count) : (frame += 1) {
		set_frame_used(frame);
	}

	next_hint = (start + count) % MAX_FRAMES;
	return @intCast(start * FRAME_SIZE);
}

/// Allocate a single frame and return its physical address
pub fn
alloc_frame() ?u32
{
	return alloc_frames(1);
}

/// Allocate a single frame and set to zero 
pub fn
alloc_frame_zeroed() ?u32
{
	const address = alloc_frame() orelse return null;

	// Paging is not enabled yet, so physical addresses are directly
	// addressable. This will need a mapping once the VMM exists.
	const frame: [*]u8 = @ptrFromInt(@as(usize, address));
	@memset(frame[0..FRAME_SIZE], 0);

	return address;
}

/// Return a frame to the allocator
pub fn
free_frame(address: u32) void
{
	const flags = common.irq_save();
	defer common.irq_restore(flags);

	const physical = @as(usize, address);
	if(physical % FRAME_SIZE != 0) return;

	const index = physical / FRAME_SIZE;
	if(index >= MAX_FRAMES) return;

	set_frame_free(index);
	if(index < next_hint) next_hint = index;
}

/// Current allocator state.
pub fn
stats() Stats
{
	const flags = common.irq_save();
	defer common.irq_restore(flags);

	const free = count_free();
	return .{
		.total = total_frames,
		.used = total_frames -| free,
		.free = free,
	};
}

fn
contains(frames: []const u32, address: u32) bool
{
	for(frames) |frame| {
		if(frame == address) return true;
	}
	return false;
}

/// Boot-time sanity test: allocate and free a handful of frames and make sure
/// the allocator hands the same ones back out
pub fn
selfTest() void
{
	const before = stats();

	if(before.total == 0) {
		tty.set_color(.light_red, .black);
		tty.print("PMM self-test: FAIL (no usable frames)\n", .{});
		tty.set_color(.white, .black);
		return;
	}

	tty.print("PMM: {} frames usable ({} MiB), {} free ({} MiB)\n", .{
		before.total,
		before.total / FRAMES_PER_MIB,
		before.free,
		before.free / FRAMES_PER_MIB,
	});

	const PROBE_COUNT = 8;
	var ok = true;

	var first: [PROBE_COUNT]u32 = undefined;
	var allocated: usize = 0;
	for(&first) |*address| {
		const frame = alloc_frame() orelse {
			ok = false;
			break;
		};

		if(@as(usize, frame) % FRAME_SIZE != 0) ok = false;
		if(contains(first[0..allocated], frame)) ok = false;

		address.* = frame;
		allocated += 1;
	}

	for(first[0..allocated]) |address| {
		free_frame(address);
	}

	var second: [PROBE_COUNT]u32 = undefined;
	var reused: usize = 0;
	for(&second) |*address| {
		const frame = alloc_frame() orelse {
			ok = false;
			break;
		};

		if(!contains(first[0..allocated], frame)) ok = false;

		address.* = frame;
		reused += 1;
	}
	if(reused != allocated) ok = false;

	for(second[0..reused]) |address| {
		free_frame(address);
	}

	const RUN_LENGTH = 4;
	if(alloc_frames(RUN_LENGTH)) |base| {
		if(@as(usize, base) % FRAME_SIZE != 0) ok = false;

		var index: usize = 0;
		while(index < RUN_LENGTH) : (index += 1) {
			free_frame(@intCast(@as(usize, base) + index * FRAME_SIZE));
		}
	} else {
		ok = false;
	}

	if(alloc_frame_zeroed()) |address| {
		if(@as(usize, address) % FRAME_SIZE != 0) ok = false;

		const frame: [*]const u8 = @ptrFromInt(@as(usize, address));
		for(frame[0..FRAME_SIZE]) |byte| {
			if(byte != 0) {
				ok = false;
				break;
			}
		}

		free_frame(address);
	} else {
		ok = false;
	}

	const after = stats();
	if(after.free != before.free) ok = false;

	if(ok) {
		tty.print("PMM self-test: PASS ({} frames reused, {} free after)\n", .{
			reused,
			after.free,
		});
	} else {
		tty.set_color(.light_red, .black);
		tty.print("PMM self-test: FAIL ({} free frames before, {} after)\n", .{
			before.free,
			after.free,
		});
		tty.set_color(.white, .black);
	}
}
