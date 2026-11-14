#include <CoreImage/CoreImage.h>

using namespace metal;

constant float hlgA = 0.17883277;
constant float hlgB = 0.28466892;
constant float hlgC = 0.55991073;
constant float referenceWhite = 203.0 / 1000.0;
constant float3 bt2020Luminance = float3(0.2627, 0.6780, 0.0593);
constant float3x3 bt709ToBt2020 = float3x3(float3(0.627404, 0.069097, 0.016391),
                                           float3(0.329283, 0.919540, 0.088013),
                                           float3(0.043313, 0.011362, 0.895595));
constant float3x3 bt2020ToBt709 = float3x3(float3(1.660491, -0.124550, -0.018151),
                                           float3(-0.587641, 1.132900, -0.100579),
                                           float3(-0.072850, -0.008349, 1.118730));

static float hlgInverseOetf(float value) {
    if (value <= 0.5) {
        return value * value / 3.0;
    }
    return (exp((value - hlgC) / hlgA) + hlgB) / 12.0;
}

static float hlgOetf(float value) {
    if (value <= 1.0 / 12.0) {
        return sqrt(3.0 * value);
    }
    return hlgA * log(12.0 * value - hlgB) + hlgC;
}

extern "C" float4 hlgToLinear(coreimage::sample_t sample) {
    float3 signal = clamp(sample.rgb, 0.0, 1.0);
    float3 scene = float3(hlgInverseOetf(signal.r), hlgInverseOetf(signal.g), hlgInverseOetf(signal.b));
    float luminance = dot(scene, bt2020Luminance);
    float3 display = luminance > 0.0 ? scene * pow(luminance, 0.2) : float3(0.0);
    return float4(bt2020ToBt709 * display / referenceWhite, sample.a);
}

extern "C" float4 linearToHlg(coreimage::sample_t sample) {
    float3 display = clamp(bt709ToBt2020 * sample.rgb * referenceWhite, 0.0, 1.0);
    float luminance = dot(display, bt2020Luminance);
    float3 scene = luminance > 0.0 ? display * pow(luminance, -1.0 / 6.0) : float3(0.0);
    scene = clamp(scene, 0.0, 1.0);
    return float4(hlgOetf(scene.r), hlgOetf(scene.g), hlgOetf(scene.b), sample.a);
}
