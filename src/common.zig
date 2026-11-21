pub fn 
outb(port: u16, data: u8) void 
{
	asm volatile (
		\\ outb %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{al}" (data),
	);
}

pub fn 
outw(port: u16, data: u16) void 
{
	asm volatile (
		\\ outw %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{ax}" (data),
	);
}


pub fn 
outl(port: u16, data: u32) void 
{
	asm volatile (
		\\ outw %[data], %[port]
		:
		: [port] "{dx}" (port),
		  [data] "{eax}" (data),
	);
}

pub fn 
disable_interrupts() void
{
	asm volatile (
		\\ cli
	);
}

pub fn 
enable_interrupts() void
{
	asm volatile (
		\\ sti
	);
}

pub fn 
halt_cpu() void
{
	asm volatile (
		\\ hlt
	);
}
