#include <CoreImage/CoreImage.h>

using namespace metal;

constant float PI = 3.14159265358979323846;

extern "C" float2 dewarp360(
    float inputWidth,
    float inputHeight,
    float outputWidth,
    float outputHeight,
    float fieldOfViewWidth,
    float fieldOfViewHeight,
    float3 rotationRow1,
    float3 rotationRow2,
    float3 rotationRow3,
    coreimage::destination dest)
{
    float x = 1;
    float y = (dest.coord().x / outputWidth - 0.5) * fieldOfViewWidth;
    float z = (dest.coord().y / outputHeight - 0.5) * fieldOfViewHeight;

    float r = sqrt(x * x + y * y + z * z);

    x /= r;
    y /= r;
    z /= r;

    float x1 = rotationRow1.x * x + rotationRow1.y * y + rotationRow1.z * z;
    float y1 = rotationRow2.x * x + rotationRow2.y * y + rotationRow2.z * z;
    float z1 = rotationRow3.x * x + rotationRow3.y * y + rotationRow3.z * z;

    float inputX = (atan2(y1, x1) / PI / 2 + 0.5) * inputWidth;
    float inputY = (asin(z1) / PI + 0.5) * inputHeight;

    return float2(inputX, inputY);
}
