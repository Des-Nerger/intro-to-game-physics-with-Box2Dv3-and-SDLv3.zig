//! 2D rotation
//! This is similar to using a complex number for rotation

/// cosine
c: f32,

/// sine.
/// Unlike in mathematics, its sign is negated in order to match Y-axis going down in SDL coordinate system.
s: f32,

pub const identity = Self{ .c = 1, .s = 0 };

const Self = @This();
const lib = @import("lib.zig");
const math = std.math;
const std = @import("std");
const testing = std.testing;

/// Get the counter-clockwise angle in radians in the range [-pi, pi]
pub fn toRadians(q: Self) f32 {
    return lib.atan2(-q.s, q.c); // s is negated due to Y-axis going down in SDL coordinate system
}
test toRadians {
    try testing.expectApproxEqAbs(
        (Self{ .c = -0.5, .s = 0.5 }).toRadians(),
        -3.0 * math.pi / 4.0,
        lib.atan_tol,
    );
}

/// Make a rotation using a counter-clockwise angle in radians
pub fn fromRadians(radians: f32) Self {
    return .{ .c = @cos(radians), .s = -@sin(radians) }; // s is negated due to Y-axis going down in SDL coords
}

/// Negate the angle by conjugating the complex number.
pub fn angleNeg(q: Self) Self {
    return .{ .c = q.c, .s = -q.s };
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

/// Multiply two rotations: q * r
pub fn mul(q: Self, r: Self) Self {
    return .{ .c = q.c * r.c - q.s * r.s, .s = q.s * r.c + q.c * r.s };
}
test mul {
    try testing.expectEqual(
        (Self{ .c = 0.6, .s = 0.8 }).mul(.{ .c = 0.6, .s = -0.8 }),
        Self{ .c = 1, .s = 0 },
    );
}
