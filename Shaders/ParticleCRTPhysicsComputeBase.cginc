// This cginc is a wrapper around ParticleCRTComputeBase.cginc specifically for
// making physics-based particle systems which have a consistent simulation
// step to ensure that the particles look the same regardless of FPS.
//
// To use this cginc, you must define a function pc_crt_physics_step with the
// following interface:
//   void pc_crt_physics_step(float2 posUV, int currentSimulationStep, float3 pos, inout float3 vel, inout float2 extraData)
// The arguments are:
//   posUV, vel, extraData: Same as in pc_crt_particle from
//     ParticleCRTComputeBase.cginc. See that file for more info.
//   pos: Same as pc_crt_particle, except input-only, not inout. The physics
//     simulation just needs to set the velocity, and the position will be
//     computed automatically.
//   currentSimulationStep: The number of steps since the start of the
//     simulation. Will be 0 on the first step after a reset.
//
// You must also define a function pc_crt_physics_reset with the following
// interface:
//   void pc_crt_physics_reset(float2 posUV, out float3 initialPos, out float3 initialVel, out float2 initialExtraData)
// The arguments are:
//   posUV: Same as in pc_crt_particle from ParticleCRTComputeBase.cginc.
//     See that file for more info.
//   <out> inital*: The initial value of position, velocity, and extraData set
//     on the first frame after a reset.
//
// Prior to including this cginc, you must define a macro CRT_PERIOD containing
// the Update Period value of the CRT being used. I recommend 1/90, aka 0.01111.
// For example:
//   #define CRT_PERIOD 0.01111
//
// You must also define the following shader properties:
//    _TimeElapsed ("Time Elapsed", Float) = 0
//    [ToggleUI] _Reset ("Reset", Float) = 0
//
// _TimeElapsed should be set by a script to be the current simulation time,
// presumably updated every frame to something like Time.time. The reason the
// shader doesn't just use the builtin shader uniform _Time.y is so that you
// have more control over exactly when the simulation progresses. For example,
// you can reset the simulation when the player leaves the room containing
// the particles. If this value does not increase, the particles will freeze.
// If you want to reset the simulation, you need to set this value back to 0
// and set _Reset to 1 for at least one frame.
//
// _Reset should be set by a script to 1 to reset the particles back to their
// initial position. _Reset only needs to be 1 for one frame, and then it can
// be returned to 0. However, holding it at 1 for longer will not cause the
// simulation to freeze; only the first frame after _Reset becomes 1 will the
// particles actually reset. When resetting, it's a good idea to also set
// _TimeElapsed back to 0, otherwise the particles will run extremely fast to
// "catch up" to the time specified by _TimeElapsed.
//
// ----------------------------------------------------------------------------
// Created by aurycat. MIT License.


#include "ParticleCRTComputeBase.cginc"

uniform float _TimeElapsed;
uniform float _Reset;

void pc_crt_physics_reset(float2 posUV, out float3 initialPos, out float3 initialVel, out float2 initialExtraData);
void pc_crt_physics_step(float2 posUV, int currentSimulationStep, float3 pos, inout float3 vel, inout float2 extraData);

void pc_compute(float2 posUV, inout float3 pos, inout float3 vel, inout float2 extraData)
{
    const float2 TEXEL_SIZE = 1 / float2(_CustomRenderTextureWidth, _CustomRenderTextureHeight);

    // Read metadata pixel, the (0,0) pixel
    float4 metadata = tex2D(_SelfTexture2D, TEXEL_SIZE/2);
    float simulationStepsElapsed = metadata.x; // integer
    float didOneFrameOfReset = metadata.z;

    // Determine how many simulation steps are needed this frame
    // to catch up with the current time. Limit it to 15 steps per
    // frame to avoid exploding the GPU if the _TimeElapsed jumps
    // far ahead of simulationTimeElapsed.
    float simulatedTimeElapsed = simulationStepsElapsed * CRT_PERIOD;
    float timeToSimulate = _TimeElapsed - simulatedTimeElapsed;
    int steps = clamp((int)floor(timeToSimulate / CRT_PERIOD), 0, 15);

    if (_Reset) {
        // Reset pos, vel, and extra data for only the first frame after _Reset is triggered
        if (didOneFrameOfReset == 0) {
            // Metadata (0,0) pixel, write out default value of metadata pixel
            // See below for meaning
            if (posUV.x < TEXEL_SIZE.x && posUV.y < TEXEL_SIZE.y) {
                pos = float3(0, 10000, 1);
                vel = 0;
                extraData = 0;
            }
            // Normal pixel, write out initial position
            else {
                pc_crt_physics_reset(posUV, /*out*/ pos, /*out*/ vel, /*out*/ extraData);
            }
            return;
        }
    }
    else {
        didOneFrameOfReset = 0;
    }

    // Write out metadata in (0,0) pixel
    // x stores number of simulation steps elapsed
    // y is constant 10000 so that the (0,0) particle is far away (it's still an actual particle position lol)
    // z stores 1 if reset is happening, 0 otherwise
    // w (ExtraData) is unused
    // The corresponding velocity (1,0) pixel is also unused
    if (posUV.x < TEXEL_SIZE.x && posUV.y < TEXEL_SIZE.y) {
        pos = float3(
            simulationStepsElapsed + steps,
            10000,
            didOneFrameOfReset);
        vel = 0;
        extraData = 0;
        return;
    }

    for (int step = 0; step < steps; step++) {
        pc_crt_physics_step(posUV, (int)simulationStepsElapsed + step, pos, /*inout*/ vel, /*inout*/ extraData);

        // Update position from velocity data
        pos += vel * CRT_PERIOD;
    }
}