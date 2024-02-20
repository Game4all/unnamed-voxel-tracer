#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable

layout(local_size_x = 32,  local_size_y = 32) in;

layout(rgba8, binding = 0) uniform image2D frameColor;
layout(rgba8, binding = 1) uniform image2D frameNormal;
layout(rgba32f, binding = 2) uniform image2D framePosition;

layout (binding = 8) uniform u_Camera {
    vec4 C_position;
    mat4 C_view;
    vec4 C_sun_dir;
    float fov;
    uint frameIndex;
    uint frameAccum;
};

#include assets/shaders/camera.glsl
#include assets/shaders/map.glsl
#include assets/shaders/rng.glsl

float vhash(vec4 p) {
    p = fract(p * 0.3183099 + 0.1) - fract(p + 23.22121);
    p = p * 17.0;
    return (fract(p.x * p.y * (1.0 - p.z) * p.w * (p.x + p.y + p.z + p.w)) - 0.5) * 2.0;
}

void main() {
    ivec2 pixelCoords = ivec2(gl_GlobalInvocationID.xy);
    uint rngState = uint(uint(pixelCoords.x) * uint(1973) + uint(pixelCoords.y) * uint(9277) + frameIndex);                              
    ivec2 size = imageSize(frameColor);

    if (pixelCoords.x >= size.x || pixelCoords.y >= size.y) 
        return;

    vec2 rayUV = vec2(pixelCoords) / vec2(size) * 2.0 - 1.0;
    rayUV.y *= float(size.y) / float(size.x);
    // rayUV += RandomFloat01(rngState) * 0.001;
    
    // applying field of view
    rayUV *= tan(fov / 2);

    vec3 rayOrigin = C_position.xyz;
    vec3 rayDir = normalize(C_view * vec4(rayUV, 1.0, 1.0)).xyz;

    // raybox intersection with the map bounding box.
    vec2 intersection = intersectAABB(rayOrigin, rayDir, vec3(0.), vec3(float(MAP_DIMENSION)));
    HitInfo inter = traceMap(rayOrigin + rayDir * max(intersection.x, 0) - EPSILON, rayDir, 192);

    // --------------------------------- Entity intersection -------------------------------------

    HitInfo entity = traceEntities(rayOrigin, rayDir, distance(C_position.xyz, inter.hit_pos / 8.) + EPSILON);
    if (entity.data != 0)
    {
        imageStore(frameColor, pixelCoords, unpackUnorm4x8(entity.data));
        imageStore(frameNormal, pixelCoords, vec4(entity.normal, 1.0));
        imageStore(framePosition, pixelCoords, vec4(entity.hit_pos, 1.0));
        return;
    }

    // --------------------------------- Terrain intersection -------------------------------------
    
    if (inter.data != 0) {
        imageStore(frameColor, pixelCoords, unpackUnorm4x8(inter.data));
        imageStore(frameNormal, pixelCoords, vec4(inter.normal, 1.0));
        imageStore(framePosition, pixelCoords, vec4(inter.hit_pos / 8.0, 1.0));
    } 
    else 
    {
        imageStore(frameColor, pixelCoords, SkyDome2(rayOrigin, rayDir, normalize(C_sun_dir.xyz)));
        imageStore(frameNormal, pixelCoords, vec4(1.0));
        imageStore(framePosition, pixelCoords, vec4(-1.0));
    }
}
