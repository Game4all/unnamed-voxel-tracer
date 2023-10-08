const std = @import("std");

// common vector types
fn vector(comptime n: comptime_int, comptime element: type) type {
    return extern struct {
        const Self = @This();
        inner: @Vector(n, element),

        /// ctor functions
        pub usingnamespace switch (n) {
            2 => struct {
                pub fn from_xy(x: element, y: element) Self {
                    return Self{ .inner = [_]element{ x, y } };
                }
            },
            3 => struct {
                pub fn from_xyz(x: element, y: element, z: element) Self {
                    return Self{ .inner = [_]element{ x, y, z } };
                }
            },
            4 => struct {
                pub fn from_xyzw(x: element, y: element, z: element, w: element) Self {
                    return Self{ .inner = [_]element{ x, y, z, w } };
                }
            },
            else => @compileError("Unsupported vector size"),
        };

        pub inline fn splat(val: element) Self {
            switch (n) {
                2 => {
                    return Self{ .inner = [_]element{ val, val } };
                },
                3 => {
                    return Self{ .inner = [_]element{ val, val, val } };
                },
                4 => {
                    return Self{ .inner = [_]element{ val, val, val, val } };
                },
                else => @compileError("Unsupported vector size"),
            }
        }

        /// add together two vectors
        pub fn add(lhs: Self, rhs: Self) Self {
            return Self{ .inner = lhs.inner + rhs.inner };
        }

        /// subtract two vectors
        pub fn sub(lhs: Self, rhs: Self) Self {
            return Self{ .inner = lhs.inner - rhs.inner };
        }

        /// multiply two vectors
        pub fn mul(lhs: Self, rhs: Self) Self {
            return Self{ .inner = lhs.inner * rhs.inner };
        }

        /// divide two vectors
        pub fn div(lhs: Self, rhs: Self) Self {
            return Self{ .inner = lhs.inner / rhs.inner };
        }

        /// returns the element at the given index
        pub fn elem(self: Self, comptime index: comptime_int) element {
            return self.inner[index];
        }

        pub fn length(self: Self) element {
            var len = undefined;
            inline for (self.inner) |x| {
                len = x * x;
            }
            return @sqrt(len);
        }

        pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (n) {
                2 => try writer.print("vec2({}, {})", .{ value.inner[0], value.inner[1] }),
                3 => try writer.print("vec3({}, {}, {})", .{ value.inner[0], value.inner[1], value.inner[2] }),
                4 => try writer.print("vec4({}, {}, {}, {})", .{ value.inner[0], value.inner[1], value.inner[2], value.inner[3] }),
                else => @compileError("Unsupported vector size"),
            }
        }
    };
}

pub const vec2 = vector(2, f32);
pub const vec3 = vector(3, f32);
pub const vec4 = vector(4, f32);

pub const ivec2 = vector(2, i32);
pub const ivec3 = vector(3, i32);
pub const ivec4 = vector(4, i32);

/// clamp a value between a min and max
pub fn clamp(comptime T: type, value: T, min: T, max: T) T {
    return @min(max, @max(value, min));
}

// vector tests

test "vector add tests" {
    const expect = std.testing.expect;

    var a = vec2.from_xy(1.0, 2.0);
    var b = vec2.from_xy(3.0, -4.0);
    var c = a.add(b);
    try expect(c.inner[0] == 4.0 and c.inner[1] == -2.0);
}

test "vector sub tests" {
    const expect = std.testing.expect;

    var a = vec2.from_xy(1.0, 2.0);
    var b = vec2.from_xy(3.0, -4.0);
    var c = a.sub(b);
    try expect(c.inner[0] == -2.0 and c.inner[1] == 6.0);
}

test "vector mul tests" {
    const expect = std.testing.expect;

    var a = vec2.from_xy(1.0, 2.0);
    var b = vec2.from_xy(3.0, -4.0);
    var c = a.mul(b);
    try expect(c.inner[0] == 3.0 and c.inner[1] == -8.0);
}

test "vector div tests" {
    const expect = std.testing.expect;

    var a = vec2.from_xy(1.0, 2.0);
    var b = vec2.from_xy(3.0, -4.0);
    var c = a.div(b);
    try expect(c.inner[0] == 1.0 / 3.0 and c.inner[1] == -0.5);
}
