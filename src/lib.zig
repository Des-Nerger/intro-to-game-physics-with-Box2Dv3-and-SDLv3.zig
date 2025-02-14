pub const GameSettings = @import("GameSettings.zig");
pub const Renderer = @import("renderer.zig").Renderer;
pub const Rot = @import("Rot.zig");
pub const SoundManager = @import("SoundManager.zig");
pub const Vec2 = @import("Vec2.zig");
/// 0.0023 degrees
pub const atan_tol = 0.00004;
pub const c = @cImport({
    if (builtin.is_test)
        @cDefine("main", "SDL_main")
    else
        @cDefine("SDL_MAIN_USE_CALLBACKS", {}); // use the callbacks instead of main()
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});
pub const sdl = struct {
    var leaked_first_88: []u8 = &.{}; // FIXME

    pub fn deinit() void {
        const disabled = struct {
            var fba = heap.FixedBufferAllocator.init(&.{});
            var allocator = @This().fba.allocator();
        };
        sdl.expect(
            @call(.auto, c.SDL_SetMemoryFunctions, sdl.memFns(&disabled.allocator)),
            "",
        ) catch unreachable;

        // lib.allocator.free(sdl.leaked_first_88); // a hacky way to stop up the leak. FIXME
        sdl.leaked_first_88 = &.{}; // FIXME
    }

    pub fn init(comptime allocator: *const mem.Allocator) !void {
        try sdl.expect(@call(.auto, c.SDL_SetMemoryFunctions, sdl.memFns(allocator)), "");
    }

    pub fn memFns(comptime allocator: *const mem.Allocator) struct {
        c.SDL_malloc_func,
        c.SDL_calloc_func,
        c.SDL_realloc_func,
        c.SDL_free_func,
    } {
        const Allocator = struct {
            fn malloc(size: usize) callconv(.c) ?*anyopaque {
                const byte_slice = allocator.alloc(u8, @sizeOf(usize) + size) catch unreachable;
                @as(*align(@alignOf(u8)) usize, @ptrCast(byte_slice.ptr)).* = byte_slice.len;
                if (byte_slice.len == @sizeOf(usize) + 88 and leaked_first_88.len == 0) // FIXME
                    sdl.leaked_first_88 = byte_slice; // FIXME
                return byte_slice[@sizeOf(usize)..].ptr;
            }
            fn calloc(nmemb: usize, size: usize) callconv(.c) ?*anyopaque {
                var byte_slice = allocator.alloc(u8, @sizeOf(usize) + nmemb * size) catch unreachable;
                @as(*align(@alignOf(u8)) usize, @ptrCast(byte_slice.ptr)).* = byte_slice.len;
                byte_slice = byte_slice[@sizeOf(usize)..];
                @memset(byte_slice, 0);
                return byte_slice.ptr;
            }
            fn realloc(maybe_ptr: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque {
                const ptr: [*]u8 = if (maybe_ptr) |ptr|
                    @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize))
                else
                    return @This().malloc(size);
                const saved_size = @as(*align(@alignOf(u8)) usize, @ptrCast(ptr)).*;
                const byte_slice =
                    allocator.realloc(ptr[0..saved_size], @sizeOf(usize) + size) catch unreachable;
                @as(*align(@alignOf(u8)) usize, @ptrCast(byte_slice.ptr)).* = byte_slice.len;
                return byte_slice[@sizeOf(usize)..].ptr;
            }
            fn free(maybe_ptr: ?*anyopaque) callconv(.c) void {
                const ptr: [*]u8 =
                    if (maybe_ptr) |ptr| @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)) else return;
                const saved_size = @as(*align(@alignOf(u8)) usize, @ptrCast(ptr)).*;
                allocator.free(ptr[0..saved_size]);
            }
        };
        return .{ Allocator.malloc, Allocator.calloc, Allocator.realloc, Allocator.free };
    }

    pub fn appFailure(err: anyerror) c.SDL_AppResult {
        const trace = @errorReturnTrace();
        if (err == error.Sdl)
            debug.print("{?}\n", .{trace})
        else
            debug.print("{}\n{?}\n", .{ err, trace });
        return c.SDL_APP_FAILURE;
    }

    fn NonNull(Parent: anytype) type {
        const ty_info = @typeInfo(Parent);
        return switch (ty_info) {
            .pointer => |pointer| pointer.child,
            .optional => |optional| @typeInfo(optional.child).pointer.child,
            else => comptime unreachable,
        };
    }

    pub fn nonNull(sdl_fn_result: anytype) !*sdl.NonNull(@TypeOf(sdl_fn_result)) {
        if (sdl_fn_result) |non_null| return non_null;
        printError("");
        return error.Sdl;
    }

    fn printError(prefix_msg: []const u8) void {
        debug.print("{s}SDL error: {s}\n", .{ prefix_msg, c.SDL_GetError() });
    }

    pub fn expect(sdl_fn_result: bool, prefix_msg: []const u8) !void {
        if (sdl_fn_result) return;
        printError(prefix_msg);
        return error.Sdl;
    }
};

