pub const GameSettings = @import("GameSettings.zig");
pub const Renderer = @import("renderer.zig").Renderer;
pub const Rot = @import("Rot.zig");
pub const Vec2 = @import("Vec2.zig");
/// 0.0023 degrees
pub const atan_tol = 0.00004;
pub usingnamespace struct {
    pub const c = @import("c.zig");
    pub var allocator: mem.Allocator = undefined;
    pub var gpa: heap.GeneralPurposeAllocator(.{}) = undefined;
    pub var game_settings: json.Parsed(GameSettings) = undefined;

    pub fn deinit() void {
        lib.game_settings.deinit();
        lib.allocator = undefined;
        _ = lib.gpa.deinit();
    }

    pub fn init(game_settings_filepath: []const u8) ?void {
        lib.initErr(game_settings_filepath) catch |err| {
            debug.print(
                "opening '{s}':{}: {}\n",
                .{ game_settings_filepath, lib.json_diagn.getLine(), err },
            );
            return null;
        };
    }

    var json_diagn: json.Diagnostics = undefined;

    fn initErr(game_settings_filepath: []const u8) !void {
        lib.gpa = @TypeOf(lib.gpa).init;
        lib.allocator = lib.gpa.allocator();

        lib.json_diagn = json.Diagnostics{};

        const file = try fs.cwd().openFile(game_settings_filepath, .{});
        defer file.close();

        var json_reader = json.reader(lib.allocator, file.reader());
        defer json_reader.deinit();

        json_reader.enableDiagnostics(&lib.json_diagn);

        lib.game_settings = try json.parseFromTokenSource(
            GameSettings,
            lib.allocator,
            &json_reader,
            .{},
        );
    }
};
pub const mem = std.mem;
pub const meta = struct {
    pub fn UnwrapOptional(optional: type) type {
        return @typeInfo(optional).optional.child;
    }
};

const debug = std.debug;
const fs = std.fs;
const heap = std.heap;
const json = std.json;
const lib = @This();
const math = std.math;
const std = @import("std");
const testing = std.testing;

test {
    testing.refAllDecls(@This());
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
    const c, const q = .{ s * a, s * s };
    var r, const t = .{ 0.024840285 * q + 0.18681418, -0.094097948 * q - 0.33213072 };
    r = r * s + t;
    r = r * c + a;

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
