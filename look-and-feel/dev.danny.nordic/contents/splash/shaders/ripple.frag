#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_progress;
    float u_aspect;
    float u_centerX;
    float u_centerY;
    float u_sigma;
    float u_waveFreq;
    float u_pushAmt;
    float u_caStrength;
    float u_noiseWarp;
};

layout(binding = 1) uniform sampler2D texA;
layout(binding = 2) uniform sampler2D texB;

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int octaves) {
    float val = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++) {
        if (i >= octaves) {
            break;
        }
        val += amp * vnoise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return val;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 center = vec2(u_centerX, u_centerY);
    vec2 p = uv - center;
    p.x *= u_aspect;

    float dist = length(p);
    float maxY = max(u_centerY, 1.0 - u_centerY);
    float maxX = max(u_centerX, 1.0 - u_centerX) * u_aspect;
    float maxDist = length(vec2(maxX, maxY));
    float normDist = clamp(dist / max(maxDist, 0.001), 0.0, 1.0);

    float noiseLarge = fbm(p * 4.0 + vec2(u_progress * 1.0, u_progress * 0.5), 4);
    float noiseSmall = fbm(p * 12.0 + vec2(u_progress * 2.0, -u_progress * 1.5), 3);

    float coverage = 1.0 + 0.5 * u_noiseWarp + 0.12;
    float waveFront = u_progress * coverage;

    float warpScale = smoothstep(0.0, 0.05, u_progress);
    float warpedDist = normDist
        + (noiseLarge - 0.5) * u_noiseWarp * warpScale
        + (noiseSmall - 0.5) * (u_noiseWarp * 0.9) * warpScale;

    float delta = warpedDist - waveFront;
    float baseEnvelope = exp(-delta * delta / (2.0 * u_sigma * u_sigma));
    float ripples = max(0.0, cos(delta * u_waveFreq));
    float envelope = baseEnvelope * ripples;

    float gate = smoothstep(0.0, 0.05, u_progress)
        * (1.0 - smoothstep(0.85, 1.0, u_progress));
    envelope *= gate;

    vec2 dir = (dist > 0.001) ? normalize(p) : vec2(0.0);
    vec2 uvOffset = dir * (envelope * u_pushAmt);
    uvOffset.x /= max(u_aspect, 0.001);

    vec2 caOffset = dir * (envelope * u_caStrength);
    caOffset.x /= max(u_aspect, 0.001);

    vec2 uvR = clamp(uv - uvOffset - caOffset, 0.0, 1.0);
    vec2 uvG = clamp(uv - uvOffset, 0.0, 1.0);
    vec2 uvB = clamp(uv - uvOffset + caOffset, 0.0, 1.0);

    vec3 colorA = vec3(
        texture(texA, uvR).r,
        texture(texA, uvG).g,
        texture(texA, uvB).b
    );
    vec3 colorB = vec3(
        texture(texB, uvR).r,
        texture(texB, uvG).g,
        texture(texB, uvB).b
    );

    float feather = 0.04 + 0.05 * noiseLarge;
    float reveal = smoothstep(waveFront + feather, waveFront - feather, warpedDist);
    reveal *= smoothstep(0.0, 0.05, u_progress);

    vec3 color = mix(colorA, colorB, reveal);
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
