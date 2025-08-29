// Created by aurycat. MIT License.

Shader "Aurycat/GPU Particle Base/Example Cuboid"
{
Properties
{
    _Range               ("Range", Vector) = (1,1,1,0)
    _Offset              ("Offset", Vector) = (0,0,0,0)

    _ParticleSize        ("Particle Size", Range(0, 5)) = 0.3
    _SizeRandomness      ("Size Randomness", Range(0,5)) = 0.5

    [IntRange] _ParticleCountFactor ("Particle Count Factor", Range(1, 64)) = 32

    _MovementRange       ("Movement Range", Vector) = (0.1,0.1,0.1,0)
    _MovementSpeed       ("Movement Speed", Vector) = (1,1,1,0)

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
        #include "../../Shaders/ParticleRendererBase.cginc"

        uniform float3 _Range;
        uniform float3 _Offset;
        uniform float _ParticleSize;
        uniform float3 _MovementRange;
        uniform float3 _MovementSpeed;
        uniform float _SizeRandomness;
        uniform float4 _Color;

        void pc_particle(float2 pid, out float3 pos, out float size, out float4 col)
        {
            // Position
            float3 t = _Time.x * (_MovementSpeed / max(_MovementRange,0.01));
            float3 rand = pc_random3(pid);
            float3 noise = pc_noise3(pid, t, rand);
            pos = _Offset + rand*max(_Range,0) + noise*max(_MovementRange,0);

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
