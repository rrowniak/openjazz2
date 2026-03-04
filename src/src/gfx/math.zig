const std = @import("std");

pub const Vec2 = struct {
    v: [2]f32,

    pub fn init(x_: f32, y_: f32) Vec2 {
        return .{ .v = .{ x_, y_ } };
    }

    pub fn x(self: Vec2) f32 {
        return self.v[0];
    }

    pub fn y(self: Vec2) f32 {
        return self.v[1];
    }
};

pub const Vec3 = struct {
    v: [3]f32,

    pub fn init(x_: f32, y_: f32, z_: f32) Vec3 {
        return .{ .v = .{ x_, y_, z_ } };
    }

    pub fn x(self: Vec3) f32 {
        return self.v[0];
    }

    pub fn y(self: Vec3) f32 {
        return self.v[1];
    }

    pub fn z(self: Vec3) f32 {
        return self.v[2];
    }
};

pub const Mat4x4 = struct {
    const Self = @This();
    // column-contiguous memory layuot
    m: [16]f32,

    pub fn init_zero() Self {
        return .{ .m = [_]f32{0.0} ** 16 };
    }

    pub fn init_ident() Self {
        var m = Self.init_zero();
        m.m[0] = 1.0;
        m.m[5] = 1.0;
        m.m[10] = 1.0;
        m.m[15] = 1.0;
        return m;
    }

    pub fn init_ortho(
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        near: f32,
        far: f32,
    ) Self {
        var mat: Self = undefined;
        const rl = right - left;
        const tb = top - bottom;
        const f_n = far - near;

        // Column 0
        mat.m[0] = 2.0 / rl;
        mat.m[1] = 0.0;
        mat.m[2] = 0.0;
        mat.m[3] = 0.0;

        // Column 1
        mat.m[4] = 0.0;
        mat.m[5] = 2.0 / tb;
        mat.m[6] = 0.0;
        mat.m[7] = 0.0;

        // Column 2
        mat.m[8] = 0.0;
        mat.m[9] = 0.0;
        mat.m[10] = -2.0 / f_n;
        mat.m[11] = 0.0;

        // Column 3 (translation)
        mat.m[12] = -(right + left) / rl;
        mat.m[13] = -(top + bottom) / tb;
        mat.m[14] = -(far + near) / f_n;
        mat.m[15] = 1.0;

        return mat;
    }

    fn index(row: usize, col: usize) usize {
        return col * 4 + row;
    }

    pub fn mul(a: Self, b: Self) Self {
        var result: Self = undefined;

        for (0..4) |col| {
            for (0..4) |row| {
                var sum: f32 = 0.0;
                for (0..4) |k| {
                    sum += a.m[index(row, k)] *
                        b.m[index(k, col)];
                }
                result.m[index(row, col)] = sum;
            }
        }

        return result;
    }

    pub fn translate(self: Self, v: Vec3) Self {
        var t = Self.init_ident();

        t.m[index(0, 3)] = v.x();
        t.m[index(1, 3)] = v.y();
        t.m[index(2, 3)] = v.z();

        return Self.mul(self, t);
    }

    pub fn scale(self: Self, v: Vec3) Self {
        var s = Self.init_ident();

        s.m[index(0, 0)] = v.x();
        s.m[index(1, 1)] = v.y();
        s.m[index(2, 2)] = v.z();

        return Self.mul(self, s);
    }

    pub fn rotate(self: Self, angle: f32, axis: Vec3) Self {
        const x = axis.x();
        const y = axis.y();
        const z = axis.z();

        const c = std.math.cos(angle);
        const s = std.math.sin(angle);
        const one_minus_c = 1.0 - c;

        var r = Self.init_ident();

        r.m[index(0, 0)] = c + x * x * one_minus_c;
        r.m[index(0, 1)] = x * y * one_minus_c - z * s;
        r.m[index(0, 2)] = x * z * one_minus_c + y * s;

        r.m[index(1, 0)] = y * x * one_minus_c + z * s;
        r.m[index(1, 1)] = c + y * y * one_minus_c;
        r.m[index(1, 2)] = y * z * one_minus_c - x * s;

        r.m[index(2, 0)] = z * x * one_minus_c - y * s;
        r.m[index(2, 1)] = z * y * one_minus_c + x * s;
        r.m[index(2, 2)] = c + z * z * one_minus_c;

        return Self.mul(self, r);
    }
};

const expect = std.testing.expect;

test "Mat4x4" {
    const zero = Mat4x4.init_zero();
    try expect(zero.m[0] == 0.0);
    const m = Mat4x4.init_ortho(0.0, 800.0, 600.0, 0.0, -1.0, 1.0);
    try expect(m.m[1] == 0.0);
}
