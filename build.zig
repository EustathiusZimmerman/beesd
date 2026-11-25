// Copyright 2026 - 2026, Eustathius Zimmerman and the BEESD contributors
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");

const Bootloader = enum {
	grub,
	limine,
};

pub fn build(b: *std.Build) !void {
	const optimize = b.standardOptimizeOption(.{});
	const bootloader = b.option(Bootloader, "bootloader", "Bootloader to use for the ISO image") orelse .grub;

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

	const git_hash_raw = b.run(&.{"git", "rev-parse", "--short", "HEAD"});
	const git_hash = std.mem.trim(u8, git_hash_raw, &std.ascii.whitespace);

	var buf: [64] u8 = undefined;
	const iso_name = switch (bootloader) {
		.grub => try std.fmt.bufPrint(&buf, "beesd-{s}-{s}-grub.iso", .{@tagName(target.result.cpu.arch), git_hash}),
		.limine => try std.fmt.bufPrint(&buf, "beesd-{s}-{s}-limine.iso", .{@tagName(target.result.cpu.arch), git_hash}),
	};

	const iso_path = switch (bootloader) {
		.grub => build_grub_iso(b, kernel, iso_name),
		.limine => build_limine_iso(b, kernel, iso_name),
	};

	const install_iso = b.addInstallFileWithDir(iso_path, .prefix, iso_name);

	const iso_step = b.step("iso", switch (bootloader) {
		.grub => "Build an ISO image with the GRUB bootloader",
		.limine => "Build an ISO image with the Limine bootloader",
	});
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

	const run_img_step = b.step("run", switch (bootloader) {
		.grub => "Run the ISO image with the GRUB bootloader installed",
		.limine => "Run the ISO image with the Limine bootloader installed",
	});
	run_img_step.dependOn(&run_img_cmd.step);
}

fn build_grub_iso(b: *std.Build, kernel: *std.Build.Step.Compile, iso_name: []const u8) std.Build.LazyPath {
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
	const iso_path = grub_mkrescue.addOutputFileArg(iso_name);
	grub_mkrescue.addDirectoryArg(iso_root.getDirectory());

	return iso_path;
}

fn build_limine_iso(b: *std.Build, kernel: *std.Build.Step.Compile, iso_name: []const u8) std.Build.LazyPath {
	const datadir_raw = b.run(&.{"limine", "--print-datadir"});
	const datadir = std.mem.trim(u8, datadir_raw, &std.ascii.whitespace);

	const iso_root = b.addWriteFiles();
	_ = iso_root.addCopyFile(kernel.getEmittedBin(), "boot/kernel.elf");
	_ = iso_root.addCopyFile(b.path("assets/banner.png"), "boot/beesd.png");
	_ = iso_root.add("boot/limine.conf",
		\\timeout: 5
		\\default_entry: 1
		\\
		\\wallpaper: boot():/boot/beesd.png
		\\
		\\/BEESD
		\\    protocol: multiboot1
		\\    path: boot():/boot/kernel.elf
		\\
	);

	// Files Limine needs to boot from BIOS and UEFI optical media.
	_ = iso_root.addCopyFile(cwd_path(b, datadir, "limine-bios-cd.bin"), "boot/limine-bios-cd.bin");
	_ = iso_root.addCopyFile(cwd_path(b, datadir, "limine-bios.sys"), "boot/limine-bios.sys");
	_ = iso_root.addCopyFile(cwd_path(b, datadir, "limine-uefi-cd.bin"), "boot/limine-uefi-cd.bin");
	_ = iso_root.addCopyFile(cwd_path(b, datadir, "BOOTX64.EFI"), "EFI/BOOT/BOOTX64.EFI");

	const xorriso = b.addSystemCommand(&[_][]const u8{
		"xorriso",
		"-as",
		"mkisofs",
		"-R",
		"-r",
		"-J",
		"-b",
		"boot/limine-bios-cd.bin",
		"-no-emul-boot",
		"-boot-load-size",
		"4",
		"-boot-info-table",
		"-hfsplus",
		"-apm-block-size",
		"2048",
		"--efi-boot",
		"boot/limine-uefi-cd.bin",
		"-efi-boot-part",
		"--efi-boot-image",
		"--protective-msdos-label",
		"-o",
	});
	const raw_iso = xorriso.addOutputFileArg("limine.iso");
	xorriso.addDirectoryArg(iso_root.getDirectory());

	const limine_install = b.addSystemCommand(&[_][]const u8{
		"sh",
		"-c",
		"cp -- \"$1\" \"$2\" && limine bios-install --quiet \"$2\"",
		"sh",
	});
	limine_install.addFileArg(raw_iso);
	const iso_path = limine_install.addOutputFileArg(iso_name);

	return iso_path;
}

fn cwd_path(b: *std.Build, dir: []const u8, name: []const u8) std.Build.LazyPath {
	return b.graph.cwdRelativePath(b.pathJoin(&.{ dir, name }));
}
