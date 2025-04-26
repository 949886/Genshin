Shader "Custom/NahidaSwingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _GlowTex ("Glow Texture", 2D) = "white" {}
        _SymbolTex ("Symbol Texture", 2D) = "white" {}
        
        [HDR] _Color ("Main Color", Color) = (0.5, 1.0, 0.5, 1.0)
        [HDR] _GlowColor ("Glow Color", Color) = (0.7, 1.0, 0.7, 1.0)
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 2.0
        
        _AlphaClip ("Alpha Clip", Range(0, 1)) = 0.1
        _Glossiness ("Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        
        _FlowSpeed ("Flow Speed", Range(0, 2)) = 0.5
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.2
        _NoiseScale ("Noise Scale", Range(0, 10)) = 2.0
        
        _GlowPulseSpeed ("Glow Pulse Speed", Range(0, 5)) = 1.0
        _GlowPulseMin ("Glow Pulse Min", Range(0, 1)) = 0.5
        _GlowPulseMax ("Glow Pulse Max", Range(0, 2)) = 1.2
        
        // Outline properties
        [HDR] _OutlineColor ("Outline Color", Color) = (0.8, 1.0, 0.8, 1.0)
        _OutlineWidth ("Outline Width", Range(0, 1)) = 0.005
        _OutlinePulseSpeed ("Outline Pulse Speed", Range(0, 5)) = 1.5
        _OutlinePulseMin ("Outline Pulse Min", Range(0, 1)) = 0.8
        _OutlinePulseMax ("Outline Pulse Max", Range(0, 2)) = 1.2
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        
        // Outline pass
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            Cull Front
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineWidth;
                float _OutlinePulseSpeed;
                float _OutlinePulseMin;
                float _OutlinePulseMax;
            CBUFFER_END
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                // Pulse the outline width
                float pulseEffect = lerp(_OutlinePulseMin, _OutlinePulseMax, 
                    (sin(_Time.y * _OutlinePulseSpeed) * 0.5 + 0.5));
                
                // Expand vertices along normals for outline
                float3 normalOS = normalize(input.normalOS);
                float3 posOS = input.positionOS.xyz + normalOS * (_OutlineWidth * pulseEffect);
                
                output.positionCS = TransformObjectToHClip(posOS);
                output.uv = input.uv;
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // Pulse the outline color slightly
                float pulseEffect = lerp(_OutlinePulseMin, _OutlinePulseMax, 
                    (sin(_Time.y * _OutlinePulseSpeed * 0.8) * 0.5 + 0.5));
                    
                half4 outlineColor = _OutlineColor * pulseEffect;
                
                // Fade outline at edges
                float fade = pow(abs(dot(normalize(input.positionCS.xyz), float3(0, 0, 1))), 0.5);
                outlineColor.a *= _OutlineColor.a; //* fade;
                
                return outlineColor;
            }
            ENDHLSL
        }
        
        // Main pass
        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 color : COLOR;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 color : COLOR;
                float fogFactor : TEXCOORD3;
            };
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_GlowTex);
            SAMPLER(sampler_GlowTex);
            TEXTURE2D(_SymbolTex);
            SAMPLER(sampler_SymbolTex);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _GlowTex_ST;
                float4 _SymbolTex_ST;
                float4 _Color;
                float4 _GlowColor;
                float _EmissionIntensity;
                float _AlphaClip;
                float _Glossiness;
                float _Metallic;
                float _FlowSpeed;
                float _NoiseStrength;
                float _NoiseScale;
                float _GlowPulseSpeed;
                float _GlowPulseMin;
                float _GlowPulseMax;
                // Outline variables are already declared in the outline pass
            CBUFFER_END
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                // Transform position and normal to world space
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = input.color;
                output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // Time-based animations
                float time = _Time.y;
                float flowOffset = time * _FlowSpeed;
                
                // Sample textures with flow effect
                float2 flowUV = input.uv + float2(sin(flowOffset * 0.5) * 0.05, cos(flowOffset * 0.4) * 0.05);
                float2 noiseUV = input.uv * _NoiseScale + float2(flowOffset * 0.2, flowOffset * 0.15);
                
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, flowUV);
                half4 noiseTex = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV);
                half4 glowTex = SAMPLE_TEXTURE2D(_GlowTex, sampler_GlowTex, flowUV);
                half4 symbolTex = SAMPLE_TEXTURE2D(_SymbolTex, sampler_SymbolTex, flowUV);
                
                // Pulse effect for glow
                float pulseEffect = lerp(_GlowPulseMin, _GlowPulseMax, (sin(time * _GlowPulseSpeed) * 0.5 + 0.5));
                
                // Apply noise distortion
                float noiseValue = (noiseTex.r * 2.0 - 1.0) * _NoiseStrength;
                
                // Base color with distortion
                half4 baseColor = mainTex * _Color;
                
                // Symbol overlay
                baseColor.rgb = lerp(baseColor.rgb, symbolTex.rgb * _GlowColor.rgb, symbolTex.a * 0.5);
                
                // Edge glow effect
                float edgeFactor = (glowTex.r + noiseValue) * pulseEffect;
                half3 glowEffect = _GlowColor.rgb * edgeFactor * _EmissionIntensity;
                
                // Final color with emission
                half4 finalColor = baseColor;
                finalColor.rgb += glowEffect;
                
                // Alpha blending
                finalColor.a = baseColor.a * _Color.a * (mainTex.a + glowTex.r * 0.5);
                
                // Apply alpha clip
                clip(finalColor.a - _AlphaClip);
                
                // Apply fog
                finalColor.rgb = MixFog(finalColor.rgb, input.fogFactor);
                
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
} 