#include <CoreImage/CoreImage.h>

using namespace metal;

extern "C" float2 crtBarrelDistortion(
    float inputWidth,
    float inputHeight,
    float strength,
    coreimage::destination dest)
{
    float2 center = float2(inputWidth / 2.0, inputHeight / 2.0);
    float2 coord = (dest.coord() - center) / center;
    float r2 = dot(coord, coord);
    float distortion = 1.0 + strength * r2;
    float2 distorted = coord * distortion;
    return distorted * center + center;
}
