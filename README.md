GPU particle boilerplate code and examples for VRChat worlds
============================================================

This package provides base/boilerplate code and examples for GPU particles
intended for use in VRChat worlds. They could also work in non-VRChat
projects, or could work on VRChat avatars depending on how you use them.

This package is like a prefab, but it's not quite drag-and-drop. You'll still
need to write shader code to define how the particles behave, but this package
provides .cginc files to do all the "boring" parts of setting up a GPU particle
system for you, as well as provides usage examples.

The following sections describe the provided examples and cgincs in increasing
order of complexity. You should open the ExampleScene to see each example and
follow along to the descriptions below.


## ExampleCuboid
 
ExampleCuboid is the simplest particle system provided. All you need to do to
use it is create a MeshRenderer with the provided `sphere_8x8` mesh and put the
ExampleCuboid material on that renderer.

Take a look at the ExampleCuboid.shader file to see the logic behind it. All
of the boilerplate code is hidden in
```
    #include "../../Shaders/ParticleRendererBase.cginc"
```
while the logic to make the cube a cube is in the `pc_particle` function.
`pc_particle` is called by the boilerplate code in `ParticleRendererBase.cginc`
for each particle rendererd, and it outputs the position, size, and color of
that particle.

If the code within ExampleCuboid's `pc_particle` function is not at least
mostly understandable to you, then this package is probably not for you :)
Learn more shader programming first and them come back!

ExampleCuboid uses a few utility functions provided by this package,
`pc_random`, `pc_random3`, `pc_noise3`, `pc_default_sparkle`. Those and more,
are all defined in `ParticleUtils.cginc` and are quite commonly useful for
particles so that's why I've provided them. See `ParticleUtils.cginc` for
descriptions of each function.


## ParticleRendererBase.cginc

This is the base for all particle rendering. See the header comment at the top
of the file for more info, but the short version is that you just need to
include this file, and then you can let it call `pc_particle` for you to define
the particle behavior.

One other thing of note is the ability to create a custom particle renderer by
defining the function `pc_render` and the macro CUSTOM_RENDER. Using a custom
renderer, you can do things like draw textures on each particle instead of just
a dot. Every particle is drawn as a single triangle, and `pc_render` is just the
fragment shader for that triangle, except with a few things like soft particles
already handled for you.


## ExampleSphere

ExampleSphere is not really any from ExampleCuboid, except with much more
complicated code for defining the position of the particle. I've provided this
example primarily for you to use as a starting point for creating more complex
movement logic.


## CRT Particle Systems and ExampleCRTPhysics

This is what you're really here for! Physics-based particles. By using a CRT
(Custom Render Texture), the particles can preserve state from one frame to the
next, allowing them to perform physics simulations.

There are a few parts to a CRT-based particle system:
1. The renderer

    This is the material which displays the contents of the CRT. In principle,
    it is no different than the ExampleCuboid or ExampleSphere. The only
    difference is that `ParticleCRTRendererBase.cginc` handles the boilerplate of
    reading all the particle state date from the CRT.
    
    Looking at `ExampleCRTPhysicsRenderer.shader`, you can see that the shader
    logic looks very similar to that of ExampleCuboid, except that it's using
    the CRT Renderer base include:
    ```
        #include "../../Shaders/ParticleCRTRendererBase.cginc"
    ```
    and now the handler function is pc_crt_particle. `pc_crt_particle` is like
    `pc_particle`, except it accepts extra state info from the CRT about the
    particle, namely position and velocity.

    Normally you just want to pass the input position back out as the output
    position. The important part will be deciding the color and size, which
    you could do based on factors like the particle's position or velocity!
    Also note that the renderer shader has the `_CRT` property. The `_CRT`
    property is required, and it must be set to the CRT asset in the renderer
    material.

