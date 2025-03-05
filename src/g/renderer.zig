const assert = debug.assert;
const c = lib.c;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const lib = @import("../lib.zig");
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

        sprite: struct {
            filepaths: @This().Filepaths,
            textures: []*c.SDL_Texture,

            pub const Filepaths = std.StringHashMap([]const u8);
        } = undefined,
        bitmap_font: *c.SDL_Texture = undefined,
        background: *c.SDL_Texture = undefined,

        const Self = @This();

        pub usingnamespace Ext;

        pub fn deinit(rx: *Self) void {
            defer rx.* = .{};
            rx.sprite.filepaths.deinit();
            lib.allocator.free(rx.sprite.textures);
            c.SDL_DestroyRenderer(rx.renderer); // Implicitly frees all its textures.
            c.SDL_DestroyWindow(rx.window);
            c.SDL_QuitSubSystem(c.SDL_INIT_VIDEO);
            sdl.expect(c.SDL_ResetHint(c.SDL_HINT_MAIN_CALLBACK_RATE), "") catch unreachable;
        }

        pub fn init() !Self {
            {
                var buf: [lib.digitSizeOf(@TypeOf(lib.g.settings.screen.fps)) + "\x00".len]u8 = undefined;
                try sdl.expect(c.SDL_SetHint(
                    c.SDL_HINT_MAIN_CALLBACK_RATE,
                    try fmt.bufPrintZ(&buf, "{}", .{lib.g.settings.screen.fps}),
                ), "");
            }
            errdefer sdl.expect(c.SDL_ResetHint(c.SDL_HINT_MAIN_CALLBACK_RATE), "") catch unreachable;

            try sdl.expect(c.SDL_InitSubSystem(c.SDL_INIT_VIDEO), "couldn't initialize SDL video subsystem: ");
            errdefer c.SDL_QuitSubSystem(c.SDL_INIT_VIDEO);

            var maybe_window: ?*c.SDL_Window, var maybe_renderer: ?*c.SDL_Renderer = .{null} ** 2;
            try sdl.expect(
                c.SDL_CreateWindowAndRenderer(
                    lib.g.settings.game_name.ptr,
                    @intFromFloat(lib.g.settings.screen.width),
                    @intFromFloat(lib.g.settings.screen.height),
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

            var sprite: @FieldType(Self, "sprite") = undefined;

            sprite.textures = try lib.allocator.alloc(*c.SDL_Texture, lib.g.settings.sprites.len);
            errdefer lib.allocator.free(sprite.textures);

            sprite.filepaths = @TypeOf(sprite).Filepaths.init(lib.allocator);
            errdefer sprite.filepaths.deinit();

            try sprite.filepaths.ensureTotalCapacity(@intCast(lib.g.settings.sprites.len));
            for (lib.g.settings.sprites) |sprite_filepath|
                sprite.filepaths.putAssumeCapacityNoClobber(path.stem(sprite_filepath), sprite_filepath);

            var rx = Self{
                .is_inited = true,
                .window = window,
                .renderer = renderer,
                .sprite = sprite,
            };
            rx.bitmap_font = try rx.loadTexture(lib.g.settings.bitmap_font);
            try sdl.expect(c.SDL_SetTextureScaleMode(rx.bitmap_font, c.SDL_SCALEMODE_NEAREST), "");
            return rx;
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
            rx.background = try rx.loadTexture(lib.g.settings.background);
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

        pub fn draw(rx: *const Self, sprite_idx: usize, center: lib.Vec2, maybe_angle: ?f32) !void {
            const sprite = rx.sprite.textures[sprite_idx];
            const up_left = lib.Vec2{
                .x = center.x - @as(f32, @floatFromInt(@divTrunc(sprite.w, 2))),
                .y = center.y - @as(f32, @floatFromInt(@divTrunc(sprite.h, 2))),
            };
            try if (maybe_angle) |angle|
                sdl.expect(c.SDL_RenderTextureRotated(
                    rx.renderer,
                    sprite,
                    null,
                    &.{
                        .x = up_left.x,
                        .y = up_left.y,
                        .w = @floatFromInt(sprite.w),
                        .h = @floatFromInt(sprite.h),
                    },
                    math.radiansToDegrees(angle),
                    null,
                    c.SDL_FLIP_NONE,
                ), "")
            else
                sdl.expect(c.SDL_RenderTexture(
                    rx.renderer,
                    sprite,
                    null,
                    &.{
                        .x = up_left.x,
                        .y = up_left.y,
                        .w = @floatFromInt(sprite.w),
                        .h = @floatFromInt(sprite.h),
                    },
                ), "");
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
        pub fn textWrite(rx: *const Self, text: []const u8, maybe_color: ?c.SDL_Color) !void {
            assert(null == maybe_color);
            // const max = math.maxInt(u8);
            // const color: c.SDL_Color =
            //     if (maybe_color) |color| color else .{ .r = max, .g = max, .b = max, .a = max };
            const font = .{ .width = 12, .height = 24 };
            const scale = 4;
            var dst = lib.Vec2{
                .x = lib.g.settings.screen.width / 2 -
                    @as(f32, @floatFromInt(text.len)) * scale * font.width / 2,
                .y = lib.g.settings.screen.height / 2 - scale * font.height / 2,
            };
            for (text) |ascii_ch| {
                const space_based_idx = ascii_ch - ' ';
                const src = lib.Vec2{
                    .x = @as(f32, @floatFromInt(space_based_idx % 16)) * font.width,
                    .y = @as(f32, @floatFromInt(space_based_idx / 16)) * font.height,
                };
                try sdl.expect(c.SDL_RenderTexture(
                    rx.renderer,
                    rx.bitmap_font,
                    &.{
                        .x = src.x,
                        .y = src.y,
                        .w = font.width,
                        .h = font.height,
                    },
                    &.{
                        .x = dst.x,
                        .y = dst.y,
                        .w = scale * font.width,
                        .h = scale * font.height,
                    },
                ), "");
                dst.x += scale * font.width;
            }
        }
    };
}
