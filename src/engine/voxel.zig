const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/graphics.zig");
const dotvox = @import("dotvox.zig");

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

        pub fn clear(self: *@This(), val: u32) void {
            @memset(self.voxels.get([dim * dim * dim]u32), val);
            @memset(self.chunks.get([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32), val);
        }

        pub fn set(self: *@This(), x: usize, y: usize, z: usize, voxels: u32) void {
            self.voxels.get([dim * dim * dim]u32)[posToIndex(dim / chsize, x / chsize, y / chsize, z / chsize) * chsize_sq + (x % 8) + ((y % 8) + (z % 8) * chsize) * chsize] = voxels;
            self.chunks.get([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)] = 1;
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) u32 {
            return self.voxels.get([dim * dim * dim]u32)[posToIndex(dim / chsize, x / chsize, y / chsize, z / chsize) * chsize_sq + (x % 8) + ((y % 8) + (z % 8) * chsize) * chsize];
        }

        pub fn is_walkable(self: *@This(), x: usize, y: usize, z: usize) bool {
            const voxel = self.get(x, y, z);
            return (voxel & 0x1000000) != 0 or voxel == 0;
        }

        pub fn bind(self: *@This(), base_binding: u32) void {
            self.voxels.bind(base_binding);
            self.chunks.bind(base_binding + 1);
        }
    };
}

pub fn VoxelMapPalette(comptime size: comptime_int) type {
    return struct {
        buffer: gfx.PersistentMappedBuffer,
        textures: std.ArrayListUnmanaged(gfx.Texture) = .{},

        pub fn init() @This() {
            return @This(){ .buffer = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, size * @sizeOf(u64), gfx.BufferCreationFlags.MappableWrite) };
        }

        /// Loads the specified model which is assumed to be 8x8x8
        pub fn load_model(
            self: *@This(),
            model: []const u8,
            allocator: std.mem.Allocator,
        ) !void {
            const storage = try allocator.alloc(u32, 8 * 8 * 8 * @sizeOf(u32));
            defer allocator.free(storage);
            @memset(storage, 0);

            var file = try std.fs.cwd().openFile(model, .{});
            defer file.close();

            var mdl_size = .{};
            try dotvox.read_format(file.reader(), storage, &mdl_size);

            var tex = gfx.Texture.init(gfx.TextureKind.Texture3D, gfx.TextureFormat.RGBA8, 8, 8, 8);
            tex.set_data(@ptrCast(storage));

            self.buffer.get([size]u64)[self.textures.items.len] = tex.get_image_handle(gfx.TextureUsage.Read, 0);
            try self.textures.append(allocator, tex);

            std.log.debug("Model {s} loaded", .{model});
        }

        pub fn bind(self: *@This(), idx: u32) void {
            self.buffer.bind(idx);
        }

        pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
            for (self.textures.items) |*item| {
                item.deinit();
            }
            self.textures.deinit(gpa);
        }
    };
}
