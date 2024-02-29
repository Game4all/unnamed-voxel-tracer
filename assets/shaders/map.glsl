
#define MAP_DIMENSION 512

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION (MAP_DIMENSION / CHUNK_DIMENSION)

#define EPSILON 0.001

#define VOXEL_SUBMODEL_DIMENSION 8

layout(binding = 9) buffer voxelData {
    uint data[];
};

layout(binding = 10) buffer mapData {
    uint chunks[];
};

layout(rgba8, binding = 6) uniform readonly image3D model;

vec2 intersectAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 tMin = (boxMin - rayOrigin) / rayDir;
    vec3 tMax = (boxMax - rayOrigin) / rayDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
};

uint map_getChunkFlags(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_CHUNK_DIMENSION))))
        return 0;

    return chunks[pos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}


uint map_getVoxel(ivec3 pos) {
    uint blk_idx = map_getChunkFlags(pos >> 3);

    if (blk_idx > 0) {
        return data[(blk_idx - 1) * CHUNK_DIMENSION * CHUNK_DIMENSION * CHUNK_DIMENSION 
        + (pos.x % CHUNK_DIMENSION) + ((pos.z % CHUNK_DIMENSION) * CHUNK_DIMENSION + (pos.y % CHUNK_DIMENSION)) * CHUNK_DIMENSION ];
    } 
    else
        return 0;
}

uint map_getSubVoxel(uint mdlid, ivec3 position) {
    ivec3 origin = ivec3((mdlid & 31) * 8, ((mdlid / 32) & 31) * 8, ((mdlid / 1024) & 31) * 8);
    return packUnorm4x8(imageLoad(model, position + origin));
}


struct HitInfo {
    // Encoded data about the hit.
    // If != 0, theres a hit.
    uint data; 
    // Position in world space of the hit.
    vec3 hit_pos;
    // Normal of the hit.
    vec3 normal;
};

const vec3 normals[] = {
        vec3(-1,0,0),
        vec3(1,0,0),
        vec3(0,-1,0),
        vec3(0,1,0),
        vec3(0,0,-1),
        vec3(0,0,1)
};


// Credits to @Lars from the VoxelGameDev discord for the original optimized DDA :D
// https://github.com/Ciwiel3/SimpleVoxelTracer/blob/master/res/shaders/compute/initial.glsl
HitInfo traceMap(in vec3 rayOrigin, in vec3 rayDir, int maxSteps) {
    // add a delta to prevent grid aligned rays
    if (rayDir.x == 0)
        rayDir.x = 0.001;
    if (rayDir.y == 0)
        rayDir.y = 0.001;
    if (rayDir.z == 0)
        rayDir.z = 0.001;


    const ivec3 bounds = ivec3(VOXEL_SUBMODEL_DIMENSION * MAP_DIMENSION);
    
    ivec3 raySign = ivec3(sign(rayDir));
    ivec3 rayPositivity = (1 + raySign) >> 1;
    vec3 rayInv = 1.0 / rayDir;

    int minIdx = 0;
    vec3 t = vec3(1.);

    ivec3 gridsCoords = ivec3(rayOrigin * float(VOXEL_SUBMODEL_DIMENSION)); // x8 because we start the DDA in subvoxel space
    vec3 withinGridCoords = rayOrigin * float(VOXEL_SUBMODEL_DIMENSION) - gridsCoords;

    uint stepSize = 0;

    for (int stepCount = 0; stepCount < maxSteps; stepCount++) {
        if ((!any(greaterThanEqual(gridsCoords, bounds))) && !any(lessThan(gridsCoords, ivec3(0)))) {
            uvec3 pos = uvec3(gridsCoords) + uvec3(withinGridCoords);
            // uint chunk_index = map_getChunkFlags(ivec3(pos) >> 6); //gets the chunk index at coords, returns chunk index if not empty else 0
            

            //FIXME: chunk stepping is broken.
            // if (chunk_index != 0) 
            // {
                uint block = map_getVoxel(ivec3(pos) >> 3); // gets block at coords, return block data encoded as uint if not empty.
                
                if (block != 0) {
                    uint subblock = map_getSubVoxel(block & 0xFFFFFFF, ivec3(pos) % 8);
                    if (subblock != 0) {
                        uint faceId = 0;
                        if (minIdx == 0)
                            faceId = -rayPositivity.x + 2;
                        if (minIdx == 1)
                            faceId = -rayPositivity.y + 4;
                        if (minIdx == 2)
                            faceId = -rayPositivity.z + 6;

                        return HitInfo(subblock, vec3(gridsCoords + withinGridCoords), normals[faceId - 1]);
                    } 
                    else
                    {
                        if (stepSize != 0) {
                            gridsCoords += ivec3(withinGridCoords);
                            withinGridCoords = fract(withinGridCoords);
                            stepSize = 0;
                        }
                    }
                }
                else
                {
                    if (stepSize != 3) {
                        withinGridCoords += gridsCoords & 7;
                        gridsCoords -= gridsCoords & 7;
                        stepSize = 3;
                    }
                }
            // }
            // else
            // {
            //     if (stepSize != 6) {
            //         withinGridCoords += gridsCoords & 63;
            //         gridsCoords -= gridsCoords & 63;
            //         stepSize = 6;
            //     }
            // }

            /// dda stepping
            t = ((rayPositivity << stepSize) - withinGridCoords) * rayInv;
            minIdx = t.x < t.y ? (t.x < t.z ? 0 : 2) : (t.y < t.z ? 1 : 2);

            gridsCoords[minIdx] += int(raySign[minIdx] << stepSize);
            withinGridCoords += rayDir * t[minIdx];
            withinGridCoords[minIdx] = ((1 - rayPositivity[minIdx]) << stepSize) * 0.999f;
        }
        else break;
    }

    return HitInfo(0, vec3(-1.0), vec3(0));
}


