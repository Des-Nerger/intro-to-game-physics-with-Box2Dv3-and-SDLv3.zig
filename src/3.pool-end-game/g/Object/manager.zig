pub fn Manager(ObjectExt: type, comptime max_objects: usize, ManagerExt: type) type {
    return struct {
        objects: [max_objects]ObjectExt = [_]ObjectExt{.{ .is_in_pocket = true }} ** max_objects,

        const Self = @This();

        pub usingnamespace ManagerExt;

        /// Create a new instance of a game object.
        /// \param objecttype The type of the new object
        pub fn create(mx: *Self, args: anytype) *ObjectExt {
            for (&mx.objects) |*ox|
                if (ox.is_in_pocket) {
                    ox.* = @call(.auto, ObjectExt.init, args);
                    return ox;
                };
            unreachable;
        }

        /// Move the game objects.
        pub fn move(mx: *Self) void {
            for (&mx.objects) |*ox|
                ox.move();
        }

        /// Clear out all game objects from the object list.
        pub fn clear(mx: *Self) void {
            mx.* = .{};
        }
    };
}
