// To use this cginc, you must define a function pc_particle with the following
// interface:
//   void pc_particle(float2 pid, out float3 pos, out float size, out float4 col)
// The arguments are:
//   pid: A unique identifier for each particle. It's a float2 because it's
//        the UV coordinate of the particle, but as far as pc_particle is
//        concerned, pid is just two arbitrary unique values for the particle.
//   <out> pos: Set this to the position of the particle in object-space
//              coordinates.
//   <out> size: Set this to the size of the particle.
//   <out> col: Set this to the color of the particle.
//
// You must also include a shader property with the following interface:
//   [IntRange] _ParticleCountFactor ("Particle Count Factor", Range(1, 64)) = 32
// *Unless* CUSTOM_FACTOR is used. See below.
//
// If not using the default sphere_8x8 mesh, prior to including this cginc,
// define a macro SQRT_NUM_QUADS_IN_MESH with the sqrt of the number of quads
// in the mesh being used, which must be an integer.
// sphere_8x8 has a SQRT_NUM_QUADS_IN_MESH of 8.
//
//
// You may also optionally define two other functions. If you define them, you
// must also define a macro indicating that the optional function is present.
//
//   #define CUSTOM_FACTOR
//   int pc_particle_count_factor()
//
// pc_particle_count_factor returns a tessellation factor in the range 1 to 64.
// The final number of particles is computed as:
//  (factor * SQRT_NUM_QUADS_IN_MESH)^2
// The default sphere_8x8 has 64 quads, so SQRT_NUM_QUADS_IN_MESH would be 8,
// so the particle count formula would be:
//  (factor * 8)^2
// If CUSTOM_FACTOR is not defined by the user, then pc_particle_count_factor
// is automatically defined to return the value of _ParticleCountFactor,
// described above.
//
//   #define CUSTOM_RENDER
//   float4 pc_render(float2 uv, float4 col)
//
// pc_render accepts a uv within a single particle quad, and color to render.
// It returns the final color of the particle.
// If CUSTOM_RENDER is not defined by the user, then pc_render is automatically
// defined to render a circular soft particle.
//
// ----------------------------------------------------------------------------
// Created by aurycat. MIT License.
// This code (especially the tesselation and geometry shader logic, sphere_8x8
// mesh, and pc_default_sparkle) is derived from Xiphic's GPU Particle Cloud
// shader: https://ko-fi.com/s/62367571e0


#ifndef SQRT_NUM_QUADS_IN_MESH
#define SQRT_NUM_QUADS_IN_MESH 8
#endif

#include "UnityCG.cginc"
#include "ParticleUtils.cginc"

#pragma target 4.6
#pragma vertex   pc_vert
#pragma hull     pc_hull
#pragma domain   pc_doma
#pragma geometry pc_geom
#pragma fragment pc_frag

struct vs_in
{
    float4 pos : POSITION;
    float4 uv  : TEXCOORD0;
};
struct tess_in
{
    float4 pos : INTERNALTESSPOS;
    float4 uv  : TEXCOORD0;
};
struct gs_in
{
    float4 pos : SV_Position;
    float4 uv  : TEXCOORD0;
};
struct fs_in
{
    float4 pos : SV_Position;
    float4 uv  : TEXCOORD0;
    nointerpolation float4 col : COLOR;
    float4 screenUV : TEXCOORD1;
};

struct PatchConstData
{
    float edges[4]  : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};


int pc_particle_count_factor();
void pc_particle(float2 pid, out float3 pos, out float size, out float4 col);
float4 pc_render(float2 uv, float4 col);

// Vertex shader
tess_in pc_vert(vs_in v)
{
    tess_in p;
    p.pos = v.pos;
    p.uv  = v.uv;
    return p;
}

PatchConstData pc_patch_constant_func(InputPatch<tess_in, 4> patch)
{
    // Total number of particles: (factor * SQRT_NUM_QUADS_IN_MESH)^2
    int factor = pc_particle_count_factor();
    PatchConstData o;
    o.edges[0] = o.edges[1] = o.edges[2] = o.edges[3] = (float)factor;
    o.inside[0] = o.inside[1] = (float)factor;
    return o;
}

