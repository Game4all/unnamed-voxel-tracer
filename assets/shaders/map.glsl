
#define MAP_DIMENSION 256

layout(binding = 2) buffer voxelData {
    uint data[];
};

vec4 map_getVoxel(ivec3 pos) {
    if (any(lessThanEqual(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(float(MAP_DIMENSION)))))
        return vec4(0.);

    return unpackUnorm4x8(data[pos.x + MAP_DIMENSION * (pos.y + pos.z * MAP_DIMENSION)]);
}
