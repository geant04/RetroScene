Shader "Hidden/PostProcess"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Strength("Strength", Range(0, 0.1)) = 0.01
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

            float _DisableScanLines;
            float _DisableWarping;
            float _DisableNoise;
            float _DisableChromaDistortion;
            float _DisableVignetteSmudge;

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

            float2 random2(float2 p) {
                return frac(sin(float2(dot(p, float2(127.1, 311.7)),
                    dot(p, float2(269.5, 183.3))))
                    * 43758.5453);
            }


            float surflet(float2 P, float2 gridPoint) {
                // Compute falloff function by converting linear distance to a polynomial
                float distX = abs(P.x - gridPoint.x);
                float distY = abs(P.y - gridPoint.y);
                float tX = 1 - 6 * pow(distX, 5.f) + 15 * pow(distX, 4.f) - 10 * pow(distX, 3.f);
                float tY = 1 - 6 * pow(distY, 5.f) + 15 * pow(distY, 4.f) - 10 * pow(distY, 3.f);
                // Get the random vector for the grid point
                float2 gradient = 2.f * random2(gridPoint) - float2(1., 1.);
                // Get the vector from the grid point to P
                float2 diff = P - gridPoint;
                // Get the value of our height field by dotting grid->P with our gradient
                float height = dot(diff, gradient);
                // Scale our height field (i.e. reduce it) by our polynomial falloff function
                return height * tX * tY;
            }

            float perlinNoise(float2 uv) {
                float surfletSum = 0.f;
                // Iterate over the four integer corners surrounding uv
                for (int dx = 0; dx <= 1; ++dx) {
                    for (int dy = 0; dy <= 1; ++dy) {
                        surfletSum += surflet(uv, floor(uv) + float2(dx, dy));
                    }
                }
                return surfletSum;
            }

            sampler2D _MainTex;

            fixed4 frag (v2f i) : SV_Target
            {
                // https://www.shadertoy.com/view/WsVSzV
                float2 sampleUV = i.uv;
                float2 distToCent = abs(float2(0.5, 0.5) - sampleUV);
                distToCent *= distToCent;

                float factor = 1.0;
                float2 ratio = float2(1.5, 1.45) * factor;
                // prev at 1.5, 1.45, try to see how that works

                float warp = 0.5;
                sampleUV -= float2(0.5, 0.5);
                sampleUV *= float2(
                    ratio.x + (distToCent.y * (0.50 * warp)),
                    ratio.y + (distToCent.x * (0.60 * warp))
                        );
                sampleUV += float2(0.5, 0.5);

                // Toggle to enable or not
                sampleUV = _DisableWarping ? i.uv : sampleUV;

                float2 border = sampleUV;
                if (border.y > 1.0 || border.x < 0.0 || border.x > 1.0 || border.y < 0.0) {
                    return fixed4(0., 0., 0.0, 0);
                }

                // Scan lines
                float2 uv = sampleUV;

                float strength = 0.005;
                float hash1 = hashOld12(float2(_Time.y, 2.0));
                float hash2 = hashOld12(float2(hash1, _Time.y));
                float noise = hashOld12(uv * _Time.y);
                float fractionalArea = frac(uv.y * 3.0 - _Time.y * 1.50);
                float lines2 = frac(uv.y * 100.0);
                float lines = 1.0 - step(fractionalArea, 0.85) * 0.15;

                float2 random = float2(1.0, 1.0);
                float2 random2 = float2(0.0, 0.0);

                if (hash2 > 0.94) {
                    strength = 0.2 * (hash2 - 1.0);
                }
                if (lines > 0.9) {
                    uv += float2(0.0025, 0.01 * noise) * (uv.x * 10.0 % 2.0 == 0 ? -1 : 1);
                    uv += float2((hashOld12(uv.y) - 0.85) * 0.01, 0.0);
                    uv += float2(0.002 + 0.001 * frac(uv.y), 0.0);
                    if(uv.y < 0.20) {
                        random *= float2(1.0, 0.2);
                    }
                }

                uv = _DisableScanLines ? i.uv : uv;

                // Default for later so I don't have to repeat this
                float4 defaultColor = float4(1, 1, 1, 1);
                
                // Aberration
                float r = tex2D(_MainTex, uv + strength * 1.20).x * 0.15;
                float g = tex2D(_MainTex, (uv) + random2 * float2(0.2, 0.0)).y;
                float b = tex2D(_MainTex, uv * random + strength * float2(0.2, 0.2)).z * 0.20;
                float4 distortedRGB = _DisableChromaDistortion ? defaultColor : float4(0.50 + r, 0.50 * g + 0.10, b + 0.35, 0.0);

                // Noise
                float4 noiseColor = float4(.86, .86, .86, 0.0);
                noiseColor += float4(lines, lines, lines, 0.0) * 0.25 * frac(uv.x);
                noiseColor += lines2 * 0.1;
                noiseColor = _DisableNoise ? noiseColor = defaultColor : noiseColor;

                float vignetteIntensity = 30.0;
                float vignetteExtent = 0.12;

                float pnoise = perlinNoise(sampleUV * 25.0);
                vignetteExtent += pnoise * 0.4 * pnoise;
                vignetteIntensity += pnoise;

                float2 v_uv = sampleUV * (1.0 - float2(sampleUV.y, sampleUV.x));

                // Vignette + Smudge enable setting
                float vignette = _DisableVignetteSmudge ? 1.0 : v_uv.x * v_uv.y * 15.0;
                vignette = pow(vignette, vignetteExtent);

                float dist = length(uv - float2(0.4, 0.55));

                float4 sample = tex2D(_MainTex, uv);
                sample = _DisableNoise ? sample : lerp(sample, float4(noise, noise, noise, 1.0), 0.4 * dist) + float4(-0.01, 0.01, 0.05, 0.0);

                return sample * distortedRGB * noiseColor * vignette * 1.0 + !_DisableChromaDistortion * fixed4(0.1,0.2,0.1,0);
            }
            ENDCG
        }
    }
}
