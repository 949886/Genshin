Shader "Luna/Toon"
{
    // Defines the properties that can be set in the Material inspector window.
    Properties
    {
        [Main(Surface, _, on)] _group1 ("Surface", float) = 1
        [Tex(Surface, _BaseColor)] _BaseMap ("Base Texture", 2D) = "white"{}
        [HideInInspector] [HDR] _BaseColor ("Base Color",Color) = (1,1,1,1)
        // [SubToggle(Surface, _NORMALMAP)] _BumpMapKeyword("Use Normal Map", Float) = 0.0
        // [Tex(Surface_NORMALMAP)] [Normal] _BumpMap ("Normal Map", 2D) = "bump" { }
        [Tex(Surface, _BumpMap)] [Normal] _BumpMap ("Normal Map", 2D) = "bump"{}
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry"
            "RenderType"="Opaque"
        }

        // Shared code block. Code in this block is shared between all passes in this subshader.
        HLSLINCLUDE
        // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
        CBUFFER_END
        ENDHLSL
    
        Pass
        {
            Tags{"LightMode"="UniversalForward"}

            // HLSL code block. Unity SRP uses HLSL as the shader language.
            HLSLPROGRAM 
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _NORMALMAP

            // Use Attributes struct as input to vertex shader.
            struct Attributes
            {
                float4 positionOS : POSITION; // positionOS contains vertex positions in object space.
                float2 uv : TEXCOORD;
                float3 normalOS : NORMAL;
                float4 tangentOS     : TANGENT;
            };

            // Varyings struct as output from vertex shader and input to fragment shader.
            struct Varyings
            {
                float4 positionHCS : SV_POSITION; // positionHCS contains vertex positions in homogenous clip space.
                float2 uv : TEXCOORD;
                float3 positionWS : TEXCOORD1;
                half3 viewDirWS : TEXCOORD2;
                half4 normalWS : TEXCOORD3;    // xyz: normal, w: viewDir.x
                half4 tangentWS : TEXCOORD4;    // xyz: tangent, w: viewDir.y
                half4 bitangentWS : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
            };

            // TEXTURE2D(_BaseMap);
            // TEXTURE2D(_BumpMap);
            // SAMPLER(sampler_BaseMap);

            //  The vertex shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS =  TransformViewToWorldNormal(IN.positionOS.xyz);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                // OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                OUT.normalWS = half4(normalInput.normalWS, OUT.viewDirWS.x);
                OUT.tangentWS = half4(normalInput.tangentWS, OUT.viewDirWS.y);
                OUT.bitangentWS = half4(normalInput.bitangentWS, OUT.viewDirWS.z);
                return OUT;
            }

            // The fragment shader.
            half4  frag(Varyings IN):SV_Target
            {   
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                // Sample normal map.
                half3 normalTS  = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap));
                // half3 normalTS = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv);
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));

                // Calculate lighting
                Light mainLight = GetMainLight();
                half3 diffuse = LightingLambert(mainLight.color, mainLight.direction, normalWS);

                // return SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv);
                return  _BaseColor * half4(diffuse, 1) ;
            }
            ENDHLSL      
        }
    }
    
    CustomEditor "LWGUI.LWGUI"
}