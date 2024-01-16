#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable


#define TRACE_AO

layout(local_size_x = 32,  local_size_y = 32) in;

layout(rgba8, binding = 0) uniform image2D frameColor;
layout(rgba8, binding = 1) uniform image2D frameNormal;

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

vec3 traceRay(vec3 rayO, in vec3 rayD, in vec2 rng, out vec3 normal) {
    vec3 pixelColor = vec3(0.0);

    vec3 rayOrigin = rayO;
    vec3 rayDir = rayD;
    ivec3 mapPos;
    vec3 mask;
    float totalDistance;
    ivec3 rayStep;
    vec4 color;

    uint voxel;

    voxel = traceMap(rayOrigin.xyz, rayDir.xyz, color, mask, mapPos, totalDistance, rayStep, 64);
    normal = mask;

    float hash = ((voxel & VOXEL_ATTR_SUBVOXEL) != 0) ? 0.0 : 0.064 * vhash(vec4(vec3(mapPos), 1.0)) 
        + 0.041 * vhash(vec4(vec3(mapPos) + vec3(floor((rayOrigin.xyz + rayDir.xyz * totalDistance - vec3(mapPos)) * 4.0)) * 17451.0, 1.0));
        
    if (voxel == 0) {
        pixelColor += SkyDome2(rayOrigin.xyz, rayDir.xyz, normalize(C_sun_dir.xyz)).xyz;
        return pixelColor;
    }

    pixelColor += (color.xyz + hash) / 2.0;

#ifdef TRACE_AO
    //ambient occlusion
    rayOrigin = rayOrigin.xyz + rayDir.xyz * totalDistance + abs(mask) * 0.001;
    // rayDir = normalize(mask + CosineSampleHemisphere(mask, rng));
    rayDir = normalize(mask + CosineSampleHemisphereA(mask, rng));

    voxel = traceMap(rayOrigin.xyz, rayDir.xyz, color, mask, mapPos, totalDistance, rayStep, 16);

    if (voxel == 0)
        pixelColor += SkyDome2(rayOrigin.xyz, rayDir.xyz, normalize(C_sun_dir.xyz)).xyz * 0.5;
#endif

    return pixelColor;
}



void main() {
    ivec2 pixelCoords = ivec2(gl_GlobalInvocationID.xy);
    uint rngState = uint(uint(pixelCoords.x) * uint(1973) + uint(pixelCoords.y) * uint(9277) + frameIndex);                              

    ivec2 size = imageSize(frameColor);

    if (pixelCoords.x >= size.x || pixelCoords.y >= size.y) 
        return;

    vec2 rayUV = vec2(pixelCoords) / vec2(size) * 2.0 - 1.0;
    rayUV.y *= float(size.y) / float(size.x);
    rayUV += RandomFloat01(rngState) * 0.001; // poorman's TAA with accumulation
    
    // applying field of view
    rayUV *= tan(fov / 2);

    vec4 rayOrigin = C_position;
    vec4 rayDir = normalize(C_view * vec4(rayUV, 1.0, 1.0));
    
    // raybox intersection with the map bounding box.
    vec2 intersection = intersectAABB(rayOrigin.xyz, rayDir.xyz, vec3(0.), vec3(float(MAP_DIMENSION)));
    if (intersection.x < intersection.y) {
        vec3 normal;
        vec3 volumeRayOrigin = rayOrigin.xyz + rayDir.xyz * max(intersection.x, 0) - EPSILON;
        vec3 color = traceRay(volumeRayOrigin.xyz, rayDir.xyz, rayUV, normal);

        vec4 prev = imageLoad(frameColor, pixelCoords);
        imageStore(frameColor, pixelCoords, mix(prev, vec4(color.xyz, 1.0), 0.3));
        imageStore(frameNormal, pixelCoords, vec4(normal, 1.0));
        return;
    }
    imageStore(frameNormal, pixelCoords, vec4(1.0));
}
