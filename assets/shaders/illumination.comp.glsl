#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable

layout(local_size_x = 32,  local_size_y = 32) in;

layout(rgba8, binding = 0) uniform readonly image2D frameColor;
layout(rgba8, binding = 1) uniform readonly image2D frameNormal;
layout(rgba32f, binding = 2) uniform readonly image2D framePosition;
layout(rgba8, binding = 3) uniform image2D frameIllumination;

layout (binding = 8) uniform u_Camera {
    vec4 C_position;
    mat4 C_view;
    vec4 C_sun_dir;
    float fov;
    uint frameIndex;
    uint frameAccum;
};

#include assets/shaders/camera.glsl
#include assets/shaders/dda.glsl
#include assets/shaders/map.glsl
#include assets/shaders/rng.glsl

void main() {
    ivec2 pixelCoords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(frameColor);

    if (pixelCoords.x >= size.x || pixelCoords.y >= size.y) 
        return;

    vec3 position = imageLoad(framePosition, pixelCoords).xyz;
    if (any(lessThan(position, vec3(0.0)))) {
        imageStore(frameIllumination, pixelCoords, vec4(0.0));
        return;
    }

    vec2 rayUV = vec2(pixelCoords) / vec2(size) * 2.0 - 1.0;
    rayUV.y *= float(size.y) / float(size.x);

    vec3 normal = imageLoad(frameNormal, pixelCoords).xyz;
    vec3 rayOrigin = position;
    vec3 rayDir = normalize(normal + CosineSampleHemisphereA(normal, rayUV));

    ivec3 mapPos;
    vec3 mask;
    float totalDistance;
    ivec3 rayStep;
    vec4 color;

    vec4 prev = imageLoad(frameIllumination, pixelCoords);
    vec4 illum;

    uint voxel = traceMap(rayOrigin, rayDir, color, mask, mapPos, totalDistance, rayStep, 16);
    illum = voxel != 0 ? vec4(0) : SkyDome2(rayOrigin, rayDir, normalize(C_sun_dir.xyz)) * 0.5;

    imageStore(frameIllumination, pixelCoords, mix(prev, illum, 0.3));
}