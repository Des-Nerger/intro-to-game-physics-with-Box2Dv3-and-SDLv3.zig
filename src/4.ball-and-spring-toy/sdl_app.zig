const c = lib.c;
const debug = std.debug;
const lib = @import("lib");
const sdl = lib.sdl;
const std = @import("std");
const testing = std.testing;

test {
    testing.refAllDecls(@This());
}

/// May be dummy, in case I'll implement an SDL3 subset using Libretro API,
/// building the app as a shared library.
pub const main = c.main;

pub const g = struct {
    pub const Particle = @import("g/Particle.zig");
    pub const Spring = @import("g/Spring.zig");

    /// These are the sounds used in actual gameplay. Sounds must be listed here in
    /// the same order that they are in the sound settings JSON file.
    pub const Sound = enum {
        thump,
        boing,
        ow,
        pub var manager = lib.g.Sound.Manager{};
    };

    pub const SpriteType = enum { invisible, ball_bearing, wood_circle, spring, beam_stick };

    pub const current_body: enum {
        chain2,
        chain3,
        chain4,
        triangle,
        square,
        wheel5,
        wheel6,
        ragdoll,
    } = .chain2;
};

comptime {
    sdl.app.@"export"(@This());
}

/// Initialize and start the game.
/// This function runs once at startup.
pub fn SDL_AppInit(_: [*c]?*anyopaque, argc: c_int, argv: [*c][*c]u8) callconv(.c) c.SDL_AppResult {
    _ = .{ argc, argv };
    lib.init("data/4.game_settings.json") catch |err| return sdl.app.failure(err);
    g.Sound.manager = lib.g.Sound.Manager.init() catch |err| return sdl.app.failure(err);

    var o = g.Particle.init(.ball_bearing, lib.Vec2{ .x = 24, .y = 42 });
    o.deliverImpulse(.{ .c = 0.6, .s = 0.8 }, 34);
    o.move();
    debug.print("o == {}\n", .{o});

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// This function runs when a new event (mouse input, keypresses, etc) occurs.
pub fn SDL_AppEvent(_: ?*anyopaque, event: [*c]c.SDL_Event) callconv(.c) c.SDL_AppResult {
    _ = .{event};
    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// Process a frame of animation.
/// This function runs once per frame, and is the heart of the program.
/// Takes appropriate action if the player has won or lost.
pub fn SDL_AppIterate(_: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    // stuff that gets done on every frame
    g.Sound.manager.beginFrame() catch |err| return sdl.app.failure(err);
    return c.SDL_APP_SUCCESS; // quit immediately
}

/// Shut down game and release resources.
/// This function runs once at shutdown.
pub fn SDL_AppQuit(_: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = .{result};

    inline for (.{ &g.Sound.manager, lib }) |deinitable| {
        const Deinitable = @TypeOf(deinitable);
        const ty_info = @typeInfo(Deinitable);
        if (!(if (ty_info == .type)
            @hasDecl(deinitable, "is_inited")
        else
            @hasField(ty_info.pointer.child, "is_inited")) or deinitable.is_inited)
        {
            debug.print("{}.deinit()\n", .{if (ty_info == .type) deinitable else Deinitable});
            deinitable.deinit();
        }
    }
}
