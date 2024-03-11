Shader "Hidden/PostProcess"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Strength ("Strength", Range(0, 0.1)) = 0.01
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

            float hashOld12(float2 p)
{
                // Two typical hashes...
	            return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            sampler2D _MainTex;

            fixed4 frag (v2f i) : SV_Target
            {
                float strength = 0.005;
                float hash1 = hashOld12(float2(_Time.y, 2.0));
                float hash2 = hashOld12(float2(hash1, _Time.y));
                float noise = hashOld12(i.uv * _Time.y);
                float fractionalArea = frac(i.uv.y * 3.0 - _Time.y * 1.50);
                float lines2 = frac(i.uv.y * 100.0);
                float lines = 1.0 - step(fractionalArea, 0.85) * 0.15;

                float2 random = float2(1.0, 1.0);
                float2 random2 = float2(0.0, 0.0);

                float2 uv = i.uv;

                if (hash2 > 0.94) {
                    strength = 0.2 * (hash2 - 1.0);
                }
                if (lines > 0.9) {
                    uv += float2(0.0025, 0.01 * noise) * (uv.x * 10.0 % 2.0 == 0 ? -1 : 1);
                    uv += float2((hashOld12(uv.y) - 0.50) * 0.01, 0.0);
                    uv += float2(0.002 + 0.001 * frac(i.uv.y), 0.0);
                    if(i.uv.y < 0.20) {
                        random *= float2(1.0, 0.2);
                    }
                }
                if (hash1 < 0.05) {
                    random *= float2(0.5, 0.01) - float2(0.2, 0.0);
                }
                if (hash2 < 0.01) {
                    random2 += float2(0.2, 0.21);
                }

                float r = tex2D(_MainTex, uv + strength * 1.20).x * 0.15;
                float g = tex2D(_MainTex, (uv) + random2 * float2(0.2, 0.0)).y;
                float b = tex2D(_MainTex, uv * random + strength * float2(0.2, 0.2)).z * 0.20;

                float4 noiseColor = float4(0.4, 0.4, 0.9, 0.0) * 1.40;

                noiseColor += float4(lines, lines, lines, 0.0) * 0.25 * frac(i.uv.x);
                noiseColor += lines2 * 0.1;

                float dist = length(i.uv - float2(0.4, 0.55));
                float vignette = 1.0 - dist;

                float4 sample = tex2D(_MainTex, i.uv);
                sample = lerp(sample, float4(noise, noise, noise, 1.0), 0.4 * dist) + float4(-0.01, 0.01, 0.05, 0.0);

                return sample * fixed4(0.60 + r, 0.50 * g + 0.10, b + 0.05,0.0) * noiseColor * vignette * 1.25 + fixed4(0,0,0.1,0);
            }
            ENDCG
        }
    }
}
