// Created by aurycat. MIT License.

#include "NoiseSimplex.cginc"

// Call with pid from pc_particle, plus some unique offset for each call
// to get a series of random numbers for each particle.
// (Output is 0 to 1)
float pc_random(float2 pid, float offset)
{
    float2 p = pid + offset;
    // https://stackoverflow.com/a/10625698
    // By Michael Pohoreski
    float2 K1 = float2(
        23.14069263277926, // e^pi (Gelfond's constant)
            2.665144142690225 // 2^sqrt(2) (Gelfond-Schneider constant)
    );
    return frac( cos( dot(p,K1) ) * 12345.6789 );
}

float2 pc_random2(float2 pid)
{
    return float2(pc_random(pid,-1), pc_random(pid,-2));
}

float3 pc_random3(float2 pid)
{
    return float3(pc_random(pid,-1), pc_random(pid,-2), pc_random(pid,-3));
}

float4 pc_random4(float2 pid)
{
    return float4(pc_random(pid,-1), pc_random(pid,-2), pc_random(pid,-3), pc_random(pid,-4));
}

// This seems to produce pretty good looking random movement along all axes
// but don't ask me why. I just messed around with it until it looked good.
// (Output is -1 to 1)
float3 pc_noise3(float2 pid, float3 t, float3 rand)
{
    return float3(snoise(t.x + (pid + rand.xy)*29),
                  snoise(t.y - (pid + rand.yz)*17),
                  snoise(t.z + (pid + rand.xz)*43));
}

float4 pc_noise4(float2 pid, float4 t, float4 rand)
{
    return float4(snoise(t.x + (rand.xy)*29),
                  snoise(t.y - (rand.yz)*17),
                  snoise(t.z + (rand.xz)*43),
                  snoise(t.w - (rand.zw)*23));
}

// This is based on the sparkle from Xiphic's GPU Particle Cloud prefab
float4 pc_default_sparkle(float2 pid)
{
    float sparkle = snoise(pid*(10+_Time.yz));
    if (sparkle < .65) {
        sparkle = 0;
    }
    sparkle *= 0.16;

    float4 s4 = sparkle;
    s4.a *= 0.3;
    return s4;
}