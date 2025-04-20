// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// VertExmotion
#if NILOTOON_SUPPORT_VERTEXMOTION
#define VERTEXMOTION_ASE_HD_LW_RP
#include "Assets/VertExmotion/Shaders/VertExmotion.cginc"
void VertExmotion_float( float3 Position, float4 VertexColor, out float3 Vertexoffset)
{
    float w = 0;
    Vertexoffset = VertExmotionBase(float4(Position, 1), VertexColor,w).xyz;
}
#endif

void ApplyExternalAssetSupportLogicToVertexAttributeAtVertexShaderStart(inout Attributes attrubute)
{
    // VertExmotion
#if NILOTOON_SUPPORT_VERTEXMOTION
    float3 afterVertExmotionPositionWS;

    float3 originalPositionWS = TransformObjectToWorld(attrubute.positionOS.xyz);
    VertExmotion_float(originalPositionWS, attrubute.color, afterVertExmotionPositionWS);

    #if NiloToonIsAnyOutlinePass
        float difference = distance(originalPositionWS, afterVertExmotionPositionWS);

        // hide outline if position offset/difference is big, since the bigger the difference, the bigger chance of ugly/wrong outline will appear
        afterVertExmotionPositionWS += normalize(afterVertExmotionPositionWS - GetCameraPositionWS()) * difference * 0.66; // 0.5~0.66 is a number that is good enough but not too much
    #endif

    attrubute.positionOS.xyz = TransformWorldToObject(afterVertExmotionPositionWS.xyz);
#endif
}

void ApplyExternalAssetSupportLogicToBaseColor(inout half4 baseColor)
{
    // currently no asset support need to use this function
}

void ApplyExternalAssetSupportLogicBeforeFog(inout half3 color, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
}

void ApplyExternalAssetSupportLogicAfterFog(inout half3 color, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
}
