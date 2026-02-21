const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx.zig");
const asset_reader = @import("assets_reader.zig");

pub fn readFileAlloc(
    allocator: std.mem.Allocator,
    filename: []const u8,
) ![]u8 {
    const cwd = std.fs.cwd();

    const file = try cwd.openFile(filename, .{});
    defer file.close();

    const stat = try file.stat();
    var buff = try allocator.alloc(u8, stat.size);
    // const io: std.Io.Reader = .fixed(buff);

    buff = try cwd.readFile(filename, buff);
    return buff;
}

pub const DiagSound = struct {
    allocator: std.mem.Allocator,
    // sound: gfx.Sound,
    update_once: bool = false,

    pub fn init(alloc: std.mem.Allocator, j2b_path: []const u8) !DiagSound {
        try loadOpenMPT();
        // const sound_raw = try asset_reader.load_music(alloc, j2b_path);
        // defer alloc.free(sound_raw.data);
        // Read file into memory
        const file_data = try readFileAlloc(alloc, j2b_path);
        defer alloc.free(file_data);

        g_module =
            g_openmpt.openmpt_module_create_from_memory.?(
                file_data.ptr,
                file_data.len,
                null,
                null,
                null,
            );

        if (g_module == null) {
            std.debug.print("Failed to load module\n", .{});
            return error.ModuleLoadingFailure;
        }
        try play_init();
        return .{
            .allocator = alloc,
            // .sound = try .init_from_raw(sound_raw.data),
        };
    }
    pub fn app_cast(self: *DiagSound) app.IApp {
        return .{ .ptr = self, .vtable = &.{
            .update = update,
            .deinit = deinit,
        } };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagSound = @ptrCast(@alignCast(ctx));

        self.clear_screen();

        if (!self.update_once) {
            // self.sound.play();
            self.update_once = true;
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagSound = @ptrCast(@alignCast(ctx));
        _ = self;
    }

    fn clear_screen(self: *DiagSound) void {
        _ = self;
        const now_: f32 = gfx.get_ticks();
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gfx.clean_screen(red, green, blue);
    }
};

const SAMPLE_RATE = 48000;
const CHANNELS = 2;
const BUFFER_FRAMES = 1024;

const OpenMPT = struct {
    handle: ?*anyopaque,

    openmpt_module_create_from_memory: ?*const fn (
        data: ?*const anyopaque,
        size: usize,
        logfunc: ?*const anyopaque,
        loguser: ?*anyopaque,
        err: ?*c_int,
    ) callconv(.c) ?*anyopaque,

    openmpt_module_destroy: *const fn (?*anyopaque) callconv(.c) void,

    openmpt_module_read_interleaved_stereo: *const fn (
        module: ?*anyopaque,
        samplerate: c_int,
        count: usize,
        buffer: [*c]i16,
    ) callconv(.c) usize,

    openmpt_module_set_repeat_count: *const fn (
        module: ?*anyopaque,
        repeat: c_int,
    ) callconv(.c) void,
};

var g_module: ?*anyopaque = null;
var g_openmpt: OpenMPT = undefined;

fn loadOpenMPT() !void {
    const rtld = std.c.RTLD{ .NOW = true };
    const handle = std.c.dlopen("libopenmpt.so", rtld);
    // const handle = std.c.dlopen("/usr/lib/x86_64-linux-gnu/libopenmpt.so", rtld);
    if (handle == null) return error.OpenFailed;

    g_openmpt = OpenMPT{
        .handle = handle,
        .openmpt_module_create_from_memory =
        // @ptrCast(@TypeOf(g_openmpt.openmpt_module_create_from_memory),
        @ptrCast(std.c.dlsym(handle, "openmpt_module_create_from_memory")),
        .openmpt_module_destroy =
        // @ptrCast(@TypeOf(g_openmpt.openmpt_module_destroy),
        @ptrCast(std.c.dlsym(handle, "openmpt_module_destroy")),
        .openmpt_module_read_interleaved_stereo =
        // @ptrCast(@TypeOf(g_openmpt.openmpt_module_read_interleaved_stereo),
        @ptrCast(std.c.dlsym(handle, "openmpt_module_read_interleaved_stereo")),
        .openmpt_module_set_repeat_count =
        // @ptrCast(@TypeOf(g_openmpt.openmpt_module_set_repeat_count),
        @ptrCast(std.c.dlsym(handle, "openmpt_module_set_repeat_count")),
    };

    if (g_openmpt.openmpt_module_create_from_memory == null)
        return error.SymbolMissing;
}

fn audioCallback(
    userdata: ?*anyopaque,
    stream: [*c]u8,
    len: c_int,
) callconv(.c) void {
    _ = userdata;
    if (g_module == null) {
        @memset(stream[0..@intCast(len)], 0);
        return;
    }

    const frames = @as(usize, @intCast(len)) / (2 * CHANNELS);
    const out = @as([*c]i16, @ptrCast(stream));

    const written = g_openmpt.openmpt_module_read_interleaved_stereo(
        g_module,
        SAMPLE_RATE,
        frames,
        out,
    );

    if (written < frames) {
        const remaining_bytes =
            (frames - written) * CHANNELS * 2;
        _ = remaining_bytes;
        @memset(stream[(written * CHANNELS * 2)..@intCast(len)], 0);
    }
}

pub fn play_init() !void {
    g_openmpt.openmpt_module_set_repeat_count(g_module, -1);

    var spec: gfx.sdl.SDL_AudioSpec = undefined;
    spec.freq = SAMPLE_RATE;
    spec.format = gfx.sdl.SDL_AUDIO_S16;
    spec.channels = CHANNELS;

    const stream = gfx.sdl.SDL_OpenAudioDeviceStream(
        gfx.sdl.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &spec,
        null,
        null,
    );
    if (stream == null) {
        std.debug.print("Failed to open audio stream\n", .{});
        return;
    }

    const c = gfx.sdl;

    if (!c.SDL_ResumeAudioDevice(c.SDL_GetAudioStreamDevice(stream))) {
        std.debug.print("Failed to resume audio\n", .{});
        return;
    }

    std.debug.print("Playing... Press Enter to quit\n", .{});

    var buffer: [BUFFER_FRAMES * CHANNELS]i16 = undefined;

    while (true) {
        const frames = g_openmpt.openmpt_module_read_interleaved_stereo(
            g_module,
            SAMPLE_RATE,
            BUFFER_FRAMES,
            &buffer,
        );

        if (frames == 0) break;

        _ = c.SDL_PutAudioStreamData(
            stream,
            &buffer,
            @intCast(frames * CHANNELS * @sizeOf(i16)),
        );

        // std.time.sleep(10 * std.time.ns_per_ms);
        // try std.Io.sleep(.fromNamoseconds(10), .awake);
    }

    // _ = std.Io.getStdIn().reader().readByte() catch {};

    // c.SDL_DestroyAudioStream(stream);
    // g_openmpt.destroy(g_module);
}
