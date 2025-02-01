const Object = @import("Object.zig");
const Self = lib.Renderer(@This());
const g = @import("sdl_app.zig").g;
const lib = @import("lib");

/// Load game images. Gets file list from `*.game_settings.json`.
pub fn loadImages(rw: *Self) ?void {
    rw.loadBackground() orelse return null;

    // Load sprite for each object
    for ([_]Object.Type{ .arrow, .cueball, .eightball }) |tag|
        rw.load(@intFromEnum(tag), @tagName(tag)) orelse return null;
}

/// Tell the player whether they've won or lost by plastering a text banner across the screen.
/// \param state The game state, which tells whether the player has won or lost.
pub fn maybeDrawWinLoseMessage(rw: *const Self, game_state: g.State) void {
    switch (game_state) {
        .won => rw.textWrite("You Win!", null),
        .lost => rw.textWrite("Loser!", null),
        else => {},
    }
}
