#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time;
out vec4 fragColor;

const vec3 PINK = vec3(1.0, 0.0, 0.333);
const vec3 CYAN = vec3(0.0, 1.0, 0.784);

float hash(float n) { return fract(sin(n) * 43758.5453); }

void main() {
    float t = clamp(time, 0.0, 3.0);
    vec2 uv = v_texcoord;
    vec2 px = 1.0 / vec2(textureSize(tex, 0));

    // ---- Phase 1: glitch + flicker (0 - 0.5s) ----
    float p1 = smoothstep(0.0, 0.5, t);

    float glitchAmt = p1 * (1.0 - smoothstep(0.8, 1.6, t));
    float blockY = floor(uv.y * 24.0);
    float glitchOff = (hash(blockY + floor(t * 25.0)) - 0.5) * 0.06 * glitchAmt;
    vec2 guv = uv + vec2(glitchOff, 0.0);

    float aberr = p1 * 0.012;
    vec2 dir = (guv - 0.5) * aberr;
    float r = texture(tex, clamp(guv + dir, 0.0, 1.0)).r;
    float g = texture(tex, clamp(guv, 0.0, 1.0)).g;
    float b = texture(tex, clamp(guv - dir, 0.0, 1.0)).b;
    vec3 col = vec3(r, g, b);

    float scan = 1.0 - p1 * 0.25 * step(0.5, fract(uv.y / px.y * 0.5));
    col *= scan;

    col *= 1.0 - p1 * 0.15 * sin(t * 45.0) * sin(t * 73.0);

    // ---- Phase 2: vertical collapse (0.4 - 1.5s) ----
    float p2 = smoothstep(0.4, 1.5, t);
    float halfH = mix(0.5, 0.0015, p2 * p2);
    float yDist = abs(uv.y - 0.5);

    float vMask = 1.0 - smoothstep(halfH - 0.008, halfH, yDist);
    col *= vMask;

    float edgeGlow = exp(-abs(yDist - halfH) * 180.0) * p2;
    col += mix(PINK, CYAN, uv.x + sin(t * 4.0) * 0.3) * edgeGlow * 0.7;

    // ---- Phase 3: horizontal collapse (1.3 - 2.0s) ----
    float p3 = smoothstep(1.3, 2.0, t);
    float halfW = mix(0.5, 0.002, p3 * p3 * p3);
    float xDist = abs(uv.x - 0.5);
    float hMask = 1.0 - smoothstep(halfW - 0.008, halfW, xDist);
    col *= mix(1.0, hMask, smoothstep(1.3, 1.6, t));

    // ---- Dot glow (phase 3 onward) ----
    float dotR = length(uv - 0.5);
    float dotGlow = exp(-dotR * 25.0) * p3 * (1.0 - smoothstep(2.0, 2.6, t));
    col += mix(PINK, CYAN, 0.5 + sin(t * 6.0) * 0.5) * dotGlow * 0.6;

    // ---- Phase 4: final fade (2.0 - 2.6s) ----
    float p4 = smoothstep(2.0, 2.6, t);
    col *= 1.0 - p4;

    // Phosphor afterglow
    float after = exp(-dotR * 6.0) * smoothstep(2.2, 2.4, t) * (1.0 - smoothstep(2.4, 2.7, t));
    col += vec3(0.025, 0.006, 0.035) * after;

    fragColor = vec4(col, 1.0);
}
