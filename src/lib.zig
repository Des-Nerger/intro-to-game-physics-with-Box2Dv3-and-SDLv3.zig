pub const Rot = @import("Rot.zig");
pub const Vec2 = @import("Vec2.zig");
/// 0.0023 degrees
pub const atan_tol = 0.00004;
const math = std.math;
const std = @import("std");
const testing = std.testing;

test {
    testing.refAllDecls(@This());
}

/// https://stackoverflow.com/questions/46210708/atan2-approximation-with-11bits-in-mantissa-on-x86with-sse2-and-armwith-vfpv4
pub fn atan2(y: f32, x: f32) f32 {
    // Added check for (0,0) to match math.atan2 and avoid NaN
    if (x == 0.0 and y == 0.0)
        return 0.0;

    const ax, const ay = .{ @abs(x), @abs(y) };
    const mn, const mx = .{ @min(ay, ax), @max(ay, ax) };
    const a = mn / mx;

    // Minimax polynomial approximation to atan(a) on [0,1]
    const s = a * a;
    const c, const q = .{ s * a, s * s };
    var r, const t = .{ 0.024840285 * q + 0.18681418, -0.094097948 * q - 0.33213072 };
    r = r * s + t;
    r = r * c + a;

    // Map to full circle
    if (ay > ax)
        r = 1.57079637 - r;

    if (x < 0)
        r = 3.14159274 - r;

    if (y < 0)
        r = -r;

    return r;
}
test atan2 {
    try testing.expectApproxEqAbs(
        atan2(-1.0, 2.0),
        math.atan2(@as(f32, -1.0), 2.0),
        atan_tol,
    );
}
