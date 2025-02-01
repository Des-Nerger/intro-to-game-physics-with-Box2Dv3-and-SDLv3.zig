const Object = @import("Object.zig");
const Self = @This();
const lib = @import("lib");

pub fn init() Self {
    return undefined;
}

/// Create new object.
pub fn create(ow: *Self, obj_type: Object.Type, pos: lib.Vec2) void {
    _ = .{ ow, obj_type, pos };
}

pub fn resetImpulseVector(ow: *Self) void {
    _ = .{ow};
}

/// Move cue-ball up or down.
pub fn adjustCueBall(ow: *Self, dy: f32) void {
    _ = .{ ow, dy };
}

/// Move all objects.
pub fn move(ow: *Self) void {
    _ = .{ow};
}

/// Adjust the Impulse Vector.
pub fn adjustImpulseVector(ow: *Self, delta_angle: f32) void {
    _ = .{ ow, delta_angle };
}

/// Draw all objects.
pub fn draw(ow: *Self) void {
    _ = .{ow};
}

/// Have all balls stopped moving?
pub fn allBallsStopped(ow: *const Self) bool {
    _ = .{ow};
    return true;
}

/// Shoot the cue ball.
pub fn shoot(ow: *Self) void {
    _ = .{ow};
}

/// Is the cue ball down in a pocket?
pub fn cueBallDown(ow: *const Self) bool {
    _ = .{ow};
    return false;
}

/// Is a ball down in a pocket?
pub fn ballDown(ow: *const Self) bool {
    _ = .{ow};
    return false;
}
