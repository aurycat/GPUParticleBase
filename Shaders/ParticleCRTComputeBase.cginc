// To use this cginc, you must define a function pc_compute with the following
// interface:
//   void pc_compute(float2 posUV, inout float3 pos, inout float3 vel, inout float2 extraData)
// The arguments are:
//   posUV: UV coordinate in the CRT of the position data for this particle.
//          You shouldn't need to do any texture lookups since pos and vel
//          are already passed, but posUV can be used as a unique identifier.
//
//   <inout> pos, vel, extraData:
//          On input, these are the previous position, velocity, and extraData
//          values of the particle, respectively.
//          The function must update these values to move the particle.
//
// pc_compute is called twice for each particle, once for the position pixel
// again for the velocity pixel. When called for the position pixel, the output
// velocity and extraData.y are discarded. And inversely, when called for the
// velocity pixel, the output position and extraData.x are discarded.
//
// However, pc_compute should behave as if it were called once, updating
// all the outputs at the same time. Doing so prevents branching. In general,
// regardless of which pixel is rendering, you should do the new velocity
// calculations, then update the position based on the velocity calculated.
//
// ----------------------------------------------------------------------------
// Created by aurycat. MIT License.


#include "UnityCG.cginc"
#include "UnityCustomRenderTexture.cginc"
#include "ParticleUtils.cginc"

#pragma vertex CustomRenderTextureVertexShader
#pragma fragment pc_frag
#pragma target 4.6

void pc_compute(float2 pid, inout float3 pos, inout float3 vel, inout float2 extraData);

float4 pc_frag(v2f_customrendertexture IN) : COLOR
{
    float2 uv = IN.globalTexcoord.xy;
    bool isVel = (uint)(uv.x*_CustomRenderTextureWidth) % 2 == 1; // Odd columns in the CRT are velocity

    float2 oneTexelHorz = float2(1.0/_CustomRenderTextureWidth, 0);
    float2 posUV = isVel ? (uv - oneTexelHorz) : uv;
    float2 velUV = isVel ? uv : (uv + oneTexelHorz);

    float4 prevPos = tex2D(_SelfTexture2D, posUV);
    float4 prevVel = tex2D(_SelfTexture2D, velUV);
    float2 prevExtraData = float2(prevPos.w, prevVel.w);

    float3 newPos = prevPos.xyz;
    float3 newVel = prevVel.xyz;
    float2 newExtraData = prevExtraData;
    pc_compute(posUV, /*inout*/ newPos, /*inout*/ newVel, /*inout*/ newExtraData);

    return isVel ? float4(newVel, newExtraData.y) : float4(newPos, newExtraData.x);
}