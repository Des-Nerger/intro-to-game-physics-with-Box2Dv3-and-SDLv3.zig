const g = @import("../../sdl_app.zig").g;
const lib = @import("lib");
const std = @import("std");

pub fn Manager(comptime objects_max: usize) type {
    return struct {
        pa: std.BoundedArray(g.Particle, objects_max) = .{},

        const Self = @This();

        /// Create a particle.
        pub fn create(pm: *Self, sprite_type: g.SpriteType, pos: lib.Vec2) *g.Particle {
            const pa = pm.pa.addOne() catch unreachable;
            pa.* = g.Particle.init(sprite_type, pos);
            return pa;
        }

        /// Move the game particles.
        pub fn move(pm: *Self) void {
            for (pm.pa.slice()) |*pa|
                pa.move();
        }

        /// Ask the Render World to draw all of the game particles.
        pub fn draw(pm: *const Self) void {
            for (pm.pa.slice()) |*pa|
                try g.renderer.world.draw(@intFromEnum(pa.sprite_type), pa.pos, pa.rot, pa.scale);
        }
    };
}
