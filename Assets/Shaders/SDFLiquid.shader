Shader "Custom/SDFLiquid"
{
    Properties
    {
        _BottleColor ("Bottle Color", Color) = (1,1,1,1)
        _Color ("Liquid Color", Color) = (1,1,1,1)
        _BubbleColor ("Bubble Color", Color) = (1,1,1,1)
        _BubbleAmbient ("Bubble Ambient", Color) = (1,1,1,1)
        _Cube ("Cubemap", CUBE)  = "" {}
        _Ambient ("Ambient", Color) = (1,1,1,1)
        _LightColor ("Light Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Level ("Level", Range(-1,1)) = 0.5
        _Intensity ("Intensity", Range(0,10)) = 0.0
        _Adhesion ("Adhesion", Range(0, 1)) = 0.85
        _FresnelSpecular ("Fresnel Specular", Range(0, 1)) = 1.00
        _kSpecular ("kSpecular", Range(0, 100)) = 1.00
        _kRim ("kRim", Range(0, 100)) = 1.00
        _Scale ("Scale", Range(0, 2)) = 0.2
        _Spread ("Spread", Range(0, 5)) = 1.5
        _Speed ("Speed", Range(0, 5)) = 1.0
        _Offset ("Offset", Range(-3, 3)) = 0.25
    }
    SubShader
    {
        Pass {

        Cull Off

        CGPROGRAM

        struct VertexData {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : TEXCOORD1;
            float3 worldPos : TEXCOORD2;
            float3 fillPosition : TEXCOORD3;
            float3 viewDir : COLOR;
            float4 cameraLocalPos : COLOR1;
        };

        #pragma vertex vp
        #pragma fragment fp
        #include "UnityCG.cginc"
        #include "Lighting.cginc"

        samplerCUBE _Cube;
        sampler2D _DepthTexture;

        float _Agitation, _WobbleX, _WobbleZ, _Adhesion, _Level, _Intensity, _FresnelSpecular, 
                _kSpecular, _kRim, _Spread, _Scale, _Speed, _Offset;
        int _NumBubbles;
        float4 _BottleColor, _Color, _Ambient, _LightColor, _BubbleColor, _BubbleAmbient;
        float4 _ObjectOrigin;

        float hash(float p) {
            return frac(sin(p * 127.1) * 43758.5453);
        }

        v2f vp(VertexData v) {
            v2f i;
            
            // idea1: ROTATE THE VERTICES BASED ON THE VELOCITY VALUE AND THEN USE A SINE WAVE TO FAKE THE MODULATION
            // idea1.5: do something different troll
            // idea2: Do all the work in the fragment shader s.t we cut off the draw call if your fragment y level is beyond the threshold, or the threshold is below your fragment y level
            // this way, we odn't have to worry about the cases of the liquid warping over where it's supposed to?

            i.vertex = UnityObjectToClipPos(float3(v.vertex.x, v.vertex.y, v.vertex.z));
            i.uv = v.uv;
            i.normal = v.normal;

            i.fillPosition = float3(v.vertex.x, v.vertex.y, v.vertex.z);
            i.worldPos = mul(unity_ObjectToWorld, v.vertex);
            i.viewDir = WorldSpaceViewDir(v.vertex);
            i.cameraLocalPos = mul(unity_ObjectToWorld, float4(_WorldSpaceCameraPos, 1.0));

            return i;
        }

        // the goat inigo quilez
        float smoothUnion(float a, float b, float k) {
            float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
            return lerp(b, a, h)- k * h  * (1.0 - h);
        }

        float SDFSphere(float3 p, float3 origin, float r) {
            return length(p - origin) - r;
        }

        float SDFPlane(float3 p, float4 normal) {
            return dot(p, normal.xyz) + normal.w;
        }

        float GetDist(float3 p, float x) {
            p -= _ObjectOrigin;

            float moveScale1 = 0.3 * sin(_Time.y * 0.9);
            float moveScale2 = 0.5 * sin(_Time.y * 1.0);

            float h_Offset = -1.0;

            float4 n = float4(0.0, -1.0, 0.0, _Level - x + 0.12);
            float plane = SDFPlane(p, n);
            float spheres = plane;

            int nBubs = floor(_NumBubbles) + 0.0;

            for(int i = 0; i < 20; i++) {
                float h = float(i) / 6;

                float seed = hash(i);
                float seed2 = hash(seed);
                float ultseed = hash(seed2) / 2.0 - 0.25;

                float xmoveScale = (4.0 * _WobbleX + 0.06) * sin(_Time.y * (_Speed * 2.0) + seed * 20.0);
                float zmoveScale = (4.0 * _WobbleZ + 0.06) * sin(_Time.y * (_Speed * 2.0) + seed2 * 20.0);

                float bposX = (seed / 1.5 + xmoveScale) - 0.5;
                float bposZ = (seed2 / 1.5 + zmoveScale) - 0.5;

                float ymovescale = frac(_Time.y * _Speed + seed) + i / 40.0;

                float3 bubble_pos = float3(bposX / 3.0 + ultseed,
                                           h_Offset  + ymovescale - ( (ultseed) / 4.0), 
                                           bposZ / 3.0 + ultseed);

                bubble_pos.x += seed / _Spread - (_Offset);
                bubble_pos.z += seed2 / _Spread - (_Offset);

                float sphere = SDFSphere(p, bubble_pos, _Scale * (ymovescale * (seed + 1.0)) / 5.0 );
                spheres = smoothUnion(spheres, sphere, 0.2);
                spheres = smoothUnion(plane, spheres, 0.3);
            }

            return spheres;
        }

        float3 GetNormal(float3 p, float x) {
            float d = GetDist(p, x);
            float e = 0.1;
            float3 n = d - float3(
                GetDist(p - float3(e, 0.0, 0.0), x),
                GetDist(p - float3(0.0, e, 0.0), x),
                GetDist(p - float3(0.0, 0.0, e), x)
            );
            return normalize(n);
        }

        float RayMarch(float3 ro, float3 rd, float x) {
            int MAX_STEPS = 100;
            float SURF_DIST = 0.0;
            float d = 0.0;
            for (int i = 0; i < MAX_STEPS; i++) {
                float3 p = ro + rd*d;
                float ds = GetDist(p, x);
                d += ds;
                if (d > 100.0 || ds < SURF_DIST) break;
            }
            return d;
        }

        float4 fp(v2f i, fixed facing : VFACE) : SV_TARGET{
            float2 uv = i.uv;
            float3 normal = i.normal;

            float depth = SAMPLE_DEPTH_TEXTURE(_DepthTexture, uv);
            depth = Linear01Depth(depth);
            float viewDistance = depth * _ProjectionParams.z;

            float xNegFactor = i.fillPosition.x < 0.0 ? -1 : 1;
            float zNegFactor = i.fillPosition.z < 0.0 ? -1 : 1;

            float displacementX = (i.fillPosition.x + (pow(i.fillPosition.x * _Adhesion, 2)) * xNegFactor) * _WobbleX * _Intensity;
            displacementX = displacementX * sin(_Time.y * 10.0) * _WobbleX;
            displacementX -= (pow(i.fillPosition.x * _Adhesion, 2));

            float displacementZ = (i.fillPosition.z + (pow(i.fillPosition.z * _Adhesion, 2)) * zNegFactor) * _WobbleZ * _Intensity;
            displacementZ = displacementZ * sin(_Time.y * 10.0) * _WobbleZ;
            displacementZ -= (pow(i.fillPosition.z * _Adhesion, 2));

            float totalDisplacement = displacementX + displacementZ;

            float totalWobble = abs(_WobbleX) + abs(_WobbleZ);
            totalDisplacement += totalWobble * 0.10 * sin((i.fillPosition.x * _WobbleX) + (i.fillPosition.z * _WobbleZ) + (_Time.y * 12.5));
            
            float3 n = float3(0.0, 1.0, 0.0);
            float x = dot(i.worldPos - _ObjectOrigin.xyz, n) + (-_Level + totalDisplacement);

            float diffuse = (dot(i.normal, normalize(i.viewDir)));
            // refractive index of air and water
            float n1 = 1.00293;
            float n2 = 1.333;

            float angle = n1 / n2;
            float cosI = diffuse;
            float sin2i = max(0.0, 1.0 - cosI * cosI);
            float sin2t = angle * angle * sin2i;

            float4 refractColor = float4(0.0, 0.0, 0.0, 0.0);
            
            if(sin2t < 1) {
                float cost = sqrt(1 - sin2t);
                float3 outVector = angle * -normalize(i.viewDir) + (angle * sin2i - sin2t) * i.normal;
                refractColor = texCUBE(_Cube, outVector);
            }

            float4 viewIndependent = (diffuse + _Ambient + _BottleColor) * _Color;

            float refDot = max(dot(i.normal, normalize(i.viewDir)), 0.0);
            float fr = (1 - pow(refDot, 1));
            float fs = _FresnelSpecular;

            float3 reflectionNormal = i.normal * fs;
            float3 reflect = -i.viewDir + 2 * (dot(i.viewDir, reflectionNormal)) * reflectionNormal;
            float3 cubeMapColor = texCUBE(_Cube, reflect).rgb;

            float finalF = fr * pow(refDot, _kRim);
            float finalSpc = fs * pow(refDot, _kSpecular);

            float3 fresnelColor = cubeMapColor * max(finalSpc, finalF);
            float4 fresnel = float4(fresnelColor.x, fresnelColor.y, fresnelColor.z, 1.0);

            float4 viewDependent = lerp(fresnel, refractColor, finalF);

            float4 liquidColor = viewIndependent + viewDependent;
            float4 bubbleColor = float4(1.0, 1.0, 1.0, 0.0);
            float4 finalColor = liquidColor * _LightColor0;
            
            if(x >= 0.0) {
                discard;
            }

            // ro = ray origin
            // rd = ray direction
            float3 ro = i.worldPos;
            float3 rd = normalize(i.worldPos - _WorldSpaceCameraPos);

            ro += rd * totalDisplacement;
            ro += rd * 0.4;

            float d = RayMarch(ro, rd, totalDisplacement);
            
            if(d < min(100.0, viewDistance + 0.02)) {
                float3 normal = GetNormal(ro + rd * d, totalDisplacement);
                
                diffuse = (dot(normal, normalize(i.viewDir)))  * 0.5 + 0.5;
                viewIndependent = (diffuse + _BubbleAmbient) * _BubbleColor;

                cosI = diffuse;
                sin2i = max(0.0, 1.0 - cosI * cosI);
                sin2t = angle * angle * sin2i;

                refractColor = float4(0.0, 0.0, 0.0, 0.0);
            
                if(sin2t < 1) {
                    float cost = sqrt(1 - sin2t);
                    float3 outVector = angle * -normalize(i.viewDir) + (angle * sin2i - sin2t) * i.normal;
                    refractColor = texCUBE(_Cube, outVector);
                }

                refDot = max(dot(normal, normalize(i.viewDir)), 0.0);
                fr = (1 - pow(refDot, 1));

                float3 reflect = -i.viewDir + 2 * (dot(i.viewDir, normal)) * normal;
                float3 bubblec = texCUBE(_Cube, reflect).rgb;
                float3 fresnelColor = bubblec * fr * pow(refDot, _kRim);
                float4 fresnel = float4(fresnelColor.x, fresnelColor.y, fresnelColor.z, 1.0);
                
                fresnel = lerp(fresnel, refractColor, finalF);

                bubbleColor = fresnel + viewIndependent;
                finalColor = bubbleColor * liquidColor;

                return facing > 0 ? finalColor * 1.50 : _BottleColor * _Color * 0.7;
            } else {
                discard;
            }

            return 0;
        }

        ENDCG
        }
    }
    FallBack "Diffuse"
}
