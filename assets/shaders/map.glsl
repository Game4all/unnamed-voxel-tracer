
#define MAP_DIMENSION 256
#define MAP_CHUNK_DIMENSION 8

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