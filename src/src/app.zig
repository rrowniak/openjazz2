const std = @import("std");

pub const IApp = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        update: *const fn(*anyopaque) void,
        deinit: *const fn(*anyopaque) void,
    };

    pub fn update(self: *IApp) void {
        self.vtable.update(self.ptr);
    }

    pub fn deinit(self: *IApp) void {
        self.vtable.deinit(self.ptr);
    }
};
