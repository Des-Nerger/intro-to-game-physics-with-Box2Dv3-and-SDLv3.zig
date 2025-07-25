const Self = @This();
const g = @import("../../sdl_app.zig").g;

pub fn draw(mmix: *Self) !void {
    const bm: *g.Ball.Manager = @alignCast(@fieldParentPtr("ball_methods", mmix));
    for (&bm.balls) |b|
        if (!b.is_in_pocket)
            try g.renderer.draw(@intFromEnum(b.obj.type), b.obj.pos, null, null);
}

/// Collision detection and response.
/// This function relies on the game engine code for collision response,
/// and merely adds an appropriate sound for ball collision.
/// \param `i` Handle response for colisions with ball at index `i` in the object list.
/// \return `true` iff it collides with some other object.
pub fn collisionResponseAt(mmix: *Self, i: usize) void {
    const bm: *g.Ball.Manager = @alignCast(@fieldParentPtr("ball_methods", mmix));
    var b = [_]*g.Ball{ &bm.balls[i], undefined };

    switch (b[0].obj.type) {
        .cue_ball, .eight_ball => {},
        else => return,
    }

    // Compare against only higher-indexed objects to avoid processing each collision twice.
    for (i + 1..bm.balls.len) |j| {
        b[1] = &bm.balls[j];
        if (b[1].is_in_pocket) continue;
        const distance = (b[0].diameter + b[1].diameter) / 2.0;
        if (b[0].obj.pos.sub(b[1].obj.pos).lengthSquared() < distance * distance and
            !(b[0].obj.isAtRest() and b[1].obj.isAtRest()))
        {
            g.Sound.manager.play(@intFromEnum(g.Sound.ball_click));

            _ = b[0].bounceWithMoving(b[1]);
            // _ = b[1].bounceWithStationary(b[0].*);
        }
    }
}

/// Perform collision response for all objects. This function basically
/// consists of a for-loop on `i` calling `mmix.collisionResponse(i)`
pub fn collisionResponse(mmix: *Self) void {
    const bm: *g.Ball.Manager = @alignCast(@fieldParentPtr("ball_methods", mmix));
    for (0..bm.balls.len) |i| // for each object
        mmix.collisionResponseAt(i); // collisions with ~~everything else~~ higher-indexed objects
}
