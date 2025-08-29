Shader "Aurycat/UnlitBlackSkybox"
{
Properties
{
}
SubShader
{
    Tags { "Queue"="Background+10" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Off
    ZWrite Off

    Pass
    {
        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 5.0
        
        #include "UnityCG.cginc"

        struct appdata
        {
            float4 vertex : POSITION;
        };

        struct v2f
        {
            float4 vertex : SV_POSITION;
        };

        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            return o;
        }

        float4 frag (v2f i) : SV_Target
        {
            return float4(0,0,0,1);
        }
        ENDCG
    }
}
}
