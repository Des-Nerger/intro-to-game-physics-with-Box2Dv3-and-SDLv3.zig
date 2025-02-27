type: g.Object.Type,
pos: lib.Vec2,
velocity: lib.Vec2,

pub var world: g.Object.World = undefined;

pub const manager = @import("Object/manager.zig");
pub const Type = enum { vector_arrow, cue_ball, eight_ball };
pub const World = @import("Object/World.zig");

pub const Self = @This();
const g = @import("../sdl_app.zig").g;
const lib = @import("lib");
const meta = std.meta;
const std = @import("std");

pub fn isAtRest(obj: *const Self) bool {
    return meta.eql(obj.velocity, lib.Vec2.zero);
}

pub fn init(obj_type: g.Object.Type) Self {
    return .{
        .type = obj_type,
        .pos = lib.Vec2.zero,
        .velocity = lib.Vec2.zero,
    };
}

/// Move in proportion to velocity vector and time since last move, and apply
/// a small amount of friction to reduce the velocity.
pub fn move(obj: *Self) void {
    const scale = 20.0;
    obj.pos = obj.pos.add(obj.velocity.mulSc(lib.dt / scale));
    obj.velocity = obj.velocity.mulSc(0.98);
    if (obj.velocity.lengthSquared() < 0.5)
        obj.velocity = lib.Vec2.zero;
}
