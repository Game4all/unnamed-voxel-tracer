const gl = @import("gl45.zig");
const assert = @import("std").debug.assert;

pub const BufferType = enum(gl.GLenum) { Uniform = gl.UNIFORM_BUFFER, Storage = gl.SHADER_STORAGE_BUFFER };

/// Buffer creation flags.
pub const BufferCreationFlags = struct {
    pub const MappableRead: gl.GLenum = gl.MAP_READ_BIT;
    pub const MappableWrite: gl.GLenum = gl.MAP_WRITE_BIT;
    pub const Persistent: gl.GLenum = gl.MAP_PERSISTENT_BIT;
    pub const Coherent: gl.GLenum = gl.MAP_COHERENT_BIT;
};

/// Buffer mapping flags.
pub const BufferMapFlags = struct {
    pub const Read: gl.GLenum = gl.MAP_READ_BIT;
    pub const Write: gl.GLenum = gl.MAP_WRITE_BIT;
    pub const InvalidateRange: gl.GLenum = gl.MAP_INVALIDATE_RANGE_BIT;
    pub const InvalidateBuffer: gl.GLenum = gl.MAP_INVALIDATE_BUFFER_BIT;
    pub const FlushExplicit: gl.GLenum = gl.MAP_FLUSH_EXPLICIT_BIT;
    pub const Unsynchronized: gl.GLenum = gl.MAP_UNSYNCHRONIZED_BIT;
};

/// Untyped OpenGL buffer.
pub const Buffer = struct {
    kind: BufferType,
    handle: c_uint,
    size: usize,
    buffer_flags: gl.GLenum,

    pub fn init(kind: BufferType, size: ?usize, flags: gl.GLenum) Buffer {
        var handle: c_uint = undefined;
        gl.createBuffers(1, &handle);
        if (size) |b_size| {
            gl.namedBufferStorage(handle, @intCast(b_size), null, flags);
        }

        return @This(){
            .kind = kind,
            .handle = handle,
            .size = size orelse 0,
            .buffer_flags = flags,
        };
    }

    /// Resize the buffer.
    pub fn resize(self: *@This(), size: usize) !void {
        if (self.size == size) return;

        if (self.size > size)
            return error.InvalidBufferSize;

        var new_buffer: c_uint = undefined;
        gl.createBuffers(1, &new_buffer);
        gl.namedBufferStorage(new_buffer, @intCast(size), null, self.buffer_flags);
        gl.copyNamedBufferSubData(self.handle, new_buffer, 0, 0, @intCast(@min(self.size, size)));
        gl.deleteBuffers(1, &self.handle);

        self.size = size;
        self.handle = new_buffer;
    }

    /// Map the whole buffer.
    pub fn map(self: *@This(), flags: gl.GLenum) ?*anyopaque {
        return gl.mapNamedBufferRange(self.handle, 0, @intCast(self.size), flags);
    }

    /// Unmap the buffer.
    pub fn unmap(self: *@This()) bool {
        return gl.unmapNamedBuffer(self.handle) > 0;
    }

    /// Bind the buffer to the given index.
    pub fn bind(self: *@This(), index: u32) void {
        gl.bindBufferBase(@intFromEnum(self.kind), @intCast(index), self.handle);
    }
};

pub fn PersistentMappedBuffer(comptime utype: type) type {
    const ptr_type = blk: {
        switch (@typeInfo(utype)) {
            .Struct => break :blk *utype,
            .Pointer => break :blk utype,
            else => @compileError("Expected pointer to many or struct."),
        }
    };

    return struct {
        buffer: Buffer,
        ptr: ?ptr_type,

        pub fn init(kind: BufferType, size: usize, flags: gl.GLenum) @This() {
            const flg = flags | BufferCreationFlags.Persistent;
            var buffer = Buffer.init(kind, size, flg);

            return @This(){
                .buffer = buffer,
                .ptr = @alignCast(@ptrCast(buffer.map(flg).?)),
            };
        }

        pub fn resize(self: *@This(), size: usize) !void {
            _ = self.buffer.unmap();
            try self.buffer.resize(size);
            self.ptr = @alignCast(@ptrCast(self.buffer.map(self.buffer.buffer_flags)));
        }

        pub fn unmap(self: *@This()) void {
            self.buffer.unmap();
            self.ptr = null;
        }

        pub inline fn deref(self: *@This()) ptr_type {
            assert(self.ptr != null);
            return self.ptr.?;
        }

        /// Bind the buffer to the given index.
        pub fn bind(self: *@This(), index: u32) void {
            self.buffer.bind(index);
        }
    };
}
