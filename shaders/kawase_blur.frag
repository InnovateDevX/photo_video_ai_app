#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uOffset;

out vec4 fragColor;

void main() {
    vec2 uv = clamp(FlutterFragCoord().xy / uResolution, 0.0, 1.0);
    vec2 offset = vec2(uOffset) / uResolution;

    vec4 color = vec4(0.0);

    color += texture(uTexture, uv + vec2(-offset.x, -offset.y));
    color += texture(uTexture, uv + vec2( offset.x, -offset.y));
    color += texture(uTexture, uv + vec2(-offset.x,  offset.y));
    color += texture(uTexture, uv + vec2( offset.x,  offset.y));

    fragColor = color * 0.25;
}