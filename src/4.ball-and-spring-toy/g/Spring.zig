ends: [2]g.Particle = undefined, // actual particles at both ends
centr: g.Particle = undefined, // virtual particle at the center
rest_len: f32 = 100, // fair-sized
restitution: f32 = 0.5, // stick
rot: lib.Rot = undefined,

pub const manager = @import("Spring/manager.zig").Manager(256);

const Self = @This();
const g = @import("../sdl_app.zig").g;
const lib = @import("lib");
const math = std.math;
const std = @import("std");

/// Perform a single iteration of Gauss-Seidel relaxation to the spring.
pub fn relax(sp: *Self) void {
    var delta = sp.ends[1].pos.sub(sp.ends[0].pos);
    const length = delta.length(); // stick current length
    if (@abs(length - sp.rest_len) > 0.5) { // if different enough then relax
        delta.mulSc(1 - sp.rest_len / length); // amount to change by
        delta.mulSc(sp.restitution); // springiness
        sp.ends[0].pos.sub(delta); // some from one end
        sp.ends[1].pos.add(delta); // some from the other
    }
    // edge collision response
    const r = [_]f32{ sp.ends[0].radius, sp.ends[1].radius };
    for (0..2) |i| {
        sp.ends[i].pos.x = math.clamp(sp.ends[i].pos.x, r[i], lib.g.settings.screen.width - r[i] - 1);
        sp.ends[i].pos.y = math.clamp(sp.ends[i].pos.y, r[i], lib.g.settings.screen.height - r[i] - 1);
    }
}

/// The particles at the ends of the spring are moved and relaxed like any
/// sensible object should be. The center of the spring just gets dragged around.
/// This is where it catches up.
pub fn computeCenter(sp: *Self) void {
    const pos = [_]lib.Vec2{ sp.ends[0].pos, sp.ends[1].pos };
    const vec = pos[0].sub(pos[1]); // vector from p1 to p0
    sp.rot, sp.centr.rot = .{.{ .c = vec.x, .sp = vec.y }} ** 2; // the rotation between them
    sp.centr.pos = pos[0].add(pos[1]).mulSc(0.5);
    sp.centr.scale = vec.length() / 256; // scale needed for sprite
}
