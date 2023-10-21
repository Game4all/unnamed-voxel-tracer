const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/buffer.zig");

inline fn posToIndex(dim: usize, x: usize, y: usize, z: usize) usize {
    return x + dim * (y + z * dim);
}

///
pub fn VoxelMap(comptime dim: comptime_int, comptime chsize: comptime_int) type {
    return struct {
        voxels: gfx.PersistentMappedBuffer,
        chunks: gfx.PersistentMappedBuffer,

        pub fn init(val: u32) @This() {
            var voxels = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, dim * dim * dim * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            var chunks = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, (dim / chsize) * (dim / chsize) * (dim / chsize) * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            @memset(voxels.get([dim * dim * dim]u32), val);
            @memset(chunks.get([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32), val);
            return .{ .voxels = voxels, .chunks = chunks };
        }

        pub fn set(self: *@This(), x: usize, y: usize, z: usize, voxels: u32) void {
            self.voxels.get([dim * dim * dim]u32)[posToIndex(dim, x, y, z)] = voxels;
            self.chunks.get([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)] = 1;
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) u32 {
            self.voxels.get([dim * dim * dim]u32)[posToIndex(dim, x, y, z)];
        }

        pub fn procgen(self: *@This(), v: u32) void {
            const gen = znoise.FnlGenerator{};
            for (0..dim) |x| {
                for (0..dim) |z| {
                    const val = gen.noise2(@as(f32, @floatFromInt(x)) / 10.0, @as(f32, @floatFromInt(z)) / 10.0);
                    const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));
                    for (0..vh) |h| {
                        self.set(x, h, z, v);
                    }
                }
            }
        }

        pub fn bind(self: *@This(), base_binding: u32) void {
            self.voxels.bind(base_binding);
            self.chunks.bind(base_binding + 1);
        }
    };
}
