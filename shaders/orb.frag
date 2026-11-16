#version 460 core
#include <flutter/runtime_effect.glsl>

// Raymarched liquid-chrome blob for "Моя волна".
uniform vec2 uSize;
uniform float uTime;
uniform float uEnergy;   // 0 idle .. 1 playing
uniform vec2 uMouse;     // -1..1, tilts the light

out vec4 fragColor;

mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float map(vec3 p) {
  float t = uTime;
  p.xz *= rot(t * 0.25);
  p.xy *= rot(t * 0.13);
  float amp = 0.07 + 0.10 * uEnergy;
  float spd = 0.8 + 1.6 * uEnergy;
  float d = sin(p.x * 3.1 + t * spd) * sin(p.y * 2.7 + t * spd * 1.3) * sin(p.z * 3.3 + t * spd * 0.8);
  d += 0.5 * sin(p.x * 5.7 - t * spd * 1.1) * sin(p.y * 6.1 + t * spd * 0.9) * sin(p.z * 5.3 - t * spd * 1.4);
  return length(p) - 0.78 - amp * d;
}

vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.002, 0.0);
  return normalize(vec3(map(p + e.xyy) - map(p - e.xyy),
                        map(p + e.yxy) - map(p - e.yxy),
                        map(p + e.yyx) - map(p - e.yyx)));
}

// soft studio environment in greys
float env(vec3 r) {
  float sky = smoothstep(-0.2, 1.0, r.y);
  float box1 = exp(-pow(length(r.xy - vec2(-0.45 + uMouse.x * 0.3, 0.65 - uMouse.y * 0.3)) * 2.6, 2.0)) * 1.6;
  float box2 = exp(-pow(length(r.xy - vec2(0.85, 0.05)) * 3.2, 2.0)) * 0.9;
  float rim = exp(-pow((r.x + 0.95) * 5.0, 2.0)) * 0.6;
  return 0.14 + 0.45 * sky + box1 + box2 + rim;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - 0.5 * uSize) / min(uSize.x, uSize.y) * 2.0;
  vec3 ro = vec3(0.0, 0.0, 2.6);
  vec3 rd = normalize(vec3(uv * 0.5, -1.0));

  float t = 0.0;
  float hit = 0.0;
  for (int i = 0; i < 56; i++) {
    vec3 p = ro + rd * t;
    float d = map(p);
    if (d < 0.0015) { hit = 1.0; break; }
    t += d * 0.8;
    if (t > 5.0) break;
  }

  // halo behind the blob
  float r = length(uv);
  float glow = exp(-pow(max(r - 0.55, 0.0) * 3.2, 2.0)) * (0.12 + 0.12 * uEnergy) * smoothstep(0.98, 0.7, r);

  if (hit < 0.5) {
    fragColor = vec4(vec3(1.0) * glow, glow);
    return;
  }

  vec3 p = ro + rd * t;
  vec3 n = normalAt(p);
  vec3 refl = reflect(rd, n);
  float fres = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
  vec3 l = normalize(vec3(-0.5 + uMouse.x * 0.4, 0.7 - uMouse.y * 0.4, 0.6));
  float diff = max(dot(n, l), 0.0);
  float spec = pow(max(dot(reflect(-l, n), -rd), 0.0), 90.0);

  float c = env(refl) * (0.55 + 0.45 * fres) + diff * 0.12 + spec * 1.6;
  c = c / (1.0 + c * 0.55);
  c = pow(clamp(c, 0.0, 1.0), 0.85);
  fragColor = vec4(vec3(c), 1.0);
}
