const std = @import("std");

pub fn Input(comptime input_enum: type) type {
    const enumeration = switch (@typeInfo(input_enum)) {
        .Enum => |e| e,
        else => @compileError("Expected enum, found xyz"),
    };

    const enum_size: usize = enumeration.fields.len;

    if (enum_size <= 0) {
        @compileError("Expected non-zero size enumeration");
    }

    const enum_offset: usize = enumeration.fields[0].value;

    return struct {
        //PERF: could be optimized
        state: [enum_size]bool = [_]bool{false} ** enum_size,
        state_prev: [enum_size]bool = [_]bool{false} ** enum_size,

        pub fn init() @This() {
            return .{};
        }

        pub fn press(this: *@This(), action: input_enum) void {
            const loc = @intFromEnum(action) - enum_offset;
            this.state[loc] = true;
        }

        pub fn is_pressed(this: *@This(), action: input_enum) bool {
            const loc = @intFromEnum(action) - enum_offset;
            return this.state[loc];
        }

        pub fn release(this: *@This(), action: input_enum) void {
            const loc = @intFromEnum(action) - enum_offset;
            this.state[loc] = false;
        }

        pub fn update(this: *@This()) void {
            @memcpy(&this.state_prev, &this.state);
        }
    };
}
