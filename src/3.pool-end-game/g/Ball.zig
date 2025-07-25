/// base
obj: g.Object = undefined,

diameter: f32 = undefined,
is_in_pocket: bool,

pub const Manager = g.Object.manager.Manager(g.Ball, 2, @import("Ball/ManagerMixin.zig"));

const Self = @This();
const g = @import("../sdl_app.zig").g;
const lib = @import("lib");

pub fn init(obj_type: g.Object.Type, pos: lib.Vec2) Self {
    var obj = g.Object.init(obj_type);
    obj.pos = pos;
    return .{
        .obj = obj,
        .diameter = 50,
        .is_in_pocket = false,
    };
}

// pub fn bounceWithStationary(b: *Self, b0: Self) bool {
//     assert(b0.obj.isAtRest());
//     var vhat = b.obj.velocity.normalize();
//
//     const c = b0.obj.pos.sub(b.obj.pos);
//     const c_dot_vhat = c.dot(vhat);
//
//     const @"δ" = (b0.diameter + b.diameter) / 2.0;
//     const discrim = c_dot_vhat * c_dot_vhat - c.lengthSquared() + @"δ" * @"δ";
//     if (discrim < 0.0) return false;
//     const d = -c_dot_vhat + @sqrt(discrim);
//
//     b.obj.pos = b.obj.pos.sub(vhat.mulSc(d));
//
//     b.obj.velocity = c.normalize().reflect(b.obj.velocity);
//
//     vhat = b.obj.velocity.normalize();
//     b.obj.pos = b.obj.pos.add(vhat.mulSc(d));
//
//     return true;
// }

pub fn bounceWithMoving(b1: *Self, b2: *Self) bool {
    const vlen, const vhat = b1.obj.velocity.sub(b2.obj.velocity).getLengthAndNormalize();

    const c = b2.obj.pos.sub(b1.obj.pos);
    const c_dot_vhat = c.dot(vhat);

    const @"δ" = (b1.diameter + b2.diameter) / 2.0;
    const discrim = c_dot_vhat * c_dot_vhat - c.lengthSquared() + @"δ" * @"δ";
    const duration_of_impact = (if (discrim >= 0.0) -c_dot_vhat + @sqrt(discrim) else return false) / vlen;

    b1.obj.pos = b1.obj.pos.sub(b1.obj.velocity.mulSc(duration_of_impact));
    b2.obj.pos = b2.obj.pos.sub(b2.obj.velocity.mulSc(duration_of_impact));

    b1.obj.velocity, b2.obj.velocity = c.normalize().reflect2(b1.obj.velocity, b2.obj.velocity);

    b1.obj.pos = b1.obj.pos.add(b1.obj.velocity.mulSc(duration_of_impact));
    b2.obj.pos = b2.obj.pos.add(b2.obj.velocity.mulSc(duration_of_impact));

    return true;
}

/// Check for collision with a pocket.
/// Collision and response for ball-in-pocket. Checks for a collision, and
/// does the necessary housework for disabling a ball if it is in a pocket.
/// \return `true` if ball is in a pocket.
fn pocketCollision(b: *Self) bool {
    const hmargin, const cmargin, const vmargin = .{ 103.0, 10.0, 95.0 };
    if (b.obj.pos.x < hmargin or
        b.obj.pos.x > lib.g.settings.screen.width - hmargin or
        @abs(b.obj.pos.x - lib.g.settings.screen.width / 2.0) < cmargin)
    {
        const is_vertical =
            b.obj.pos.y < vmargin or b.obj.pos.y > lib.g.settings.screen.height - vmargin;
        b.is_in_pocket = is_vertical;
    }

    if (b.is_in_pocket)
        b.obj.velocity = lib.Vec2.zero;

    return b.is_in_pocket;
}

/// Check for collision with a rail.
/// Collision and response for ball hitting a rail. Checks for a collision, and
/// does the necessary housework for reflecting a ball if it hits a rail. Function
/// backs off the ball so that it does not appear to overlap the rail.
/// \return `true` if ball is in a pocket.
pub fn railCollision(b: *Self) bool {
    const radius = b.diameter / 2.0;

    // rail positions hard-coded from image
    const top, const bottom = .{ lib.g.settings.screen.height - 64.0 - radius, 64.0 + radius };
    const left, const right = .{ 78.0 + radius, lib.g.settings.screen.width - 72.0 - radius };

    const rail_restitution = 0.75; // how bouncy the rails are
    var result = false; // whether we hit

    if (b.obj.pos.x < left) { // left rail
        b.obj.pos.x = left;
        if (@abs(b.obj.velocity.x) > 0.0) { // could fail if ball moved by hand
            b.obj.pos.y += (left - b.obj.pos.x) * b.obj.velocity.y / b.obj.velocity.x;
            b.obj.velocity.x = -rail_restitution * b.obj.velocity.x;
        }
        result = true;
    } else if (b.obj.pos.x > right) { // right rail
        b.obj.pos.x = right;
        if (@abs(b.obj.velocity.x) > 0.0) { // could fail if ball moved by hand
            b.obj.pos.y += (b.obj.pos.x - right) * b.obj.velocity.y / b.obj.velocity.x;
            b.obj.velocity.x = -rail_restitution * b.obj.velocity.x;
        }
        result = true;
    }
    if (b.obj.pos.y < bottom) { // bottom rail
        b.obj.pos.y = bottom;
        if (@abs(b.obj.velocity.y) > 0.0) { // could fail if ball moved by hand
            b.obj.pos.x += (bottom - b.obj.pos.y) * b.obj.velocity.x / b.obj.velocity.y;
            b.obj.velocity.y = -rail_restitution * b.obj.velocity.y;
        }
        result = true;
    } else if (b.obj.pos.y > top) { // top rail
        b.obj.pos.y = top;
        if (@abs(b.obj.velocity.y) > 0.0) { // could fail if ball moved by hand
            b.obj.pos.x -= (b.obj.pos.y - top) * b.obj.velocity.x / b.obj.velocity.y;
            b.obj.velocity.y = -rail_restitution * b.obj.velocity.y;
        }
        result = true;
    }

    return result;
}

/// Move ball.
/// Move the ball, apply collision and response with pockets and rails,
/// playing the appropriate sound if necessary.
pub fn move(b: *Self) void {
    if (b.is_in_pocket) return;

    b.obj.move();

    // sounds
    if (b.pocketCollision())
        g.Sound.manager.play(@intFromEnum(g.Sound.pocket));
    if (b.railCollision())
        g.Sound.manager.play(@intFromEnum(g.Sound.thump));
}

/// Change velocity to a new value. This is mainly used in collision response.
/// \param velocity New velocity vector.
pub fn setVelocity(b: *Self, velocity: lib.Vec2) void {
    b.obj.is_at_rest, b.obj.velocity = .{ false, velocity };
}

/// Deliver an impulse to the object, given the rotation and magnitude.
/// \param rot_delta Rotation at which the impulse is to be applied.
/// \param magnitude Magnitude of the impulse to apply.
pub fn deliverImpulse(b: *Self, rot_delta: lib.Rot, magnitude: f32) void {
    b.obj.velocity = (lib.Vec2{ .x = rot_delta.c, .y = rot_delta.s }).mulSc(magnitude);
}
