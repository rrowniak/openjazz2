const std = @import("std");

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



