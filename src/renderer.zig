const c = lib.c;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const lib = @import("lib.zig");
const math = std.math;
const path = fs.path;
const sdl = lib.sdl;
const std = @import("std");
const zigimg = @import("zigimg");

pub fn Renderer(Ext: type) type {
    return struct {
        is_inited: bool = false,

        window: *c.SDL_Window = undefined,

        // We will use this renderer to draw into this window every frame.
        renderer: *c.SDL_Renderer = undefined,

        sprite: Self.Sprite = undefined,
        background: *c.SDL_Texture = undefined,

        const Self = @This();
        const Sprite = struct {
            filepaths: @This().Filepaths,
            textures: []*c.SDL_Texture,

            pub const Filepaths = std.StringHashMap([]const u8);
        };

        pub usingnamespace Ext;

        pub fn deinit(rx: *Self) void {
            defer rx.* = Self{};
            rx.sprite.filepaths.deinit();
            lib.allocator.free(rx.sprite.textures);
            c.SDL_DestroyRenderer(rx.renderer); // Implicitly frees all its textures.
            c.SDL_DestroyWindow(rx.window);
            c.SDL_QuitSubSystem(c.SDL_INIT_VIDEO);
            sdl.expect(c.SDL_ResetHint(c.SDL_HINT_MAIN_CALLBACK_RATE), "") catch unreachable;
        }

        pub fn init() !Self {
            {
                var buf: [lib.digitSizeOf(@TypeOf(lib.game_settings.renderer.fps)) + "\x00".len]u8 = undefined;
                try sdl.expect(c.SDL_SetHint(
                    c.SDL_HINT_MAIN_CALLBACK_RATE,
                    try fmt.bufPrintZ(&buf, "{}", .{lib.game_settings.renderer.fps}),
                ), "");
            }
            errdefer sdl.expect(c.SDL_ResetHint(c.SDL_HINT_MAIN_CALLBACK_RATE), "") catch unreachable;

            try sdl.expect(c.SDL_InitSubSystem(c.SDL_INIT_VIDEO), "couldn't initialize SDL video subsystem: ");
            errdefer c.SDL_QuitSubSystem(c.SDL_INIT_VIDEO);

            var maybe_window: ?*c.SDL_Window, var maybe_renderer: ?*c.SDL_Renderer = .{null} ** 2;
            try sdl.expect(
                c.SDL_CreateWindowAndRenderer(
                    lib.game_settings.game_name.ptr,
                    lib.game_settings.renderer.width,
                    lib.game_settings.renderer.height,
                    0,
                    &maybe_window,
                    &maybe_renderer,
                ),
                "couldn't create window/renderer: ",
            );
            const window = maybe_window.?;
            errdefer c.SDL_DestroyWindow(window);
            const renderer = maybe_renderer.?;
            errdefer c.SDL_DestroyRenderer(renderer);

            var sprite: Self.Sprite = undefined;

            sprite.textures = try lib.allocator.alloc(*c.SDL_Texture, lib.game_settings.sprites.len);
            errdefer lib.allocator.free(sprite.textures);

            sprite.filepaths = Self.Sprite.Filepaths.init(lib.allocator);
            errdefer sprite.filepaths.deinit();

            try sprite.filepaths.ensureTotalCapacity(@intCast(lib.game_settings.sprites.len));
            for (lib.game_settings.sprites) |sprite_filepath|
                sprite.filepaths.putAssumeCapacityNoClobber(path.stem(sprite_filepath), sprite_filepath);

            return .{
                .is_inited = true,
                .window = window,
                .renderer = renderer,
                .sprite = sprite,
            };
        }

        pub fn load(rx: *Self, sprite_idx: usize, sprite_name: [:0]const u8) !void {
            rx.sprite.textures[sprite_idx] = try rx.loadTexture(
                rx.sprite.filepaths.get(sprite_name).?,
            );
        }

        fn loadTexture(rx: *const Self, filepath: []const u8) !*c.SDL_Texture {
            var image = zigimg.Image.fromFilePath(
                lib.allocator,
                filepath,
            ) catch |err| {
                debug.print("loading image '{s}': ", .{filepath});
                return err;
            };
            defer image.deinit();

            const texture = try sdl.nonNull(c.SDL_CreateTexture(
                rx.renderer,
                c.SDL_PIXELFORMAT_RGBA32,
                c.SDL_TEXTUREACCESS_STATIC,
                @intCast(image.width),
                @intCast(image.height),
            ));
            try sdl.expect(c.SDL_UpdateTexture(
                texture,
                null,
                image.pixels.rgba32.ptr,
                @intCast(image.rowByteSize()),
            ), "");
            return texture;
        }

        pub fn loadBackground(rx: *Self) !void {
            rx.background = try rx.loadTexture(lib.game_settings.background);
        }

        pub fn beginScene(rx: *const Self) !void {
            const black = c.SDL_Color{ .r = 0x00, .g = 0x00, .b = 0x00 };
            try sdl.expect(
                c.SDL_SetRenderDrawColor(rx.renderer, black.r, black.g, black.b, c.SDL_ALPHA_OPAQUE),
                "",
            );
            try sdl.expect(c.SDL_RenderClear(rx.renderer), "");
        }

        pub fn endScene(rx: *const Self) !void {
            try sdl.expect(c.SDL_RenderPresent(rx.renderer), "");
        }

        pub fn drawBackground(rx: *const Self) !void {
            try sdl.expect(c.SDL_RenderTexture(
                rx.renderer,
                rx.background,
                null,
                &.{ .x = 0, .y = 0, .w = @floatFromInt(rx.background.w), .h = @floatFromInt(rx.background.h) },
            ), "");
        }

        /// Write text to screen.
        pub fn textWrite(rx: *const Self, text: []const u8, maybe_color: ?c.SDL_Color) void {
            const max = math.maxInt(u8);
            const color: c.SDL_Color =
                if (maybe_color) |color| color else .{ .r = max, .g = max, .b = max, .a = max };
            _ = .{ rx, text, color };
        }
    };
}
