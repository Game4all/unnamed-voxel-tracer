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

float sdBoxFrame( vec3 p, vec3 orig, vec3 b, float e )
{
       p = abs(p - orig)-b;
  vec3 q = abs(p - orig + e)-e;
  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}
