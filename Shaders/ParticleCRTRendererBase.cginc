// This cginc is a wrapper around ParticleRendererBase.cginc for use with CRT
// particle systems (particles that carry state from one frame to the next).
//
// To use this cginc, you must define a function pc_crt_particle with the
// following interface:
//   void pc_crt_particle(float2 pid, float3 statePos, float3 stateVel, float2 stateExtraData, out float3 pos, out float size, out float4 col);
// The arguments are:
//   pid, pos, size, col: Same as in pc_particle in ParticleRendererBase.cginc.
//     See that file for more info.
//   statePos, stateVel, stateExtraData: The position, velocity, and extraData
//     values from the CRT for the current particle.
//
// You must also define a shader property for the CRT texture called _Buffer.
// It should be defined as:
//   [NoScaleOffset] _CRT ("CRT", 2D)  = "black" {}
//
// If not using the default sphere_8x8 mesh, prior to including this cginc,
// define a macro SQRT_NUM_QUADS_IN_MESH with the sqrt of the number of quads
// in the mesh being used, which must be an integer.
//
// The CRT must have a height that is an integer multiple of
// SQRT_NUM_QUADS_IN_MESH, and the width must be 2x the height.
//
// ----------------------------------------------------------------------------
// Created by aurycat. MIT License.


#define CUSTOM_FACTOR
#include "ParticleRendererBase.cginc"

Texture2D<float4> _CRT;
float4 _CRT_TexelSize;

void pc_crt_particle(float2 pid, float3 statePos, float3 stateVel, float2 stateExtraData, out float3 pos, out float size, out float4 col);

int pc_particle_count_factor()
{
    // Total number of particles  =  crtWidth * crtHeight  =  (factor * sqrt(NumQuadsInMesh))^2
    // crtHeight^2  =  (factor * sqrt(NumQuadsInMesh))^2       <--- assume width is the same as the height, ignoring the 2x columns for velocity data
    // crtHeight  =  factor * sqrt(NumQuadsInMesh)
    // factor  =  crtHeight / sqrt(NumQuadsInMesh)
    const uint crtHeight = _CRT_TexelSize.w;
    // Note it's not possible for there to be fewer than NumQuadsInMesh particles
    // This will return 0 if there are fewer pixels than NumQuadsInMesh, which makes everything disappear
    return crtHeight / SQRT_NUM_QUADS_IN_MESH;
}

void pc_particle(float2 pid, out float3 pos, out float size, out float4 col)
{
    // Read CRT
    // pid is in increments of 1/crtHeight along both axes.
    // crtWidth is actually (or, should be!) 2x the height in order to store the velocity.
    // So nx will only be even numbers (nx  =  pid.x * crtWidth  =  (n/crtHeight) * crtWidth  =  (n/crtHeight) * (2*crtHeight)  =  2*n, where n is some integer)
    // The even columns are position and the odd columns are velocity.
    // (nx,ny) is position and (nx+1,ny) is corresponding velocity.
    const float crtWidth = _CRT_TexelSize.z;
    const float crtHeight = _CRT_TexelSize.w;
    uint nx = pid.x * crtWidth;
    uint ny = pid.y * crtHeight;
    float4 statePos = _CRT.Load(int3(nx,ny,0));
    float4 stateVel = _CRT.Load(int3(nx+1,ny,0))+float4(.001,.001,.001,.001); // add tiny bit or else zero vel blacks out tri
    float2 stateExtraData = float2(statePos.w, stateVel.w);

    pc_crt_particle(pid, statePos.xyz, stateVel.xyz, stateExtraData, /*out*/ pos, /*out*/ size, /*out*/ col);
}