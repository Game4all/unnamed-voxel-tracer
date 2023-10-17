const std = @import("std");
const znoise = @import("znoise");

pub fn VoxelBuffer(comptime dataT: type, comptime width: usize, comptime height: usize, comptime depth: usize) type {
    return struct {
        data: []dataT,

        pub fn init(alloc: std.mem.Allocator, val: dataT) !@This() {
            var dat = try alloc.alloc(dataT, width * height * depth);
            @memset(dat, val);
            return @This(){
                .data = dat,
            };
        }

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.data);
        }

        inline fn linearize(self: *@This(), x: u32, y: u32, z: u32) usize {
            _ = self;
            return @as(usize, @intCast(x)) + width * (@as(usize, @intCast(y)) + @as(usize, @intCast(z)) * depth);
        }

        pub fn set(self: *@This(), x: u32, y: u32, z: u32, voxel: dataT) void {
            self.data[self.linearize(x, y, z)] = voxel;
        }

        pub fn get(self: *@This(), x: u32, y: u32, z: u32) dataT {
            return self.data[self.linearize(x, y, z)];
        }

        pub fn procgen(self: *@This(), v: dataT) void {
            const gen = znoise.FnlGenerator{};
            for (0..width) |x| {
                for (0..depth) |z| {
                    const val = gen.noise2(@as(f32, @floatFromInt(x)) / 10.0, @as(f32, @floatFromInt(z)) / 10.0);
                    const vh: u32 = @intFromFloat(val * @as(f32, @floatFromInt(height)) * 0.1);
                    for (0..vh) |h| {
                        self.set(@intCast(x), @intCast(h), @intCast(z), v);
                    }
                }
            }
        }
    };
}