/// Trace the entities.
//TODO: FIX WITH VOLUME ATLAS;
HitInfo traceEntities(in vec3 rayOrigin, in vec3 rayDir, float maxDistance) {
    const vec3 positions[] = {
        vec3(256., 21., 256.),
        vec3(251., 21., 259.),
        vec3(253., 21., 256.),
        vec3(251., 21., 256.),
        vec3(257., 21., 261.),
    };

    vec2 hit = vec2(0.);
    float prevD = 1.0 / 0.;
    uint id = 0xFFFFFFFF;

    // we first iterate over all the available bounding boxes.
    for (int i = 0; i < 5; i++) {
        if (distance(rayOrigin, positions[i]) >= maxDistance)
            continue;

        hit = intersectAABB(rayOrigin, rayDir, positions[i], positions[i] + vec3(1.));

        if (hit.y >= hit.x && prevD >= hit.y) {
            id = i;
            prevD = hit.y;
        }
    }

    if (id != 0xFFFFFFFF) {
        hit = intersectAABB(rayOrigin, rayDir, positions[id], positions[id] + vec3(1.));
        if (hit.y >= hit.x) {
        
        
            return HitInfo(0xFFFFFFFF, positions[id], vec3(0.));
            
            ivec3 bounds = ivec3(8);
            rayOrigin = rayOrigin + max(hit.x, 0) * rayDir;
            ivec3 raySign = ivec3(sign(rayDir));
            ivec3 rayPositivity = (1 + raySign) >> 1;
            vec3 rayInv = 1.0 / rayDir;

            int minIdx = 0;
            vec3 t = vec3(1.);

            ivec3 gridsCoords = ivec3((rayOrigin - EPSILON - positions[id]) * vec3(bounds)); 
            vec3 withinGridCoords = (rayOrigin - positions[id]) * vec3(bounds) - gridsCoords;

            for (int stepCount = 0; stepCount < 64; stepCount++) {
                if ((!any(greaterThanEqual(gridsCoords, bounds))) && !any(lessThan(gridsCoords, ivec3(0)))) {
                    uvec3 pos = uvec3(gridsCoords) + uvec3(withinGridCoords);
                    uint block = packUnorm4x8(imageLoad(model, ivec3(pos) & 7));

                    if (block != 0) {
                        uint faceId = 0;
                        if (minIdx == 0)
                            faceId = -rayPositivity.x + 2;
                        if (minIdx == 1)
                            faceId = -rayPositivity.y + 4;
                        if (minIdx == 2)
                            faceId = -rayPositivity.z + 6;

                        // we return hit position for entities directly in world space.
                        return HitInfo(block, positions[id] + vec3(gridsCoords + withinGridCoords) / 8., normals[faceId - 1]);
                    } 
                    else
                    {
                        gridsCoords += ivec3(withinGridCoords);
                        withinGridCoords = fract(withinGridCoords);
                    }

                    /// dda stepping
                    t = ((rayPositivity << 0) - withinGridCoords) * rayInv;
                    minIdx = t.x < t.y ? (t.x < t.z ? 0 : 2) : (t.y < t.z ? 1 : 2);

                    gridsCoords[minIdx] += int(raySign[minIdx] << 0);
                    withinGridCoords += rayDir * t[minIdx];
                    withinGridCoords[minIdx] = ((1 - rayPositivity[minIdx]) << 0) * 0.999f;
                }
                else break;
            }
            return HitInfo(0, vec3(0), vec3(0));
        }   
    }
    
    return HitInfo(0, vec3(0), vec3(0));
}