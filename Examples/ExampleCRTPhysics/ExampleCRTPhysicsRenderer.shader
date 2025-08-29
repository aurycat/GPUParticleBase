// Created by aurycat. MIT License.

Shader "Aurycat/GPU Particle Base/Example CRT Physics Renderer"
{
Properties
{
    [NoScaleOffset] _CRT ("CRT", 2D)  = "black" {}

    _ParticleSize        ("Particle Size", Range(0, 5)) = 0.3
    _SizeRandomness      ("Size Randomness", Range(0,5)) = 0.5
    [HDR] _Color         ("Color", Color) = (1,1,1,1)
}
SubShader
{
    Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" }
    Blend SrcAlpha One
    Cull Off
    ZWrite Off
    ColorMask RGBA

    Pass
    {
        CGPROGRAM
        #include "../../Shaders/ParticleCRTRendererBase.cginc"

        uniform float _ParticleSize;
        uniform float _SizeRandomness;
        uniform float4 _Color;

        void pc_crt_particle(float2 pid, float3 statePos, float3 stateVel, float2 stateExtraData, out float3 pos, out float size, out float4 col)
        {
            // Position
            pos = statePos;

            // Size
            float rand2 = pc_random(pid, 0);
            size = (_ParticleSize + (rand2 * _SizeRandomness));

            // Color
            col = _Color;
            col += pc_default_sparkle(pid);
        }
        ENDCG
    }
}
}