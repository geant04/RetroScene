Shader "Hidden/BoxBlurMultipass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _KernelSize("Kernel Size", Int) = 6
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

            sampler2D _MainTex;

            float2 _MainTex_TexelSize;
            int _KernelSize;

            fixed4 frag (v2f i) : SV_Target
            {
                //_KernelSize = 6;
                fixed3 sum = fixed3(0.0, 0.0, 0.0);

                int upper = ((_KernelSize - 1) / 2);
                int lower = -upper;

                for (int x = lower; x <= upper; ++x)  {
                    for (int y = lower; y <= upper; ++y)  {
                        fixed2 offset = fixed2(_MainTex_TexelSize.x * x, _MainTex_TexelSize.y * y);
                        sum += tex2D(_MainTex, i.uv + offset);
                    }
                }

                sum /= (_KernelSize * _KernelSize);

                return fixed4(sum, 1.0);
            }
            ENDCG
        }
    }
}
