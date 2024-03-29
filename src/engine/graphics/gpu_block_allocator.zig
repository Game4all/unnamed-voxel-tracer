const gfx = @import("buffer.zig");

/// A GPU memory block allocator.
pub fn GpuBlockAllocator(comptime blk_size: comptime_int) type {
    return struct {
        buffer: gfx.PersistentMappedBuffer([*][blk_size]u32),
        block_index: usize = 0,
        max_block_index: usize = 0,

        pub fn init(size_hint: usize) @This() {
            var buffer = gfx.PersistentMappedBuffer([*][blk_size]u32).init(.Storage, size_hint * blk_size * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            const len = buffer.len();
            return .{
                .buffer = buffer,
                .max_block_index = len,
            };
        }

        /// Allocates a block in the GPU buffer and returns its ID.
        pub fn alloc(self: *@This()) usize {
            if (self.block_index >= self.max_block_index) {
                self.buffer.resize(self.buffer.buffer.size * 2) catch @panic("Failed to resize GPU Memory block buffer");
                self.max_block_index = self.buffer.len();
            }

            const idx = self.block_index;
            self.block_index += 1;

            return idx;
        }

        pub fn clear(self: *@This()) void {
            self.block_index = 0;
            @memset(self.buffer.get_raw([*]u32)[0..(self.buffer.buffer.size / @sizeOf(u32))], 0);
        }

        pub fn get_slice(self: *@This(), idx: usize) []u32 {
            return self.buffer.deref()[idx][0..];
        }
    };
}
