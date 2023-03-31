var global: u8 = undefined;

export fn kernel_main() void {
    global = 100;
    halt();
}

fn halt() void {
    while (true) {
        asm volatile ("hlt");
    }
}
