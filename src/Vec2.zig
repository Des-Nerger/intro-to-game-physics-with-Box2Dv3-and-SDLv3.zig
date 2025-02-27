//! 2D vector
//! This can be used to represent a point or free vector

x: f32,
y: f32,

pub const zero = Self{ .x = 0, .y = 0 };

const Self = @This();
const assert = debug.assert;
const debug = std.debug;
const lib = @import("lib.zig");
const math = std.math;
const std = @import("std");
const testing = std.testing;

/// Vector addition
pub fn add(a: Self, b: Self) Self {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}
test add {
    try testing.expectEqual(
        (Self{ .x = 0.25, .y = 1.50 }).add(.{ .x = 2.75, .y = 3.00 }),
        Self{ .x = 3.00, .y = 4.50 },
    );
}

/// Compute the rotation between two unit vectors
pub fn computeRotationBetweenUnits(v1: Self, v2: Self) lib.Rot {
    assert(@abs(1.0 - v1.length()) < 100.0 * math.floatEps(f32));
    assert(@abs(1.0 - v2.length()) < 100.0 * math.floatEps(f32));
    return (lib.Rot{ .c = v1.dot(v2), .s = v1.cross(v2) }).normalize();
}
test computeRotationBetweenUnits {
    const angle = math.acos(@as(f32, 0.96));
    const wanted_rot = lib.Rot{ .c = @cos(angle), .s = @sin(angle) };
    const got_rot = computeRotationBetweenUnits(
        Self{ .x = 0.8, .y = 0.6 },
        Self{ .x = 0.6, .y = 0.8 },
    );
    inline for ([_]*const [1:0]u8{ "c", "s" }) |field_name|
        try testing.expectApproxEqAbs(
            @field(got_rot, field_name),
            @field(wanted_rot, field_name),
            lib.atan_tol,
        );
}

/// Vector cross product. In 2D this yields a scalar.
pub fn cross(a: Self, b: Self) f32 {
    return a.x * b.y - a.y * b.x;
}
test cross {
    const a, const b = .{ Self{ .x = 1.0, .y = 0.0 }, Self{ .x = 3.0, .y = -4.0 } };
    try testing.expectEqual(
        a.cross(b),
        a.length() * b.length() * @sin(math.atan2(b.y, b.x)),
    );
}

/// Vector dot product
pub fn dot(a: Self, b: Self) f32 {
    return a.x * b.x + a.y * b.y;
}
test dot {
    try testing.expectEqual(
        (Self{ .x = 1.5, .y = 3.75 }).dot(.{ .x = -0.5, .y = 4 }),
        14.25,
    );
}

/// Convert a vector into a unit vector if possible, otherwise returns the zero vector. Also
/// outputs the length.
pub fn getLengthAndNormalize(v: Self) struct { f32, Self } {
    const length = v.length();
    if (length < math.floatEps(f32))
        return .{ length, Self.zero };

    const inv_len = 1.0 / length;
    return .{ length, Self{ .x = inv_len * v.x, .y = inv_len * v.y } };
}
test getLengthAndNormalize {
    try testing.expectEqual(
        (Self{ .x = 4.0, .y = -3.0 }).getLengthAndNormalize(),
        .{ 5.0, Self{ .x = 0.8, .y = -0.6 } },
    );
}

pub usingnamespace struct {
    /// Get the length of this vector (the norm)
    pub fn length(v: Self) f32 {
        return @sqrt(v.lengthSquared());
    }
    test length {
        try testing.expectEqual((Self{ .x = 3.0, .y = 4.0 }).length(), 5.0);
    }
};

/// Get the length squared of this vector
pub fn lengthSquared(v: Self) f32 {
    return v.x * v.x + v.y * v.y;
}
test lengthSquared {
    try testing.expectEqual((Self{ .x = 3.0, .y = 4.0 }).lengthSquared(), 25.0);
}

/// Multiply a vector and scalar
pub fn mulSc(v: Self, sc: f32) Self {
    return .{ .x = sc * v.x, .y = sc * v.y };
}
test mulSc {
    try testing.expectEqual(
        (Self{ .x = 1.50, .y = 3.00 }).mulSc(0.50),
        Self{ .x = 0.75, .y = 1.50 },
    );
}

/// Convert a vector into a unit vector if possible, otherwise returns the zero vector.
pub fn normalize(v: Self) Self {
    return v.getLengthAndNormalize().@"1";
}
test normalize {
    try testing.expectEqual(
        (Self{ .x = 3.0, .y = 4.0 }).normalize(),
        Self{ .x = 0.6, .y = 0.8 },
    );
}

pub fn reflect(n: Self, u: Self) Self {
    return u.add(n.mulSc(-2.0 * u.dot(n)));
}
test reflect {
    try testing.expectEqual(
        (Self{ .x = 0.0, .y = 1.0 }).reflect(.{ .x = -4.0, .y = 3.0 }),
        Self{ .x = -4.0, .y = -3.0 },
    );
}

pub inline fn reflect2(n: Self, u: Self, v: Self) [2]Self {
    const m = u.sub(v).dot(n);
    const mn = n.mulSc(m);
    return .{ u.sub(mn), v.add(mn) };
}
// test reflect2 {
//     try testing.expectEqual(
//         // TODO
//     );
// }

/// Rotate a vector
pub fn rotate(v: Self, q: lib.Rot) Self {
    return .{ .x = q.c * v.x - q.s * v.y, .y = q.s * v.x + q.c * v.y };
}
test rotate {
    try testing.expectEqual(
        (Self{ .x = 3.0, .y = 4.0 }).rotate(.{ .c = 0.8, .s = 0.6 }),
        Self{ .x = 0.0, .y = 5.0 },
    );
}

/// Vector subtraction
pub fn sub(a: Self, b: Self) Self {
    return .{ .x = a.x - b.x, .y = a.y - b.y };
}
test sub {
    try testing.expectEqual(
        (Self{ .x = 3.25, .y = -4.75 }).sub(.{ .x = 0.5, .y = -0.25 }),
        Self{ .x = 2.75, .y = -4.5 },
    );
}
