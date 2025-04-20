// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

//#include "NiloInvLerpRemapUtil.hlsl" // TODO: not sure why we can't include this, we should be able to include this if #pragma once exist in that .hlsl file

// warning: using perspective removal may make CPU per renderer culling not perfect, since CPU won't know what is happening in GPU
float4 NiloDoPerspectiveRemoval(float4 originalPositionCS, float perspectiveRemovalAmount, float centerPosVSz)
{
    // resources:
    // - https://zhuanlan.zhihu.com/p/268433650?utm_source=ZHShareTargetIDMore
    // - https://zhuanlan.zhihu.com/p/332804613

    // resources link's demo method
    /*
    float originalPositionCSZ = output.positionCS.z;
    float4 perspectiveCorrectPosVS = mul(UNITY_MATRIX_I_P, output.positionCS);
    perspectiveCorrectPosVS.z -= centerPosVSz;
    perspectiveCorrectPosVS.z *= lerp(1,0.1,perspectiveCorrectUsage); // Flatten model's pos z in view space
    perspectiveCorrectPosVS.z += centerPosVSz;    
    output.positionCS = mul(UNITY_MATRIX_P, perspectiveCorrectPosVS);
    output.positionCS.z = originalPositionCSZ;
    */

    // our method
    float2 newPosCSxy = originalPositionCS.xy;
    newPosCSxy *= abs(originalPositionCS.w); // cancel Hardware w-divide
    newPosCSxy *= rcp(abs(centerPosVSz)); // do our flattened w-divide
    originalPositionCS.xy = lerp(originalPositionCS.xy, newPosCSxy, perspectiveRemovalAmount); // apply 0~100% perspective removal  

    return originalPositionCS;    
}

// this global float can be optionally controlled if user call to NiloToonPlanarReflectionHelper.cs
// originally added for supporting planar reflection (CalculateObliqueMatrix will make our perspective removal method fail)
float _GlobalShouldDisableNiloToonPerspectiveRemoval; // default 0 in GPU, so even no one assign this float, the code will still function correctly by default

// high level helper function
float4 NiloDoPerspectiveRemoval(float4 originalPositionCS, float3 positionWS, float3 removalCenterPositionWS, float removalRadius, float removalAmount, float removalStartHeight, float removalEndHeight)
{
    // only do perspective removal if is perspective camera
    // high level function contain global disable logic, to reduce code complexity of this .hlsl's user code
    if(_GlobalShouldDisableNiloToonPerspectiveRemoval || unity_OrthoParams.w == 1)
        return originalPositionCS;

    float perspectiveRemovalAreaSphere = saturate(removalRadius - distance(positionWS,removalCenterPositionWS) / removalRadius);
    float perspectiveRemovalAreaWorldHeight = saturate(invLerp(removalStartHeight, removalEndHeight, positionWS.y));
    float perspectiveRemovalFinalAmount = removalAmount * perspectiveRemovalAreaSphere * perspectiveRemovalAreaWorldHeight;
    float centerPosVSz = mul(UNITY_MATRIX_V, float4(removalCenterPositionWS,1)).z;

    return NiloDoPerspectiveRemoval(originalPositionCS, perspectiveRemovalFinalAmount, centerPosVSz);
}
