// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Kernel image bounds, defined by src/linker.ld.
extern const kernel_start: u8;
extern const kernel_end: u8;

/// The page size used by the kernel.
pub const PAGE_SIZE: usize = 4096;

pub const Bounds = struct {
	start: usize,
	end: usize,

	pub fn size(self: Bounds) usize {
		return self.end - self.start;
	}
};

/// The physical range occupied by the kernel image, including its BSS.
pub fn bounds() Bounds {
	return .{
		.start = @intFromPtr(&kernel_start),
		.end = @intFromPtr(&kernel_end),
	};
}
