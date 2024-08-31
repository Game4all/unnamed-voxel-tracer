#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable

layout(local_size_x = 32,  local_size_y = 32) in;

layout(rgba8, binding = 0) uniform readonly image2D frameColor;
layout(rgba8, binding = 1) uniform readonly image2D frameNormal;
layout(rgba32f, binding = 2) uniform readonly image2D framePosition;
layout(rgba8, binding = 3) uniform image2D frameIllumination;


#include assets/shaders/camera.glsl

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

    // let's replace illumination by shadows for now.

    vec3 normal = imageLoad(frameNormal, pixelCoords).xyz;
    vec3 rayOrigin = position + normal * 0.001;
    vec3 rayDir = SUN_DIR;

    // entity collision
    HitInfo inter = traceMap(rayOrigin, rayDir, 48);
    HitInfo entity = traceEntities(rayOrigin, rayDir, distance(rayOrigin, inter.hit_pos / 8.));
    vec4 illum;

    if (entity.data != 0)
        illum = vec4(rayDir.xyz, -0.3);
    else
        illum = inter.data != 0 ? vec4(rayDir.xyz, -0.3) : vec4(rayDir.xyz, 0.3);

    imageStore(frameIllumination, pixelCoords, illum);
}