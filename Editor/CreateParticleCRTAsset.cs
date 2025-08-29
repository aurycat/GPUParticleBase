// Created by aurycat. MIT License.

#if UNITY_EDITOR
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEditor;

public class CreateParticleCRTAsset
{
    [MenuItem("Assets/Create/Aurycat/Particle CRT")]
    private static void Create()
    {
        CustomRenderTexture crt = ObjectFactory.CreateInstance<CustomRenderTexture>();
        crt.dimension = TextureDimension.Tex2D;
        crt.width = 512;
        crt.height = 256;
        crt.antiAliasing = 1;
        crt.graphicsFormat = GraphicsFormat.R32G32B32A32_SFloat;
        crt.depthStencilFormat = GraphicsFormat.None;
        crt.useMipMap = false;
        crt.useDynamicScale = false;
        crt.enableRandomWrite = false;
        crt.wrapMode = TextureWrapMode.Clamp;
        crt.filterMode = FilterMode.Point;
        crt.anisoLevel = 0;
        crt.initializationMode = CustomRenderTextureUpdateMode.OnDemand;
        crt.initializationSource = CustomRenderTextureInitializationSource.TextureAndColor;
        crt.initializationColor = Color.clear;
        crt.initializationTexture = null;
        crt.updateMode = CustomRenderTextureUpdateMode.OnDemand; // Will be set to Realtime at runtime by script
        crt.updatePeriod = 0.01111f; // 90 FPS
        crt.doubleBuffered = true;
        crt.wrapUpdateZones = false;
        crt.updateZoneSpace = CustomRenderTextureUpdateZoneSpace.Pixel;
        crt.ClearUpdateZones();

        ProjectWindowUtil.CreateAsset(crt, "New Particle CRT.asset");
    }
}
#endif