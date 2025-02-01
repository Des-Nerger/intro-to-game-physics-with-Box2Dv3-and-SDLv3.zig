const assert = debug.assert;
const c = @import("c.zig");
const debug = std.debug;
const lib = @import("lib.zig");
const math = std.math;
const std = @import("std");

pub fn Renderer(Ext: type) type {
    return struct {
        window: *c.SDL_Window,

        // We will use this renderer to draw into this window every frame.
        renderer: *c.SDL_Renderer,

        const Self = @This();
        pub usingnamespace Ext;

        pub fn deinit(rx: *Self) void {
            c.SDL_DestroyRenderer(rx.renderer);
            c.SDL_DestroyWindow(rx.window);
            rx.* = undefined;
        }

        pub fn init() ?Self {
            if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
                debug.print("Couldn't initialize SDL: {s}\n", .{c.SDL_GetError()});
                return null;
            }
            var window: ?*c.SDL_Window, var renderer: ?*c.SDL_Renderer = .{null} ** 2;
            const s = lib.game_settings.value; // game_-ettings
            if (!c.SDL_CreateWindowAndRenderer(
                s.game_name.ptr,
                s.renderer.width,
                s.renderer.height,
                0,
                &window,
                &renderer,
            )) {
                debug.print("Couldn't create window/renderer: {s}\n", .{c.SDL_GetError()});
                return null;
            }
            return .{ .window = window.?, .renderer = renderer.? };
        }

        pub fn load(rx: *Self, obj_type: i32, name: [:0]const u8) ?void {
            _ = .{ rx, obj_type, name };
        }

        pub fn loadBackground(rx: *Self) ?void {
            _ = .{rx};
        }

        pub fn beginScene(rx: *const Self) void {
            assert(true == c.SDL_SetRenderDrawColor(rx.renderer, 0x80, 0x42, 0x66, c.SDL_ALPHA_OPAQUE));
            assert(true == c.SDL_RenderClear(rx.renderer));
        }

        pub fn endScene(rx: *const Self) void {
            assert(true == c.SDL_RenderPresent(rx.renderer));
        }

        pub fn drawBackground(rx: *const Self) void {
            _ = .{rx};
        }

        pub fn drawObjects(rx: *const Self) void {
            _ = .{rx};
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
