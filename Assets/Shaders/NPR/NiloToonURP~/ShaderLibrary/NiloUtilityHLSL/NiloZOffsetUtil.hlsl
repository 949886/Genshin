// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// Push an imaginary vertex from original position towards camera in view space (linear, view space unit),
// complete imaginary vertex's view space to clip space transformation, 
// then only overwrite original positionCS.z using imaginary vertex's w division corrected result positionCS.z value.
// Will only affect ZTest ZWrite's depth value when doing rasterization

// Useful for:
// -Hide ugly outline on face/eye/hair
// -Make eyebrow/eye render on top of hair
// -Solve ZFighting issue without moving geometry

// note:
// Why not just positionCS.z += _ConstantOffset?
// because depth buffer is non-linear if perspective camera, doing this will make ZOffset not stable across all camera near/far settings or vertex to camera distance.
// This function use view space unit ZOffset which is stable across all camera near/far settings or camera distance.

// This method will work in DirectX, Vulkan and OpenGL/OpenGLES, 
// because it is doing full projection matrix mul completely without knowing the projection matrix z-row.zw value

// In Unity, view space look into -Z direction, so
// positive viewSpaceZOffsetAmount means bring vertex depth closer to camera
// negative viewSpaceZOffsetAmount means push vertex depth away from camera
// *if you just want to use this function, you don't have to understand the math inside in order to use it
float4 NiloGetNewClipPosWithZOffsetVSPerspectiveCamera(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    // push imaginary vertex in view space
    // use max(near+eps,x) to prevent push over camera's near plane
    float float_Eps = 5.960464478e-8;  // 2^-24, machine epsilon: 1 + EPS = 1 (half of the ULP for 1.0f)
    // _ProjectionParams.y is the camera’s near plane
    float modifiedPositionVS_Z = -max(_ProjectionParams.y + float_Eps, abs(originalPositionCS.w) - viewSpaceZOffsetAmount); 
  
    // we only care mul(UNITY_MATRIX_P, modifiedPositionVS).z, and
    // UNITY_MATRIX_P's Z row's xy is always 0, and
    // positionVS's w is always 1
    // so this is the only math that remains after removing all the useless math that won't affect calculating mul(UNITY_MATRIX_P, modifiedPositionVS).z
    float modifiedPositionCS_Z = modifiedPositionVS_Z * UNITY_MATRIX_P[2].z + UNITY_MATRIX_P[2].w;

    // when this function received an originalPositionCS.xyzw and we want to apply viewspace ZOffset,
    // we can't edit it's xy because it will affect vertex position on screen
    // we can't edit it's w because positionCS.w will be used by w division later in hardware, which also affect ndc's xy vertex position
    // so we can only edit originalPositionCS.z

    // But in order to do a correct view space ZOffset, we need to edit both originalPositionCS's zw
    // So we first "cancel" the hardware w division by * original CLIPw to our new modified CLIPz first
    // then we do the correct w division manually in vertex shader to simulate hardware's w division
    // original NDCz = original CLIPz / original CLIPw

    // [here are the steps to find out the correct positionCS.z to output]
    // our desired NDCz = modified CLIPz / modified CLIPw
    // our desired NDCz = modified CLIPz / modified CLIPw * original CLIPw / original CLIPw
    // our desired NDCz = modified CLIPz * original CLIPw / modified CLIPw / original CLIPw
    // our desired NDCz = (modified CLIPz * original CLIPw / modified CLIPw) / (original CLIPw)
    // our desired NDCz = (modified CLIPz * original CLIPw / -modified VIEWz) / (original CLIPw)
    // so (modified CLIPz * original CLIPw / -modified VIEWz) is our output positionCS.z
    originalPositionCS.z = modifiedPositionCS_Z * originalPositionCS.w / (-modifiedPositionVS_Z); // overwrite positionCS.z

    return originalPositionCS;    
}
float4 NiloGetNewClipPosWithZOffsetVSOrthographicCamera(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    // since depth buffer is linear when using Orthographic camera
    // just push imaginary vertex linearly and overwrite originalPositionCS.z
    float zoffsetCS = viewSpaceZOffsetAmount / (_ProjectionParams.z-_ProjectionParams.y); // if near plane is really small, use * _ProjectionParams.w ?
    zoffsetCS *= (UNITY_NEAR_CLIP_VALUE > 0 ? 1 : -2); // DirectX ndcZ is [1,0], OpenGL ndcZ is [-1,1]
    originalPositionCS.z = originalPositionCS.z + zoffsetCS;
    return originalPositionCS;
}

// this global float can be optionally controlled if user call to NiloToonPlanarReflectionHelper.cs
// originally added for supporting planar reflection (CalculateObliqueMatrix will make our ZOffset method fail)
float _GlobalShouldDisableNiloToonZOffset; // default 0 in GPU, so even no one assign this float, the code will still function correctly by default

// support both Orthographic and Perspective camera projection, 
// always slower than above functions but easier for user if they need to support both cameras
float4 NiloGetNewClipPosWithZOffsetVS(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    // high level function contain global disable logic, to reduce code complexity of this .hlsl's user code
    if(_GlobalShouldDisableNiloToonZOffset)
        return originalPositionCS;

    // since instruction count is not high and it is pure ALU, maybe not worth a static uniform branching here, 
    // so we use a?b:c (movc: conditional move) here
    return unity_OrthoParams.w ? 
    NiloGetNewClipPosWithZOffsetVSOrthographicCamera(originalPositionCS,viewSpaceZOffsetAmount) :
    NiloGetNewClipPosWithZOffsetVSPerspectiveCamera(originalPositionCS,viewSpaceZOffsetAmount);
}

