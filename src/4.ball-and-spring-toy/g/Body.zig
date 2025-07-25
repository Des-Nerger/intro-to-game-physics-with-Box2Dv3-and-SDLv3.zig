sp: std.BoundedArray(*g.Spring, g.Spring.manager.capacity()) = .{},
pa: std.BoundedArray(*g.Particle, g.Particle.manager.capacity()) = .{},
edge_pa: *g.Particle,

const type = enum {
    chain2,
    chain3,
    chain4,
    triangle,
    square,
    wheel5,
    wheel6,
    ragdoll,
};

/// Choose the kind of sprites used for this body, sticks or springs.
/// \param restitution The spring restitution value, used to decide whether this is a stick or a spring.
/// \return Pair of sprite types to be used for particles and edges, respectively.
fn chooseSprites(restitution: f32) [2]g.SpriteType {
    return if (restitution > 0.49)
        .{ .wood_circle, .beam_stick }
    else
        .{ .ball_bearing, .spring };
}

/// Connect a spring between two particles.
/// \param centr Spring centers created by the outside calling function.
/// \param p0 First particle.
/// \param p1 Second particle.
/// \param s The spring index.
/// \param restitution Restitution value for the spring.
fn connectSpring(b: *Self, centr: []*const g.Particle, p0: usize, p1: usize, s: usize, restitution: f32) void {
    const pa = b.pa.constSlice();
    b.sp.set(s, g.obj_world.sp_man.connectSpring(.{ pa[p0], pa[p1] }, centr[s], restitution));
}

/// Create virtual particle for center of edge.
/// \param centr Spring centers created by the outside calling function.
/// \param edge The edge in question.
/// \param sprite_type The type of sprite there.
fn createEdgeCenter(b: *Self, centr: []*g.Particle, edge: usize, sprite_type: g.SpriteType) void {
    centr[edge] = g.obj_world.pa_man.create(sprite_type, lib.Vec2.zero);
}

/// Create particle for end of edge.
/// \param p Particle in question.
/// \param sprite_type Sprite to be drawn there.
/// \param pos Location of particle.
/// \return Pointer to particle for end of edge.
fn createPoint(b: *Self, p: usize, sprite_type: g.SpriteType, pos: lib.Vec2) *g.Particle {
    const pa = b.pa.slice();
    pa[p] = g.obj_world.pa_man.create(sprite_type, pos);
    return pa[p];
}

/// Make a chain of points in a straight line connected by springs.
/// \param count Number of points
/// \param radius Half the length of one of the springs.
/// \param restitution Coefficient of restitution of the springs.
/// \param angle Angle that the chain makes with the horizontal.
fn makeChain(b: *Self, count: usize, radius: f32, restitution: f32, angle: f32) *g.Particle {
    if (2 > count) unreachable;

    // make space for particles and springs
    b.pa.resize(count) catch unreachable;
    b.sp.resize(count - 1) catch unreachable;
    var centr =
        std.BoundedArray(*g.Particle, g.Particle.manager.capacity()).init(b.sp.len) catch unreachable;

    // decide whether to draw springs or sticks
    const vertex_type, const edge_type = Self.chooseSprites(restitution);

    const dx = radius * 2.0 * @cos(angle); // x and
    const dy = radius * 2.0 * @sin(angle); //   y offsets between balls

    var pos = lib.Vec2{ // center chain on screen
        .x = lib.g.settings.screen.width / 2.0 - radius * @floatFromInt(b.sp.len),
        .y = lib.g.settings.screen.height / 2.0,
    };

    // first ball and spring
    b.createEdgeCenter(centr.slice(), 0, edge_type);
    b.createPoint(0, vertex_type, pos);

    for (1..b.sp.len) |i| { // for the rest of the springs
        b.createEdgeCenter(centr.slice(), i, edge_type); // add a ball & spring, connect prev spring
        pos.x += dx; // offset
        pos.y += dy; //   position
        b.createPoint(i, vertex_type, pos);
        b.connectSpring(centr.constSlice(), i - 1, i, i - 1, restitution);
    }

    pos.x += dx; // last
    pos.y += dy; //   ball
    b.pa.set(b.pa.len - 1) = pa_man.create(vertex_type, pos);
    b.connectSpring(centr.constSlice(), count - 2, count - 1, count - 2, restitution);

    // clean up
    b.edge_pa = b.pa.get(0);
    return b.edge_pa;
}

/// Make a triangle of points connected by springs.
/// \param radius Half the length of one of the springs.
/// \param restitution Coefficient of restitution of the springs.
fn makeTriangle(b: *Self, radius: f32, restitution: f32) *g.Particle {
    // make space for particles and springs
    b.pa.resize(3) catch unreachable;
    var centr: [3]*g.Particle = undefined;
    b.sp.resize(centr.len) catch unreachable;

    // decide whether to draw springs or sticks
    const vertex_type, const edge_type = Self.chooseSprites(restitution);

    var pos = lib.Vec2{ // default position
        .x = lib.g.settings.screen.width / 2,
        .y = lib.g.settings.screen.height / 2 + radius,
    };

    for (0..3) |i| // edge objects
        b.createEdgeCenter(&centr, i, edge_type);

    // balls
    b.createPoint(0, vertex_type, pos);
    pos.x += radius;
    pos.y -= radius * @tan(math.pi / 3);
    b.createPoint(1, vertex_type, pos);
    pos.x -= radius * 2;
    b.createPoint(2, vertex_type, pos);

    // tie spring to balls
    b.connectSpring(&centr, 0, 1, 0, restitution);
    b.connectSpring(&centr, 1, 2, 1, restitution);
    b.connectSpring(&centr, 2, 0, 2, restitution);

    // clean up
    b.edge_pa = b.pa.get(0);
    return b.edge_pa;
}

fn makeSquare() *g.Particle {}

fn makeWheel() *g.Particle {}

fn makeRagdoll() *g.Particle {}

fn deliverImpulse(b: *g.Body, rot_delta: lib.Rot, magnitude: f32) void {
    for (b.pa) |*pa|
        pa.deliverImpulse(rot_delta, magnitude);
}

/// Deliver torque to body. This is achieved by delivering an impulse to a
/// particle on the outside of the body.
/// \param rot_delta Orientation of torque.
/// \param magnitude Magnitude of torque.
fn applyTorque(b: *g.Body, rot_delta: lib.Rot, magnitude: f32) void {
    if (2 <= b.pa.len)
        b.pa[1].deliverImpulse(rot_delta, magnitude);
}

/// Teleport the body without moving any of the particle relative to each other.
/// \param delta Amount to move horizontally/vertically.
fn teleport(b: *g.Body, delta: lib.Vec2) void {
    for (b.pa) |*pa| {
        pa.pos.x += delta.x;
        pa.pos.y += delta.y;
        pa.old_pos.x += delta.x;
        pa.old_pos.y += delta.y;
    }
}

/// Move the body.
/// Since the components of the body (particles and springs) are responsible for moving themselves,
/// all we need to do here is to orient the particles at the ends and middle of the springs correctly.
fn move() void {
    for (b.sp) |*sp|
        if (.beam_stick == sp.centr.sprite_type)
            sp.end[0].rot, sp.end[1].rot = .{sp.centr.rot} ** 2;
}