2. The CRT asset

    To summarize CRTs, they're essentially a shorthand for taking a quad with a
    material, pointing a camera at it, and setting the camera to render to a
    texture. The material is what does all the compuation, but the CRT asset
    needs to be configured correctly to make it work.

    I've provided a utility menu item, `Assets > Create > Aurycat > Particle CRT`
    to automatically create a CRT with the correct configuration. All you need
    to do is set the material on it.

    One thing of note is that the Update Mode is set to OnDemand by default.
    That's because generally you want to avoid having the CRT be updating except
    when you want it to. In ExampleCRTPhysics, CRT's update mode is changed to
    Realtime (update every frame) by `ExampleCRTPhysicsScript.cs` at runtime.
    You should do something similar: only setting the update mode to Realtime
    when you want to render the particles, and setting it back to OnDemand
    when the particles don't need to be updating.

3. The compute

    Here's where the actual logic of the particle system happens. Looking at
    `ExampleCRTPhysicsCompute.shader`, you'll see that now
    ```
        #include "../../Shaders/ParticleCRTPhysicsComputeBase.cginc"
    ```
    is used to provide boilerplate for a physics particle system. It will call
    two functions which you must define: `pc_crt_physics_reset`, which provides
    the initial position of the particles at the start of the simulation, and
    `pc_crt_physics_step`, which handles updating the velocity after each physics
    step. Everything that goes into these functions is up to you, and will
    define the movement-apperance of the particle system.

As a recap, the logic defining the particle system is split into the renderer,
which handles drawing each particle and defining its color and size, and the
compute, which handles computing the position and velocity of each particle.
The CRT asset joins those two parts.


## ExampleCRTPhysicsScript

It is possible to use the CRT particle system without a script (e.g. for a
VRChat avatar), however it's trickier and isn't the primary focus of this
package. In general, you'll want to have a script for each CRT particle system
which handles turning on and off the CRT, resetting the particle system when
desired, as well as updating compute material properties for any interactive
parts of the particle system (e.g. the PhysicsForcePoint in the example).

There is one other thing the script needs to do specifically for particles
using `ParticleCRTPhysicsComputeBase.cginc`, which is update the `_ElapsedTime`
property. `_ElapsedTime` indicates how much time has occured since the start
of the simulation. The script needs to update it every frame in its `Update`
method. If you want to reset the particle system, the script needs to reset
`_ElapsedTime` to 0 and set `_Reset` to 1 for at least one frame. See
`ExampleCRTPhysicsScript.cs` for an example of how to do all that.


## ParticleCRTRendererBase.cginc

Look at section 1 of the "CRT Particle Systems and ExampleCRTPhysics" section
above, but essentially this cginc is just a wrapper around
`ParticleRendererBase.cginc` which handles looking up the position and velocity
of each particle from the CRT for you.


## ParticleCRTPhysicsComputeBase.cginc

This cginc is a wrapper around `ParticleCRTComputeBase.cginc` (described next)
which is for CRT particle systems specifically doing physics-based movement.

The main benefit of using `ParticleCRTPhysicsComputeBase.cginc` for physics
particle is it ensures the particles look the same despite the framerate the
game is running at. It does that in a manner very similar to Unity's
`FixedUpdate`. It keeps track of the elapsed simulated time, compares it to
the elapsed actual time (provided by `_ElapsedTime`) and runs the physics step
as many times as needed to bring the simulation time up to date with the
real time. That way, you can write your simulation code in a framerate-
independent manner.


## ParticleCRTComputeBase.cginc

This cginc is more low-level boilerplate for a particle CRT compute shader.
It doesn't do any timekeeping for you, instead just calling `pc_compute` to let
you handle updating the position and velocity yourself. All it does is perform
the self-texture lookup to get the previous position and velocity data from
the CRT.


## Credits

This package was created by aurycat. The original base for the particle
rendering code came from [Xiphic's GPU Particle Cloud prefab](https://ko-fi.com/s/62367571e0)
but has been heaviliy modified.

The code is all under the [MIT license](https://mit-license.org/).