const std = @import("std");
const glfw = @import("mach_glfw");

pub const InputState = struct {
    old_mouse_pos: @Vector(2, f64) = @splat(0.0),
    mouse_pos: @Vector(2, f64) = @splat(0.0),
    keyboard: Input(glfw.Key) = .{},
    mouse: Input(glfw.MouseButton) = .{},
};

pub fn Input(comptime input_enum: type) type {
    const enumeration = switch (@typeInfo(input_enum)) {
        .Enum => |e| e,
        else => @compileError("Expected enum, found xyz"),
    };

    if (enumeration.fields.len <= 0) {
        @compileError("Expected non-zero size enumeration");
    }

    return struct {
        state: std.bit_set.StaticBitSet(enumeration.fields.len) = std.bit_set.StaticBitSet(enumeration.fields.len).initEmpty(),
        state_prev: std.bit_set.StaticBitSet(enumeration.fields.len) = std.bit_set.StaticBitSet(enumeration.fields.len).initEmpty(),

        // gets the index for the specific action.
        inline fn get_variant_index(action: input_enum) usize {
            const enum_table = comptime blk: {
                var table: [enumeration.fields.len]enumeration.tag_type = undefined;
                for (&table, enumeration.fields) |*dst, src| {
                    dst.* = src.value;
                }
                break :blk table;
            };

            for (enum_table, 0..) |value, idx| {
                if (value == @intFromEnum(action))
                    return idx;
            }

            unreachable;
        }

        pub fn press(this: *@This(), action: input_enum) void {
            const loc: usize = get_variant_index(action);
            this.state.set(loc);
        }

        pub fn is_pressed(this: *@This(), action: input_enum) bool {
            const loc: usize = get_variant_index(action);
            return this.state.isSet(loc);
        }

        pub fn is_just_pressed(this: *@This(), action: input_enum) bool {
            const loc: usize = get_variant_index(action);
            return !this.state_prev.isSet(loc) and this.state.isSet(loc);
        }

        pub fn release(this: *@This(), action: input_enum) void {
            const loc: usize = get_variant_index(action);
            this.state.unset(loc);
        }

        pub fn is_just_released(this: *@This(), action: input_enum) bool {
            const loc: usize = get_variant_index(action);
            return this.state_prev.isSet(loc) and !this.state.isSet(loc);
        }

        pub fn any_pressed(this: *@This()) bool {
            return this.state.findFirstSet() != null;
        }

        pub fn update(this: *@This()) void {
            this.state_prev = this.state;
        }
    };
}
