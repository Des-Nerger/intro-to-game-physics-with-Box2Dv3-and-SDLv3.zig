const ObjectWorld = @import("ObjectWorld.zig");
const RenderWorldExt = @import("RenderWorldExt.zig");
const c = lib.c;
const debug = std.debug;
const lib = @import("lib");
const mem = std.mem;
const meta = std.meta;
const sdl = lib.sdl;
const std = @import("std");
const testing = std.testing;
const time = std.time;

test {
    testing.refAllDecls(@This());
}

/// May be dummy, in case I'll implement an SDL3 subset using Libretro API,
/// building the app as a shared library.
pub const main = c.main;

pub const g = struct { // -ame or -lobal_vars
    /// These are the sounds used in actual gameplay. Sounds must be listed here in
    /// the same order that they are in the sound settings JSON file.
    pub const Sound = enum { cue, ballclick, thump, pocket };

    pub const State = enum { balls_moving, initial, lost, setting_upshot, won };
    var state: State = undefined;

    var sound_manager = lib.SoundManager{};
    var object_world: ObjectWorld = undefined;
    var render_world = lib.Renderer(RenderWorldExt){};
    var timer: time.Timer = undefined;

    /// Create all game objects.
    fn createObjects() void {
        const screen_height: f32 = @floatFromInt(lib.game_settings.renderer.height);

        // create 8 ball
        g.object_world.create(.eightball, lib.Vec2{ .x = 750.0, .y = screen_height / 2.0 });

        // create cue ball
        g.object_world.create(.cueball, lib.Vec2{ .x = 295.0, .y = screen_height / 2.0 });

        g.object_world.resetImpulseVector();
    }

    /// Start the game.
    fn beginGame() !void {
        g.state = .initial; // playing state
        g.timer = try time.Timer.start(); // starting level now
        g.object_world = ObjectWorld.init(); // clear old objects
        g.createObjects(); // create new objects
    }

    /// Render a frame of animation.
    fn renderFrame() !void {
        try g.render_world.beginScene(); // start up graphics pipeline
        try g.render_world.drawBackground(); // draw the background
        g.object_world.draw(); // draw the objects
        g.render_world.maybeDrawWinLoseMessage(g.state);
        try g.render_world.endScene(); // shut down graphics pipeline
    }
};

comptime {
    for (@typeInfo(@This()).@"struct".decls) |decl| {
        if (!mem.startsWith(u8, decl.name, "SDL_App"))
            continue;
        const field = @field(@This(), decl.name);
        if (@TypeOf(field) !=
            meta.Child(meta.Child(@field(c, decl.name ++ "_func"))))
        {
            @compileError("pub fn type mismatch: " ++ decl.name);
        }
        @export(&field, .{ .name = decl.name, .linkage = .strong });
    }
}

/// Initialize and start the game.
/// This function runs once at startup.
pub fn SDL_AppInit(_: [*c]?*anyopaque, argc: c_int, argv: [*c][*c]u8) callconv(.c) c.SDL_AppResult {
    _ = .{ argc, argv };

    lib.init("data/3.game_settings.json") catch |err| return sdl.appFailure(err);
    g.sound_manager = lib.SoundManager.init() catch |err| return sdl.appFailure(err);

    // set up Render World
    g.render_world = @TypeOf(g.render_world).init() catch |err| return sdl.appFailure(err); // bails if fails
    g.render_world.loadImages() catch |err| return sdl.appFailure(err); // load images from .json file list

    g.beginGame() catch |err| return sdl.appFailure(err); // now start the game

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// This function runs when a new event (mouse input, keypresses, etc) occurs.
pub fn SDL_AppEvent(_: ?*anyopaque, event: [*c]c.SDL_Event) callconv(.c) c.SDL_AppResult {
    const move_delta = 5.0; // small change in position.
    const angle_delta = 0.01; // small change in angle.

    switch (event.*.type) {
        c.SDL_EVENT_QUIT => return c.SDL_APP_SUCCESS, // end the program, reporting success to the OS.
        c.SDL_EVENT_KEY_DOWN => switch (event.*.key.scancode) {
            c.SDL_SCANCODE_ESCAPE => return c.SDL_APP_SUCCESS, // ^
            c.SDL_SCANCODE_UP => if (g.state == .initial) {
                g.object_world.adjustCueBall(move_delta);
                g.object_world.resetImpulseVector();
            },
            c.SDL_SCANCODE_DOWN => if (g.state == .initial) {
                g.object_world.adjustCueBall(-move_delta);
                g.object_world.resetImpulseVector();
            },
            c.SDL_SCANCODE_LEFT => switch (g.state) {
                .setting_upshot, .initial => g.object_world.adjustImpulseVector(angle_delta),
                else => {},
            },
            c.SDL_SCANCODE_RIGHT => switch (g.state) {
                .setting_upshot, .initial => g.object_world.adjustImpulseVector(-angle_delta),
                else => {},
            },
            c.SDL_SCANCODE_Z => switch (g.state) {
                .won, .lost => if (g.object_world.allBallsStopped()) g.beginGame() catch |err|
                    return sdl.appFailure(err),
                .setting_upshot, .initial => {
                    g.state = .balls_moving;
                    g.object_world.shoot();
                    g.sound_manager.play(@intFromEnum(g.Sound.cue));
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
    // const nanosecs = g.timer.lap(); // capture time elapsed since last .lap or .start
    g.sound_manager.beginFrame() catch |err| return sdl.appFailure(err); // no double sounds
    // debug.print(
    //     "milliseconds = {d:6.2}, stream_available = {}\n",
    //     .{
    //         @as(f64, @floatFromInt(nanosecs)) / time.ns_per_ms,
    //         c.SDL_GetAudioStreamAvailable(g.sound_manager.stream),
    //     },
    // );
    g.object_world.move(); // move all objects
    g.renderFrame() catch |err| return sdl.appFailure(err); // render a frame of animation

    // change game state to set up next shot, if necessary
    if (g.object_world.cueBallDown())
        g.state = .lost
    else if (g.object_world.ballDown()) // a non-cue-ball is down, must be the 8-ball
        g.state = .won
    else if (g.state == .balls_moving and
        !g.object_world.ballDown() and
        g.object_world.allBallsStopped())
    { // shoot again
        g.state = .setting_upshot;
        g.object_world.resetImpulseVector();
    }

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

/// Shut down game and release resources.
/// This function runs once at shutdown.
pub fn SDL_AppQuit(_: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = .{result};

    inline for (.{ &g.render_world, &g.sound_manager, lib }) |deinitable| {
        const Deinitable = @TypeOf(deinitable);
        const ty_info = @typeInfo(Deinitable);
        if (!(if (ty_info == .type)
            @hasDecl(deinitable, "is_inited")
        else
            @hasField(ty_info.pointer.child, "is_inited")) or deinitable.is_inited)
        {
            if (ty_info == .type and deinitable == lib) {
                debug.print("c.SDL_Quit()\n", .{});
                c.SDL_Quit(); // we want SDL to clean up all their stuff before we deinit allocator
            }
            debug.print("{}.deinit()\n", .{if (ty_info == .type) deinitable else Deinitable});
            deinitable.deinit();
        }
    }
}
