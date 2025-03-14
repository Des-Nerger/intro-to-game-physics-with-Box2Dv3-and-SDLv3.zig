is_inited: bool = false,
stream: *c.SDL_AudioStream = undefined,
buf: []Sample = undefined,
playing: [simultaneous_max][]Sample = undefined,
samples_per_frame: usize = undefined,
sounds: [][]Sample = undefined,
// i: u32 = 0, // for underruns debugging

const Sample = i16;
const Self = @This();
const assert = debug.assert;
const builtin = @import("builtin");
const c = lib.c;
const debug = std.debug;
const lib = @import("../../lib.zig");
const meta = std.meta;
const mono = 1;
const sdl = lib.sdl;
const simultaneous_max = 6;
const std = @import("std");

inline fn masterSpec() c.SDL_AudioSpec {
    return .{
        .format = c.SDL_AUDIO_S16,
        .channels = Self.mono,
        .freq = lib.g.settings.sound.rate,
    };
}

pub fn deinit(sm: *Self) void {
    defer sm.* = .{};
    for (sm.sounds) |*sound| {
        defer sound.* = undefined;
        c.SDL_free(sound.ptr);
    }
    lib.allocator.free(sm.sounds);
    lib.allocator.free(sm.buf);
    c.SDL_DestroyAudioStream(sm.stream);
    c.SDL_QuitSubSystem(c.SDL_INIT_AUDIO);
    if (builtin.os.tag == .linux and !builtin.abi.isAndroid())
        sdl.expect(c.SDL_ResetHint(c.SDL_HINT_AUDIO_DRIVER), "") catch unreachable;
}

pub fn init() !Self {
    if (builtin.os.tag == .linux and !builtin.abi.isAndroid())
        try sdl.expect(c.SDL_SetHint(c.SDL_HINT_AUDIO_DRIVER, "pulseaudio"), "");
    errdefer if (builtin.os.tag == .linux and !builtin.abi.isAndroid())
        sdl.expect(c.SDL_ResetHint(c.SDL_HINT_AUDIO_DRIVER), "") catch unreachable;

    try sdl.expect(c.SDL_InitSubSystem(c.SDL_INIT_AUDIO), "couldn't initialize SDL audio subsystem: ");
    errdefer c.SDL_QuitSubSystem(c.SDL_INIT_AUDIO);

    const stream = try sdl.nonNull(c.SDL_OpenAudioDeviceStream(
        c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &Self.masterSpec(),
        null,
        null,
    ));
    errdefer c.SDL_DestroyAudioStream(stream);

    const samples_per_frame = @divExact(lib.g.settings.sound.rate, lib.g.settings.screen.fps);

    const buf = try lib.allocator.alloc(Self.Sample, samples_per_frame);
    errdefer lib.allocator.free(buf);

    const sounds = try lib.allocator.alloc([]Self.Sample, lib.g.settings.sounds.len); // + 1 << 55
    errdefer lib.allocator.free(sounds);
    @memset(sounds, &.{});

    errdefer for (sounds) |*sound| {
        defer sound.* = undefined;
        if (sound.len != 0)
            c.SDL_free(sound.ptr);
    };
    for (sounds, lib.g.settings.sounds) |*sound, sound_filepath| {
        var spec: c.SDL_AudioSpec = undefined;
        var maybe_audio_buf: ?[*]u8 = undefined;
        var audio_len_in_bytes: u32 = undefined;
        try sdl.expect(c.SDL_LoadWAV(sound_filepath, &spec, &maybe_audio_buf, &audio_len_in_bytes), "");
        assert(meta.eql(spec, Self.masterSpec()));
        assert(0 != audio_len_in_bytes); // Let's made .wav's with no content illegal. Whatever SDL thinks.
        sound.* = @as([*]Sample, @ptrCast(@alignCast(maybe_audio_buf.?)))[0..@divExact(
            audio_len_in_bytes,
            @sizeOf(Self.Sample),
        )];
        for (sound.*) |*sample|
            sample.* = @intFromFloat(@as(f32, @floatFromInt(sample.*)) * lib.g.settings.sound.volume);
    }

    // SDL_OpenAudioDeviceStream starts the device paused. You have to tell it to start!
    try sdl.expect(c.SDL_ResumeAudioStreamDevice(stream), "");

    return .{
        .is_inited = true,
        .stream = stream,
        .buf = buf,
        .playing = @splat(&.{}),
        .samples_per_frame = samples_per_frame,
        .sounds = sounds,
    };
}

pub fn beginFrame(sm: *Self) !void {
    @memset(sm.buf, @as(Self.Sample, 0));

    for (&sm.playing) |*sound| {
        if (sound.len == 0) continue;

        const samples_to_mix = @min(sound.len, sm.samples_per_frame);
        defer sound.* = sound.*[samples_to_mix..];

        // const simd_size = 16;
        // const V = @Vector(simd_size / @sizeOf(Self.Sample), Self.Sample);
        // Self.simdMix(sm.buf, sound.*[0..samples_to_mix]);

        for (sm.buf[0..samples_to_mix], sound.*[0..samples_to_mix]) |*buf, sample|
            buf.* +|= sample;
    }

    // defer sm.i +%= 1;   // for underruns
    // if (sm.i % 16 == 0) //     debugging

    // feed the new data to the stream. It will queue at the end,
    // and trickle out as the hardware needs more data.
    try sdl.expect(
        c.SDL_PutAudioStreamData(sm.stream, sm.buf.ptr, @intCast(sm.buf.len * @sizeOf(Self.Sample))),
        "",
    );
}

pub fn play(sm: *Self, sound_idx: usize) void {
    for (&sm.playing) |*samples|
        if (samples.len == 0) {
            samples.* = sm.sounds[sound_idx];
            return;
        };
    unreachable;
}
