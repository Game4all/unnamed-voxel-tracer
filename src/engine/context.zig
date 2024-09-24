const std = @import("std");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;

/// The engine execution state.
pub const ExecutionState = enum { running, stopping };

/// The engine state module.
pub const EngineBaseState = struct {
    pub const name = .engine;
    pub const priority = .{
        .update = -0xFFFFFFFF,
    };

    /// Engine-wide general purpose allocator.
    allocator: Allocator,
    /// The engine execution state.
    /// Set to .stopping to stop execution.
    execution_state: ExecutionState = .running,

    // Time keeping

    /// Number of elapsed seconds since update last ticked aka delta time.
    /// Updated on every update.
    delta_seconds: f64,

    /// The timestamp at which update last ticked.
    /// Updated on every update.
    last_update: std.time.Instant,

    pub fn engine_init(engine: *Context, alloc: Allocator) void {
        engine.ctx.engine.allocator = alloc;
        engine.ctx.engine.last_update = std.time.Instant.now() catch {
            std.log.err("Current OS doesn't have any hi-perf timers for time keeping!", .{});
            unreachable;
        };
    }

    pub fn update(engine: *Context) void {
        const self = engine.mod(@This());

        const instant = std.time.Instant.now() catch {
            std.log.err("Current OS doesn't have any hi-perf timers for time keeping!", .{});
            unreachable;
        };

        const delta_ns = instant.since(self.last_update);
        const delta_s: f64 = @as(f64, @floatFromInt(delta_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

        self.last_update = instant;
        self.delta_seconds = delta_s;
    }
};

/// The engine context.
/// Holds state for all registered engine modules.
fn EngineContext(comptime mods: []type) type {
    // make the engine base state a built in module.
    const modules = @constCast(mods ++ [_]type{EngineBaseState});
    return struct {
        // The module state
        ctx: InnerState(modules) = undefined,

        /// Sends a signal to all modules that registered event handler for that signal.
        /// The event handlers will be executed in order w.r.t the event handling priorities of each module.
        pub fn signal(state: *@This(), comptime sig_name: anytype, data: anytype) void {
            switch (@typeInfo(@TypeOf(sig_name))) {
                .enum_literal => {},
                .@"enum" => {},
                else => @compileError(std.fmt.comptimePrint("Expected sig_name to be an enum litteral or enum, got {s}.", .{@typeName(@TypeOf(sig_name))})),
            }

            // get all modules that have a declared signal handler
            // and sort them according to their event priority.
            const handlers = comptime blk: {
                const event_handlers = hdl: {
                    var module_list: []const type = &[0]type{};
                    for (modules) |module| {
                        if (@hasDecl(module, @tagName(sig_name))) {
                            module_list = module_list ++ &[_]type{module};
                        }
                    }

                    break :hdl module_list;
                };

                // we need an array in order to do runtime sorting.
                var handlers: [event_handlers.len]type = undefined;
                @memcpy(&handlers, event_handlers);

                util.comptime_sort(type, &handlers, (struct {
                    pub fn inner(_: void, a: type, b: type) bool {
                        var prio_a: comptime_int = 0;
                        var prio_b: comptime_int = 0;

                        if (@hasField(@TypeOf(a.priority), @tagName(sig_name)))
                            prio_a = @field(a.priority, @tagName(sig_name));

                        if (@hasField(@TypeOf(b.priority), @tagName(sig_name)))
                            prio_b = @field(b.priority, @tagName(sig_name));

                        return prio_b > prio_a;
                    }
                }).inner);

                break :blk handlers;
            };

            inline for (handlers) |handler| {
                @call(.auto, @field(handler, @tagName(sig_name)), .{state} ++ data);
            }
        }

        /// Returns a pointer to the specified module state if it is registered in the engine context.
        pub inline fn mod(state: *@This(), comptime ty: type) *ty {
            // ensure the module exists
            inline for (modules, 0..) |mod_type, i| {
                if (mod_type == ty)
                    break;

                if (i == modules.len - 1) {
                    @compileError(std.fmt.comptimePrint("Tried to fetch state for module {s} which is not registered in the engine context.", .{@typeName(ty)}));
                }
            }

            return &@field(state.ctx, @tagName(ty.name));
        }
    };
}

/// A struct wrapping all modules under their module names.
fn InnerState(comptime modules: []type) type {
    var module_fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};

    for (modules) |module| {
        const mod = Module(module);
        module_fields = module_fields ++ [_]std.builtin.Type.StructField{.{ .name = @tagName(mod.name), .alignment = @alignOf(mod), .default_value = null, .type = mod, .is_comptime = false }};
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .is_tuple = false,
            .fields = module_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

/// Checks that the specified type is a valid engine module.
fn Module(comptime ty: type) type {
    if (!@hasDecl(ty, "name")) {
        @compileError(std.fmt.comptimePrint("Application module type '{s}' doesn't have a name.", .{@typeName(ty)}));
    }

    switch (@typeInfo(@TypeOf(ty.name))) {
        .enum_literal => {},
        else => @compileError(std.fmt.comptimePrint("Expected enum litteral for application module '{s}' name, got {s} instead.", .{ @typeName(ty), @typeName(@TypeOf(ty.name)) })),
    }

    if (!@hasDecl(ty, "priority")) {
        @compileError(std.fmt.comptimePrint("Application module {s} is missing event handler priorities.", .{@typeName(ty)}));
    }

    switch (@typeInfo(@TypeOf(ty.priority))) {
        .@"struct" => {},
        else => @compileError(std.fmt.comptimePrint("Expected struct for application module '{s}' event handler priorities, got {s} instead.", .{ @typeName(ty), @typeName(@TypeOf(ty.priority)) })),
    }

    return ty;
}

/// Gets the declared engine modules in the main file.
fn EngineModules() []type {
    if (!@hasDecl(@import("root"), "modules"))
        @compileError("No engine modules declared in root file. ");

    return @constCast(@import("root").modules);
}

/// Engine context
pub const Context = EngineContext(EngineModules());

pub const App = struct {
    context: Context = undefined,

    /// Initializes the engine context.
    /// Sends an `init` signal to all engine modules.
    pub fn init(app: *@This(), allocator: std.mem.Allocator) void {
        app.context.signal(.engine_init, .{allocator});
        app.context.signal(.init, .{});
    }

    /// Deinitializes the engine context.
    /// Sends a `deinit` signal to all engine modules.
    pub fn deinit(app: *@This()) void {
        app.context.signal(.deinit, .{});
    }

    /// Launches the engine main loop.
    pub fn run(app: *@This()) void {
        while (app.context.ctx.engine.execution_state == .running) {
            app.context.signal(.update, .{});
        }
    }
};

// Tests that the signal handler priorities are respected, and that signal handlers without a set priority will execute with priority 0.
test "Signal handler priorities" {
    const A = struct {
        pub const name = .a;
        pub const priority = .{ .init = -0xFF };

        idx: usize = 0,
        order: [4]u32 = undefined,

        pub fn init(app: anytype) void {
            var a: *@This() = app.mod(@This());
            a.order[a.idx] = 1;
            a.idx += 1;
        }
    };

    const C = struct {
        pub const name = .c;
        pub const priority = .{ .init = -0xFFF };

        pub fn init(app: anytype) void {
            var a: *A = app.mod(A);
            a.order[a.idx] = 3;
            a.idx += 1;
        }
    };

    const B = struct {
        pub const name = .b;
        pub const priority = .{ .init = C.priority.init + 1 };

        pub fn init(app: anytype) void {
            var a: *A = app.mod(A);
            a.order[a.idx] = 2;
            a.idx += 1;
        }
    };

    const D = struct {
        pub const name = .d;
        pub const priority = .{};

        pub fn init(app: anytype) void {
            var a: *A = app.mod(A);
            a.order[a.idx] = 4;
            a.idx += 1;
        }
    };

    const application = EngineContext(@constCast(&[_]type{ A, B, C, D }));
    var app: application = .{};

    app.signal(.init, .{});

    try std.testing.expectEqual([4]u32{ 3, 2, 1, 4 }, app.ctx.a.order);
}
