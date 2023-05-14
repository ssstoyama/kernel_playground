pub fn getCS() u16 {
    return asm volatile (
        \\ xor %rax, %rax
        \\ mov %cs, %ax
        : [ret] "={ax}" (-> u16),
    );
}

// limit: idt size
// base: idt base address
pub fn loadIDT(limit: u16, base: u64) void {
    const idtr = packed struct {
        limit: u16,
        base: u64,
    }{
        .limit = limit,
        .base = base,
    };
    asm volatile (
        \\ lidt (%rdi)
        : // no output
        : [idtr] "{rdi}" (&idtr),
    );
}
