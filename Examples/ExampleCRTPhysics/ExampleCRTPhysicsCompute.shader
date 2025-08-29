// Created by aurycat. MIT License.

Shader "Aurycat/GPU Particle Base/Example CRT Physics Compute"
{
Properties
{
    _TimeElapsed      ("Time Elapsed", Float) = 0
    [ToggleUI] _Reset ("Reset", Float) = 0

    _ForcePoint       ("Force Position", Vector) = (0,0,0,0)
    _ForceStrength    ("Force Strength", Float) = -0.5

    _Seed             ("Seed", Range(0,10)) = 0
}
SubShader
{
    Tags { "Queue"="Overlay+1000" "IgnoreProjector"="True" "RenderType"="Overlay" "PreviewType"="Plane" "DisableBatching"="True" }
    Blend Off
    ZWrite Off
    ZTest Always
    Lighting Off
    ColorMask RGBA

    Pass
    {
        CGPROGRAM
        #define CRT_PERIOD 0.01111 // Should match the Realtime Period value in the CRT. 0.01111 is 1/90 aka 90 FPS
        #include "../../Shaders/ParticleCRTPhysicsComputeBase.cginc"

        uniform float4 _ForcePoint;
        uniform float _ForceStrength;
        uniform float _Seed;

        void pc_crt_physics_reset(float2 posUV, out float3 initialPos, out float3 initialVel, out float2 initialExtraData)
        {
            initialPos = pc_random3(posUV);
            initialVel = 0;
            initialExtraData = 0;
        }

        // Physics step only modifies vel (velocity), and optionally extraData
        // Position is updated based on velocity in pc_particle
        void pc_crt_physics_step(float2 posUV, int currentSimulationStep, float3 pos, inout float3 vel, inout float2 extraData)
        {
            float timeShift = (float)currentSimulationStep * 0.003;
            // Apply a bit of "randomness" based on the current position.
            // I was having trouble with physics simulation reproducibility
            // when I used pc_random here, so just use this sad excuse for
            // a random function.
            float3 jitter = (frac(dot(pos, vel) * float3(86.83, 44.82, 15.72))-0.5)*0.5;
            float3 shift = jitter + timeShift + (posUV.x + posUV.y)*0.5;

            float3 flow;
            float3 scale = 0.2;
            flow.x = snoise(pos*scale + float3(.1285, .7692, .9808)*shift + float3(  2.915, -13.398,  -3.361) - _Seed);
            flow.y = snoise(pos*scale + float3(.7152, .6338, .7561)*shift + float3( 33.457, 535.157, 417.349) - _Seed);
            flow.z = snoise(pos*scale + float3(.4571, .2570, .0918)*shift + float3(-51.023,   2.767,   3.104) - _Seed);

            // Apply flow direction
            vel += flow * 0.04;

            // Restoring force to prevent particles getting too far away
            float3 origin = 0;
            float distFromOrigin = distance(pos, origin);
            float3 dirToOrigin = normalize(origin - pos + 0.00001);
            vel += dirToOrigin*lerp(0, 0.1, distFromOrigin/10);

            // Force point to be moved around (can be attractive or repulsive depending on sign of _ForceStrength)
            float distFromForcePoint = distance(pos, _ForcePoint.xyz);
            float3 dirToForcePoint = normalize(_ForcePoint.xyz - pos + 0.00001);
            vel += dirToForcePoint * _ForceStrength / pow(distFromForcePoint, 2);

            // Limit speed of particles, helps keep them from moving too far away
            const float MAX_SPEED = 2;
            vel = min(length(vel), MAX_SPEED) * normalize(vel);
        }
        ENDCG
    }
}
}
