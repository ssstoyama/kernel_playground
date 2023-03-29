export fn kernel_main() void {
    halt();
}

fn halt() void {
    while (true) {
        asm volatile ("hlt");
    }
}
