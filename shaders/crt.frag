#version 300 es
// Modo CRT cyberpunk: scanlines + aberración cromática + viñeta (SUPER+X)
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec2 uv = v_texcoord;
    vec2 px = 1.0 / vec2(textureSize(tex, 0));
    vec2 off = (uv - 0.5) * px * 3.0;              // más separación hacia los bordes
    float r = texture(tex, uv + off).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - off).b;
    vec3 col = vec3(r, g, b);

    float line = mod(floor(uv.y / px.y), 3.0);      // una de cada 3 filas, más oscura
    col *= line < 1.0 ? 0.82 : 1.0;

    vec2 d = uv - 0.5;
    col *= 1.0 - dot(d, d) * 0.9;                   // viñeta
    col += vec3(0.02, 0.0, 0.03);                   // tinte magenta
    fragColor = vec4(col, 1.0);
}
