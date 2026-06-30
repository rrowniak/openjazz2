//! Compatibility shim: provides the old `std.fs.cwd()`, `Dir`, `File` API
//! which was removed in zig 0.16.0 in favor of the new `std.Io` system.
//!
//! The new API requires threading a `std.Io` instance through every caller,
//! which would be an invasive refactor. Instead we store a global `Io`
//! (initialized from `main`'s `std.process.Init.io` or `std.testing.io`)
//! and wrap `std.Io.Dir`/`File` behind the old convenient signatures.
//!
//! This is a migration shim — if the project ever rewrites its I/O layer
//! to pass `Io` explicitly, this module can be deleted.

const std = @import("std");
const builtin = @import("builtin");

var g_io: std.Io = if (builtin.is_test) std.testing.io else undefined;

pub fn init(io: std.Io) void {
    g_io = io;
}

pub fn deinit() void {}

pub fn cwd() Dir {
    return Dir.cwd();
}

pub const Dir = struct {
    inner: std.Io.Dir,

    pub fn cwd() Dir {
        return .{ .inner = std.Io.Dir.cwd() };
    }

    pub fn openFile(dir: Dir, sub_path: []const u8, _: struct {}) !File {
        const file = try dir.inner.openFile(g_io, sub_path, .{ .mode = .read_only });
        return .{ .inner = file, .seek_pos = 0 };
    }

    pub fn openDir(dir: Dir, sub_path: []const u8, options: struct { iterate: bool = false }) !Dir {
        const new_dir = try dir.inner.openDir(g_io, sub_path, .{ .iterate = options.iterate });
        return .{ .inner = new_dir };
    }

    pub fn readFile(dir: Dir, sub_path: []const u8, buffer: []u8) ![]u8 {
        var file = try dir.openFile(sub_path, .{});
        defer file.close();
        const stat = try file.stat();
        const to_read = @min(buffer.len, stat.size);
        const n = try file.inner.readPositional(g_io, &.{buffer[0..to_read]}, 0);
        return buffer[0..n];
    }

    pub fn close(dir: Dir) void {
        dir.inner.close(g_io);
    }

    pub fn iterate(dir: Dir) Dir.Iterator {
        return .{ .inner = dir.inner.iterate() };
    }

    pub const Iterator = struct {
        inner: std.Io.Dir.Iterator,

        pub fn next(it: *Iterator) !?std.Io.Dir.Entry {
            return it.inner.next(g_io);
        }
    };
};

pub const File = struct {
    inner: std.Io.File,
    seek_pos: u64,

    pub fn read(self: *File, buffer: []u8) !usize {
        const n = try self.inner.readPositional(g_io, &.{buffer}, self.seek_pos);
        self.seek_pos += n;
        return n;
    }

    pub fn seekTo(self: *File, pos: u64) void {
        self.seek_pos = pos;
    }

    pub fn stat(self: *File) !Stat {
        return self.inner.stat(g_io);
    }

    pub fn close(self: *File) void {
        self.inner.close(g_io);
    }
};

pub const Stat = std.Io.File.Stat;
