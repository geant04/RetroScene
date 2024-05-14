Shader "Hidden/DepthOfField"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass 
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex, _CameraDepthTexture;
            float _FocusDistance, _FocusRange;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                half depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                depth = LinearEyeDepth(depth);

                float coc = (depth - _FocusDistance) / _FocusRange;
                coc = clamp(coc, -1, 1);

                return coc;
            }
            ENDCG
        }
        Pass{
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float _BokehRadius, _FocusDistance, _FocusRange;
            half4 _MainTex_TexelSize;

            static const int kernelSampleCount = 16;
            static const float2 kernel[kernelSampleCount] = {
                float2(0, 0),
                float2(0.54545456, 0),
                float2(0.16855472, 0.5187581),
                float2(-0.44128203, 0.3206101),
                float2(-0.44128197, -0.3206102),
                float2(0.1685548, -0.5187581),
                float2(1, 0),
                float2(0.809017, 0.58778524),
                float2(0.30901697, 0.95105654),
                float2(-0.30901703, 0.9510565),
                float2(-0.80901706, 0.5877852),
                float2(-1, 0),
                float2(-0.80901694, -0.58778536),
                float2(-0.30901664, -0.9510566),
                float2(0.30901712, -0.9510565),
                float2(0.80901694, -0.5877853),
            };

            fixed4 frag(v2f i) : SV_Target
            {
                float weight = 0;
                half3 color = 0;

                for (int k = 0; k < kernelSampleCount; k++) {
                    float2 o = kernel[k];
                    // halve the 8 to be a 4 to be consistent with the half-sized texture
                    o *= _MainTex_TexelSize.xy * _BokehRadius;
                    color += tex2D(_MainTex, i.uv + o).rgb;
                }
                color *= 1.0 / kernelSampleCount;
                return fixed4(color, 1);
            }
            ENDCG
        }
        Pass{
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            half4 _MainTex_TexelSize;

            fixed4 frag(v2f i) : SV_Target
            {
                float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;
                half4 s =
                    tex2D(_MainTex, i.uv + o.xy) +
                    tex2D(_MainTex, i.uv + o.zy) +
                    tex2D(_MainTex, i.uv + o.xw) +
                    tex2D(_MainTex, i.uv + o.zw);
                return s * 0.25;
            }
            ENDCG
        }
    }
}
