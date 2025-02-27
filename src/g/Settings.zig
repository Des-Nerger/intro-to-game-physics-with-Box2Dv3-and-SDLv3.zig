game_name: [:0]u8,
screen: struct { fps: u24, width: f32, height: f32 },
bitmap_font: [:0]u8,
background: [:0]u8,
sprites: [][:0]u8,
sound: struct { rate: u24, volume: f32 },
sounds: [][:0]u8,

const Self = @This();
const json = std.json;
const std = @import("std");
const testing = std.testing;

test "parse and stringify back" {
    const input_slice =
        \\{
        \\    "game_name": "Game",
        \\    "renderer": {
        \\        "fps": 120,
        \\        "width": 720,
        \\        "height": 480
        \\    },
        \\    "bitmap_font": "images/bitmap_font_u13n_ascii.png",
        \\    "background": "images/background.png",
        \\    "sprites": [
        \\        "images/sprite_0.png",
        \\        "images/sprite_1.png",
        \\        "images/sprite_2.png"
        \\    ],
        \\    "sound": {
        \\        "rate": 44100,
        \\        "volume": 8.00000011920929e-1
        \\    },
        \\    "sounds": [
        \\        "sounds/sound_0.wav",
        \\        "sounds/sound_1.wav",
        \\        "sounds/sound_2.wav",
        \\        "sounds/sound_3.wav"
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
