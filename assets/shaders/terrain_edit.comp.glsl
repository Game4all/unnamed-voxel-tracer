#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable

layout(local_size_x = 1,  local_size_y = 1) in;

#include assets/shaders/camera.glsl

#include assets/shaders/map.glsl

void main() {
    vec2 rayUV = vec2(0.);
    vec3 rayOrigin = C_position.xyz;
    vec3 rayDir = normalize(C_view * vec4(rayUV, 1.0, 1.0)).xyz;

    vec2 intersection = intersectAABB(rayOrigin, rayDir, vec3(0.), vec3(float(MAP_DIMENSION)));
    HitInfo inter = traceMap(rayOrigin + rayDir * max(intersection.x, 0) - EPSILON, rayDir, 64);

    // if (inter.data != 0) {
    //     if (edit_mode > 0)
    //         map_setVoxel(ivec3(inter.hit_pos + inter.normal) >> 3, (1 << 28) + edit_mode - 1);
    //     else
    //         map_setVoxel(ivec3(inter.hit_pos) >> 3, 0);
    // }
}