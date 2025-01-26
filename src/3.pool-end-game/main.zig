const Ball = @import("Ball.zig");
const std = @import("std");
// const testing = std.testing;

// test {
//     testing.refAllDecls(@This());
// }

pub fn main() void {
    _ = Ball;
    std.debug.print("{s}()\n", .{@src().fn_name});
}
