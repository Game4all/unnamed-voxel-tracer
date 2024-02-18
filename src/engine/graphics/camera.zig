const zmath = @import("zmath");
const std = @import("std");
const clamp = zmath.clamp;

pub const Camera = struct {
    fov: f32 = std.math.pi / 2.0,
    pitch: f32 = 0.0,
    yaw: f32 = 0.0,
    cam_mat: zmath.Mat = zmath.identity(),

    pub fn rotate(self: *@This(), pitch: f32, yaw: f32) void {
        self.pitch = clamp(self.pitch + @as(f32, @floatCast(pitch)) * 0.001, -std.math.pi / 2.0, std.math.pi / 2.0);
        self.yaw = self.yaw + @as(f32, @floatCast(yaw)) * 0.001;

        self.cam_mat = zmath.matFromRollPitchYaw(self.pitch, self.yaw, 0.0);
    }

    pub fn incrementFov(self: *@This(), increment: f32) void {
        self.fov = clamp(self.fov + increment * 0.1, 0.314, 2.4);
    }

    pub inline fn camera_mat(self: *const @This()) zmath.Mat {
        return self.cam_mat;
    }
};
