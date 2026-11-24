// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const common = @import("common.zig");
const idt = @import("idt.zig");
const pic = @import("pic.zig");
const tty = @import("tty.zig");
const std = @import("std");

const PS2_DATA_PORT: u16 = 0x60;
const PS2_STATUS_PORT: u16 = 0x64;


const STATUS_OUT: u8 = 1 << 0;

const KEYBOARD_IRQ: u8 = 1;

/// Used for extended 2 byte scancodes in set №1
const SCANCODE_EXTENDED: u8 = 0xE0;

const SCANCODE_RELEASE: u8 = 0x80;

const KeyEvent = struct {
	scancode: u8,
	extended: bool,
};

const UNKNOWN_KEY = "Unknown";

const key_names: [128][]const u8 = bulk: {
	var names: [128][]const u8 = @splat(UNKNOWN_KEY);

	names[0x01] = "Escape";
	names[0x02] = "1";
	names[0x03] = "2";
	names[0x04] = "3";
	names[0x05] = "4";
	names[0x06] = "5";
	names[0x07] = "6";
	names[0x08] = "7";
	names[0x09] = "8";
	names[0x0A] = "9";
	names[0x0B] = "0";
	names[0x0C] = "Minus";
	names[0x0D] = "Equals";
	names[0x0E] = "Backspace";
	names[0x0F] = "Tab";
	names[0x10] = "Q";
	names[0x11] = "W";
	names[0x12] = "E";
	names[0x13] = "R";
	names[0x14] = "T";
	names[0x15] = "Y";
	names[0x16] = "U";
	names[0x17] = "I";
	names[0x18] = "O";
	names[0x19] = "P";
	names[0x1A] = "Left Bracket";
	names[0x1B] = "Right Bracket";
	names[0x1C] = "Enter";
	names[0x1D] = "Left Ctrl";
	names[0x1E] = "A";
	names[0x1F] = "S";
	names[0x20] = "D";
	names[0x21] = "F";
	names[0x22] = "G";
	names[0x23] = "H";
	names[0x24] = "J";
	names[0x25] = "K";
	names[0x26] = "L";
	names[0x27] = "Semicolon";
	names[0x28] = "Apostrophe";
	names[0x29] = "Backtick";
	names[0x2A] = "Left Shift";
	names[0x2B] = "Backslash";
	names[0x2C] = "Z";
	names[0x2D] = "X";
	names[0x2E] = "C";
	names[0x2F] = "V";
	names[0x30] = "B";
	names[0x31] = "N";
	names[0x32] = "M";
	names[0x33] = "Comma";
	names[0x34] = "Period";
	names[0x35] = "Slash";
	names[0x36] = "Right Shift";
	names[0x37] = "Keypad *";
	names[0x38] = "Left Alt";
	names[0x39] = "Space";
	names[0x3A] = "Caps Lock";
	names[0x3B] = "F1";
	names[0x3C] = "F2";
	names[0x3D] = "F3";
	names[0x3E] = "F4";
	names[0x3F] = "F5";
	names[0x40] = "F6";
	names[0x41] = "F7";
	names[0x42] = "F8";
	names[0x43] = "F9";
	names[0x44] = "F10";
	names[0x45] = "Num Lock";
	names[0x46] = "Scroll Lock";
	names[0x47] = "Keypad 7";
	names[0x48] = "Keypad 8";
	names[0x49] = "Keypad 9";
	names[0x4A] = "Keypad -";
	names[0x4B] = "Keypad 4";
	names[0x4C] = "Keypad 5";
	names[0x4D] = "Keypad 6";
	names[0x4E] = "Keypad +";
	names[0x4F] = "Keypad 1";
	names[0x50] = "Keypad 2";
	names[0x51] = "Keypad 3";
	names[0x52] = "Keypad 0";
	names[0x53] = "Keypad .";
	names[0x54] = "SysRq";
	names[0x57] = "F11";
	names[0x58] = "F12";

	break :bulk names;
};

const extended_key_names: [128][]const u8 = bulk: {
	var names: [128][]const u8 = @splat(UNKNOWN_KEY);

	names[0x1C] = "Keypad Enter";
	names[0x1D] = "Right Ctrl";
	names[0x35] = "Keypad /";
	names[0x37] = "Print Screen";
	names[0x38] = "Right Alt";
	names[0x46] = "Pause";
	names[0x47] = "Home";
	names[0x48] = "Up Arrow";
	names[0x49] = "Page Up";
	names[0x4B] = "Left Arrow";
	names[0x4D] = "Right Arrow";
	names[0x4F] = "End";
	names[0x50] = "Down Arrow";
	names[0x51] = "Page Down";
	names[0x52] = "Insert";
	names[0x53] = "Delete";
	names[0x5B] = "Left Super";
	names[0x5C] = "Right Super";
	names[0x5D] = "Menu";
	names[0x5E] = "Power";
	names[0x5F] = "Sleep";
	names[0x63] = "Wake";

	break :bulk names;
};

fn
key_name(event: KeyEvent) []const u8 {
	const code = event.scancode & ~SCANCODE_RELEASE;
	const names = if(event.extended) &extended_key_names else &key_names;

	return names[code];
}

const BUFFER_SIZE: usize = 64;

var buffer: [BUFFER_SIZE]KeyEvent = undefined;
var head: usize = 0;
var tail: usize = 0;

var extended: bool = false;
var minimal: bool = true;

fn
read_data() ?u8 
{
	const status = common.inb(PS2_STATUS_PORT);
	if((status & STATUS_OUT) == 0) return null;
	return common.inb(PS2_DATA_PORT);
}

fn
flush() void 
{
	while(read_data() != null) {}
}

fn
push(event: KeyEvent) void
{
	const next = (head + 1) % BUFFER_SIZE;
	if(next == tail) return; // Buffer full: stop everything and start screaming
	buffer[head] = event;
	head = next;
}

fn
on_interrupt(frame: *idt.InterruptFrame) void {
	_ = &frame;

	const scancode = read_data() orelse return;

	if(scancode == SCANCODE_EXTENDED) {
		extended = true;
		return;
	}

	push(.{.scancode = scancode, .extended = extended});
	extended = false;
}

pub fn
init() void
{
	idt.register_irq(KEYBOARD_IRQ, on_interrupt);

	flush();

	pic.unmask(KEYBOARD_IRQ);
}

pub fn
drain() void
{
	while(tail != head) {
		const event = buffer[tail];
		tail = (tail + 1) % BUFFER_SIZE;

		const state = if((event.scancode & SCANCODE_RELEASE) != 0) "released" else "pressed";
		const kind = if(event.extended) "extended, " else "";

		if((event.scancode & SCANCODE_RELEASE) != 0) {
			minimal = if((std.mem.eql(u8, key_name(event), "Home"))) !minimal else minimal;
		}

		if(minimal) {
			if((event.scancode & SCANCODE_RELEASE) == 0) {
				if(std.mem.eql(u8, key_name(event), "Space")) {
					tty.print(" ", .{});
				} else if(std.mem.eql(u8, key_name(event), "Enter")) {
					tty.print("\n", .{});
				} else {
					tty.print("{s}", .{key_name(event)});
				}
			}
		} else {
			tty.print("scancode 0x{x:0>2}: {s} ({s}{s})\n", .{ event.scancode, key_name(event), kind, state });
		}

	}
}
