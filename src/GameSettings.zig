game_name: [:0]u8,
renderer: struct { width: i32, height: i32 },
bitmap_font: [:0]u8,
images: []struct { src: [:0]u8 },
sprites: []struct { name: [:0]u8, file: [:0]u8 },
sound: struct { level: i32, cps: i32, bps: i32, rate: i32 },
sounds: []struct { file: [:0]u8, copies: i32 },

const Self = @This();
const json = std.json;
const std = @import("std");
const testing = std.testing;

test "parse and stringify back" {
    const input_slice =
        \\{
        \\    "game_name": "Game",
        \\    "renderer": {
        \\        "width": 720,
        \\        "height": 480
        \\    },
        \\    "bitmap_font": "images/bitmap-font.png",
        \\    "images": [
        \\        {
        \\            "src": "images/image.png"
        \\        }
        \\    ],
        \\    "sprites": [
        \\        {
        \\            "name": "sprite_0",
        \\            "file": "images/sprite-0.png"
        \\        },
        \\        {
        \\            "name": "sprite_1",
        \\            "file": "images/sprite-1.png"
        \\        },
        \\        {
        \\            "name": "sprite_2",
        \\            "file": "images/sprite-2.png"
        \\        }
        \\    ],
        \\    "sound": {
        \\        "level": 0,
        \\        "cps": 2,
        \\        "bps": 16,
        \\        "rate": 44100
        \\    },
        \\    "sounds": [
        \\        {
        \\            "file": "sounds/sound-0.wav",
        \\            "copies": 1
        \\        },
        \\        {
        \\            "file": "sounds/sound-1.wav",
        \\            "copies": 4
        \\        },
        \\        {
        \\            "file": "sounds/sound-2.wav",
        \\            "copies": 4
        \\        },
        \\        {
        \\            "file": "sounds/sound-3.wav",
        \\            "copies": 2
        \\        }
        \\    ]
        \\}
    ;
    var parsed = try json.parseFromSlice(
        Self,
        testing.allocator,
        input_slice,
        .{},
    );
    defer parsed.deinit();
    const output_slice = try json.stringifyAlloc(testing.allocator, parsed.value, .{ .whitespace = .indent_4 });
    defer testing.allocator.free(output_slice);
    try testing.expectEqualStrings(input_slice, output_slice);
}
