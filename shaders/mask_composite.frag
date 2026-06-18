#include <flutter/runtime_effect.glsl>

uniform sampler2D uBackground;
uniform sampler2D uForeground;
uniform sampler2D uMask;
uniform vec2 uResolution;
uniform float uFeather;

out vec4 fragColor;

void main() {
    vec2 uv = clamp(FlutterFragCoord().xy / uResolution, 0.0, 1.0);

    vec4 bgColor = texture(uBackground, uv);
    vec4 fgColor = texture(uForeground, uv);
    vec4 maskColor = texture(uMask, uv);

    // Use the red channel of the mask as alpha
    float maskAlpha = maskColor.r;

    // Apply feathering: soften mask edges by the feather amount
    // A small gaussian-like falloff at the mask edges
    if (uFeather > 0.0) {
        float edgeDist = 1.0 - abs(maskAlpha - 0.5) * 2.0;
        float featherFactor = smoothstep(0.0, uFeather, edgeDist);
        maskAlpha = mix(maskAlpha, maskAlpha * featherFactor, 0.5);
    }

    // Composite foreground over background using mask
    fragColor = mix(bgColor, fgColor, maskAlpha);
}