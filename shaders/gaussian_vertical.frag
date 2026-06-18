#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uSigma;

out vec4 fragColor;

void main() {
    vec2 uv = clamp(FlutterFragCoord().xy / uResolution, 0.0, 1.0);
    vec2 texelSize = vec2(1.0) / uResolution;

    // Normalized Gaussian kernel (5-tap)
    // Weights: 0.06136, 0.24477, 0.38774, 0.24477, 0.06136
    float w[5];
    w[0] = 0.06136;
    w[1] = 0.24477;
    w[2] = 0.38774;
    w[3] = 0.24477;
    w[4] = 0.06136;

    // Sample offsets based on sigma
    float offsets[5];
    offsets[0] = -2.0 * uSigma;
    offsets[1] = -1.0 * uSigma;
    offsets[2] = 0.0;
    offsets[3] = 1.0 * uSigma;
    offsets[4] = 2.0 * uSigma;

    vec4 color = vec4(0.0);

    for (int i = 0; i < 5; i++) {
        vec2 sampleUv = clamp(
            uv + vec2(0.0, offsets[i] * texelSize.y),
            0.0, 1.0
        );
        color += texture(uTexture, sampleUv) * w[i];
    }

    fragColor = color;
}