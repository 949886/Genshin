// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// [Screen Space Outline]
// very similar to depth texture rim light & shadow's logic, 
// see "_CameraDepthTexture depth" vs "self depth" difference 2D rim light and 2D shadow in NiloToonCharacter_LightingEquation.hlsl
// but here we ignore light direction, used for outline (brute force 4 directional sample)
// TODO: result is not consistance when screen resolution / renderscale is changing, or when camera distance is changing
float IsScreenSpaceOutline(float2 SV_POSITIONxy, float OutlineThickness, float DepthSensitivity, float NormalsSensitivity, float selfLinearEyeDepth, float depthSensitivityDistanceFadeoutStrength, float cameraFOV)
{
    // CameraNormalTexture only exist in URP10 or above
#if SHADER_LIBRARY_VERSION_MAJOR >= 10
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // We start from a screen space outline method by "alexander ameye", and develop base on it
    // *Code: https://gist.github.com/alexanderameye/d956574a67adf885f4e008d68b1c3238
    // *Tutorial: https://alexanderameye.github.io/notes/edge-detection-outlines/
    //
    // currently this method is using both depth and normals texture's screen space difference
    // TODO: add color's delta
    // TODO: add user defined color RT's difference (blue protocal material ID difference as outline method)?
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    float2 texelSize = _CameraDepthTexture_TexelSize.xy; // (x = 1/texture width, y = 1/texture height)
    float2 UV = SV_POSITIONxy * texelSize.xy; // UV is screen space [0,1] uv

    // far away pixels auto reduce depth sensitivity in shader, to avoid far object always = outline
    DepthSensitivity /= (1 + selfLinearEyeDepth * depthSensitivityDistanceFadeoutStrength * cameraFOV * 0.01); // 0.01 is a magic number that prevent most of the outline artifact

    // make screen space outline result not affected by render scale / game resolution
    OutlineThickness *= _CameraDepthTexture_TexelSize.w / 1080; // TODO: currently hardcode using height only, make it better for all aspect

    float halfScaleFloor = floor(OutlineThickness * 0.5);
    float halfScaleCeil = ceil(OutlineThickness * 0.5);
    
    float2 uvSamples[4];
    float depthSamples[4];
    float3 normalSamples[4];

    uvSamples[0] = UV - float2(texelSize.x, texelSize.y) * halfScaleFloor;
    uvSamples[1] = UV + float2(texelSize.x, texelSize.y) * halfScaleCeil;
    uvSamples[2] = UV + float2(texelSize.x * halfScaleCeil, -texelSize.y * halfScaleFloor);
    uvSamples[3] = UV + float2(-texelSize.x * halfScaleFloor, texelSize.y * halfScaleCeil);

    for(int i = 0; i < 4 ; i++)
    {
        depthSamples[i] = SampleSceneDepth(uvSamples[i]);
        normalSamples[i] = SampleSceneNormals(uvSamples[i]);
    }

    // Depth
    float depthFiniteDifference0 = depthSamples[1] - depthSamples[0];
    float depthFiniteDifference1 = depthSamples[3] - depthSamples[2];
    float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
    float depthThreshold = (1/DepthSensitivity) * depthSamples[0];
    edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

    // Normals
    float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
    float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
    float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
    edgeNormal = edgeNormal > (1/NormalsSensitivity) ? 1 : 0;

    float edge = max(edgeDepth, edgeNormal);
    return edge;
#else
    return 1;
#endif
}

// old method (unused)
/*
{
    float halfScaleFloor = (outlineWidth * 0.3);
    float halfScaleCeil = (outlineWidth * 0.3);

    // for perspective camera, reduce width when camera move away, but clamp at max = 1 using 1/(1+x) if camera is very close to vertex
    // for orthographic camera, disable camera distance fix(only return a constant 0.7 to match perspective's result) since distance/depth will not affect polygon NDC xy position on screen
    float cameraDistanceFix = unity_OrthoParams.w ? 0.7 : rcp(selfLinearEyeDepth+1); // no need to care orthographicCameraAmount, this line is already correct
    // allow width per material and global edit
    // group all float1 to calculate first for better performance
    float2 UvOffsetMultiplier = _GlobalAspectFix * _GlobalFOVorOrthoSizeFix * cameraDistanceFix; // TODO: volume global outline width control multiply

    // _Texture_TexelSize.xyzw is {1/width,1/height,width,height}
    // https://forum.unity.com/threads/_maintex_texelsize-whats-the-meaning.110278/#post-1579985
    float2 loadPosOffsetMultiplier = UvOffsetMultiplier * _CameraDepthTexture_TexelSize.zw;
    int2 bottomLeftLoadPos   = SV_POSITIONxy + float2(+halfScaleFloor, +halfScaleFloor) * loadPosOffsetMultiplier; 
    int2 topRightLoadPos     = SV_POSITIONxy + float2(+halfScaleCeil , +halfScaleCeil ) * loadPosOffsetMultiplier;
    int2 bottomRightLoadPos  = SV_POSITIONxy + float2(+halfScaleCeil , -halfScaleFloor) * loadPosOffsetMultiplier;
    int2 topLeftLoadPos      = SV_POSITIONxy + float2(-halfScaleFloor, +halfScaleCeil ) * loadPosOffsetMultiplier;

    // clamp loadTexPos to prevent loading outside of _CameraDepthTexture's valid area
    int2 maxAllowedIndex = _CameraDepthTexture_TexelSize.zw-1;
    bottomLeftLoadPos = min(bottomLeftLoadPos,maxAllowedIndex);
    topRightLoadPos = min(topRightLoadPos,maxAllowedIndex);
    bottomRightLoadPos = min(bottomRightLoadPos,maxAllowedIndex);
    topLeftLoadPos = min(topLeftLoadPos,maxAllowedIndex);

    float depth0 = LOAD_TEXTURE2D(_CameraDepthTexture, bottomLeftLoadPos).r;
    float depth1 = LOAD_TEXTURE2D(_CameraDepthTexture, topRightLoadPos).r;
    float depth2 = LOAD_TEXTURE2D(_CameraDepthTexture, bottomRightLoadPos).r;
    float depth3 = LOAD_TEXTURE2D(_CameraDepthTexture, topLeftLoadPos).r;

    depth0 = Convert_SV_PositionZ_ToLinearViewSpaceDepth(depth0);
    depth1 = Convert_SV_PositionZ_ToLinearViewSpaceDepth(depth1);
    depth2 = Convert_SV_PositionZ_ToLinearViewSpaceDepth(depth2);
    depth3 = Convert_SV_PositionZ_ToLinearViewSpaceDepth(depth3);

    float depthDerivative0 = depth1 - depth0;
    float depthDerivative1 = depth3 - depth2;

    float edgeDepth = sqrt(depthDerivative0*depthDerivative0 + depthDerivative1*depthDerivative1) * 10;
    edgeDepth = edgeDepth > (selfLinearEyeDepth * depthThreshold) ? 1 : 0; // TODO: convert to smooth fade out?

    return edgeDepth;
}
*/

