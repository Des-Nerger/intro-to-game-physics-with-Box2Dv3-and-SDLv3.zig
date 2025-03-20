ball_manager: g.Object.manager.Manager(g.Ball, 2, g.Ball.ManagerExt),
cue: struct {
    impulse_rot: lib.Rot,
    is_to_draw_impulse_vector: bool,
    ball: *g.Ball,
},
eight_ball: *g.Ball,

const Self = @This();
const g = @import("../../sdl_app.zig").g;
const lib = @import("lib");

pub fn init() Self {
    return .{
        .ball_manager = .{},
        .cue = .{
            .impulse_rot = lib.Rot.identity,
            .is_to_draw_impulse_vector = true,
            .ball = undefined,
        },
        .eight_ball = undefined,
    };
}

/// Create an object in the Object World.
/// \param `obj_type` Object type.
/// \param `pos` Initial position.
/// \return Pointer to the object created.
pub fn create(ow: *Self, obj_type: g.Object.Type, pos: lib.Vec2) void {
    (switch (obj_type) {
        .cue_ball => &ow.cue.ball,
        .eight_ball => &ow.eight_ball,
        else => return,
    }).* = ow.ball_manager.create(.{ obj_type, pos });
}

/// Clear objects, reset to initial conditions.
pub fn clear(ow: *Self) void {
    ow.ball_manager.clear();
}

/// Draw everything in the Object World.
/// Draw the impulse vector, then the game objects.
pub fn draw(ow: *Self) !void {
    if (ow.cue.is_to_draw_impulse_vector)
        try g.renderer.world.draw(
            @intFromEnum(g.Object.Type.vector_arrow),
            ow.cue.ball.obj.pos,
            ow.cue.impulse_rot,
            null,
        );
    try ow.ball_manager.draw();
}

/// Move all objects.
pub fn move(ow: *Self) void {
    ow.ball_manager.move();
    ow.ball_manager.collisionResponse();
}

/// Make the impulse vector point from the center of the cue-ball
/// to the center of the eight-ball.
pub fn resetImpulseVector(ow: *Self) void {
    ow.cue.is_to_draw_impulse_vector = true;
    const cue_to_eight = ow.eight_ball.obj.pos.sub(ow.cue.ball.obj.pos).normalize();
    ow.cue.impulse_rot = lib.Rot{ .c = cue_to_eight.x, .s = cue_to_eight.y };
}

pub fn adjustImpulseVector(ow: *Self, rot_delta: lib.Rot) void {
    ow.cue.impulse_rot = ow.cue.impulse_rot.mul(rot_delta);
}

/// Adjust the cue ball up or down.
/// \param `dy` Amount to move by.
pub fn adjustCueBall(ow: *Self, dy: f32) void {
    ow.cue.ball.obj.pos.y += dy;
    _ = ow.cue.ball.railCollision();
}

/// Shoot the cue ball.
pub fn shoot(ow: *Self) void {
    ow.cue.is_to_draw_impulse_vector = false;
    ow.cue.ball.deliverImpulse(ow.cue.impulse_rot, 40.0);
}

/// Check whether the cue-ball or the eight-ball is in a pocket.
/// \return `true` If one of the balls is in a pocket.
pub fn ballDown(ow: *const Self) bool {
    return ow.cue.ball.is_in_pocket or ow.eight_ball.is_in_pocket;
}

/// Check whether the cue-ball is in a pocket.
/// \return `true` If the cue-ball is in a pocket.
pub fn cueBallDown(ow: *const Self) bool {
    return ow.cue.ball.is_in_pocket;
}

/// Check whether both the cue-ball and the eight-ball have stopped moving.
/// \return `true` If both balls have stopped moving.
pub fn allBallsStopped(ow: *const Self) bool {
    return ow.cue.ball.obj.isAtRest() and ow.eight_ball.obj.isAtRest();
}
