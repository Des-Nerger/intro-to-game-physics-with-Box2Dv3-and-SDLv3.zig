const Self = g.Object.manager.Manager(g.Ball, 2, @This());
const g = @import("../../sdl_app.zig").g;

pub fn draw(bm: *Self) !void {
    for (&bm.objects) |b|
        if (!b.is_in_pocket)
            try g.renderer.world.draw(@intFromEnum(b.obj.type), b.obj.pos, null);
}

/// Collision detection and response.
/// This function relies on the game engine code for collision response,
/// and merely adds an appropriate sound for ball collision.
/// \param `i` Handle response for colisions with ball at index `i` in the object list.
/// \return `true` iff it collides with some other object.
pub fn collisionResponseAt(bm: *Self, i: usize) void {
    var b = [_]*g.Ball{ &bm.objects[i], undefined };

    switch (b[0].obj.type) {
        .cue_ball, .eight_ball => {},
        else => return,
    }

    // Compare against only higher-indexed objects to avoid processing each collision twice.
    for (i + 1..bm.objects.len) |j| {
        b[1] = &bm.objects[j];
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
/// consists of a for-loop on `i` calling `bm.collisionResponse(i)`
pub fn collisionResponse(bm: *Self) void {
    for (0..bm.objects.len) |i| // for each object
        bm.collisionResponseAt(i); // collisions with ~~everything else~~ higher-indexed objects
}
