const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/graphics.zig");
const dotvox = @import("dotvox.zig");

inline fn posToIndex(dim: usize, x: usize, y: usize, z: usize) usize {
    return x + dim * (y + z * dim);
}

///
pub fn VoxelBrickmap(comptime dim: comptime_int, comptime chsize: comptime_int) type {
    const chsize_sq = chsize * chsize * chsize;

    return struct {
        voxels: gfx.PersistentMappedBuffer,
        chunks: gfx.PersistentMappedBuffer,
        block_index: usize = 0,
        max_block_index: usize = 0,

        pub fn init(val: u32) @This() {
            var voxels = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, dim * dim * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            var chunks = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, (dim / chsize) * (dim / chsize) * (dim / chsize) * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            @memset(voxels.get_raw([*]u32)[0..(voxels.buffer.size / @sizeOf(u32))], val);
            @memset(chunks.get_raw([*]u32)[0..(chunks.buffer.size / @sizeOf(u32))], 0);
            return .{ .voxels = voxels, .chunks = chunks, .block_index = 0, .max_block_index = @divFloor(voxels.buffer.size, chsize_sq * @sizeOf(u32)) };
        }

        pub fn clear(self: *@This(), val: u32) void {
            @memset(self.voxels.get_raw([*]u32)[0..(self.voxels.buffer.size / @sizeOf(u32))], val);
            @memset(self.chunks.get_raw([*]u32)[0..(self.chunks.buffer.size / @sizeOf(u32))], 0);
            self.block_index = 0;
        }

        /// Ensure that there's at least a free block available to store voxel data in, else resize the buffer.
        fn ensure_free_blocks(self: *@This()) void {
            if (self.block_index >= self.max_block_index) {
                self.voxels.resize(self.voxels.buffer.size * 2) catch @panic("A");
                self.max_block_index = @divFloor(self.voxels.buffer.size, chsize_sq * @sizeOf(u32));
            }
        }

        /// Grabs a block for the chunk data
        pub fn get_block_for_chunk(self: *@This(), chx: usize, chy: usize, chz: usize) usize {
            const index = self.chunks.get_ptr([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), chx, chy, chz)];
            if (index > 0) {
                return @as(usize, @intCast(index - 1));
            } else {
                self.ensure_free_blocks();
                self.chunks.get_ptr([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), chx, chy, chz)] = @as(u32, @intCast(self.block_index)) + 1;
                self.block_index += 1;
                return self.block_index - 1;
            }
        }

        pub fn set(self: *@This(), x: usize, y: usize, z: usize, voxel: u32) void {
            const blk = self.get_block_for_chunk(x / chsize, y / chsize, z / chsize);
            self.voxels.get_raw([*][chsize_sq]u32)[blk][(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize] = voxel;
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) u32 {
            const index = self.chunks.get_raw([*]u32)[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)];
            if (index > 0) {
                return self.voxels.get_raw([*][chsize_sq]u32)[index - 1][(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize];
            } else {
                return 0;
            }
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

            self.buffer.get_ptr([size]u64)[self.textures.items.len] = tex.get_image_handle(gfx.TextureUsage.Read, 0);
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
