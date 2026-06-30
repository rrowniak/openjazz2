const std = @import("std");
const fs = @import("fs.zig");

///
/// File utilities
///

/// Given a possibly case-wrong path, return the actual filename on disk.
/// Returns an allocated string containing the corrected full path.
/// Caller owns the memory.
/// Finds a file in a directory by case-insensitive name matching.
pub fn find_file_case_insensitive(
    allocator: std.mem.Allocator,
    dirname: []const u8,
    wanted_name: []const u8,
) ![]u8 {
    var dir = try fs.cwd().openDir(dirname, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.name, wanted_name)) {
            // Return full corrected path (dir + real filename)
            return try std.fs.path.join(
                allocator,
                &[_][]const u8{ dirname, entry.name },
            );
        }
    }

    return error.FileNotFound;
}

/// Reads a given filename into a newly allocated buffer.
/// The size of the buffer is equal to the file size.
/// Caller owns the memory.
/// Reads an entire file into a newly allocated buffer.
pub fn read_file_to_buff(
    allocator: std.mem.Allocator,
    filename: []const u8,
) ![]u8 {
    var stats = try fs.cwd().openFile(filename, .{});
    defer stats.close();

    const stat = try stats.stat();
    const buff = try allocator.alloc(u8, stat.size);

    _ = try stats.read(buff);
    return buff;
}

