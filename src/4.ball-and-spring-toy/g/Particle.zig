sprite_type: g.SpriteType,
pos: lib.Vec2,
old_pos: lib.Vec2,
radius: f32,
rot: lib.Rot,
scale: lib.Vec2,

pub const manager = @import("Particle/manager.zig").Manager(256);

const Self = @This();
const g = @import("../sdl_app.zig").g;
const lib = @import("lib");

pub fn init(sprite_type: g.SpriteType, pos: lib.Vec2) Self {
    return Self{
        .sprite_type = sprite_type,
        .pos = pos,
        .old_pos = pos,
        .radius = 32, // from the image file
        .rot = lib.Rot.identity,
        .scale = lib.Vec2{ .x = 1, .y = 1 },
    };
}

/// Check for collision with an edge.
/// Collision and response for particle hitting an edge of the screen.
/// Checks for a collision, and does the necessary housework for reflecting
/// a particle if it hits an edge. Function
/// backs off the particle so that it does not appear to overlap the edge.
/// \return `true` if particle hits an edge.
pub fn edgeCollision(pa: *Self) bool {
    var is_rebound = false;
    const restitution = 0.8;
    var delta = pa.pos.sub(pa.old_pos);
    const min_collision_speed = 2.0;
    const left, const bottom = .{pa.radius} ** 2;
    const right = lib.g.settings.screen.width - pa.radius;
    const top = lib.g.settings.screen.height - pa.radius;

    vert_walls: {
        pa.pos.x = if (pa.pos.x < left) left else if (pa.pos.x > right) right else break :vert_walls;
        delta.y *= -1;
        pa.old_pos = pa.pos.add(delta.mulSc(restitution));
        if (!is_rebound) is_rebound = @abs(delta.x) > min_collision_speed;
    }

    horiz_walls: {
        pa.pos.y = if (pa.pos.y < bottom) bottom else if (pa.pos.y > top) top else break :horiz_walls;
        delta.x *= -1;
        pa.old_pos = pa.pos.add(delta.mulSc(restitution));
        if (!is_rebound) is_rebound = @abs(delta.y) > min_collision_speed;
    }

    return is_rebound;
}

/// Move the particle, apply collision and response.
pub fn move(pa: *Self) void { // move particle using Verlet integration.
    const pos = pa.pos;
    pa.pos = pa.pos.mulSc(2).sub(pa.old_pos);
    pa.old_pos = pos;
    pa.pos.y -= 0.2; // gravity;

    if (pa.edgeCollision()) {
        g.Sound.manager.play(@intFromEnum(@as(g.Sound, if (g.current_body == .ragdoll)
            .ow
        else switch (pa.sprite_type) {
            .ball_bearing => .boing,
            .wood_circle => .thump,
            else => return,
        })));
    }
}

/// Deliver an impulse to the particle, given the rotation and magnitude.
/// \param rot_delta Rotation at which the impulse is to be applied.
/// \param magnitude Magnitude of the impulse to apply.
pub fn deliverImpulse(pa: *Self, rot_delta: lib.Rot, magnitude: f32) void {
    pa.old_pos = pa.pos.sub((lib.Vec2{ .x = rot_delta.c, .y = rot_delta.s }).mulSc(magnitude));
}
