/// SDF functions from inigo quilez (iq) https://iquilezles.org/articles/distfunctions/

float sdPlane( vec3 p, vec3 n, float h )
{
  // n must be normalized
  return dot(p,n) + h;
}

float sdSphere( vec3 p, vec3 orig, float s )
{
  return length(p - orig) - s;
}

float sdBox( vec3 p, vec3 orig, vec3 b )
{
  vec3 q = abs(p - orig) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}