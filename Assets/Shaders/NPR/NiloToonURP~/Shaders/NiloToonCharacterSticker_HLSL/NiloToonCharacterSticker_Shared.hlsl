// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// include a few small utility .hlsl files to help us
#include "/../ShaderLibrary/NiloUtilityHLSL/NiloAllUtilIncludes.hlsl"       

sampler2D _BaseMap;
sampler2D _OverrideAlphaMap;

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 uv           : TEXCOORD0;

    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_VERTEX_INPUT_INSTANCE_ID  // in non OpenGL / non PSSL, will turn into -> uint instanceID : SV_InstanceID;
    //------------------------------------------------------------------------------------------------------------------------------                   
};

struct Varyings
{
    float4 positionHCS  : SV_POSITION;
    float2 uv           : TEXCOORD0;
    half fogFactor      : TEXCOORD1;

    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_VERTEX_INPUT_INSTANCE_ID  // will turn into this in non OpenGL / non PSSL -> uint instanceID : SV_InstanceID;
    UNITY_VERTEX_OUTPUT_STEREO      // will turn into this in non OpenGL / non PSSL -> uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
    //------------------------------------------------------------------------------------------------------------------------------
};

CBUFFER_START(UnityPerMaterial)
    float4  _BaseMap_ST;
	half4   _BaseColor;

    // perspective removal
    float   _PerspectiveRemovalAmount; // total amount
    // perspective removal(sphere)
    float   _PerspectiveRemovalRadius;
    float3  _HeadBonePositionWS;
    // perspective removal(world height)
    float   _PerspectiveRemovalStartHeight; // usually is world space pos.y 0
    float   _PerspectiveRemovalEndHeight;
    
	float   _DitherOpacity;  
	float   _ZOffset;

	half    _FadeoutByBaseMapAlpha;
CBUFFER_END     

Varyings vert(Attributes IN)
{
    Varyings OUT;

    // disable rendering sticker if minimum shader debug is on
#if _NILOTOON_FORCE_MINIMUM_SHADER
    return (Varyings)0;
#endif
    
    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_SETUP_INSTANCE_ID(IN);                 // will turn into this in non OpenGL / non PSSL -> UnitySetupInstanceID(input.instanceID);
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT);      // will turn into this in non OpenGL / non PSSL -> output.instanceID = input.instanceID;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);  // will turn into this in non OpenGL / non PSSL -> output.stereoTargetEyeIndexAsRTArrayIdx = unity_StereoEyeIndex;
    //------------------------------------------------------------------------------------------------------------------------------

    OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

    // fog, do it before any positionHCS.z's edit
    OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);

    // zoffset
    OUT.positionHCS = NiloGetNewClipPosWithZOffsetVS(OUT.positionHCS, -_ZOffset);

    // perspective removal
    float3 positionWS = mul(UNITY_MATRIX_M, float4(IN.positionOS.xyz,1)).xyz;
    OUT.positionHCS = NiloDoPerspectiveRemoval(OUT.positionHCS,positionWS,_HeadBonePositionWS,_PerspectiveRemovalRadius,_PerspectiveRemovalAmount, _PerspectiveRemovalStartHeight, _PerspectiveRemovalEndHeight);

    OUT.uv = TRANSFORM_TEX(IN.uv,_BaseMap);

    return OUT;
}

half FogAsAlpha(real fogFactor)
{
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        return ComputeFogIntensity(fogFactor);
    #else
        return 1; // if fog is off, return constant 1 so it will not affect any multiplication (compiler will remove * 1)
    #endif
}

half4 frag(Varyings IN) : SV_Target
{
    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_SETUP_INSTANCE_ID(IN);                     // in non OpenGL / non PSSL, MACRO will turn into -> UnitySetupInstanceID(input.instanceID);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);    // in non OpenGL / non PSSL, MACRO will turn into -> unity_StereoEyeIndex = input.stereoTargetEyeIndexAsRTArrayIdx;
    //------------------------------------------------------------------------------------------------------------------------------
    
    // dither
#if _NILOTOON_DITHER_FADEOUT
    NiloDoDitherFadeoutClip(IN.positionHCS.xy, _DitherOpacity);
#endif

    half4 customColor = tex2D(_BaseMap, IN.uv);

#if OVERRIDE_ALPHA
    customColor.a = tex2D(_OverrideAlphaMap, IN.uv).r; // TODO: accept r,g,b,a option
#endif

    customColor *= _BaseColor;

    half fogAsAlpha = FogAsAlpha(IN.fogFactor);
    half opacity = customColor.a * fogAsAlpha;

#if NiloToonStickerMultiply
    customColor.rgb = lerp(1,customColor.rgb, opacity);
#endif
#if NiloToonStickerAdditive
    customColor.rgb *= opacity;
#endif

    // return const 1 alpha, because we don't want to pollute RT's alpha channel 
    return half4(customColor.rgb, 1);
}
