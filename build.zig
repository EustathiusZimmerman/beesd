// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");

pub fn build(b: *std.Build) !void {
	const optimize = b.standardOptimizeOption(.{});

	const Target = std.Target.x86;
	const target = b.resolveTargetQuery(.{
		.cpu_arch = .x86,
		.os_tag = .freestanding,
		.abi = .none,
		.cpu_features_add = Target.featureSet(&.{
			.soft_float,
		}),
		.cpu_features_sub = Target.featureSet(&.{
			.avx,
			.avx2,
			.sse,
			.sse2,
			.mmx,
		}),
	});

	const kernel = b.addExecutable(.{
		.name = "kernel.elf",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/kernel.zig"),
			.target = target,
			.optimize = optimize,
			.code_model = .kernel,
		}),
	});

	kernel.root_module.addAssemblyFile(b.path("src/interrupts.S"));
	kernel.setLinkerScript(b.path("src/linker.ld"));
	b.installArtifact(kernel);

	const iso_root = b.addWriteFiles();
	_ = iso_root.addCopyFile(kernel.getEmittedBin(), "boot/kernel.elf");
	// GRUB's PNG reader only supports non-interlaced images.
	_ = iso_root.addCopyFile(b.path("assets/banner.png"), "grub/beesd.png");
	_ = iso_root.add("boot/grub/grub.cfg",
		\\insmod all_video
		\\insmod png
		\\insmod font
		\\insmod gfxterm
		\\insmod gfxterm_background
		\\
		\\set gfxmode=auto
		\\loadfont /boot/grub/fonts/unicode.pf2
		\\terminal_output gfxterm
		\\
		\\background_image /grub/beesd.png
		\\
		\\set timeout=5
		\\set default=0
		\\
		\\menuentry "BEESD" {
		\\  multiboot /boot/kernel.elf
		\\  boot
		\\}
		\\
	);

	const grub_mkrescue = b.addSystemCommand(&[_][]const u8{
		"grub-mkrescue",
		"-o",
	});
	const git_hash_raw = b.run(&.{"git", "rev-parse", "--short", "HEAD"});
	const git_hash = std.mem.trim(u8, git_hash_raw, &std.ascii.whitespace);

	var buf: [64] u8 = undefined;
	const iso_name = try std.fmt.bufPrint(&buf, "beesd-{s}-{s}.iso", .{@tagName(target.result.cpu.arch), git_hash});
	const iso_path = grub_mkrescue.addOutputFileArg(iso_name);
	grub_mkrescue.addDirectoryArg(iso_root.getDirectory());

	const install_iso = b.addInstallFileWithDir(iso_path, .prefix, iso_name);

	const iso_step = b.step("iso", "Build an ISO image with GRUB bootloader");
	iso_step.dependOn(&install_iso.step);

	const kernel_path = kernel.getEmittedBin();
	const qemu_raw_cmd = b.addSystemCommand(&[_][]const u8{
		"qemu-system-x86_64",
		"-m",
		"1G",
		"-serial",
		"stdio",
	});

	qemu_raw_cmd.addArg("-kernel");
	qemu_raw_cmd.addFileArg(kernel_path);
	qemu_raw_cmd.step.dependOn(b.getInstallStep());

	const run_raw_cmd = b.addRunArtifact(kernel);
	run_raw_cmd.step.dependOn(&qemu_raw_cmd.step);

	const run_raw_step = b.step("run-raw", "Run the raw kernel with QEMU");
	run_raw_step.dependOn(&run_raw_cmd.step);

	const qemu_img_cmd = b.addSystemCommand(&[_][]const u8{
		"qemu-system-x86_64",
		"-m",
		"1G",
		"-serial",
		"stdio",
	});

	qemu_img_cmd.addArg("-cdrom");
	qemu_img_cmd.addFileArg(iso_path);
	qemu_img_cmd.step.dependOn(iso_step);

	const run_img_cmd = b.addRunArtifact(kernel);
	run_img_cmd.step.dependOn(&qemu_img_cmd.step);

	const run_img_step = b.step("run", "Run the ISO image with GRUB bootloader installed");
	run_img_step.dependOn(&run_img_cmd.step);
}
