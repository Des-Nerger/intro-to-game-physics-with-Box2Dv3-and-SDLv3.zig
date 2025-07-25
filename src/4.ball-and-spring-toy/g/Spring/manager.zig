const g = @import("../../sdl_app.zig").g;
const std = @import("std");

pub fn Manager(comptime objects_max: usize) type {
    return struct {
        sp: std.BoundedArray(g.Spring, objects_max) = .{},

        const Self = @This();

        fn connectSpring(sm: *Self, ends: [2]*g.Particle, centr: *g.Particle, restitution: f32) *g.Spring {
            const sp = sm.addOneAssumeCapacity();
            sp.ends, sp.centr, sp.restitution = .{ ends, centr, restitution };
            sp.rest_len = sp.ends[0].pos.sub(sp.ends[1].pos).length();
            return sp;
        }

        /// Perform Gauss-Seidel relaxation on a collection of springs. The more
        /// iterations, the more stick-like the springs will be.
        /// \param iterations Number of iterations of relaxation to perform.
        fn relax(sm: *Self, iterations: u32) void {
            for (0..iterations) |_| // more iterations means more like a stick
                for (sm.spring.slice()) |*sp|
                    sp.relax();
        }

        /// Springs don't move around in the normal way, instead they get dragged around
        /// by their end points. All we need to do here is recompute their center points.
        fn move(sm: *Self) void {
            for (sm.sp.slice()) |*sp|
                sp.computeCenter();
        }
    };
}
