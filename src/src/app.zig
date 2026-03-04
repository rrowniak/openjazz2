const std = @import("std");

pub const IApp = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        run: *const fn (*anyopaque) void,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn run(self: *IApp) void {
        self.vtable.run(self.ptr);
    }

    pub fn deinit(self: *IApp) void {
        self.vtable.deinit(self.ptr);
    }
};
