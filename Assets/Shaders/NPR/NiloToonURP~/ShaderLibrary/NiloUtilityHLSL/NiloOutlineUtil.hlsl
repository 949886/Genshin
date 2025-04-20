// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

float ApplyOutlineFadeOutPerspectiveCamera(float inputMulFix, float cameraFov)
{
    // make outline "fadeout" if character is too small/far in camera's view
    // imagine this line is the most simple way to do tone mapping that clamp at 60/cameraFov,
    // but here we are not mapping HDR color, we are mapping outline width
    return min(60/cameraFov, inputMulFix); // keep it similar to min(2,inputMulFix) in fov 30 camera
}
float ApplyOutlineFadeOutOrthoCamera(float inputMulFix)
{
    // make outline "fadeout" if character is too small/far in camera's view
    // imagine this line is the most simple way to do tone mapping that clamp at 2,
    // but here we are not mapping HDR color, we are mapping outline width
    return min(2,inputMulFix);
}
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z, float cameraFOV)
{
    float outlineWidthMulFix;
    if(unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        // Perspective camera case
        ////////////////////////////////

        // keep outline similar width on screen across all camera distance       
        outlineWidthMulFix = abs(positionVS_Z);

        // can replace to a better tonemapping function if a smooth stop is needed
        outlineWidthMulFix = ApplyOutlineFadeOutPerspectiveCamera(outlineWidthMulFix,cameraFOV);

        // keep outline similar width on screen accoss all camera fov
        outlineWidthMulFix *= cameraFOV;       
    }
    else
    {
        ////////////////////////////////
        // Orthographic camera case
        ////////////////////////////////

        // no need to care camera distance nor fov, because orthographic camera don't need to consider them
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineFadeOutOrthoCamera(orthoSize);
        outlineWidthMulFix = orthoSize * 50; // 100/2 is a magic number to match perspective camera's outline width
    }

    return outlineWidthMulFix * 0.00005; // mul a const to make return result = default normal expand amount WS
}
// If your project has a faster way to get camera fov in shader, you don't need to use this method.
// For example, you write cmd.SetGlobalFloat("_CurrentCameraFOV",cameraFOV) using a new RendererFeature in C# 
// (NiloToonURP's renderer feature did that already by providing _CurrentCameraFOV).
float GetCameraFOV()
{
    // https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
    float t = unity_CameraProjection._m11;
    float Rad2Deg = 180 / 3.1415;
    float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
    return fov;
}
// slower due to GetCameraFOV(), but don't need to provide cameraFOV
float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
{
    return GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z,GetCameraFOV());
}

