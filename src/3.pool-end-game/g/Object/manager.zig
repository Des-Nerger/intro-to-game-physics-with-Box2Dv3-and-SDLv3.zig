pub fn Manager(ExtendedObject: type, comptime objects_max: usize, BallsMixin: type) type {
    return struct {
        balls: [objects_max]ExtendedObject = [_]ExtendedObject{.{ .is_in_pocket = true }} ** objects_max,
        ball_methods: BallsMixin = .{},

        const Self = @This();

        /// Create a new instance of a game object.
        /// \param objecttype The type of the new object
        pub fn create(bm: *Self, args: anytype) *ExtendedObject {
            for (&bm.balls) |*b|
                if (b.is_in_pocket) {
                    b.* = @call(.auto, ExtendedObject.init, args);
                    return b;
                };
            unreachable;
        }

        /// Move the game objects.
        pub fn move(bm: *Self) void {
            for (&bm.balls) |*b|
                b.move();
        }

        /// Clear out all game objects from the object list.
        pub fn clear(bm: *Self) void {
            bm.* = .{};
        }
    };
}
