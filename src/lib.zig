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
    pub fn appFailure(err: anyerror) c.SDL_AppResult {
        if (err != error.Sdl)
            debug.print("{}\n{?}\n", .{ err, @errorReturnTrace() });
        return c.SDL_APP_FAILURE;
    }

    pub fn nonNull(sdl_fn_result: anytype) !*@typeInfo(@TypeOf(sdl_fn_result)).pointer.child {
        if (sdl_fn_result) |non_null| return non_null;
        printError();
        return error.Sdl;
    }

    pub fn printError() void {
        debug.print("SDL error: {s}\n", .{c.SDL_GetError()});
    }

    pub fn expect(sdl_fn_result: bool) !void {
        if (sdl_fn_result) return;
        printError();
        return error.Sdl;
    }
};

pub fn UnwrapOptional(optional: type) type {
    return @typeInfo(optional).optional.child;
}

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
pub var allocator: mem.Allocator = undefined;
pub var game_settings: *const GameSettings = undefined;

pub fn deinit() void {
    is_inited = false;
    lib.game_settings = undefined;
    lib.game_settings_parsed.deinit();
    lib.game_settings_parsed = undefined;

    lib.allocator = undefined;
    _ = lib.gpa.deinit();
    lib.gpa = undefined;
}

pub fn init(game_settings_filepath: []const u8) !void {
    lib.gpa = @TypeOf(lib.gpa).init;
    lib.allocator = lib.gpa.allocator();

    {
        var json_diagn = json.Diagnostics{};
        errdefer {
            debug.print(
                "opening '{s}':{}: ",
                .{ game_settings_filepath, json_diagn.getLine() },
            );
        }

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
var gpa: heap.GeneralPurposeAllocator(.{}) = undefined;
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
