Shader "Custom/Auroras"
{
    Properties
    {
        _iMouse ("_iMouse", Vector) = (0,0,0,0)
        //To Add Properties
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderQueue" = "Geometry"}

        Pass
        {
            Cull Back
            ZWrite On
            ZTest LEqual
            Blend Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma target 3.5

            #include "UnityCG.cginc"

            //////////////////////////////////////////////////////////////////////////

            //Vertex Shader Begin
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            //Vertex Shader End

            //////////////////////////////////////////////////////////////////////////
            
            uniform float4 _iMouse;

            static float4 gl_FragCoord;
            static float4 fragColor;

            struct SPIRV_Cross_Input
            {
                float4 gl_FragCoord : VPOS;
            };

            struct SPIRV_Cross_Output
            {
                float4 fragColor : COLOR0;
            };

            static float2x2 m2 = float2x2(0.0f.xx, 0.0f.xx);

            float2x2 mm2(float a)
            {
                float c = cos(a);
                float s = sin(a);
                return float2x2(float2(c, s), float2(-s, c));
            }

            float3 bg(float3 rd)
            {
                float sd = (dot(float3(-0.4195906817913055419921875f, -0.5035088062286376953125f, 0.75526320934295654296875f), rd) * 0.5f) + 0.5f;
                sd = pow(sd, 5.0f);
                float3 col = lerp(float3(0.0500000007450580596923828125f, 0.100000001490116119384765625f, 0.20000000298023223876953125f), float3(0.100000001490116119384765625f, 0.0500000007450580596923828125f, 0.20000000298023223876953125f), sd.xxx);
                return col * 0.62999999523162841796875f;
            }

            float hash21(float2 n)
            {
                return frac(sin(dot(n, float2(12.98980045318603515625f, 4.141399860382080078125f))) * 43758.546875f);
            }

            float tri(float x)
            {
                return clamp(abs(frac(x) - 0.5f), 0.00999999977648258209228515625f, 0.4900000095367431640625f);
            }

            float2 tri2(float2 p)
            {
                float param = p.x;
                float param_1 = p.y;
                float param_2 = p.x;
                float param_3 = p.y + tri(param_2);
                return float2(tri(param) + tri(param_1), tri(param_3));
            }

            float triNoise2d(inout float2 p, float spd)
            {
                float z = 1.7999999523162841796875f;
                float z2 = 2.5f;
                float rz = 0.0f;
                float param = p.x * 0.0599999986588954925537109375f;
                p = mul(mm2(param), p);
                float2 bp = p;
                for (float i = 0.0f; i < 5.0f; i += 1.0f)
                {
                    float2 param_1 = bp * 1.85000002384185791015625f;
                    float2 dg = tri2(param_1) * 0.75f;
                    float param_2 = _Time.y * spd;
                    dg = mul(mm2(param_2), dg);
                    p -= (dg / z2.xx);
                    bp *= 1.2999999523162841796875f;
                    z2 *= 0.449999988079071044921875f;
                    z *= 0.4199999868869781494140625f;
                    p *= (1.21000003814697265625f + ((rz - 1.0f) * 0.0199999995529651641845703125f));
                    float param_3 = p.y;
                    float param_4 = p.x + tri(param_3);
                    rz += (tri(param_4) * z);
                    p = mul(float2x2(-m2[0], -m2[1]), p);
                }
                return clamp(1.0f / pow(rz * 29.0f, 1.2999999523162841796875f), 0.0f, 0.550000011920928955078125f);
            }

            float4 aurora(float3 ro, float3 rd)
            {
                float4 col = 0.0f.xxxx;
                float4 avgCol = 0.0f.xxxx;
                for (float i = 0.0f; i < 50.0f; i += 1.0f)
                {
                    float2 param = gl_FragCoord.xy;
                    float of = (0.006000000052154064178466796875f * hash21(param)) * smoothstep(0.0f, 15.0f, i);
                    float pt = ((0.800000011920928955078125f + (pow(i, 1.39999997615814208984375f) * 0.00200000009499490261077880859375f)) - ro.y) / ((rd.y * 2.0f) + 0.4000000059604644775390625f);
                    pt -= of;
                    float3 bpos = ro + (rd * pt);
                    float2 p = bpos.zx;
                    float2 param_1 = p;
                    float param_2 = 0.0599999986588954925537109375f;
                    float _278 = triNoise2d(param_1, param_2);
                    float rzt = _278;
                    float4 col2 = float4(0.0f, 0.0f, 0.0f, rzt);
                    float3 _296 = ((sin(float3(-1.14999997615814208984375f, 1.5f, -0.20000000298023223876953125f) + (i * 0.0430000014603137969970703125f).xxx) * 0.5f) + 0.5f.xxx) * rzt;
                    col2.x = _296.x;
                    col2.y = _296.y;
                    col2.z = _296.z;
                    avgCol = lerp(avgCol, col2, 0.5f.xxxx);
                    col += ((avgCol * exp2(((-i) * 0.064999997615814208984375f) - 2.5f)) * smoothstep(0.0f, 5.0f, i));
                }
                col *= clamp((rd.y * 15.0f) + 0.4000000059604644775390625f, 0.0f, 1.0f);
                return col * 1.7999999523162841796875f;
            }

            float3 nmzHash33(float3 q)
            {
                uint3 p = uint3(int3(q));
                p = ((p * uint3(374761393u, 1103515245u, 668265263u)) + p.zxy) + p.yzx;
                p = p.yzx * (p.zxy ^ (p >> uint3(3u, 3u, 3u)));
                return float3(p ^ (p >> uint3(16u, 16u, 16u))) * 2.3283064365386962890625e-10f.xxx;
            }

            float3 stars(inout float3 p)
            {
                float3 c = 0.0f.xxx;
                float res = _ScreenParams.x * 1.0f;
                for (float i = 0.0f; i < 4.0f; i += 1.0f)
                {
                    float3 q = frac(p * (0.1500000059604644775390625f * res)) - 0.5f.xxx;
                    float3 id = floor(p * (0.1500000059604644775390625f * res));
                    float3 param = id;
                    float2 rn = nmzHash33(param).xy;
                    float c2 = 1.0f - smoothstep(0.0f, 0.60000002384185791015625f, length(q));
                    c2 *= step(rn.x, 0.0005000000237487256526947021484375f + ((i * i) * 0.001000000047497451305389404296875f));
                    c += (((lerp(float3(1.0f, 0.4900000095367431640625f, 0.100000001490116119384765625f), float3(0.75f, 0.89999997615814208984375f, 1.0f), rn.y.xxx) * 0.100000001490116119384765625f) + 0.89999997615814208984375f.xxx) * c2);
                    p *= 1.2999999523162841796875f;
                }
                return (c * c) * 0.800000011920928955078125f;
            }

            void frag_main()
            {
                m2 = float2x2(float2(0.95534002780914306640625f, 0.295520007610321044921875f), float2(-0.295520007610321044921875f, 0.95534002780914306640625f));
                float2 q = gl_FragCoord.xy / _ScreenParams.xy;
                float2 p = q - 0.5f.xx;
                p.x *= (_ScreenParams.x / _ScreenParams.y);
                float3 ro = float3(0.0f, 0.0f, -6.69999980926513671875f);
                float3 rd = normalize(float3(p, 1.2999999523162841796875f));
                float2 mo = (_iMouse.xy / _ScreenParams.xy) - 0.5f.xx;
                float2 _524 = 0.0f.xx;
                if (all(bool2(mo.x == (-0.5f).xx.x, mo.y == (-0.5f).xx.y)))
                {
                    mo = float2(-0.100000001490116119384765625f, 0.100000001490116119384765625f);
                    _524 = float2(-0.100000001490116119384765625f, 0.100000001490116119384765625f);
                }
                else
                {
                    _524 = mo;
                }
                mo = _524;
                mo.x *= (_ScreenParams.x / _ScreenParams.y);
                float param = mo.y;
                float3 _545 = rd;
                float2 _547 = mul(mm2(param), _545.yz);
                rd.y = _547.x;
                rd.z = _547.y;
                float param_1 = mo.x + (sin(_Time.y * 0.0500000007450580596923828125f) * 0.20000000298023223876953125f);
                float3 _561 = rd;
                float2 _563 = mul(mm2(param_1), _561.xz);
                rd.x = _563.x;
                rd.z = _563.y;
                float3 col = 0.0f.xxx;
                float3 brd = rd;
                float fade = (smoothstep(0.0f, 0.001f, abs(brd.y)) * 0.1f) + 0.1f;
                float3 param_2 = rd;
                col = bg(param_2) * fade;
                if (rd.y > 0.0f)
                {
                    float3 param_3 = ro;
                    float3 param_4 = rd;
                    float4 aur = smoothstep(0.0f.xxxx, 1.5f.xxxx, aurora(param_3, param_4)) * fade;
                    float3 param_5 = rd;
                    float3 _601 = stars(param_5);
                    col += _601;
                    col = (col * (1.0f - aur.w)) + aur.xyz;
                }
                else
                {
                    rd.y = abs(rd.y);
                    float3 param_6 = rd;
                    col = (bg(param_6) * fade) * 0.6f;
                    float3 param_7 = ro;
                    float3 param_8 = rd;
                    float4 aur_1 = smoothstep(0.0f.xxxx, 2.5f.xxxx, aurora(param_7, param_8));
                    float3 param_9 = rd;
                    float3 _634 = stars(param_9);
                    col += (_634 * 0.1f);
                    col = (col * (1.0f - aur_1.w)) + aur_1.xyz;
                    float3 pos = ro + (rd * ((0.5f - ro.y) / rd.y));
                    float2 param_10 = pos.xz * float2(0.5f, 0.7f);
                    float param_11 = 0.0f;
                    float _665 = triNoise2d(param_10, param_11);
                    float nz2 = _665;
                    col += lerp(float3(0.2,0.25,0.5)*0.00, float3(0.3,0.3,0.5)*0.7, (nz2 * 0.4f).xxx);
                }
                fragColor = float4(col, 1.0f);
            }

            SPIRV_Cross_Output frag(SPIRV_Cross_Input stage_input)
            {
                gl_FragCoord = stage_input.gl_FragCoord + float4(0.5f, 0.5f, 0.0f, 0.0f);
                frag_main();
                SPIRV_Cross_Output stage_output;
                stage_output.fragColor = float4(fragColor);
                return stage_output;
            }


            ENDCG
        }
    }
}