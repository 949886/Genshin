// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

Shader "Hidden/NiloToon/AverageShadowTestRT"
{
    HLSLINCLUDE

    // we need URP's shadow map related keywords
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

    // for most game type, 128 is a big enough number, but still not affect performance 
    #define MAX_CHARACTER_COUNT 128
    #define MAX_DATA_ARRAY_SIZE 512 // = 128 characters * 4 data slot
    #define TEST_COUNT 6 // usually 6 is smooth enough, it means (6+1+6)^3 = total of 2197 shadow tests for 1 character per frame

    float _GlobalAverageShadowTestBoundingSphereDataArray[MAX_DATA_ARRAY_SIZE];
    float _GlobalAverageShadowStrength;
    // to support URP7(2019.4), copy FullscreenVert() from URP10's Fullscreen.hlsl to here
    Varyings FullscreenVertexShader(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
// [TODO]
// #if _USE_DRAW_PROCEDURAL
//         output.positionCS = GetQuadVertexPosition(input.vertexID);
//         output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1
//         output.uv = GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw;
// #else
//         output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
//         output.uv = input.uv;
// #endif

        return output;
    }

    half Frag(Varyings input) : SV_Target
    {
        int index = floor(input.texcoord.x * MAX_CHARACTER_COUNT);
        float3 center;
        center.x =      _GlobalAverageShadowTestBoundingSphereDataArray[index*4+0];
        center.y =      _GlobalAverageShadowTestBoundingSphereDataArray[index*4+1];
        center.z =      _GlobalAverageShadowTestBoundingSphereDataArray[index*4+2];
        float radius =  _GlobalAverageShadowTestBoundingSphereDataArray[index*4+3];

        Light mainLight = GetMainLight();

        // to prevent generating shadow due to near by objects
        center += mainLight.direction;
        
        // this crazy forloop^3 looks extremely scary,
        // but it will run once per character only, so it will not affect performance at all
        float shadowTestSum = 0;
        for(int x = -TEST_COUNT ; x < TEST_COUNT ; x++)
        for(int y = -TEST_COUNT ; y < TEST_COUNT ; y++)
        for(int z = -TEST_COUNT ; z < TEST_COUNT ; z++)
        {
            float3 shadowTestPosWS = center + float3(x,y,z) / TEST_COUNT / 2.0 * radius;
            float shadowAttenuation = MainLightRealtimeShadow(TransformWorldToShadowCoord(shadowTestPosWS));
            shadowTestSum += shadowAttenuation;
        }
        float count1D = TEST_COUNT * 2 + 1;
        shadowTestSum /= float(count1D*count1D*count1D) * 0.5; // if more than 50% shadow test passed, treat it as no shadow

        return lerp(1,saturate(shadowTestSum),_GlobalAverageShadowStrength);
    }

    ENDHLSL

    SubShader
    {
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "RenderAverageShadowTestRT"

            HLSLPROGRAM
                #pragma vertex FullscreenVertexShader
                #pragma fragment Frag
            ENDHLSL
        }
    }
}