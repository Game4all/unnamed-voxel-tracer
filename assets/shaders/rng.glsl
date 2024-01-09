
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float BlueNoise(vec2 U) { 
    float v =  hash( U + vec2(-1, 0) )
             + hash( U + vec2( 1, 0) )
             + hash( U + vec2( 0, 1) )
             + hash( U + vec2( 0,-1) );
    v =  hash(U) - v/4.  + .5;

    return mod(v + 1.6180339887 * float(frameIndex % 32), 1.0);
}

uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float RandomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}
 
vec3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * 2 * 3.1457;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}

vec3 CosineSampleHemisphere(vec3 n, inout uint seed)
{
    float a1 = RandomFloat01(seed);
    float a2 = RandomFloat01(seed);
    
    vec2 u = vec2(a1, a2);

    float r = sqrt(u.x);
    float theta = 2.0 * 3.14 * u.y;
 
    vec3  B = normalize( cross( n, vec3(0.0,1.0,1.0) ) );
	vec3  T = cross( B, n );
    
    return normalize(r * sin(theta) * B + sqrt(1.0 - u.x) * n + r * cos(theta) * T);
}

vec3 CosineSampleHemisphereA(vec3 n, in vec2 rng)
{
    float a1 = BlueNoise(rng);
    float a2 = BlueNoise(rng + 2*rng);
    
    vec2 u = vec2(a1, a2);

    float r = sqrt(u.x);
    float theta = 2.0 * 3.14 * u.y;
 
    vec3  B = normalize( cross( n, vec3(0.0,1.0,1.0) ) );
	vec3  T = cross( B, n );
    
    return normalize(r * sin(theta) * B + sqrt(1.0 - u.x) * n + r * cos(theta) * T);
}