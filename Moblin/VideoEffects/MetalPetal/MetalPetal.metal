#include <MTIShaderLib.h>

using namespace metal;

fragment float4 radialGradient(metalpetal::VertexOut vertexIn [[ stage_in ]]) {
    return float4(float3(1.0 - smoothstep(0.2, 0.5, distance(vertexIn.textureCoordinate, float2(0.5, 0.5)))), 1);
}
