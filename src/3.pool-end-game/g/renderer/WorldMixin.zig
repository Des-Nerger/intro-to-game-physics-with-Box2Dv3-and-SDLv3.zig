const Self = @This();
const g = @import("../../sdl_app.zig").g;
const lib = @import("lib");

/// Load game images. Gets file list from `*.game_settings.json`.
pub fn loadImages(wm: *Self) !void {
    const rw: *g.RendererWorld = @alignCast(@fieldParentPtr("world", wm));
    try rw.loadBackground();

    // Load sprite for each object
    for ([_]g.Object.Type{ .vector_arrow, .cue_ball, .eight_ball }) |tag|
        try rw.load(@intFromEnum(tag), @tagName(tag));
}

/// Tell the player whether they've won or lost by plastering a text banner across the screen.
/// \param state The game state, which tells whether the player has won or lost.
pub fn maybeDrawWinLoseMessage(wm: *const Self, game_state: g.State) !void {
    const rw: *const g.RendererWorld = @alignCast(@fieldParentPtr("world", wm));
    switch (game_state) {
        .won => try rw.textWrite("You Win!", null),
        .lost => try rw.textWrite("Loser!", null),
        else => {},
    }
}
