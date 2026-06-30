const std = @import("std");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const assets = @import("assets.zig");

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

        const openmpt = OpenMPT{
            .handle = handle,
            .module_create_from_memory = @ptrCast(std.c.dlsym(handle, "openmpt_module_create_from_memory")),
            .module_destroy = @ptrCast(std.c.dlsym(handle, "openmpt_module_destroy")),
            .module_read_interleaved_stereo = @ptrCast(std.c.dlsym(handle, "openmpt_module_read_interleaved_stereo")),
            .module_set_repeat_count = @ptrCast(std.c.dlsym(handle, "openmpt_module_set_repeat_count")),
        };

        if (openmpt.module_create_from_memory == null)
            return error.SymbolMissing;

        return openmpt;
    }

    fn deinit(self: OpenMPT) void {
        _ = std.c.dlclose(self.handle.?);
    }
};

const MusicTrack = struct {
    module: ?*anyopaque,
    openmpt: OpenMPT,
    buffer: [BUFFER_FRAMES * CHANNELS]i16 = undefined,

    fn init(data: []const u8, openmpt: OpenMPT) !MusicTrack {
        const module = openmpt.module_create_from_memory.?(
            data.ptr,
            data.len,
            null,
            null,
            null,
        );
        if (module == null) {
            return error.ModuleLoadingFailure;
        }
        openmpt.module_set_repeat_count(module, -1);

        return .{ .module = module, .openmpt = openmpt };
    }

    fn progress_play(self: *MusicTrack, stream: ?*sdl.SDL_AudioStream) void {
        const frames = self.openmpt.module_read_interleaved_stereo(
            self.module, SAMPLE_RATE, BUFFER_FRAMES, &self.buffer,
        );
        if (frames != 0) {
            _ = sdl.SDL_PutAudioStreamData(stream, &self.buffer, @intCast(frames * CHANNELS * @sizeOf(i16)));
        }
    }

    fn deinit(self: *MusicTrack) void {
        self.openmpt.module_destroy(self.module);
    }
};

pub const SoundManager = struct {
    allocator: std.mem.Allocator,
    openmpt: ?OpenMPT,
    music: ?MusicTrack,
    music_stream: ?*sdl.SDL_AudioStream,

    pub fn init(allocator: std.mem.Allocator) !SoundManager {
        const openmpt = OpenMPT.init() catch null;

        var spec: sdl.SDL_AudioSpec = undefined;
        spec.freq = SAMPLE_RATE;
        spec.format = sdl.SDL_AUDIO_S16;
        spec.channels = CHANNELS;

        const stream = sdl.SDL_OpenAudioDeviceStream(
            sdl.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
            &spec,
            null,
            null,
        );
        if (stream == null) {
            if (openmpt) |o| o.deinit();
            return error.StreamInitFailed;
        }

        if (!sdl.SDL_ResumeAudioDevice(sdl.SDL_GetAudioStreamDevice(stream))) {
            if (openmpt) |o| o.deinit();
            sdl.SDL_DestroyAudioStream(stream);
            return error.FailResumeAudio;
        }

        return SoundManager{
            .allocator = allocator,
            .openmpt = openmpt,
            .music = null,
            .music_stream = stream,
        };
    }

    pub fn deinit(self: *SoundManager) void {
        self.stop_music();
        if (self.music_stream) |stream| {
            sdl.SDL_DestroyAudioStream(stream);
        }
    }

    pub fn play_sfx(self: *SoundManager, sample: *const assets.Sample, gain: f32) void {
        _ = gain;

        const bytes_per_sample: usize = if (sample.multiplier == 0)
            1
        else
            (sample.multiplier / 4) % 2 + 1;

        const is_8bit = bytes_per_sample == 1;

        var spec = sdl.SDL_AudioSpec{
            .freq = @intCast(sample.sample_rate),
            .format = if (is_8bit) sdl.SDL_AUDIO_U8 else sdl.SDL_AUDIO_S16LE,
            .channels = 1,
        };

        if (is_8bit) {
            const decoded = self.allocator.alloc(u8, sample.data.len) catch return;
            for (sample.data, 0..) |byte, i| {
                decoded[i] = byte ^ 0x80;
            }
            const chunk = sdl.MIX_LoadRawAudioNoCopy(null, decoded.ptr, decoded.len, &spec, true) orelse {
                self.allocator.free(decoded);
                return;
            };
            self.allocator.free(decoded);
            _ = sdl.MIX_PlayAudio(gfx.sys.g_mixer, chunk);
        } else {
            const chunk = sdl.MIX_LoadRawAudioNoCopy(null, sample.data.ptr, sample.data.len, &spec, true) orelse return;
            _ = sdl.MIX_PlayAudio(gfx.sys.g_mixer, chunk);
        }
    }

    pub fn begin_play_music(self: *SoundManager, j2b_data: []const u8) !void {
        const openmpt = self.openmpt orelse return error.NoOpenMPT;

        self.stop_music();
        self.music = try MusicTrack.init(j2b_data, openmpt);
    }

    pub fn stop_music(self: *SoundManager) void {
        if (self.music) |*m| {
            m.deinit();
        }
        self.music = null;
    }

    pub fn update(self: *SoundManager) void {
        if (self.music) |*m| {
            m.progress_play(self.music_stream);
        }
    }
};
