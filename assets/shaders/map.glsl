
#define MAP_DIMENSION 512

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION (MAP_DIMENSION / CHUNK_DIMENSION)

/// Whether the voxel has a subvoxel model.
#define VOXEL_ATTR_SUBVOXEL (1 << 24)

layout(binding = 2) buffer voxelData {
    uint data[];
};

layout(binding = 3) buffer mapData {
    uint chunks[];
};


uint map_getVoxelRaw(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_DIMENSION))))
        return 0;

    return data[((pos.x / 8) + MAP_CHUNK_DIMENSION * ((pos.y / 8) + (pos.z / 8) * MAP_CHUNK_DIMENSION)) * CHUNK_DIMENSION * CHUNK_DIMENSION * CHUNK_DIMENSION 
        + (pos.x % 8) + ((pos.z % 8) * CHUNK_DIMENSION + (pos.y % 8)) * CHUNK_DIMENSION ];
}

vec4 map_getVoxel(ivec3 pos) {
    return unpackUnorm4x8(map_getVoxelRaw(pos));
}

uint map_getChunkFlags(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_CHUNK_DIMENSION))))
        return 0;

    return chunks[pos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}


bool traceMap(in vec3 rayOrigin, in vec3 rayDir, out vec4 color,  out vec3 vmask, out ivec3 vmapPos, out float totalDistance, out ivec3 vrayStep) {
    ivec3 chMapPos;
    vec3 chDeltaDist;
    ivec3 chRayStep;
    vec3 chSideDist;
    bvec3 chMask;

    dda_init(rayOrigin / float(CHUNK_DIMENSION), rayDir, chMapPos, chDeltaDist, chRayStep, chSideDist, chMask);

    for (int i = 0; i < 64; i++) {

        if (map_getChunkFlags(chMapPos) != 0) {
            vec3 updatedRayOrigin = rayOrigin + rayDir * dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + 0.001;
            ivec3 mapPos;
            vec3 deltaDist;
            ivec3 rayStep;
            vec3 sideDist;
            bvec3 mask;

            dda_init(updatedRayOrigin, rayDir, mapPos, deltaDist, rayStep, sideDist, mask);
            mask = lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy)); //FIXME: this is a hack at best.

            for (int j = 0; j < 24; j++) {
                uint voxel = map_getVoxelRaw(mapPos);
                if (voxel != 0) {
                    if ((voxel & VOXEL_ATTR_SUBVOXEL) != 0) {
                        vec3 subOrigin = updatedRayOrigin.xyz + rayDir * dda_distance(rayDir, deltaDist, sideDist, mask);
                        ivec3 submapPos;
                        vec3 subdeltaDist;
                        ivec3 subrayStep;
                        vec3 subsideDist;
                        bvec3 submask = lessThanEqual(subsideDist.xyz + 0.001, min(subsideDist.yzx, subsideDist.zxy));

                        dda_init((subOrigin - vec3(mapPos)) * 8.0 - 0.001, rayDir, submapPos, subdeltaDist, subrayStep, subsideDist, submask);

                        for (int o = 0; o < 28; o++) {
                            bool lena = length(submapPos) < 4.;                            
                            if (lena) {
                                vmask = vec3(submask);
                                vmapPos = mapPos;
                                color = vec4(0.5);
                                totalDistance = dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + dda_distance(rayDir, deltaDist, sideDist, mask);
                                vrayStep = rayStep;
                                return true;
                            }

                            dda_step(submapPos, subdeltaDist, subrayStep, subsideDist, submask);

                            if (any(lessThan(submapPos, ivec3(0))) || any(greaterThanEqual(submapPos, ivec3(8))))
                                break;
                        }

                    } else {
                        vmask = vec3(mask);
                        vmapPos = mapPos;
                        color = unpackUnorm4x8(voxel); //TODO: add support for subvoxel models.
                        totalDistance = dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + dda_distance(rayDir, deltaDist, sideDist, mask);
                        vrayStep = rayStep;
                        return true;
                    }
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