const gl = @import("gl45.zig");

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
    pub fn resize(self: *@This(), size: usize) void {
        if (self.size == size) return;

        gl.namedBufferData(self.handle, size, null, self.buffer_flags);
        self.size = size;
    }

    /// Map the whole buffer.
    pub fn map(self: *@This(), flags: gl.GLenum) ?*anyopaque {
        return gl.mapNamedBufferRange(self.handle, 0, @intCast(self.size), flags);
    }

    /// Unmap the buffer.
    pub fn unmap(self: *@This()) bool {
        return gl.unmapNamedBuffer(self.handle);
    }

    /// Bind the buffer to the given index.
    pub fn bind(self: *@This(), index: u32) void {
        gl.bindBufferBase(@intFromEnum(self.kind), @intCast(index), self.handle);
    }
};

/// An opengl buffer that can is persistently mapped.
pub const PersistentMappedBuffer = struct {
    buffer: Buffer,
    map_ptr: ?*anyopaque,

    pub fn init(kind: BufferType, size: usize, flags: gl.GLenum) PersistentMappedBuffer {
        const flg = flags | BufferCreationFlags.Persistent;
        var buffer = Buffer.init(kind, size, flg);
        var map_ptr = buffer.map(flg);

        return @This(){
            .buffer = buffer,
            .map_ptr = map_ptr,
        };
    }

    pub fn resize(self: *@This(), size: usize) void {
        self.buffer.unmap();
        self.buffer.resize(size);
        self.map_ptr = self.buffer.map(self.buffer.buffer_flags);
    }

    pub fn unmap(self: *@This()) void {
        self.buffer.unmap();
        self.map_ptr = null;
    }

    pub fn get(self: *@This(), comptime t: type) *t {
        const ptr: *t = @alignCast(@ptrCast(self.map_ptr.?));
        return ptr;
    }

    /// Bind the buffer to the given index.
    pub fn bind(self: *@This(), index: u32) void {
        self.buffer.bind(index);
    }
};
