pub fn halt() void {
    while (true) asm volatile ("hlt");
}
