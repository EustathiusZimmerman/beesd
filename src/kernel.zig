const tty = @import("tty.zig");

const MULTIBOOT_HEADER_MAGIC = 0x1BADB002;
const MULTIBOOT_FLAG_ALIGN = 1 << 0;
const MULTIBOOT_FLAG_MEMINFO = 1 << 1;
const FLAGS = MULTIBOOT_FLAG_ALIGN | MULTIBOOT_FLAG_MEMINFO;

const MultibootHeader = packed struct(u128) {
	magic:    u32 = MULTIBOOT_HEADER_MAGIC,
	flags:    u32 = FLAGS,
	checksum: u32,
	padding:  u32 = 0,
};

export var multiboot: MultibootHeader align(4) linksection(".multiboot") = .{
	.checksum = ~@as(u32, (MULTIBOOT_HEADER_MAGIC + FLAGS)) + 1,
};

var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

// Naked means no function prologue and epilogue
// cuz there ain't no stack yet
export fn 
_start() callconv(.naked) noreturn 
{
	asm volatile (
		\\ movl %[stack_top], %%esp
		\\ movl %%esp, %%ebp
		\\ call %[kmain:P]
		:
		: [stack_top] "i" (stack_bytes[stack_bytes.len..].ptr),
		  [kmain] "X" (&kmain),
	);
}

noinline fn 
kmain() callconv(.c) noreturn 
{
	tty.init();
	tty.print("{s} kernel", .{"BEESD"});

	while(true) {
		asm volatile (
			\\ hlt
		);
	}
}
