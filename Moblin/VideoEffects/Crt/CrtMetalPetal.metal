#include <metal_stdlib>
#include "MTIShaderLib.h"

using namespace metal;
using namespace metalpetal;

fragment float4 crtMetalPetal(VertexOut vertexIn [[stage_in]],
                              texture2d<float, access::sample> sourceTexture [[texture(0)]],
                              sampler sourceSampler [[sampler(0)]],
                              constant float &inputWidth [[buffer(0)]],
                              constant float &inputHeight [[buffer(1)]],
                              constant float &barrelStrength [[buffer(2)]])
{
    float2 uv = vertexIn.textureCoordinate;

    // Crop to center 75% horizontally (4:3 from 16:9).
    float cropMargin = 1.0 / 8.0;
    float cropWidth = 3.0 / 4.0;
    float cropUvX = (uv.x - cropMargin) / cropWidth;
    if (cropUvX < 0.0 || cropUvX > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Barrel distortion on the cropped region.
    float2 center = float2(0.5, 0.5);
    float2 coord = float2(cropUvX, uv.y) - center;
    float r2 = dot(coord, coord);
    float distortion = 1.0 + barrelStrength * r2;
    float2 distorted = coord * distortion + center;

    // Outside distorted bounds is black.
    if (distorted.x < 0.0 || distorted.x > 1.0 || distorted.y < 0.0 || distorted.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Map back to original texture coordinates.
    float2 sampleUv = float2(distorted.x * cropWidth + cropMargin, distorted.y);
    float4 color = sourceTexture.sample(sourceSampler, sampleUv);

    // Scanlines: darken alternate rows to simulate CRT scanlines.
    float scanlineWidth = max(1.0, inputHeight / 240.0);
    float scanlinePhase = fmod(distorted.y * inputHeight, scanlineWidth * 2.0);
    if (scanlinePhase < scanlineWidth) {
        color.rgb *= 0.75;
    }

    // Color adjustments (saturation 0.7, contrast 1.05, brightness -0.02).
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(float3(luminance), color.rgb, 0.7);
    color.rgb = (color.rgb - 0.5) * 1.05 + 0.5;
    color.rgb += -0.02;

    // Vignette.
    float2 vignetteCoord = float2(cropUvX, uv.y) - center;
    float vignetteDistance = length(vignetteCoord) * 2.0;
    float vignetteFactor = 1.0 - smoothstep(0.5, 1.5, vignetteDistance);
    color.rgb *= vignetteFactor;

    color.rgb = clamp(color.rgb, 0.0, 1.0);
    return color;
}
