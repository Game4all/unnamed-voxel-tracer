
#define MAP_DIMENSION 512

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION (MAP_DIMENSION / CHUNK_DIMENSION)

layout(binding = 2) buffer voxelData {
    uint data[];
};

layout(binding = 3) buffer mapData {
    uint chunks[];
};

vec4 map_getVoxel(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_DIMENSION))))
        return vec4(0.);

    return unpackUnorm4x8(data[pos.x + MAP_DIMENSION * (pos.y + pos.z * MAP_DIMENSION)]);
}

uint map_getChunkFlags(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_CHUNK_DIMENSION))))
        return 0;

    const ivec3 chPos = pos;

    return chunks[chPos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}


bool traceMap(in vec3 rayOrigin, in vec3 rayDir, out vec3 color, out vec3 vmask, out ivec3 vmapPos, out float totalDistance, out ivec3 vrayStep) {
    ivec3 chMapPos;
    vec3 chDeltaDist;
    ivec3 chRayStep;
    vec3 chSideDist;
    bvec3 chMask;

    dda_init(rayOrigin / float(CHUNK_DIMENSION), rayDir, chMapPos, chDeltaDist, chRayStep, chSideDist, chMask);

    for (int i = 0; i < 128; i++) {

        if (map_getChunkFlags(chMapPos) != 0) {
            vec3 updatedRayOrigin = rayOrigin + rayDir * dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + 0.001;
            ivec3 mapPos;
            vec3 deltaDist;
            ivec3 rayStep;
            vec3 sideDist;
            bvec3 mask;

            dda_init(updatedRayOrigin, rayDir, mapPos, deltaDist, rayStep, sideDist, mask);

            for (int i = 0; i < 24; i++) {
                
                vec4 voxel = map_getVoxel(mapPos);
                if (length(voxel) > 0.) {
                    color = voxel.rgb;
                    vmask = vec3(mask);
                    vmapPos = mapPos;
                    totalDistance = dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + dda_distance(rayDir, deltaDist, sideDist, mask);
                    vrayStep = rayStep;
                    return true;
                }

                dda_step(mapPos, deltaDist, rayStep, sideDist, mask);

                if (any(lessThan(chMapPos, ivec3(0))) || any(greaterThanEqual(chMapPos, ivec3(MAP_DIMENSION))))
                    break;
            }
        }

        dda_step(chMapPos, chDeltaDist, chRayStep, chSideDist, chMask);

        if (any(lessThan(chMapPos, ivec3(0))) || any(greaterThanEqual(chMapPos, ivec3(MAP_CHUNK_DIMENSION))))
            return false;
    }

    return false;
}
