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
#include assets/shaders/dda.glsl
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
    vec3 volumeRayOrigin = rayOrigin + rayDir * max(intersection.x, 0) - EPSILON;

    ivec3 mapPos;
    vec3 mask;
    float totalDistance;
    ivec3 rayStep;
    vec4 color;

    uint voxel;

    voxel = traceMap(rayOrigin, rayDir, color, mask, mapPos, totalDistance, rayStep, 64);

    float hash = ((voxel & VOXEL_ATTR_SUBVOXEL) != 0) ? 0.0 : 0.064 * vhash(vec4(vec3(mapPos), 1.0)) 
        + 0.041 * vhash(vec4(vec3(mapPos) + vec3(floor((rayOrigin.xyz + rayDir.xyz * totalDistance - vec3(mapPos)) * 4.0)) * 17451.0, 1.0));
        
    if (voxel == 0) 
    {
        imageStore(frameNormal, pixelCoords, vec4(1.0));
        imageStore(framePosition, pixelCoords, vec4(-1.0));
        imageStore(frameColor, pixelCoords, SkyDome2(rayOrigin, rayDir, normalize(C_sun_dir.xyz)));
        return;
    }

    imageStore(frameColor, pixelCoords, vec4((color.xyz + hash) / 2.0, 1.0));
    imageStore(frameNormal, pixelCoords, vec4(mask, 1.0));
    imageStore(framePosition, pixelCoords, vec4(rayOrigin + rayDir * totalDistance + mask * 0.001, 1.0));
}