#version 450
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_ARB_bindless_texture: enable

layout(local_size_x = 32,  local_size_y = 32) in;

layout(rgba8, binding = 0) writeonly uniform image2D frameColor;
layout(rgba8, binding = 1) writeonly uniform image2D frameNormals;
layout(rgba32f, binding = 2) writeonly uniform image2D framePositions;

layout (binding = 8) uniform u_Camera {
    vec4 C_position;
    mat4 C_view;
    vec4 C_sun_dir;
    float fov;
};

#include assets/shaders/camera.glsl
#include assets/shaders/dda.glsl
#include assets/shaders/map.glsl

float hash(vec4 p) {
    p = fract(p * 0.3183099 + 0.1) - fract(p + 23.22121);
    p = p * 17.0;
    return (fract(p.x * p.y * (1.0 - p.z) * p.w * (p.x + p.y + p.z + p.w)) - 0.5) * 2.0;
}

float vertexAo(vec2 side, float corner) {
	return (side.x + side.y + max(corner, side.x * side.y)) / 3.0;
}

vec4 voxelAo(vec3 pos, vec3 d1, vec3 d2) {
	vec4 side = vec4(float(map_getVoxelRaw(ivec3(pos + d1)) != 0), float(map_getVoxelRaw(ivec3(pos + d2)) != 0), float(map_getVoxelRaw(ivec3(pos - d1)) != 0), float(map_getVoxel((ivec3(pos - d2))) != 0));
	vec4 corner = vec4(float(map_getVoxelRaw(ivec3(pos + d1 + d2)) != 0), float(map_getVoxelRaw(ivec3(pos - d1 + d2)) != 0), float(map_getVoxelRaw(ivec3(pos - d1 - d2)) != 0), float(map_getVoxel(ivec3(pos + d1 - d2)) != 0));
	vec4 ao;
	ao.x = vertexAo(side.xy, corner.x);
	ao.y = vertexAo(side.yz, corner.y);
	ao.z = vertexAo(side.zw, corner.z);
	ao.w = vertexAo(side.wx, corner.w);
	return 1.0 - ao;
}

float shadowTrace(in vec3 rayOrigin, in vec3 rayDir) {
    ivec3 mapPos;
    vec3 deltaDist;
    ivec3 rayStep;
    vec3 sideDist;
    vec3 mask;
    vec4 color;
    float t;

    if (traceMap(rayOrigin, rayDir, color, mask, mapPos, t, rayStep) != 0)
        return 0.3;
    else
        return 1.0;
}

void main() {
    ivec2 pixelCoords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(frameColor);

    if (pixelCoords.x >= size.x || pixelCoords.y >= size.y) 
        return;

    vec2 rayUV = vec2(pixelCoords) / vec2(size) * 2.0 - 1.0;
    rayUV.y *= float(size.y) / float(size.x);
    
    // applying field of view
    rayUV *= tan(fov / 2);

    vec4 rayOrigin = C_position;
    vec4 rayDir = normalize(C_view * vec4(rayUV, 1.0, 1.0));

    // raybox intersection with the map bounding box.
    vec2 intersection = intersectAABB(rayOrigin.xyz, rayDir.xyz, vec3(0.), vec3(float(MAP_DIMENSION)));
    if (intersection.x < intersection.y) {
        vec3 volumeRayOrigin = rayOrigin.xyz + rayDir.xyz * max(intersection.x, 0) - EPSILON;

        ivec3 mapPos;
        vec3 mask;
        float totalDistance;
        ivec3 rayStep;
        vec4 color;
        uint voxel = traceMap(volumeRayOrigin.xyz, rayDir.xyz, color, mask, mapPos, totalDistance, rayStep);

        if (voxel != 0) 
        {
            vec3 intersectionPoint = rayOrigin.xyz + rayDir.xyz * totalDistance;
            float coeff = shadowTrace(intersectionPoint + EPSILON, C_sun_dir.xyz);

            vec4 ambient = voxelAo(vec3(mapPos) - rayStep * vec3(mask), vec3(mask.zxy), vec3(mask.yzx));            
	        vec2 uv = mod(vec2(dot(vec3(mask) * intersectionPoint.yzx, vec3(1.0)), dot(vec3(mask) * intersectionPoint.zxy, vec3(1.0))), vec2(1.0));
	        float interpAo = mix(mix(ambient.z, ambient.w, uv.x), mix(ambient.y, ambient.x, uv.x), uv.y);

            float hash = ((voxel & VOXEL_ATTR_SUBVOXEL) != 0) ? 0.0 : 0.064 * hash(vec4(vec3(mapPos), 1.0)) 
                    + 0.041 * hash(vec4(vec3(mapPos) + vec3(floor((intersectionPoint - vec3(mapPos)) * 4.0)) * 17451.0, 1.0));

            imageStore(frameColor, pixelCoords, vec4((color.xyz + hash) * interpAo * coeff, 1.0));
            imageStore(frameNormals, pixelCoords, vec4(abs(mask), 1.0));
            imageStore(framePositions, pixelCoords, vec4(intersectionPoint, 1.0));
            return;
        }
    }

    /// sky coloring according to ray direction
    vec4 skyColor = SkyDome(rayOrigin.xyz, rayDir.xyz);
    imageStore(frameColor, pixelCoords, vec4(Reinhardt(skyColor.xyz), 1.0));
    imageStore(frameNormals, pixelCoords, vec4(0.));
    imageStore(framePositions, pixelCoords, vec4(0.));
}
