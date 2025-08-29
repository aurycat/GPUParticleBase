// Created by aurycat. MIT License.

Shader "Aurycat/GPU Particle Base/Example Sphere"
{
Properties
{
    _Radius              ("Radius", Float) = 1
    _Offset              ("Offset", Vector) = (0,0,0,0)
    _Distribution        ("Distribution", Range(0,2)) = 1

    _ParticleSize        ("Particle Size", Range(0, 5)) = 0.3
    _SizeRandomness      ("Size Randomness", Range(0,5)) = 0.5

    [IntRange] _ParticleCountFactor ("Particle Count Factor", Range(1, 64)) = 32

    _MovementSpeed       ("Particle Movement Speed", Range(0,50)) = 10
    _RadialMovementSpeed ("Radial Particle Movement Speed", Range(0,5)) = 1

    _Seed                ("Seed", Range(1,2)) = 1
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
        #define TAU 6.283185307179586476925286766559

        uniform float _Radius;
        uniform float3 _Offset;
        uniform float _Distribution;
        uniform float _ParticleSize;
        uniform float _SizeRandomness;
        uniform float _MovementSpeed;
        uniform float _RadialMovementSpeed;
        uniform float _Seed;
        uniform float4 _Color;

        // https://github.com/boksajak/GaussianDistribution
        // ------------------------------------
        // Fast inverse error function approximation
        // Source: "A handy approximation for the error function and its inverse" by Sergei Winitzki.
        // Code: https://stackoverflow.com/questions/27229371/inverse-error-function-in-c
        float erfinv(float x)
        {
            float tt1, tt2, lnx, sgn;
            sgn = (x < 0.0f) ? -1.0f : 1.0f;
        
            x = (1.0f - x) * (1.0f + x);
            lnx = log(x);
        
            tt1 = 2.0f / (3.14159265359f * 0.147f) + 0.5f * lnx;
            tt2 = 1.0f / (0.147f) * lnx;
        
            return (sgn * sqrt(-tt1 + sqrt(tt1 * tt1 - tt2)));
        }
        // Generates a normally distributed sample using a CDF inversion method with fast inverse error function approximation
        // Parameter u is a random number in the range [0;1)
        float sampleNormalDistributionInvCDFFast(float u, float mean, float standardDeviation)
        {
            u = min(u, 0.9999999);
            #define SQRT_TWO 1.41421356237
            return mean + SQRT_TWO * standardDeviation * erfinv(2.0f * u - 1.0f);
        }
        // ------------------------------------

    
        // Simplex noise, adapted from https://www.shadertoy.com/view/Msf3WH
        // Seems to work better for sphere stuff than the code from NoiseSimplex.cginc, no idea why
        // ------------------------------------
        float2 hash( float2 p )
        {
            p = float2( dot(p,float2(127.1,311.7)), dot(p,float2(269.5,183.3)) );
            return -1.0 + 2.0*frac(sin(p)*43758.5453123*_Seed); // Just putting _Seed (random seed) in here seems to work pretty well
        }
        float noise( in float2 p )
        {
            const float K1 = 0.366025404; // (sqrt(3)-1)/2;
            const float K2 = 0.211324865; // (3-sqrt(3))/6;
        
            float2  i = floor( p + (p.x+p.y)*K1 );
            float2  a = p - i + (i.x+i.y)*K2;
            float m = step(a.y,a.x); 
            float2  o = float2(m,1.0-m);
            float2  b = a - o + K2;
            float2  c = a - 1.0 + 2.0*K2;
            float3  h = max( 0.5-float3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
            float3  n = h*h*h*h*float3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
            float3  d = 70.0;
            return dot( n, d );
        }
        float fractal_noise(float2 uv)
        {
            uv *= 5.0;
            float2x2 m = float2x2( 1.6,  1.2, -1.2,  1.6 );
            float f = 0;
            f  = 0.5000*noise( uv ); uv = mul(m, uv);
            f += 0.2500*noise( uv ); uv = mul(m, uv);
            f += 0.1250*noise( uv ); uv = mul(m, uv);
            // f += 0.0625*noise( uv ); uv = mul(m, uv);
            return f;
        }
        float fractal_noise_01(float2 uv)
        {
            return fractal_noise(uv)*0.5 + 0.5;
        }
        // ------------------------------------


        void pc_particle(float2 pid, out float3 pos, out float size, out float4 col)
        {
            float time = 1 + _Time.x / 50;
            float tmPos = time * _MovementSpeed;
            float tmRad = time * _RadialMovementSpeed;

            // Get time-varying point on the surface of the unit sphere
            {
                // Hash pid so that none of the noise components are associated
                float2 pidhash = hash(pid);
                // Get random XYZ from noise function
                pos.x = fractal_noise_01(tmPos + pidhash   - 19);
                pos.y = fractal_noise_01(tmPos + pidhash*7 + 23);
                pos.z = fractal_noise_01(tmPos - pidhash*3 + 149);
                // http://gamedev.net/forums/topic/705038-random-point-in-sphere/5418477/
                // Using method 2. here because it's better for random noise/movement,
                // at least as far as I could figure out.
                pos.x = sampleNormalDistributionInvCDFFast(pos.x, 0, 3);
                pos.y = sampleNormalDistributionInvCDFFast(pos.y, 0, 3);
                pos.z = sampleNormalDistributionInvCDFFast(pos.z, 0, 3);
                pos = normalize(pos);
            }

            // Get time-varying radius (distance of point from center)
            // Implement "basic" radial movement. I feel like there should be a
            // much simpler way to make this look better, but everything I tried
            // with a noise function gave gross artifacts and non-uniform distributions.
            float r = 0;
            float3 bubblePos;
            {
                float rand = pc_random(pid, 0);
                // Normalize rand. I have no idea why this makes it look better :)
                float normalRand = sampleNormalDistributionInvCDFFast(rand, 0.01, _Distribution);
                // Add time-varying movement, but only near the edges, otherwise
                // particles look very fast in the center and slow at the edges.
                //
                // Apply the x400 after mod by 2pi to avoid precision loss when
                // time is multiplied by a large number (400). This only works for
                // whole numbers (e.g. 400.1 wouldn't be able to go outside of the fmod).
                float r = normalRand - (sin(fmod(tmRad * normalRand, TAU) * 400)*0.5 + 0.5) * 0.3 * pow(normalRand,2);

                // Cube root gives uniform radius distribution
                r = pow(r, 1./3);

                r *= _Radius;
                pos *= r;
            }

            // Offset
            pos += _Offset;

            // Particle
            float rand2 = pc_random(pid, 1);
            size = (_ParticleSize + (rand2 * _SizeRandomness));

            // Color
            col = _Color;
            col += pc_default_sparkle(pid);
        }
        ENDCG
    }
}
}