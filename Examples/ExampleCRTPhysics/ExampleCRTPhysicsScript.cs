// Created by aurycat. MIT License.

using UnityEngine;
#if UDONSHARP
    using UdonSharp;
    using VRC.SDKBase;
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class ExampleCRTPhysicsScript : UdonSharpBehaviour
#else
    public class ExampleCRTPhysicsScript : MonoBehaviour
#endif
{
    public CustomRenderTexture computeCRT;
    public Transform forcePoint;

    private int timeElapsedID;
    private int resetID;
    private int seedID;
    private int forcePointID;

    private Material computeMaterial;
    private bool doingReset = true;
    private int resetFrames = 0;
    private double enableTime = 0;

    void OnEnable()
    {
#if UDONSHARP
        timeElapsedID = VRCShader.PropertyToID("_TimeElapsed");
        resetID = VRCShader.PropertyToID("_Reset");
        seedID = VRCShader.PropertyToID("_Seed");
        forcePointID = VRCShader.PropertyToID("_ForcePoint");
#else
        timeElapsedID = Shader.PropertyToID("_TimeElapsed");
        resetID = Shader.PropertyToID("_Reset");
        seedID = Shader.PropertyToID("_Seed");
        forcePointID = Shader.PropertyToID("_ForcePoint");
#endif

        computeMaterial = computeCRT.material;
        computeMaterial.SetFloat(resetID, 1);
        computeMaterial.SetFloat(timeElapsedID, 0);
        computeMaterial.SetFloat(seedID, Random.value*10);
        computeCRT.Initialize();
        computeCRT.updateMode = CustomRenderTextureUpdateMode.Realtime;
        computeCRT.updatePeriod = 0.01111f; // 90 FPS (maximum -- actual period will be lower if the game framerate is lower)
        computeCRT.Update(1);
        doingReset = true;
        resetFrames = 0;

        enableTime = Time.timeAsDouble;
    }

    void OnDisable()
    {
        // This is mostly just for the editor so the .mat doesn't
        // change after every time in Play mode
        if (computeMaterial != null) { // Avoid nuisance crash on world exit
            computeMaterial.SetFloat(timeElapsedID, 0);
            computeMaterial.SetFloat(resetID, 0);
            computeMaterial.SetFloat(seedID, 0);
            computeMaterial.SetVector(forcePointID, Vector4.zero);
        }

        if (computeCRT != null) { // Avoid nuisance crash on world exit
            computeCRT.updateMode = CustomRenderTextureUpdateMode.OnDemand;
            computeCRT.Release();
        }
    }

    void Update()
    {
        // Hold _Reset high for 5 frames just to make sure the CRT gets the
        // message, and then clear it back to 0
        if (doingReset) {
            if (resetFrames > 5) {
                doingReset = false;
                computeMaterial.SetFloat(resetID, 0);
            }
            else {
                resetFrames++;
            }
        }

        computeMaterial.SetFloat(timeElapsedID, (float)(Time.timeAsDouble - enableTime));

        Vector3 pos = forcePoint.position;
        // Put force point in the coordinate space of the particle system
        // (not really necessary in the example scene because both are at
        // the origin, but just do it for the principle!)
        pos = transform.InverseTransformPoint(pos);
        computeMaterial.SetVector(forcePointID, new Vector4(pos.x, pos.y, pos.z, 0.0f));
    }
}