/// https://stackoverflow.com/questions/46210708/atan2-approximation-with-11bits-in-mantissa-on-x86with-sse2-and-armwith-vfpv4
pub fn atan2(y: f32, x: f32) f32 {
    // Added check for (0,0) to match math.atan2 and avoid NaN
    if (x == 0.0 and y == 0.0)
        return 0.0;

    const ax, const ay = .{ @abs(x), @abs(y) };
    const mn, const mx = .{ @min(ay, ax), @max(ay, ax) };
    const a = mn / mx;

    // Minimax polynomial approximation to atan(a) on [0,1]
    const s = a * a;
    const q = s * s;
    var r, const t = .{ 0.024840285 * q + 0.18681418, -0.094097948 * q - 0.33213072 };
    r = r * s + t;
    r = r * (s * a) + a;

    // Map to full circle
    if (ay > ax)
        r = 1.57079637 - r;

    if (x < 0)
        r = 3.14159274 - r;

    if (y < 0)
        r = -r;

    return r;
}
test atan2 {
    try testing.expectApproxEqAbs(
        atan2(-1.0, 2.0),
        math.atan2(@as(f32, -1.0), 2.0),
        atan_tol,
    );
}

/// Number of decimal digits needed to "store" an unsigned-integer type.
pub fn digitSizeOf(U: type) math.Log2Int(U) { // Log2Int is a rough estimate.
    if (.int != @typeInfo(U) or .unsigned != @typeInfo(U).int.signedness)
        @compileError("expected unsigned-integer type, found '" ++ @typeName(U) ++ "' one");
    return 1 + math.log10_int(@as(U, math.maxInt(U)));
}
test digitSizeOf {
    try testing.expectEqual(1, digitSizeOf(u3));
    try testing.expectEqual(2, digitSizeOf(u4));
    try testing.expectEqual(2, digitSizeOf(u6));
    try testing.expectEqual(3, digitSizeOf(u8));
    try testing.expectEqual(3, digitSizeOf(u9));
    try testing.expectEqual(4, digitSizeOf(u10));
    try testing.expectEqual(5, digitSizeOf(u16));
}

//___________________/ encapsulated \___________________
pub var is_inited = false;
pub usingnamespace struct {
    pub var allocator: mem.Allocator = undefined;
};
pub var game_settings: *const GameSettings = undefined;

pub fn deinit() void {
    is_inited = false;
    lib.game_settings = undefined;
    lib.game_settings_parsed.deinit();
    lib.game_settings_parsed = undefined;

    sdl.deinit();

    lib.allocator = undefined;
    _ = lib.gpa.deinit();
    lib.gpa = undefined;
}

pub fn init(game_settings_filepath: []const u8) !void {
    lib.gpa = @TypeOf(lib.gpa).init;
    lib.allocator = lib.gpa.allocator();

    try sdl.init(&lib.allocator);

    {
        var json_diagn = json.Diagnostics{};
        errdefer debug.print("opening '{s}':{}: ", .{ game_settings_filepath, json_diagn.getLine() });

        const file = try fs.cwd().openFile(game_settings_filepath, .{});
        defer file.close();

        var json_reader = json.reader(lib.allocator, file.reader());
        defer json_reader.deinit();
        json_reader.enableDiagnostics(&json_diagn);

        lib.game_settings_parsed = try json.parseFromTokenSource(
            GameSettings,
            lib.allocator,
            &json_reader,
            .{},
        );
        lib.game_settings = &lib.game_settings_parsed.value;
    }

    if (path.dirname(game_settings_filepath)) |new_cwd| {
        posix.chdir(new_cwd) catch |err| {
            debug.print("chdir to '{s}': ", .{new_cwd});
            return err;
        };
    }

    is_inited = true;
}

var game_settings_parsed: json.Parsed(GameSettings) = undefined;
var gpa: heap.GeneralPurposeAllocator(.{}) = undefined; // .{ .safety = false }
//¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\ encapsulated /¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

const builtin = @import("builtin");
const debug = std.debug;
const fs = std.fs;
const heap = std.heap;
const json = std.json;
const lib = @This();
const math = std.math;
const mem = std.mem;
const path = fs.path;
const posix = std.posix;
const std = @import("std");
const testing = std.testing;
test {
    testing.refAllDecls(@This());
}
