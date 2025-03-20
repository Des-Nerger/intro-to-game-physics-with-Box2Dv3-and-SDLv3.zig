const g = @import("../../sdl_app.zig").g;
const lib = @import("lib");
const std = @import("std");

pub fn Manager(comptime objects_max: usize) type {
    return struct {
        particles: std.BoundedArray(g.Particle, objects_max) = .{},

        const Self = @This();

        pub fn create(pm: *Self, sprite_type: g.SpriteType, pos: lib.Vec2) *g.Particle {
            const p = pm.particles.addOne() catch unreachable;
            p.* = g.Particle.init(sprite_type, pos);
            return p;
        }

        /// Move the game particles.
        pub fn move(pm: *Self) void {
            for (pm.particles.slice()) |*p|
                p.move();
        }

        /// Ask the Render World to draw all of the game particles.
        pub fn draw(pm: *const Self) void {
            for (pm.particles.slice()) |*p|
                try g.renderer.world.draw(@intFromEnum(p.sprite_type), p.pos, p.rot, p.scale);
        }
    };
}
