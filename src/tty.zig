// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");
const common = @import("common.zig");
const serial = @import("serial.zig");

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

const CRTC_INDEX_PORT: u16 = 0x3D4;
const CRTC_DATA_PORT: u16 = 0x3D5;

const CURSOR_LOCATION_HIGH: u8 = 0x0E;
const CURSOR_LOCATION_LOW: u8 = 0x0F;

var global_row: usize = 0;
var global_col: usize = 0;
var global_color: Color = .init(.light_brown, .black);
var global_buffer = @as([*]volatile u16, @ptrFromInt(0xB8000)); // Address of Video Memory

pub const ColorType = enum(u4) {
	black,
	blue,
	green,
	cyan,
	red,
	magenta,
	brown,
	light_gray,
	dark_gray,
	light_blue,
	light_green,
	light_cyan,
	light_red,
	light_magenta,
	light_brown,
	white,
};

const Color = packed struct(u8) {
	fg: ColorType,
	bg: ColorType,

	pub fn 
	init(fg: ColorType, bg: ColorType) Color 
	{
		return .{ .fg = fg, .bg = bg };
	}

	pub fn 
	get_vga_char(self: Color, char: u8) u16 
	{
		return @as(u16, @as(u8, @bitCast(self))) << 8 | char;
	}
};

pub fn 
init() void 
{
	clear();
}

/// Move the hardware cursor to the current typing position
fn
update_cursor() void 
{
	const position: u16 = @intCast(global_row * VGA_WIDTH + global_col);

	common.outb(CRTC_INDEX_PORT, CURSOR_LOCATION_HIGH);
	common.outb(CRTC_DATA_PORT, @intCast((position >> 8) & 0xFF));

	common.outb(CRTC_INDEX_PORT, CURSOR_LOCATION_LOW);
	common.outb(CRTC_DATA_PORT, @intCast(position & 0xFF));
}

pub fn 
set_color(fg: ColorType, bg: ColorType) void 
{
	global_color = Color.init(fg, bg);
}

pub fn 
clear() void 
{
	@memset(global_buffer[0..VGA_SIZE], Color.get_vga_char(global_color, ' '));
	update_cursor();
}

pub fn 
print_char_at(char: u8, color: Color, x: usize, y: usize) void 
{
	const index = y * VGA_WIDTH + x;
	global_buffer[index] = color.get_vga_char(char);
}

fn 
check_and_scroll() void 
{
	if(global_row >= VGA_HEIGHT) {
		for(0..((VGA_HEIGHT - 1) * VGA_WIDTH)) |index| {
			global_buffer[index] = global_buffer[index + VGA_WIDTH];
		}
		for(0..(VGA_WIDTH)) |index| {
			print_char_at(' ', global_color, index, 24);
		}
		global_row = VGA_HEIGHT - 1;
	}
}

pub fn 
print_char(char: u8) void 
{
	switch (char) {
		'\n' => {
			global_col = 0;
			global_row += 1;
			check_and_scroll();
		},
		else => {
			print_char_at(char, global_color, global_col, global_row);
			global_col += 1;
			if(global_col == VGA_WIDTH) {
				global_col = 0;
				global_row += 1;
				check_and_scroll();
			}
		},
	}

	update_cursor();
}

/// Implementation of std.Io.Writer.vtable.drain function
fn 
drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize 
{
	std.debug.assert(data.len != 0);

	var consumed: usize = 0;
	const pattern = data[data.len - 1];
	const splat_len = pattern.len * splat;

	if(w.end != 0) {
		print_string(w.buffered());
		w.end = 0;
	}

	for(data[0 .. data.len - 1]) |bytes| {
		print_string(bytes);
		consumed += bytes.len;
	}

	switch(pattern.len) {
		0 => {},
		else => {
			for (0..splat) |_| {
				print_string(pattern);
			}
		},
	}

	consumed += splat_len;
	return consumed;
}

pub fn 
writer(buffer: []u8) std.Io.Writer 
{
	return .{
		.buffer = buffer,
		.end = 0,
		.vtable = &.{
			.drain = drain,
		},
	};
}

pub fn 
print_string(str: []const u8) void 
{
	for(str) |char| {
		print_char(char);
		serial.write_char(char);
	}
}

pub fn 
print(comptime fmt: []const u8, args: anytype) void 
{
	var w = writer(&.{});
	w.print(fmt, args) catch return;
}
