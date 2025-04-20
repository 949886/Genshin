// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This shader is a direct copy of URP10.4.0's LitForwardPass.hlsl, but with some edit.
// If you want to see what is the difference, all edited lines will have a [NiloToon] tag, you can search [NiloToon] in this file 

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// [NiloToon] add:
//==========================================================================================================
#include "../../ShaderLibrary/NiloUtilityHLSL/NiloAllUtilIncludes.hlsl"
//==========================================================================================================

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD2;
#endif

    float3 normalWS                 : TEXCOORD3;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS                : TEXCOORD5;

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD7;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    float3 viewDirTS                : TEXCOORD8;
#endif

    // [NiloToon] add:
    //=======================================================
    float4 screenPos                : TEXCOORD9;
    //=======================================================

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// [NiloToon] add:
//=======================================================
// https://github.com/phi-lira/UniversalShaderExamples/blob/d6288b349414ad074e758a6f61cfe3a871fa28f8/Assets/ShaderLibrary/CustomShading.hlsl#L91
// defined in latest URP
#if SHADER_LIBRARY_VERSION_MAJOR < 9
// Computes the world space view direction (pointing towards the viewer).
float3 GetWorldSpaceViewDir(float3 positionWS)
{
    if (unity_OrthoParams.w == 0)
    {
        // Perspective
        return _WorldSpaceCameraPos - positionWS;
    }
    else
    {
        // Orthographic
        float4x4 viewMat = GetWorldToViewMatrix();
        return viewMat[2].xyz;
    }
}
#endif
//=======================================================

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = SafeNormalize(input.viewDirWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);

    // [NiloToon] edit:
    //=======================================================
    #if SHADER_LIBRARY_VERSION_MAJOR >= 10
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);    

    inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
    #endif
    //=======================================================
}

// [NiloToon] add:
//==========================================================================================================================================================
// TODO: support planar reflection?

// debug on off
float _NiloToonGlobalEnviMinimumShader;

// shadow boader color
float4 _NiloToonGlobalEnviShadowBorderTintColor;

// global GI edit
float3 _NiloToonGlobalEnviGITintColor;
float3 _NiloToonGlobalEnviGIAddColor;
// global GI override
float4 _NiloToonGlobalEnviGIOverride;

// global albedo override
float4 _NiloToonGlobalEnviAlbedoOverrideColor;

// global screen space outline settings
float _GlobalScreenSpaceOutlineIntensityForEnvi;
float _GlobalScreenSpaceOutlineWidthMultiplierForEnvi;
float _GlobalScreenSpaceOutlineNormalsSensitivityOffsetForEnvi;
float _GlobalScreenSpaceOutlineDepthSensitivityOffsetForEnvi;
float _GlobalScreenSpaceOutlineDepthSensitivityDistanceFadeoutStrengthForEnvi;
half3 _GlobalScreenSpaceOutlineTintColorForEnvi;

// global camera uniforms
float   _CurrentCameraFOV;
//==========================================================================================================================================================

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    // [NiloToon] add:
    //=======================================================
    output.screenPos = ComputeScreenPos(output.positionCS);
    //=======================================================
    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    //[NiloToon] add:
    //==========================================================================================================================================================
    // debug on off
    if(_NiloToonGlobalEnviMinimumShader)
    {
        Light mainLight = GetMainLight();
        return half4(saturate(dot(mainLight.direction, input.normalWS)) * mainLight.color * surfaceData.albedo,1);
    }

    // GI edit and override
    inputData.bakedGI = inputData.bakedGI * _NiloToonGlobalEnviGITintColor + _NiloToonGlobalEnviGIAddColor;
    inputData.bakedGI = lerp(inputData.bakedGI, _NiloToonGlobalEnviGIOverride.rgb, _NiloToonGlobalEnviGIOverride.a);

    // albedo override
    surfaceData.albedo.rgb = lerp(surfaceData.albedo.rgb, _NiloToonGlobalEnviAlbedoOverrideColor.rgb, _NiloToonGlobalEnviAlbedoOverrideColor.a);
    //==========================================================================================================================================================

    // [NiloToon] Edit:
    //=======================================================
    #if SHADER_LIBRARY_VERSION_MAJOR >= 10
    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    #else
    half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic,surfaceData.specular,surfaceData.smoothness,surfaceData.occlusion,surfaceData.emission,surfaceData.alpha); //half3 albedo, half metallic, half3 specular, half smoothness, half occlusion, half3 emission, half alpha)
    #endif
    //=======================================================

    //[NiloToon] add:
    //==========================================================================================================================================================
    // copy from URP10.4's Lighting.hlsl->UniversalFragmentPBR()
    // To ensure backward compatibility we have to avoid using shadowMask input, as it is not present in older shaders
#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
    half4 shadowMask = inputData.shadowMask;
#elif !defined (LIGHTMAP_ON)
    half4 shadowMask = unity_ProbesOcclusion;
#else
    half4 shadowMask = half4(1, 1, 1, 1);
#endif

    #if SHADER_LIBRARY_VERSION_MAJOR >= 10
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);
    #else
    Light mainLight = GetMainLight(inputData.shadowCoord); // the only overload option in URP7.6.0's Lighting.hlsl
    #endif

    // shadow border tint color
    float isShadowEdge = 1-abs(mainLight.shadowAttenuation-0.5)*2;
    color.rgb = lerp(color.rgb,color.rgb * _NiloToonGlobalEnviShadowBorderTintColor.rgb, isShadowEdge * _NiloToonGlobalEnviShadowBorderTintColor.a);

#if _NILOTOON_GLOBAL_ENABLE_SCREENSPACE_OUTLINE
    // ss outline
    float2 ssUV = input.screenPos.xy / input.screenPos.w;
    float finalOutlineWidth = 1 * _GlobalScreenSpaceOutlineWidthMultiplierForEnvi;
    float finalNormalsSensitivity = max(0,1 + _GlobalScreenSpaceOutlineNormalsSensitivityOffsetForEnvi); // max(0,x) to prevent negative sensitivity
    float finalDepthSensitivity = max(0,1 + _GlobalScreenSpaceOutlineDepthSensitivityOffsetForEnvi); // max(0,x) to prevent negative
    float selfLinearDepth = abs(mul(UNITY_MATRIX_V,float4(input.positionWS,1)).z);

    // reduce finalDepthSensitivity according to depth

    finalDepthSensitivity *= 0.35; // make GUI's default value is 1

    float isScreenSpaceOutlineArea = IsScreenSpaceOutline(
        ssUV * _CameraDepthTexture_TexelSize.zw, 
        finalOutlineWidth, 
        finalDepthSensitivity, 
        finalNormalsSensitivity, 
        selfLinearDepth, 
        _GlobalScreenSpaceOutlineDepthSensitivityDistanceFadeoutStrengthForEnvi, 
        _CurrentCameraFOV);

    isScreenSpaceOutlineArea *= _GlobalScreenSpaceOutlineIntensityForEnvi;
    color.rgb = lerp(color.rgb, color.rgb * _GlobalScreenSpaceOutlineTintColorForEnvi, isScreenSpaceOutlineArea);
#endif
    //==========================================================================================================================================================

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);

    return color;
}