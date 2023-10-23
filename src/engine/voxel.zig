const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/buffer.zig");

inline fn posToIndex(dim: usize, x: usize, y: usize, z: usize) usize {
    return x + dim * (y + z * dim);
}

///
pub fn VoxelMap(comptime dim: comptime_int, comptime chsize: comptime_int) type {
    const chsize_sq = chsize * chsize * chsize;

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
            self.voxels.get([dim * dim * dim]u32)[posToIndex(dim / chsize, x / chsize, y / chsize, z / chsize) * chsize_sq + (x % 8) + ((y % 8) + (z % 8) * chsize) * chsize] = voxels;
            self.chunks.get([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)] = 1;
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) u32 {
            return self.voxels.get([dim * dim * dim]u32)[posToIndex(dim, x, y, z)];
        }

        pub fn bind(self: *@This(), base_binding: u32) void {
            self.voxels.bind(base_binding);
            self.chunks.bind(base_binding + 1);
        }
    };
}
