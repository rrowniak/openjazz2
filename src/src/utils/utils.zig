const std = @import("std");

///
/// File utilities
///

/// Given a possibly case-wrong path, return the actual filename on disk.
/// Returns an allocated string containing the corrected full path.
/// Caller owns the memory.
pub fn find_file_case_insensitive(
    allocator: std.mem.Allocator,
    dirname: []const u8,
    wanted_name: []const u8,
) ![]u8 {
    var dir = try std.fs.cwd().openDir(dirname, .{ .iterate = true });
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
pub fn read_file_to_buff(
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

