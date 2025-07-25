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

pub const g = struct { // -ame or -lobals
    pub const Ball = @import("g/Ball.zig");
    pub const Object = @import("g/Object.zig");
    pub const RendererWorld = lib.g.renderer.Renderer(@import("g/renderer/WorldMixin.zig"));
    pub var renderer = g.RendererWorld{};

    /// These are the sounds used in actual gameplay. Sounds must be listed here in
    /// the same order that they are in the sound settings JSON file.
    pub const Sound = enum {
        cue,
        ball_click,
        thump,
        pocket,
        pub var manager = lib.g.Sound.Manager{};
    };

    pub const State = enum { balls_moving, initial, lost, setting_upshot, won };
    var state: State = undefined;

    /// Create all game objects.
    fn createObjects() void {
        // create eight ball
        g.Object.world.create(.eight_ball, lib.Vec2{ .x = 750.0, .y = lib.g.settings.screen.height / 2.0 });

        // create cue ball
        g.Object.world.create(.cue_ball, lib.Vec2{ .x = 295.0, .y = lib.g.settings.screen.height / 2.0 });

        g.Object.world.resetImpulseVector();
    }

    /// Start the game.
    fn begin() !void {
        g.state = .initial; // playing state
        g.Object.world = g.Object.World.init(); // clear old objects
        g.createObjects(); // create new objects
    }

    /// Render a frame of animation.
    fn renderFrame() !void {
        try g.renderer.beginScene(); // start up graphics pipeline
        try g.renderer.drawBackground(); // draw the background
        try g.Object.world.draw(); // draw the objects
        try g.renderer.world.maybeDrawWinLoseMessage(g.state);
        try g.renderer.endScene(); // shut down graphics pipeline
    }
};

comptime {
    sdl.app.@"export"(@This());
}

/// Initialize and start the game.
/// This function runs once at startup.
pub fn SDL_AppInit(_: [*c]?*anyopaque, argc: c_int, argv: [*c][*c]u8) callconv(.c) c.SDL_AppResult {
    _ = .{ argc, argv };

    lib.init("data/3.game_settings.json") catch |err| return sdl.app.failure(err);
    g.Sound.manager = lib.g.Sound.Manager.init() catch |err| return sdl.app.failure(err);

    // set up Render World
    g.renderer = @TypeOf(g.renderer).init() catch |err|
        return sdl.app.failure(err); // bails if fails
    g.renderer.world.loadImages() catch |err| return sdl.app.failure(err); // load images from .json file list

    g.begin() catch |err| return sdl.app.failure(err); // now start the game

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// This function runs when a new event (mouse input, keypresses, etc) occurs.
pub fn SDL_AppEvent(_: ?*anyopaque, event: [*c]c.SDL_Event) callconv(.c) c.SDL_AppResult {
    const move_delta = 5.0; // small change in position.
    const rot_delta = comptime lib.Rot.fromRadians(0.01); // small change in angle.

    switch (event.*.type) {
        c.SDL_EVENT_QUIT => return c.SDL_APP_SUCCESS, // end the program, reporting success to the OS.
        c.SDL_EVENT_KEY_DOWN => switch (event.*.key.scancode) {
            c.SDL_SCANCODE_ESCAPE => return c.SDL_APP_SUCCESS, // ^
            c.SDL_SCANCODE_UP => if (g.state == .initial) {
                g.Object.world.adjustCueBall(move_delta);
                g.Object.world.resetImpulseVector();
            },
            c.SDL_SCANCODE_DOWN => if (g.state == .initial) {
                g.Object.world.adjustCueBall(-move_delta);
                g.Object.world.resetImpulseVector();
            },
            c.SDL_SCANCODE_LEFT => switch (g.state) {
                .setting_upshot, .initial => g.Object.world.adjustImpulseVector(rot_delta),
                else => {},
            },
            c.SDL_SCANCODE_RIGHT => switch (g.state) {
                .setting_upshot, .initial => g.Object.world.adjustImpulseVector(rot_delta.angleNeg()),
                else => {},
            },
            c.SDL_SCANCODE_Z => switch (g.state) {
                .won, .lost => if (g.Object.world.allBallsStopped()) g.begin() catch |err|
                    return sdl.app.failure(err),
                .setting_upshot, .initial => {
                    g.state = .balls_moving;
                    g.Object.world.shoot();
                    g.Sound.manager.play(@intFromEnum(g.Sound.cue));
                },
                else => {},
            },
            else => {},
        },
        else => {},
    }
    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// Process a frame of animation.
/// This function runs once per frame, and is the heart of the program.
/// Takes appropriate action if the player has won or lost.
pub fn SDL_AppIterate(_: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    // stuff that gets done on every frame
    g.Sound.manager.beginFrame() catch |err| return sdl.app.failure(err);
    g.Object.world.move(); // move all objects
    g.renderFrame() catch |err| return sdl.app.failure(err); // render a frame of animation

    // change game state to set up next shot, if necessary
    if (g.Object.world.cueBallDown())
        g.state = .lost
    else if (g.Object.world.ballDown()) // a non-cue-ball is down, must be the eight-ball
        g.state = .won
    else if (g.state == .balls_moving and
        !g.Object.world.ballDown() and
        g.Object.world.allBallsStopped())
    { // shoot again
        g.state = .setting_upshot;
        g.Object.world.resetImpulseVector();
    }

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// Shut down game and release resources.
/// This function runs once at shutdown.
pub fn SDL_AppQuit(_: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = .{result};

    inline for (.{ &g.renderer, &g.Sound.manager, lib }) |deinitable| {
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
