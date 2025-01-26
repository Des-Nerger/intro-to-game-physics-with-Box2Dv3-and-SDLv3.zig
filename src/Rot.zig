//! 2D rotation
//! This is similar to using a complex number for rotation

/// cosine
c: f32,

/// sine
s: f32,

const Self = @This();
const lib = @import("lib.zig");
const math = std.math;
const std = @import("std");
const testing = std.testing;

/// Get the angle in radians in the range [-pi, pi]
pub fn getAngle(q: Self) f32 {
    return lib.atan2(q.s, q.c);
}
test getAngle {
    try testing.expectApproxEqAbs(
        (Self{ .c = -0.5, .s = -0.5 }).getAngle(),
        -3.0 * math.pi / 4.0,
        lib.atan_tol,
    );
}

/// Normalize rotation
pub fn normalize(q: Self) Self {
    const mag = @sqrt(q.s * q.s + q.c * q.c);
    const inv_mag = if (mag > 0.0) 1.0 / mag else 0.0;
    return .{ .c = q.c * inv_mag, .s = q.s * inv_mag };
}
test normalize {
    try testing.expectEqual(
        (Self{ .c = 4.0, .s = -3.0 }).normalize(),
        Self{ .c = 0.8, .s = -0.6 },
    );
}
