const std = @import("std");
const c = @import("cpu.zig");
const Bus = @import("bus.zig").Bus;

pub fn main() !void {
    var bus = Bus{};

    var cpu = c.CPU.init(&bus);
    test_init(&bus);
    cpu.reset();
    cpu.print_state();
}

fn test_init(bus: *Bus) void {
    // Reset vector to 0x0000
    bus.write(0xfffc, 0x10);
    bus.write(0xfffd, 0x20);
}

test "loading reset vector into pc" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    test_init(&bus);
    cpu.reset();
    assert(cpu.PC == 0x2010);
}
