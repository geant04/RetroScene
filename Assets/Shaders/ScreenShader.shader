Shader "Custom/ScreenShader"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Brightness ("Brightness", Range(0,5)) = 2.0
    }
    SubShader
    {
        Pass{
        CGPROGRAM

        #pragma vertex vp
        #pragma fragment fp

        sampler2D _MainTex;
        float _Brightness;

        #include "UnityCG.cginc"

        struct inputData
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float4 vertex : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : TEXCOORD1;
        };

        v2f vp (inputData v) {
            v2f i;
            i.uv = v.uv;
            i.normal = v.normal;
            i.vertex = UnityObjectToClipPos(v.vertex);

            return i;
        }

        float4 fp(v2f i) : SV_TARGET
        {
            float vignette = 1.0 - 1.2 * length(i.uv - float2(0.5, 0.5));

            float2 bulgeUV = 1.0 - 0.125 * length(i.uv - float2(0.5, 0.5));

            float4 sample = tex2D(_MainTex, 0.98 * i.uv / bulgeUV + float2(-0.02, -0.05));

            float lines = frac(i.uv.y * 2.0 - _Time.y * 5.0);
            float smallLines = frac(i.uv.y  * 100.0) * 0.03;

            //float vignette = 1.0 - 1.2 * length(i.uv - float2(0.5, 0.5));

            float4 finalColor = (sample);

            float greyscale = dot(finalColor.rgb, fixed3(.222, .707, .071));  // Convert to greyscale numbers with magic luminance numbers
            //finalColor.rgb = lerp(float3(greyscale, greyscale, greyscale), finalColor.rgb, 2.0);

            finalColor.rgb *= float3(0.20, 0.50, 1.0) * 3.0;
            finalColor += (smallLines + lines * 0.20);

            return finalColor * _Brightness * vignette;
        }

        ENDCG
        }
    }
}
