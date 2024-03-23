pub const zaudio = @import("zaudio");
const context = @import("context.zig");

const Context = @import("context.zig").Context;

const std = @import("std");

pub const AudioModule = struct {
    pub const name = .audio;
    pub const priority = .{
        .init = -0xFFF,
        .deinit = 0xFFFFFFF,
    };

    audio_engine: *zaudio.Engine,

    pub fn init(ctx: *Context) void {
        zaudio.init(ctx.mod(context.EngineBaseState).allocator);
        ctx.mod(@This()).audio_engine = zaudio.Engine.create(null) catch |err| {
            std.log.err("Failed to create audio engine : {}", .{err});
            unreachable;
        };
    }

    pub fn deinit(ctx: *Context) void {
        ctx.mod(@This()).audio_engine.destroy();
        zaudio.deinit();
    }
};