// Hull shader
[UNITY_domain("quad")]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_outputcontrolpoints(4)]
[UNITY_patchconstantfunc("pc_patch_constant_func")]
tess_in pc_hull(
    InputPatch<tess_in, 4> patch,
    uint id : SV_OutputControlPointID)
{
    return patch[id];
}

// Domain shader
[UNITY_domain("quad")]
gs_in pc_doma(
    PatchConstData patchdata,
    const OutputPatch<tess_in, 4> patch,
    float2 uv : SV_DomainLocation)
{
    gs_in data;

    #define DOMAIN_INTERPOLATE(member) data.member = \
        lerp(lerp(patch[0].member, patch[1].member, uv.x), \
                lerp(patch[3].member, patch[2].member, uv.x), uv.y);

    DOMAIN_INTERPOLATE(pos)
    DOMAIN_INTERPOLATE(uv)
    return data;
}

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

// Geometry shader
[maxvertexcount(3)]
void pc_geom(triangle gs_in tri[3], inout TriangleStream<fs_in> tristream)
{
    fs_in o;

    // Detect and discard lower half of each input quad
    // TODO: optimize upper/lower half detection
    float2 uv_min  = min(min(tri[0].uv.xy, tri[1].uv.xy), tri[2].uv.xy);
    float uv_max_y = max(max(tri[0].uv.y,  tri[1].uv.y),  tri[2].uv.y);
    float ycent = (uv_min.y + uv_max_y)/2;
    float yavg = (tri[0].uv.y+tri[1].uv.y+tri[2].uv.y)/3;
    if (ycent < yavg) return; // discard lower quad half

    float3 pos;
    float size;
    pc_particle(uv_min, pos, size, o.col);

    // Near distance fading
    float distToCamera = distance(mul(unity_ObjectToWorld, float4(pos, 1)).xyz, _WorldSpaceCameraPos);
    o.col.a *= saturate(distToCamera*2-0.5);

    // Generate billboard triangle
    float3 right = UNITY_MATRIX_V._m00_m01_m02;
    float3 up    = UNITY_MATRIX_V._m10_m11_m12;
    float  halfS = size*0.02;
    float  dist = log10(distToCamera*3.+1.); // Increase size a bit for distant particles
    halfS *= dist+.2;

    float4 vert;
    vert  = float4(pos + halfS * right - halfS * up, 1.0f); // Left
    o.uv  = float4(0.866,-0.5,0,1);
    o.pos = UnityObjectToClipPos(vert);
    o.screenUV = ComputeScreenPos(o.pos);
    tristream.Append(o);

    vert  = float4(pos + halfS * up                , 1.0f); // Top
    o.uv  = float4(0,1,0,1);
    o.pos = UnityObjectToClipPos(vert);
    o.screenUV = ComputeScreenPos(o.pos);
    tristream.Append(o);

    vert  = float4(pos - halfS * right - halfS * up, 1.0f); // Right
    o.uv  = float4(-0.866,-0.5,0,1);
    o.pos = UnityObjectToClipPos(vert);
    o.screenUV = ComputeScreenPos(o.pos);
    tristream.Append(o);
}

// Fragment shader
float4 pc_frag(fs_in i) : SV_Target
{
    // Original method from Xiphic's shader
    // clip(1.1 - length(i.uv));

    // From Nestorboy - do this for antialiasing
    float sdf = 1.1 - length(i.uv);
    float aaSdf = saturate(sdf / fwidth(sdf));
    i.col.a *= aaSdf;

    // Soft particles
    float bufferDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, i.screenUV));
    float particleDepth = LinearEyeDepth(i.pos.z);
    float softFade = saturate(1.0f * (bufferDepth - particleDepth));
    i.col.a *= softFade;

    return pc_render(i.uv, i.col);
}


// --- Auto implementations ---
#ifndef CUSTOM_FACTOR
uniform float _ParticleCountFactor;
int pc_particle_count_factor()
{
    return (int)_ParticleCountFactor;
}
#endif

#ifndef CUSTOM_RENDER
float4 pc_render(float2 uv, float4 col)
{
    return col;
}
#endif