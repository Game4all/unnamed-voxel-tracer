const gl = @import("gl45.zig");
const std = @import("std");

const buffer = @import("buffer.zig");

// read a whole file into a string.
fn readToEnd(file: []const u8, alloc: std.mem.Allocator) ![:0]const u8 {
    const fileSt = try std.fs.cwd().openFile(file, std.fs.File.OpenFlags{ .mode = .read_only });
    const sourceStat = try fileSt.stat();
    const source = try std.fs.File.readToEndAllocOptions(fileSt, alloc, @as(usize, 2 * sourceStat.size), @as(usize, sourceStat.size), 1, 0);
    return source;
}

// read a whole file into a string, and replace all #include statements with the contents of the included file.
fn readGLSLSource(filepath: []const u8, alloc: std.mem.Allocator) ![:0]const u8 {
    const file = try std.fs.cwd().openFile(filepath, std.fs.File.OpenFlags{ .mode = .read_only });
    defer file.close();

    var finalSource = std.ArrayList(u8).init(alloc);
    var sourceWriter = finalSource.writer();

    const fileReader = file.reader();
    var buffered_line: [1024]u8 = undefined;
    while (try fileReader.readUntilDelimiterOrEof(&buffered_line, '\r')) |line| {
        if (std.mem.indexOf(u8, line, "#include")) |index| {
            const fileName = line[index + 9 ..];
            const depContents = readToEnd(fileName, alloc) catch |err| {
                std.log.err("Failed to read GLSL file {s}: {}", .{ fileName, err });
                continue;
            };
            try sourceWriter.writeAll(depContents);
            alloc.free(depContents);
        } else {
            try sourceWriter.writeAll(line);
        }
    }
    return try finalSource.toOwnedSliceSentinel(0);
}

/// Types of shaders that can be compiled.
pub const ShaderType = enum(gl.GLenum) {
    Vertex = gl.VERTEX_SHADER,
    Fragment = gl.FRAGMENT_SHADER,
    Compute = gl.COMPUTE_SHADER,
};

// Returns a handle to a shader of given type, compiled from the given file.
// Errors are logged to std.log.
pub fn compileShader(file: []const u8, shader_kind: ShaderType, alloc: std.mem.Allocator) !c_uint {
    const source = try readGLSLSource(file, alloc);
    defer alloc.free(source);
    errdefer alloc.free(source);

    std.log.info("Compiling shader: {s}", .{file});

    const handle = gl.createShader(@intFromEnum(shader_kind));
    errdefer gl.deleteShader(handle);

    gl.shaderSource(handle, 1, @ptrCast(&source), null);
    gl.compileShader(handle);
    var info_log: [1024]u8 = undefined;
    var info_log_len: gl.GLsizei = undefined;
    gl.getShaderInfoLog(handle, 1024, &info_log_len, &info_log);
    if (info_log_len != 0) {
        std.log.info("Error while compiling shader {s} : {s}", .{ file, info_log[0..@intCast(info_log_len)] });
        return error.ShaderCompilationError;
    }
    return handle;
}

// Returns a linked shader program from the given shaders.
// Errors are logged to std.log.
pub fn linkShaderProgram(shadersHandles: anytype) !c_uint {
    const program = gl.createProgram();
    errdefer gl.deleteProgram(program);

    inline for (shadersHandles) |handle| {
        gl.attachShader(program, handle);
        defer gl.deleteShader(handle);
    }

    var link_status: gl.GLint = undefined;
    var info_log: [1024]u8 = undefined;
    var info_log_len: gl.GLsizei = undefined;
    gl.linkProgram(program);
    gl.getProgramiv(program, gl.LINK_STATUS, &link_status);
    gl.getProgramInfoLog(program, 1024, &info_log_len, &info_log);
    if (link_status == gl.FALSE) {
        std.log.info("Failed to link shader program: {s}", .{info_log[0..@intCast(info_log_len)]});
        return error.ProgramLinkError;
    } else {
        return program;
    }
}

/// A compute pipeline.
pub const ComputePipeline = struct {
    pipeline: c_uint,

    /// Creates a compute pipeline from the given file.
    pub fn init(alloc: std.mem.Allocator, file: []const u8) !@This() {
        const shader = try compileShader(file, ShaderType.Compute, alloc);
        const pipeline = try linkShaderProgram(.{shader});

        return @This(){ .pipeline = pipeline };
    }

    /// Binds the pipeline to the current context for use.
    pub fn bind(self: *const @This()) void {
        gl.useProgram(self.pipeline);
    }

    pub fn dispatch(self: *const @This(), x: c_uint, y: c_uint, z: c_uint) void {
        gl.useProgram(self.pipeline);
        gl.dispatchCompute(x, y, z);
        gl.memoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT);
    }

    pub fn deinit(self: *const @This()) void {
        gl.deleteProgram(self.pipeline);
    }
};

/// A raster pipeline.
pub const RasterPipeline = struct {
    pipeline: c_uint,

    pub fn init(alloc: std.mem.Allocator, vertex: []const u8, frag: []const u8) !@This() {
        const vertex_shader = try compileShader(vertex, .Vertex, alloc);
        errdefer gl.deleteShader(vertex_shader);

        const fragment_shader = try compileShader(frag, .Fragment, alloc);
        errdefer gl.deleteShader(fragment_shader);

        const program = try linkShaderProgram(.{ vertex_shader, fragment_shader });

        return @This(){ .pipeline = program };
    }

    /// Binds the pipeline to the current context for use.
    pub fn bind(self: *const @This()) void {
        gl.useProgram(self.pipeline);
    }

    pub fn draw(this: *@This(), max_idx: usize) void {
        _ = this;
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, @intCast(max_idx));
    }

    pub fn deinit(self: *const @This()) void {
        gl.deleteProgram(self.pipeline);
    }
};
