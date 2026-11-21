const std = @import("std");

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

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
		return .{.fg = fg, .bg = bg};
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

pub fn 
set_color(fg: ColorType, bg: ColorType) void
{
	global_color = Color.init(fg, bg);
}

pub fn
clear() void
{
	@memset(global_buffer[0..VGA_SIZE], Color.get_vga_char(global_color, ' '));
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
	if(global_row == VGA_HEIGHT) {
		global_row = 0;
	}
}

pub fn
print_char(char: u8) void 
{
	switch(char) {
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
			for(0..splat) |_| {
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
	}
}

pub fn 
print(comptime fmt: []const u8, args: anytype) void
{
	var w = writer(&.{});
	w.print(fmt, args) catch return;
}
