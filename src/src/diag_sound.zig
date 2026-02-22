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

    buff = try cwd.readFile(filename, buff);
    return buff;
}

pub const DiagSound = struct {
    allocator: std.mem.Allocator,
    update_once: bool = false,
    openmpt: OpenMPT,
    music: J2bSound,
    stream: ?*gfx.sdl.SDL_AudioStream,

    pub fn init(alloc: std.mem.Allocator, j2b_path: []const u8) !DiagSound {
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
            return error.StreamInitFailed;
        }

        if (!gfx.sdl.SDL_ResumeAudioDevice(gfx.sdl.SDL_GetAudioStreamDevice(stream))) {
            std.debug.print("Failed to resume audio\n", .{});
            return error.FailResumeAudio;
        }

        const openmpt: OpenMPT = try .init();

        const file_data = try readFileAlloc(alloc, j2b_path);
        defer alloc.free(file_data);

        const music = try J2bSound.init(file_data, openmpt);

        return .{
            .allocator = alloc,
            .openmpt = openmpt,
            .music = music,
            .stream = stream,
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
        self.music.progress_play(self.stream);

        if (!self.update_once) {
            // self.sound.play();
            self.update_once = true;
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagSound = @ptrCast(@alignCast(ctx));
        self.music.deinit();
        self.openmpt.deinit();
        gfx.sdl.SDL_DestroyAudioStream(self.stream);
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

    module_create_from_memory: ?*const fn (
        data: ?*const anyopaque,
        size: usize,
        logfunc: ?*const anyopaque,
        loguser: ?*anyopaque,
        err: ?*c_int,
    ) callconv(.c) ?*anyopaque,

    module_destroy: *const fn (?*anyopaque) callconv(.c) void,

    module_read_interleaved_stereo: *const fn (
        module: ?*anyopaque,
        samplerate: c_int,
        count: usize,
        buffer: [*c]i16,
    ) callconv(.c) usize,

    module_set_repeat_count: *const fn (
        module: ?*anyopaque,
        repeat: c_int,
    ) callconv(.c) void,

    fn init() !OpenMPT {
        const rtld = std.c.RTLD{ .NOW = true };
        const handle = std.c.dlopen("libopenmpt.so", rtld);
        if (handle == null) return error.OpenFailed;
        errdefer _ = std.c.dlclose(handle.?);
        // const handle = std.c.dlopen("/usr/lib/x86_64-linux-gnu/libopenmpt.so", rtld);
        var openmpt = OpenMPT{
            .handle = handle,
            .module_create_from_memory =
            // @ptrCast(@TypeOf(g_openmpt.openmpt_module_create_from_memory),
            @ptrCast(std.c.dlsym(handle, "openmpt_module_create_from_memory")),
            .module_destroy =
            // @ptrCast(@TypeOf(g_openmpt.openmpt_module_destroy),
            @ptrCast(std.c.dlsym(handle, "openmpt_module_destroy")),
            .module_read_interleaved_stereo =
            // @ptrCast(@TypeOf(g_openmpt.openmpt_module_read_interleaved_stereo),
            @ptrCast(std.c.dlsym(handle, "openmpt_module_read_interleaved_stereo")),
            .module_set_repeat_count =
            // @ptrCast(@TypeOf(g_openmpt.openmpt_module_set_repeat_count),
            @ptrCast(std.c.dlsym(handle, "openmpt_module_set_repeat_count")),
        };

        if (openmpt.module_create_from_memory == null)
            return error.SymbolMissing;

        return openmpt;
    }

    fn deinit(self: OpenMPT) void {
        _ = std.c.dlclose(self.handle.?);
    }
};

// fn audioCallback(
//     userdata: ?*anyopaque,
//     stream: [*c]u8,
//     len: c_int,
// ) callconv(.c) void {
//     _ = userdata;
//     if (g_module == null) {
//         @memset(stream[0..@intCast(len)], 0);
//         return;
//     }
//
//     const frames = @as(usize, @intCast(len)) / (2 * CHANNELS);
//     const out = @as([*c]i16, @ptrCast(stream));
//
//     const written = g_openmpt.openmpt_module_read_interleaved_stereo(
//         g_module,
//         SAMPLE_RATE,
//         frames,
//         out,
//     );
//
//     if (written < frames) {
//         const remaining_bytes =
//             (frames - written) * CHANNELS * 2;
//         _ = remaining_bytes;
//         @memset(stream[(written * CHANNELS * 2)..@intCast(len)], 0);
//     }
// }

const J2bSound = struct {
    module: ?*anyopaque,
    openmpt: OpenMPT,
    buffer: [BUFFER_FRAMES * CHANNELS]i16 = undefined,

    fn init(data: []const u8, openmpt: OpenMPT) !J2bSound {
        const module =
            openmpt.module_create_from_memory.?(
                data.ptr,
                data.len,
                null,
                null,
                null,
            );
        if (module == null) {
            std.debug.print("Failed to load module\n", .{});
            return error.ModuleLoadingFailure;
        }
        openmpt.module_set_repeat_count(module, -1);

        return .{ .module = module, .openmpt = openmpt };
    }

    fn progress_play(self: *J2bSound, stream: ?*gfx.sdl.SDL_AudioStream) void {
        const frames = self.openmpt.module_read_interleaved_stereo(self.module, SAMPLE_RATE, BUFFER_FRAMES, &self.buffer);
        if (frames != 0) {
            _ = gfx.sdl.SDL_PutAudioStreamData(stream, &self.buffer, @intCast(frames * CHANNELS * @sizeOf(i16)));
        }
    }

    fn deinit(self: *J2bSound) void {
        _ = self;
    }
};
