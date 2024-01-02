
#define MAP_DIMENSION 512

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION (MAP_DIMENSION / CHUNK_DIMENSION)

#define EPSILON 0.001

/// Whether the voxel has a subvoxel model.
#define VOXEL_ATTR_SUBVOXEL (1 << 24)

layout(binding = 9) buffer voxelData {
    uint data[];
};

layout(binding = 10) buffer mapData {
    uint chunks[];
};

layout(binding = 11) buffer models {
    layout(rgba8) image3D model[];
};


uint map_getVoxelRaw(ivec3 pos) {
    uint blk_idx = chunks[((pos.x / CHUNK_DIMENSION) + MAP_CHUNK_DIMENSION * ((pos.y / CHUNK_DIMENSION) + (pos.z / CHUNK_DIMENSION) * MAP_CHUNK_DIMENSION))];

    if (blk_idx > 0) {
        return data[(blk_idx - 1) * CHUNK_DIMENSION * CHUNK_DIMENSION * CHUNK_DIMENSION 
        + (pos.x % CHUNK_DIMENSION) + ((pos.z % CHUNK_DIMENSION) * CHUNK_DIMENSION + (pos.y % CHUNK_DIMENSION)) * CHUNK_DIMENSION ];
    } 
    else
        return 0; 
}

vec4 map_getVoxel(ivec3 pos) {
    return unpackUnorm4x8(map_getVoxelRaw(pos));
}

uint map_getChunkFlags(ivec3 pos) {
    return chunks[pos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}

//TODO: let's juste rewrite this from scratch.
uint traceMap(in vec3 rayOrigin, in vec3 rayDir, out vec4 color,  out vec3 vmask, out ivec3 vmapPos, out float totalDistance, out ivec3 vrayStep, int nSteps) {
    ivec3 chMapPos;
    vec3 chDeltaDist;
    ivec3 chRayStep;
    vec3 chSideDist;
    bvec3 chMask;

    dda_init(rayOrigin / float(CHUNK_DIMENSION), rayDir, chMapPos, chDeltaDist, chRayStep, chSideDist, chMask);

    for (int i = 0; i < nSteps; i++) {

        if (map_getChunkFlags(chMapPos) > 0) {
            vec3 updatedRayOrigin = rayOrigin + rayDir * dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + EPSILON;
            ivec3 mapPos;
            vec3 deltaDist;
            ivec3 rayStep;
            vec3 sideDist;
            bvec3 mask;

            dda_init(updatedRayOrigin, rayDir, mapPos, deltaDist, rayStep, sideDist, mask);

            for (int j = 0; j < (nSteps / 2); j++) {
                uint voxel = map_getVoxelRaw(mapPos);
                if (voxel != 0) {
                    if ((voxel & VOXEL_ATTR_SUBVOXEL) != 0) {
                        vec3 subOrigin = updatedRayOrigin.xyz + rayDir * dda_distance(rayDir, deltaDist, sideDist, mask);
                        ivec3 submapPos;
                        vec3 subdeltaDist;
                        ivec3 subrayStep;
                        vec3 subsideDist;
                        bvec3 submask;


                        //TODO: fix this heck.abs
                        //TODO: this may have to do with the sub ray origin.
                        dda_init((subOrigin - vec3(mapPos)) * 8.0, rayDir, submapPos, subdeltaDist, subrayStep, subsideDist, submask);
                        submask = lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy));

                        for (int o = 0; o < (nSteps / 2); o++) {
                            vec4 subC = imageLoad(model[voxel & 0x00ffffff], submapPos);                        
                            if (length(subC) > 0.) {
                                vmask = vec3(submask);
                                vmapPos = mapPos;
                                color = subC;
                                totalDistance = dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + dda_distance(rayDir, deltaDist, sideDist, mask);
                                vrayStep = rayStep;
                                return voxel;
                            }

                            dda_step(submapPos, subdeltaDist, subrayStep, subsideDist, submask);

                            if (any(lessThan(submapPos, ivec3(0))) || any(greaterThanEqual(submapPos, ivec3(8))))
                                break;
                        }

                    } else {
                        vmask = vec3(mask);
                        vmapPos = mapPos;
                        color = unpackUnorm4x8(voxel);
                        totalDistance = dda_distance(rayDir, chDeltaDist, chSideDist, chMask) * float(CHUNK_DIMENSION) + dda_distance(rayDir, deltaDist, sideDist, mask);
                        vrayStep = rayStep;
                        return voxel;
                    }
                }

                dda_step(mapPos, deltaDist, rayStep, sideDist, mask);

                if (any(lessThan(chMapPos, ivec3(0))) || any(greaterThanEqual(chMapPos, ivec3(MAP_DIMENSION))))
                    break;
            }
        }

        dda_step(chMapPos, chDeltaDist, chRayStep, chSideDist, chMask);

        if (any(lessThan(chMapPos, ivec3(0))) || any(greaterThanEqual(chMapPos, ivec3(MAP_CHUNK_DIMENSION))))
            return 0;
    }

    return 0;
}