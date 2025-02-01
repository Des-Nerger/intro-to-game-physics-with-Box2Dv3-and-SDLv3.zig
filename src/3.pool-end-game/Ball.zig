/// position or point
p: lib.Vec2,

/// velocity
v: lib.Vec2,

/// radius
r: f32,

const Self = @This();
const assert = debug.assert;
const debug = std.debug;
const lib = @import("lib");
const math = std.math;
const std = @import("std");

pub fn bounceWithStationary(b: *Self, b0: Self) bool {
    assert(b0.v < math.floatEps(f32));
    var vhat = b.v.normalize();

    const c = b0.p.sub(b.p);
    const c_dot_vhat = c.dot(vhat);

    const @"δ" = b0.r + b.r;
    const discrim = c_dot_vhat * c_dot_vhat - c.dot(c) + @"δ" * @"δ";
    if (discrim < 0.0) return false;
    const d = -c_dot_vhat + @sqrt(discrim);

    b.p -= d * vhat;

    b.v = c.normalize().reflect(b.v);

    vhat = b.v.normalize();
    b.p += d * vhat;

    return true;
}

// pub fn bounceMoving(b1: *Self, b2: *Self) bool {
//     const v1len, var v1hat = b1.v.getLengthAndNormalize();
//     const v2len, var v2hat = b2.v.getLengthAndNormalize();
//     _ = v1len / v2len; // -rs

//     const vhat = b1.v.sub(b2.v).normalize();

//     const c = b2.p.sub(b1.p);
//     const c_dot_vhat = c.dot(vhat);

//     const @"δ" = b1.r + b2.r;
//     const s = c_dot_vhat * c_dot_vhat - c.lengthSquared() + @"δ" * @"δ";
//     const d = if (s >= 0.0) -c_dot_vhat + @sqrt(s) else return false;

//     b1.p -= d * v1hat;
//     b2.p -= d * (v2hat + v1hat);

//     b1.v, b2.v = c.normalize().reflect2(b1.v, b2.v);

//     v1hat, v2hat = .{ b1.v.normalize(), b2.v.normalize() };
//     b1.p += d * v1hat;
//     b2.p += d * v2hat;

//     return true;
// }
