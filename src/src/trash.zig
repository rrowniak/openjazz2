const std = @import("std");
/// Reads a binary representation of a struct `T` from the given `reader`.
pub fn readStruct2(comptime T: type, reader: anytype) !T {
    var result: T = undefined;
    const fields = std.meta.fields(T);

    inline for (fields) |field| {
        const F = field.type;

        switch (F) {
            u8, u16, i32, u32 => {
                var bytes: [@sizeOf(F)]u8 = undefined;
                const read = try reader.read(&bytes);
                if (read != bytes.len) {
                    return error.EndOfStream;
                }
                const val = std.mem.bytesToValue(F, &bytes);
                @field(result, field.name) = val;
            },
            else => {
                switch (@typeInfo(field.type)) {
                    .@"array" => |arr| {
                        if (arr.child == u8) {
                            var buf: [arr.len]u8 = undefined;
                            const read = try reader.read(&buf);
                            if (read != buf.len) {
                                return error.EndOfStream;
                            }
                            @field(result, field.name) = buf;
                        }
                        else @compileError("Unsupported array type: " ++ @typeName(F));
                    },
                    else => @compileError("Unsupported field type: " ++ @typeName(F)),
                }
            },
        }
    }

    return result;
}
const foo = struct {f: u8,};

