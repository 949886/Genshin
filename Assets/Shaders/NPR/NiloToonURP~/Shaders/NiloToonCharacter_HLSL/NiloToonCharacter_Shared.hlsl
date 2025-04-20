// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// note:
// subfix OS means object spaces    (e.g. positionOS = position object space)
// subfix WS means world space      (e.g. positionWS = position world space)
// subfix VS means view space       (e.g. positionVS = position view space)
// subfix CS means clip space       (e.g. positionCS = position clip space)

// just helper defines to help us write less macro code
// write #define XXX 1, instead of just #define XXX, so we can use both #if or #ifdef in shader code without problem
#if defined(NiloToonSelfOutlinePass) || defined(NiloToonExtraThickOutlinePass) || defined(NiloToonDepthOnlyOrDepthNormalPass)
    #define NiloToonIsAnyOutlinePass 1
#endif
#if defined(NiloToonForwardLitPass) || defined(NiloToonSelfOutlinePass)
    #define NiloToonIsAnyLitColorPass 1
#endif
#if defined(_NILOTOON_ADDITIONAL_LIGHTS)
    //#define _ADDITIONAL_LIGHTS 1 // we only require URP shader library's vertex level additional lighting
    #define _ADDITIONAL_LIGHTS_VERTEX 1 // a MACRO used by URP's lighting .hlsl, define it here to make URP's shader library to run their vertex lighting code
    #define NeedCalculateAdditionalLight 1
#endif
#if defined(_NILOTOON_DEBUG_SHADING)
    #define NeedVertexColorInFrag 1
#endif
// because _DETAIL always sample detail normal map
#if defined(_NORMALMAP) || defined(_DETAIL) || defined(_KAJIYAKAY_SPECULAR) || defined(_DYNAMIC_EYE)
    #define VaryingsHasTangentWS 1
#endif
#if defined(_ISFACE) && defined(_FACE_MASK_ON)
    #define NeedFaceMaskArea 1
#endif
#if defined(_NILOTOON_RECEIVE_URP_SHADOWMAPPING)
    #define _MAIN_LIGHT_SHADOWS 1 // a MACRO used by URP's shadow .hlsl, define it here to make URP's shader library to run their shadow code
#endif

#define FACE_AREA_DEPTH_TEXTURE_ZOFFSET 0.04 // a just enough ZOffset for face area when writing depth into _CameraDepthTexture.Good ZOffset range is about 0.04 to 0.06

// We don't have "UnityCG.cginc" in SRP/URP's package anymore, so:
// Including the following two hlsl files is enough for shading with Universal Pipeline. Everything is included in them.
// - Core.hlsl will include SRP shader library, all constant buffers not related to materials (perobject, percamera, perframe).
//   It also includes matrix/space conversion functions and fog.
// - Lighting.hlsl will include the light functions/data to abstract light constants. You should use GetMainLight and GetLight functions
//   that initialize Light struct. Lighting.hlsl also include GI, Light BDRF functions. It also includes Shadows.

// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// include a few small utility .hlsl files to help us write less code
#include "../../ShaderLibrary/NiloUtilityHLSL/NiloAllUtilIncludes.hlsl"

// all pass will share this Attributes struct (define data needed from Unity app to our vertex shader)
struct Attributes
{
    float3 positionOS   : POSITION;
    float3 normalOS     : NORMAL;       // GetVertexNormalInputs(...) expect float3 normalOS input, don't write half3 to produce unneeded type convertion cost
    float4 tangentOS    : TANGENT;      // GetVertexNormalInputs(...) expect float4 tangentOS input, don't write half4 to produce unneeded type convertion cost
    float2 uv           : TEXCOORD0;
    float2 uv2          : TEXCOORD1;
    float3 uv8          : TEXCOORD7;
    float4 color        : COLOR;        // used for outline width mask, not as a color, so use float not half

    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_VERTEX_INPUT_INSTANCE_ID  // in non OpenGL and non PSSL, will turn into -> uint instanceID : SV_InstanceID;
    //------------------------------------------------------------------------------------------------------------------------------ 
};

// all pass will share this Varyings struct (define data needed from our vertex shader to our fragment shader)
// Note: once a field is written here, no matter fragment shader use it or not
// you will pay for the rasterization interpolation cost, 
// compiler can't help you in this case, you can check Unity's compiled shader code to confirm.
// so using #if to remove a field in Varyings struct is a meaningful optimization here
struct Varyings
{
    float4 positionCS                           : SV_POSITION;

    float2 uv                                   : TEXCOORD0;    // need float not half, if texture >= 2048 size, half is not enough
    half4 SH_fogFactor                          : TEXCOORD1;    // (4 half pack into 1 TEXCOORD)  xyz: SampleSH(normalWS) * multipliers, w: fog factor
    float3 positionWS                           : TEXCOORD2;    // * can pack 1 more unskippable float into this TEXCOORD.w in the future if needed
    half4 normalWS_averageShadowAttenuation     : TEXCOORD3;    // (4 half pack into 1 TEXCOORD)  xyz: normalWS, w: averageShadowAttenuation

#if _DETAIL
    float2 detailUV                             : TEXCOORD4;
#endif

#if NeedCalculateAdditionalLight
    half3 additionalLightSum                    : TEXCOORD5;    // calculate a sum in vertex shader to save fragment forloop cycles
#endif

#if NeedFaceMaskArea
    half isFaceArea                             : TEXCOORD6;
#endif

#if VaryingsHasTangentWS
    half4 tangentWS                             : TANGENT;      // xyz: tangent, w: sign
#endif
   
    // debug use
    //--------------------------------------------------------------------
#if _NILOTOON_DEBUG_SHADING
    float3 uv8                                  : TEXCOORD7;
#endif

#if NeedVertexColorInFrag
    half4 color                                 : COLOR;        // vertex color, currently only for debug shading
#endif
    //--------------------------------------------------------------------

    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_VERTEX_INPUT_INSTANCE_ID  // will turn into this in non OpenGL and non PSSL -> uint instanceID : SV_InstanceID;
    UNITY_VERTEX_OUTPUT_STEREO      // will turn into this in non OpenGL and non PSSL -> uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
    //------------------------------------------------------------------------------------------------------------------------------
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// samplers / CBUFFER(material local Uniforms) 
// you should put all per material uniforms of all passes inside this single UnityPerMaterial CBUFFER! 
// else SRP batching is not possible!
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// per material textures
// *all samplers don't need to put inside CBUFFER
sampler2D _BaseMap;
#if _ALPHAOVERRIDEMAP
    sampler2D _AlphaOverrideTex;
#endif
#if _NORMALMAP
    sampler2D _BumpMap;
#endif
#if _EMISSION 
    sampler2D _EmissionMap;
#endif
#if _ENVIRONMENTREFLECTIONS
    sampler2D _EnvironmentReflectionMaskMap;
#endif
#if _MATCAP_BLEND
    sampler2D _MatCapAlphaBlendMap;
    sampler2D _MatCapAlphaBlendMaskMap;
#endif
#if _MATCAP_ADD
    sampler2D _MatCapAdditiveMap;
    sampler2D _MatCapAdditiveMaskMap;
#endif
    SAMPLER(linear_clamp_sampler); // force linear clamp sampler to prevent ramp lighting sampling wrong pixels using repeat wrap mode
#if _RAMP_LIGHTING
    TEXTURE2D(_RampLightingTex);            
#endif
#if _RAMP_LIGHTING_SAMPLE_UVY_TEX
    sampler2D _RampLightingSampleUvYTex;
#endif
#if _RAMP_SPECULAR
    TEXTURE2D(_RampSpecularTex);            
#endif
#if _RAMP_SPECULAR_SAMPLE_UVY_TEX
    sampler2D _RampSpecularSampleUvYTex;
#endif
#if _OCCLUSIONMAP
    sampler2D _OcclusionMap;
#endif
#if _SMOOTHNESSMAP
    sampler2D _SmoothnessMap;
#endif
#if _SPECULARHIGHLIGHTS
    sampler2D _SpecularMap;
    #if _SPECULARHIGHLIGHTS_TEX_TINT
    sampler2D _SpecularColorTintMap;
    #endif
#endif
#if _ZOFFSETMAP
    sampler2D _ZOffsetMaskTex;
#endif
#if _OUTLINEWIDTHMAP
    sampler2D _OutlineWidthTex;
#endif
#if _OUTLINEZOFFSETMAP
    sampler2D _OutlineZOffsetMaskTex;
#endif
#if NeedFaceMaskArea
    sampler2D _FaceMaskMap;
#endif
#if _SKIN_MASK_ON
    sampler2D _SkinMaskMap;
#endif
#if _DYNAMIC_EYE
    sampler2D _DynamicEyePupilMap;
    sampler2D _DynamicEyePupilMaskTex;
    sampler2D _DynamicEyeWhiteMap;
#endif
#if _DETAIL
    TEXTURE2D(_DetailMask);                 SAMPLER(sampler_DetailMask);
    TEXTURE2D(_DetailAlbedoMap);            SAMPLER(sampler_DetailAlbedoMap);
    TEXTURE2D(_DetailNormalMap);            SAMPLER(sampler_DetailNormalMap);
#endif
#if _OVERRIDE_SHADOWCOLOR_BY_TEXTURE
    sampler2D _OverrideShadowColorTex;
#endif
#if _OVERRIDE_OUTLINECOLOR_BY_TEXTURE
    sampler2D _OverrideOutlineColorTex;
#endif
#if _SCREENSPACE_OUTLINE
    sampler2D _ScreenSpaceOutlineDepthSensitivityTex;
    sampler2D _ScreenSpaceOutlineNormalsSensitivityTex;
#endif

// NiloToon's global textures
TEXTURE2D(_NiloToonAverageShadowMapRT);
TEXTURE2D(_NiloToonCharSelfShadowMapRT);    SAMPLER_CMP(sampler_NiloToonCharSelfShadowMapRT);

// Material shader variables are not defined in SRP or URP shader library.
// This means _BaseColor, _BaseMap, _BaseMap_ST, and all variables in the Properties section of a shader
// must be defined by the shader itself. If you define all those properties in CBUFFER named
// UnityPerMaterial, SRP can cache the material properties between frames and reduce significantly the cost
// of each drawcall.
// In this case, although URP's LitInput.hlsl contains the CBUFFER for some of the material
// properties defined in .shader file. As one can see this is not part of the ShaderLibrary, it specific to the
// URP Lit shader.
// So we are not going to use LitInput.hlsl, we will implement everything by ourself.
//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

// put all your uniforms(usually things inside .shader file's properties{}) inside this CBUFFER, in order to make SRP batcher compatible
// see -> https://blogs.unity3d.com/2019/02/28/srp-batcher-speed-up-your-rendering/

// IMPORTANT NOTE: Do not #ifdef #endif the properties inside CBUFFER as SRP batcher can NOT handle different CBUFFER layouts.
CBUFFER_START(UnityPerMaterial)

    // base color
    float4  _BaseMap_ST;
    half4   _BaseColor;
    half3   _PerCharacterBaseColorTint;

    // alpha override
    half4   _AlphaOverrideTexChannelMask;

    // alpha test
    half    _Cutoff;

    // fina output alpha
    half    _EditFinalOutputAlphaEnable;
    half    _ForceFinalOutputAlphaEqualsOne;

    // z offset
    float   _ZOffsetEnable;
    float   _ZOffset;
    float4  _ZOffsetMaskMapChannelMask;

    // normal map
    half    _BumpScale;

    // emission
    float4  _EmissionMapTilingXyOffsetZw;
    half    _EmissionIntensity;
    half3   _EmissionColor;
    half    _MultiplyBaseColorToEmissionColor; 

    // mat cap (alpha blend)
    half    _MatCapAlphaBlendUsage;
    half4   _MatCapAlphaBlendTintColor;
    float   _MatCapAlphaBlendUvScale;
    half    _MatCapAlphaBlendMapAlphaAsMask;
    half4   _MatCapAlphaBlendMaskMapChannelMask;
    half    _MatCapAlphaBlendMaskMapRemapStart;
    half    _MatCapAlphaBlendMaskMapRemapEnd;

    // mat cap (additive)
    half    _MatCapAdditiveMapAlphaAsMask;
    half    _MatCapAdditiveIntensity;
    half4   _MatCapAdditiveColor;
    float   _MatCapAdditiveUvScale;   
    half4   _MatCapAdditiveMaskMapChannelMask;
    half    _MatCapAdditiveMaskMapRemapStart;
    half    _MatCapAdditiveMaskMapRemapEnd;

    // occlusion
    half    _OcclusionStrength;
    half4   _OcclusionMapChannelMask;
    half    _OcclusionRemapStart;
    half    _OcclusionRemapEnd;

    // smoothness
    half    _Smoothness;
    half    _SmoothnessMapInputIsRoughnessMap;
    half4   _SmoothnessMapChannelMask;
    half    _SmoothnessMapRemapStart;
    half    _SmoothnessMapRemapEnd;   

    // specular
    half4   _SpecularMapChannelMask;
    half    _SpecularMapRemapStart;
    half    _SpecularMapRemapEnd;
    half    _UseGGXDirectSpecular;
    half    _SpecularIntensity;
    half3   _SpecularColor;
    half    _MultiplyBaseColorToSpecularColor;
    half    _GGXDirectSpecularSmoothnessMultiplier;
    half    _SpecularColorTintMapUsage;
    half    _SpecularAreaRemapUsage;
    half    _SpecularAreaRemapMidPoint;
    half    _SpecularAreaRemapRange;

    // Environment Reflections
    half    _EnvironmentReflectionUsage;
    half    _EnvironmentReflectionBrightness;
    half3   _EnvironmentReflectionColor;
    half    _EnvironmentReflectionSmoothnessMultiplier;
    half    _EnvironmentReflectionFresnelEffect;
    half4   _EnvironmentReflectionMaskMapChannelMask;
    half    _EnvironmentReflectionMaskMapRemapStart;
    half    _EnvironmentReflectionMaskMapRemapEnd;

    // kayjiya-kay hair specular
    half3   _HairStrandSpecularMainColor;
    half3   _HairStrandSpecularSecondColor;
    half    _HairStrandSpecularMainExponent;
    half    _HairStrandSpecularSecondExponent;

    // detail map
    float   _DetailUseSecondUv;
    half4   _DetailMaskChannelMask;
    float4  _DetailMapsScaleTiling;
    half    _DetailAlbedoWhitePoint;
    half    _DetailAlbedoMapScale;
    half    _DetailNormalMapScale;

    // self shadow color
    half    _SelfShadowAreaHueOffset;
    half    _SelfShadowAreaSaturationBoost;
    half    _SelfShadowAreaValueMul;
    half3   _SelfShadowTintColor;
    half    _LitToShadowTransitionAreaIntensity;
    half    _LitToShadowTransitionAreaHueOffset;
    half    _LitToShadowTransitionAreaSaturationBoost;
    half    _LitToShadowTransitionAreaValueMul;
    half3   _LitToShadowTransitionAreaTintColor;
    half4   _LowSaturationFallbackColor;
    half    _OverrideBySkinShadowTintColor;
    half3   _SkinShadowTintColor;
    half    _OverrideByFaceShadowTintColor;
    half3   _FaceShadowTintColor;

    // override shadow color by tex
    half    _OverrideShadowColorByTexIntensity;
    half4   _OverrideShadowColorTexTintColor;
    half    _OverrideShadowColorTexIgnoreAlphaChannel;

    // ramp lighting texture
    half    _RampLightingTexSampleUvY;
    // ramp specular texture
    half    _RampSpecularTexSampleUvY;

    // lighting style
    half    _CelShadeMidPoint;
    half    _CelShadeSoftness;
    half    _MainLightIgnoreCelShade;
    half    _IndirectLightFlatten;

    // lighting style for face area
    float   _OverrideCelShadeParamForFaceArea;
    half    _CelShadeMidPointForFaceArea;
    half    _CelShadeSoftnessForFaceArea;
    half    _MainLightIgnoreCelShadeForFaceArea;    

    // URP shadow mapping
    float   _ReceiveURPShadowMapping; // on/off toggle per material
    half    _ReceiveURPShadowMappingAmount;
    float   _ReceiveSelfShadowMappingPosOffset;
    float   _ReceiveSelfShadowMappingPosOffsetForFaceArea;
    half3   _URPShadowMappingTintColor;

    // depth texture rim light and shadow
    float   _DepthTexRimLightAndShadowWidthMultiplier;

    half    _DepthTexRimLightUsage;
    half3   _DepthTexRimLightTintColor;

    half    _DepthTexShadowUsage;
    float   _DepthTexShadowThresholdOffset;
    float   _DepthTexShadowFadeoutRange;
    half3   _DepthTexShadowTintColor;

    // average shadow mapping
    float   _AverageShadowMapRTSampleIndex;

    // NiloToon self shadow mapping
    float   _EnableNiloToonSelfShadowMapping;
    float   _NiloToonSelfShadowMappingDepthBias;
    half    _NiloToonSelfShadowIntensityForNonFace;
    half    _NiloToonSelfShadowIntensityForFace;

    // outline
    float   _RenderOutline;
    float   _OutlineUseBakedSmoothNormal;
    float   _UnityCameraDepthTextureWriteOutlineExtrudedPosition;
    half3   _OutlineTintColor;
    half3   _OutlineOcclusionAreaTintColor;
    half    _OutlineUseReplaceColor;
    half3   _OutlineReplaceColor;

    float   _OutlineWidth;
    float   _OutlineWidthExtraMultiplier;

    float   _OutlineZOffset;
    float   _OutlineZOffsetForFaceArea;
    float   _UseOutlineZOffsetTex;
    float   _OutlineZOffsetMaskRemapStart;
    float   _OutlineZOffsetMaskRemapEnd;
    float   _UseOutlineWidthMaskFromVertexColor;
    float4  _OutlineWidthMaskFromVertexColor;

    float   _PerCharacterOutlineWidthMultiply;
    half3   _PerCharacterOutlineColorTint;
    half4   _PerCharacterOutlineColorLerp;

    // override outline color by tex
    half4   _OverrideOutlineColorTexTintColor;
    half    _OverrideOutlineColorTexIgnoreAlphaChannel;
    half    _OverrideOutlineColorByTexIntensity;

    // screen space outline
    float   _ScreenSpaceOutlineWidth;
    float   _ScreenSpaceOutlineWidthIfFace;
    float   _ScreenSpaceOutlineDepthSensitivity;
    float   _ScreenSpaceOutlineDepthSensitivityIfFace;
    float   _ScreenSpaceOutlineNormalsSensitivity;
    float   _ScreenSpaceOutlineNormalsSensitivityIfFace;
    half3   _ScreenSpaceOutlineTintColor;
    half3   _ScreenSpaceOutlineOcclusionAreaTintColor;
    half    _ScreenSpaceOutlineUseReplaceColor;
    half3   _ScreenSpaceOutlineReplaceColor;   
    half4   _ScreenSpaceOutlineDepthSensitivityTexChannelMask;
    half4   _ScreenSpaceOutlineNormalsSensitivityTexChannelMask;
    half    _ScreenSpaceOutlineDepthSensitivityTexRemapStart;
    half    _ScreenSpaceOutlineDepthSensitivityTexRemapEnd;
    half    _ScreenSpaceOutlineNormalsSensitivityTexRemapStart;
    half    _ScreenSpaceOutlineNormalsSensitivityTexRemapEnd;

    // dynamic eye
    float   _DynamicEyeSize;
    half    _DynamicEyeFinalBrightness;
    half3   _DynamicEyeFinalTintColor;
    half4   _DynamicEyePupilMaskTexChannelMask;
    half3   _DynamicEyePupilColor;
    float   _DynamicEyePupilDepthScale;
    float   _DynamicEyePupilSize;
    float   _DynamicEyePupilMaskSoftness;
    float4  _DynamicEyeWhiteMap_ST;

    // extra thick outline
    float   _ExtraThickOutlineWidth;
    float   _ExtraThickOutlineMaxFinalWidth;
    float3  _ExtraThickOutlineViewSpacePosOffset;
    half4   _ExtraThickOutlineColor;
    float   _ExtraThickOutlineZOffset;

    // gameplay effect
    half3   _PerCharEffectTintColor;
    half3   _PerCharEffectAddColor;
    half4   _PerCharEffectLerpColor;
    half3   _PerCharEffectRimColor;
    half    _PerCharEffectDesaturatePercentage;

    // skin
    float   _IsSkin;
    half4   _SkinMaskMapChannelMask;

    // face
    half4   _FaceMaskMapChannelMask;
    half3   _FaceForwardDirection;
    half    _FixFaceNormalAmount;

    // per char center
    float3  _CharacterBoundCenterPosWS;

    // dither fadeout
    float   _DitherOpacity; // clip() only accept float

    // perspective removal
    float   _PerspectiveRemovalAmount; // total amount
    // perspective removal(sphere)
    float   _PerspectiveRemovalRadius;
    float3  _HeadBonePositionWS;
    // perspective removal(world height)
    float   _PerspectiveRemovalStartHeight; // usually is world space pos.y 0
    float   _PerspectiveRemovalEndHeight;

    // ZWrite (for disabling all _CameraDepthTexture related effect when _ZWrite = off)
    float   _ZWrite;
    // Cull (for fixing outline problem when rendering planar reflection pass)
    float   _Cull;
CBUFFER_END

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Global uniforms
// if an uniform is not a per material uniform, 
// it is fine to write it outside of CBUFFER_START(UnityPerMaterial)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// a special uniform for applyShadowBiasFixToHClipPos() only
float3  _LightDirection;

// global outline uniforms
float   _GlobalShouldRenderOutline;
float   _GlobalOutlineWidthMultiplier;
half3   _GlobalOutlineTintColor;

// global shadow mapping uniforms
float   _GlobalShouldReceiveShadowMapping;
half    _GlobalReceiveShadowMappingAmount;
float   _GlobalToonShaderNormalBiasMultiplier;
half3   _GlobalMainLightURPShadowAsDirectResultTintColor;

// self shadow mapping
float4x4 _NiloToonSelfShadowWorldToClip;
float4  _NiloToonSelfShadowParam;
float   _NiloToonSelfShadowRange;
float   _NiloToonGlobalSelfShadowDepthBias;
half3   _NiloToonSelfShadowLightDirection;
half    _NiloToonSelfShadowUseNdotLFix;
float   _GlobalReceiveSelfShadowMappingPosOffset;

// global occlusion uniforms
half    _GlobalOcclusionStrength;

// global lighting uniforms
half    _GlobalIndirectLightMultiplier;
half3   _GlobalIndirectLightMinColor;

// global depth diff rim light and shadow uniforms
float   _GlobalDepthTexRimLightAndShadowWidthMultiplier;
float   _GlobalDepthTexRimLightDepthDiffThresholdOffset;

// global light uniforms
half3   _GlobalMainLightDirVS;

// global camera uniforms
float   _CurrentCameraFOV;

// global camera fix
float2  _GlobalAspectFix;
float   _GlobalFOVorOrthoSizeFix;

// global volume
half3   _GlobalVolumeMulColor;
half4   _GlobalVolumeLerpColor;
half3   _GlobalRimLightMultiplier;
half3   _GlobalMainDirectionalLightMaxContribution;
half3   _GlobalAdditionalLightMaxContribution;
half    _GlobalSpecularIntensityMultiplier;
half    _GlobalSpecularMinIntensity;
half3   _GlobalMainDirectionalLightMultiplier;
half3   _GlobalAdditionalLightMultiplier;
half3   _GlobalVolumeBaseColorTintColor;

// global screen space outline settings
float   _GlobalScreenSpaceOutlineIntensityForChar;
float   _GlobalScreenSpaceOutlineWidthMultiplierForChar;
float   _GlobalScreenSpaceOutlineNormalsSensitivityOffsetForChar;
float   _GlobalScreenSpaceOutlineDepthSensitivityOffsetForChar;
float   _GlobalScreenSpaceOutlineDepthSensitivityDistanceFadeoutStrengthForChar;
half3   _GlobalScreenSpaceOutlineTintColorForChar;

// global debug
float   _GlobalToonShadeDebugCase;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Data Structs
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
struct ToonSurfaceData
{
    half3   albedo;
    half    alpha;
    half3   emission;
    half    occlusion;
    half3   specular;
    half3   normalTS;
    half    smoothness;
};
struct ToonLightingData
{
    float2  uv;
    half3   normalWS;
    float3  positionWS;
    half3   viewDirectionWS;
    float   selfLinearEyeDepth;
    half    averageShadowAttenuation;
    half3   SH;
    half    isFaceArea; // default 0, = not face, see InitializeLightingData(...)
    half    isSkinArea; // default 0, = not skin, see InitializeLightingData(...)
    float2  SV_POSITIONxy;
    half3   normalVS;
    half3   reflectionVectorVS;
    half    NdotV;

#if VaryingsHasTangentWS
    half3x3 TBN_WS;
    half3   viewDirectionTS;
#endif

#if NeedCalculateAdditionalLight
    half3   additionalLightSum;
#endif
};

// all lighting equation written inside this .hlsl,
// just by editing this .hlsl can control most of the visual result.
#include "NiloToonCharacter_LightingEquation.hlsl"

// all NiloToon supported ExternalAsset extension will goes here
#include "NiloToonCharacter_ExtendDefinesForExternalAsset.hlsl" 
#include "NiloToonCharacter_ExtendFunctionsForExternalAsset.hlsl"

// if you want to extend this shader without future update merge conflict, you should edit this .hlsl
// it is made for NiloToonURP's user to extend more features by themselves
#include "NiloToonCharacter_ExtendFunctionsForUserCustomLogic.hlsl" 

///////////////////////////////////////////////////////////////////////////////////////
// vertex shared functions
///////////////////////////////////////////////////////////////////////////////////////

// output: xyz = lightingNormalWS, w = isFaceArea
half4 GetLightingNormalWS_FaceArea(half3 normalWS, float2 uv)
{
    // default use original normalWS
    half3 resultNormalWS = normalWS;
    // default not face
    half isFaceArea = 0;

#if _ISFACE
    #if _FACE_MASK_ON
        // if has mask, we treat only white area on the mask texture is face
        isFaceArea = dot(tex2Dlod(_FaceMaskMap, float4(uv,0,0)), _FaceMaskMapChannelMask);             
    #else
        // if no mask, we assume the whole material is face
        isFaceArea = 1; 
    #endif

    // fix face normal (by forcing normal becoming face's forward direction vector)
    resultNormalWS = normalize(lerp(normalWS, _FaceForwardDirection, isFaceArea * _FixFaceNormalAmount)); 
#endif

    return half4(resultNormalWS,isFaceArea); 
}

float3 TransformPositionWSToOutlinePositionWS(float width, VertexPositionInputs vertexPositionInputs, VertexNormalInputs vertexNormalInputs, float3 smoothedNormalTS)
{
    width *= GetOutlineCameraFovAndDistanceFixMultiplier(vertexPositionInputs.positionVS.z, _CurrentCameraFOV);

    // by default we will use lighting normalWS as extrude direction also,
    // it is usable but not perfect due to smoothing group's split normal
    // which will produce discontinue outlinefor hard edge polygons(e.g. a cube)
    float3 extrudeDirectionWS = vertexNormalInputs.normalWS;

    // but "world space smoothed normal" is a much better extrude direction for outline than simply using lighting normal,
    // because smoothed normal doesn't have any split normal, so the outline will always be continuous, which looks much better. 
    // If we baked "tangent space smoothed normal" in model's uv8, 
    // we can convert it back to world space and use it as a much better extrude direction for outline 
    extrudeDirectionWS = _OutlineUseBakedSmoothNormal ? 
    ConvertNormalTSToNormalTargetSpace(smoothedNormalTS, vertexNormalInputs.tangentWS,vertexNormalInputs.bitangentWS, vertexNormalInputs.normalWS) :
    extrudeDirectionWS;

    // [this part is optional]
    // you can make extrude direction normalized in screen space, which will produce screen space constant width outline
    // https://www.videopoetics.com/tutorials/pixel-perfect-outline-shaders-unity/
    // https://github.com/Santarh/MToon/blob/master/MToon/Resources/Shaders/MToonCore.cginc#L90
    // TODO: do we need to support this option?
    // ...

    float3 outlinePositionWS = vertexPositionInputs.positionWS + extrudeDirectionWS * width;
    return outlinePositionWS;
}

// [All pass's vertex shader will share this function]
// if "NiloToonIsAnyOutlinePass" is not defined    = do regular MVP transform
// if "NiloToonIsAnyOutlinePass" is defined        = do regular MVP transform + outline extrude vertex + all outline related task
Varyings VertexShaderAllWork(Attributes input)
{
    // init output struct with all 0 bits just to avoid "struct not init" warning/error
    // but passing 0 from vertex to fragment still has rasterization cost
    // so make sure Varyings struct is as small as possible
    Varyings output = (Varyings)0;

    // when rendering to _CameraColorTexture, this section will allow material's _RenderOutline toggle to control render outline or not, per material.
    // Be careful not to run this section in DepthOnly pass, 
    // in DepthOnly pass we only need to skip the outline extrude, not invalid the vertex!
    // so here only #if NiloToonSelfOutlinePass is used instead of #if NiloToonIsAnyOutlinePass
#if NiloToonSelfOutlinePass
    if(!_RenderOutline)
    { 
        // [a trick to "delete" any vertex]
        // if the output vertex's positionCS.w is 0, GPU will invalid this vertex and all directly connected vertices,
        // we can use "positionCS.w = 0" to invalid all outline vertices if needed.
        // Ideally you want to remove the outline pass completely and not use this trick if the material's _RenderOutline toggle is off for best performance,
        // but it will require a custom material editor inspector, which may make things too complex without gaining much, 
        // since only a small amount of material will want to NOT render outline, like eyeball,eyebrow,teeth....
        output.positionCS.w = 0; // it is 0 already even without writing this line, since Varyings struct was init with all 0 bits, but we still write this line for clarity
        
        return output;         
    }
#endif

    // after invalid vertex part, do this part asap.
    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_SETUP_INSTANCE_ID(input);                 // will turn into this in non OpenGL and non PSSL -> UnitySetupInstanceID(input.instanceID);
    UNITY_TRANSFER_INSTANCE_ID(input, output);      // will turn into this in non OpenGL and non PSSL -> output.instanceID = input.instanceID;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);  // will turn into this in non OpenGL and non PSSL -> output.stereoTargetEyeIndexAsRTArrayIdx = unity_StereoEyeIndex;
    //------------------------------------------------------------------------------------------------------------------------------

    // [insert a performance debug early exit]
    //------------------------------------------------------------------------------------------------------------------------------
    // exit as early as possible, to maximize performance difference
#if _NILOTOON_FORCE_MINIMUM_SHADER
    #if NiloToonIsAnyOutlinePass
        output.positionCS = TransformObjectToHClip(input.positionOS + input.normalOS * 0.005); // any visible debug outline width is ok
    #else
        output.positionCS = TransformObjectToHClip(input.positionOS);
    #endif

    // return minimum v2f data to render just _BaseMap (same as Unlit)
    output.uv = input.uv;

    return output;    
#endif
    //------------------------------------------------------------------------------------------------------------------------------

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Edit Attributes struct by other .hlsl
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // allow developer to supporting external asset by editing Attributes struct, 
    // using NiloToonCharacter_ExtendFunctionsForExternalAsset.hlsl (used by NiloToon's developer)
    ApplyExternalAssetSupportLogicToVertexAttributeAtVertexShaderStart(input);
    // allow user to edit Attributes struct,
    // using NiloToonCharacter_ExtendFunctionsForUserCustomLogic.hlsl (used by NiloToon's user)
    ApplyCustomUserLogicToVertexAttributeAtVertexShaderStart(input);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fill in VertexPositionInputs and VertexNormalInputs utility struct
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VertexPositionInputs struct contains the position in multiple spaces (world, view, homogeneous clip space, NDC)
    // Unity compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost when using VertexPositionInputs struct.
    VertexPositionInputs vertexPositionInput = GetVertexPositionInputs(input.positionOS);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    // NormalWS and tangentWS are already normalized,
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation if needed
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float3 positionWS = vertexPositionInput.positionWS;
    float3 positionVS = vertexPositionInput.positionVS;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fog
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
#if NiloToonIsAnyLitColorPass
    // calculate fogFactor before any positionHCS.z's edit (ZOffset edit)
    half fogFactor = ComputeFogFactor(vertexPositionInput.positionCS.z);
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Extrude positionWS for outline
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
    // extrude positionWS if is any outline pass and this material wants to render outline
#if NiloToonIsAnyOutlinePass
    // if _RenderOutline is false,
    // NiloToonSelfOutlinePass already early exit (see early return code above), 
    // and ExtraThickOutlinePass will ignore material's _RenderOutline toggle
    // so only NiloToonDepthOnlyOrDepthNormalPass will need to include this if()
    #if NiloToonDepthOnlyOrDepthNormalPass
    // 1)if _RenderOutline is false, 
    // no need to extrude in NiloToonDepthOnlyOrDepthNormalPass, simple to understand.
    // 2)if _OutlineUseBakedSmoothNormal is false,
    // which means we are going to use split normal for extrude.
    // Due to smoothing group's split normal, TransformPositionWSToOutlinePositionWS() may produce holes between polygons,
    // which pollute _CameraDepthTexture, which makes depth texture 2D rim light produce bad result.
    // so better NOT do TransformPositionWSToOutlinePositionWS() if _OutlineUseBakedSmoothNormal is false
    // 3)if _UnityCameraDepthTextureWriteOutlineExtrudedPosition is false (default is true),
    // which means user explictly want to skip this section, usually user want to turn off _UnityCameraDepthTextureWriteOutlineExtrudedPosition if ugly 2D rim light artifact appeared
    if(_RenderOutline && _OutlineUseBakedSmoothNormal && _UnityCameraDepthTextureWriteOutlineExtrudedPosition)
    #endif
    {
        float finalOutlineWidth = 1;
        finalOutlineWidth = _OutlineWidth * _OutlineWidthExtraMultiplier * _PerCharacterOutlineWidthMultiply * _GlobalOutlineWidthMultiplier;

        // outline width mul from texture
        #if _OUTLINEWIDTHMAP
            float outlineWidthTex2DlodExplicitMipLevel = 0;
            float outlineWidthMultiplierByTex = tex2Dlod(_OutlineWidthTex, float4(input.uv,0,outlineWidthTex2DlodExplicitMipLevel)).g; // TODO: should we expose channel mask?
            finalOutlineWidth *= outlineWidthMultiplierByTex;           
        #endif

        // outline width mul from vertex color
        finalOutlineWidth = _UseOutlineWidthMaskFromVertexColor? finalOutlineWidth * dot(input.color, _OutlineWidthMaskFromVertexColor) : finalOutlineWidth;

        // ExtraThickOutlinePass will affect finalOutlineWidth at the last, to ensure width control is isolated
        #if NiloToonExtraThickOutlinePass
            // apply by add, not mul, to make extra thick outline's width has it's own isolated width
            finalOutlineWidth += _ExtraThickOutlineWidth;
            // if user used different outline width per material, 
            // here we expose min(x,_ExtraThickOutlineMaxFinalWidth) for user to have a uniform final ExtraThickOutline width 
            finalOutlineWidth = min(finalOutlineWidth, _ExtraThickOutlineMaxFinalWidth); 
        #endif

        if(_GlobalShouldDisableNiloToonZOffset)
        {
            // in planar reflection pass, _GlobalShouldDisableNiloToonZOffset will set to true (= ZOffset is disabled),
            // so we don't render face's outline, else ugly outline will appear in planar reflection pass
            #if _ISFACE
                output.positionCS.w = 0;
                return output;
            #endif

            // https://docs.unity3d.com/ScriptReference/Rendering.CullMode.html
            // 0 is Off
            // 1 is Front
            // 2 is Back
            // in planar reflection pass, _GlobalShouldDisableNiloToonZOffset will set to true (= ZOffset is disabled),
            // so don't render Cull off material's outline
            // only Cull Off has problem, so only disable outline when Cull Off
            finalOutlineWidth = _Cull == 0 ? 0 : finalOutlineWidth;
        }

        // do positionWS extrude for outline
        positionWS = TransformPositionWSToOutlinePositionWS(finalOutlineWidth, vertexPositionInput, vertexNormalInput, input.uv8);

        // do ExtraThickOutline's view space pos offset(in world space)
        #if NiloToonExtraThickOutlinePass
            // transform view space position offset to world space, apply offset in world space
            positionWS += mul((float3x3)UNITY_MATRIX_I_V, _ExtraThickOutlineViewSpacePosOffset).xyz;
        #endif
    }        
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UV
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = TRANSFORM_TEX(input.uv,_BaseMap);

#if _NILOTOON_DEBUG_SHADING
    output.uv8 = input.uv8; // for showing tangent space smoothed normal as debug color, in fragment shader
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PositionWS
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    output.positionWS = positionWS;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TangentWS
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if VaryingsHasTangentWS
    half sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(vertexNormalInput.tangentWS.xyz, sign);
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PositionCS
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    output.positionCS = TransformWorldToHClip(positionWS);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Find out face area, and edit normalWS for face area
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    half4 lightingNormalWS_faceArea = GetLightingNormalWS_FaceArea(vertexNormalInput.normalWS, output.uv);
    output.normalWS_averageShadowAttenuation.xyz = lightingNormalWS_faceArea.xyz; //normalized already by GetLightingNormalWS_FaceArea(...)

    #if NeedFaceMaskArea
        output.isFaceArea = lightingNormalWS_faceArea.w;
    #endif
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Outline ZOffset
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // this section will apply clip space ZOffset (view space unit input) to outline position
    // doing this can hide ugly/unwanted outline, usually for face/eye
    // Only apply to _CameraColorTexture's outline pass(NiloToonSelfOutlinePass)
#if NiloToonSelfOutlinePass

    // we have separated settings for "face" and "not face" vertices 
    float outlineZOffset = lerp(_OutlineZOffset,_OutlineZOffsetForFaceArea,lightingNormalWS_faceArea.w);

    // [ZOffset mask]
    #if _OUTLINEZOFFSETMAP
        float outlineZOffsetMask = 1;

        // [Read ZOffset mask texture]
        // we can't use tex2D() in vertex shader because ddx & ddy is unknown before rasterization, 
        // so use tex2Dlod() with an explicit mip level 0, you need to put explicit mip level 0 inside the 4th component of tex2Dlod()'s' input param
        float outlineZOffsetTex2DlodExplicitMipLevel = 0;
        outlineZOffsetMask = tex2Dlod(_OutlineZOffsetMaskTex, float4(input.uv,0,outlineZOffsetTex2DlodExplicitMipLevel)).g; // we assume it is a Black/White texture, to save 1 dot() //TODO: expose channel mask?

        // [Remap ZOffset texture value]
        // flip texture read value so default black area = apply ZOffset, because usually outline mask texture are using this format(black = hide outline, white = do nothing)
        outlineZOffsetMask = 1-outlineZOffsetMask;
        outlineZOffsetMask = invLerpClamp(_OutlineZOffsetMaskRemapStart,_OutlineZOffsetMaskRemapEnd,outlineZOffsetMask);// allow user to remap

        // [Apply ZOffset, Use remapped value as ZOffset mask]
        outlineZOffset *= outlineZOffsetMask;           
    #endif

    // this line make ZOffset sync with camera distance corrected outline width
    // If we don't do this, once camera is far away, zoffset will become not enough because outline width keep growing larger
    // also stop reduce zoffset when camera is too close using max(1,x)
    // TODO: we should share the GetOutlineCameraFovAndDistanceFixMultiplier() call to save some performance?  
    outlineZOffset *= max(1,GetOutlineCameraFovAndDistanceFixMultiplier(positionVS.z, _CurrentCameraFOV) / 0.0025); 

    // add ExtraThickOutlinePass's ZOffset (add) at the end, use add for isolated zoffset control
    #if NiloToonExtraThickOutlinePass
        outlineZOffset += _ExtraThickOutlineZOffset;
    #endif

    // apply ZOffset (will only affect positionCS.z)
    output.positionCS = NiloGetNewClipPosWithZOffsetVS(output.positionCS, -outlineZOffset);
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Shadow bias
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ShadowCaster pass needs special process to positionCS, else shadow artifact will appear
#if NiloToonShadowCasterPass
    // see GetShadowPositionHClip() in URP/Shaders/ShadowCasterPass.hlsl
    // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl

    // normalBias will produce "holes" in shadowmap, so we add a slider to control it globally
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, vertexNormalInput.normalWS * _GlobalToonShaderNormalBiasMultiplier, _LightDirection));

    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif

    output.positionCS = positionCS;
#endif

#if NiloToonCharSelfShadowCasterPass
    // WIP, fix self shadow's artifact in shadow pass, not shading pass
    /*
    // get smooth normalWS
    float3 smoothNormalWS = vertexNormalInput.normalWS;
    // but "world space smoothed normal" is a much better extrude direction for outline than simply using lighting normal,
    // because smoothed normal doesn't have any split normal, so the outline will always be continuous, which looks much better. 
    // If we baked "tangent space smoothed normal" in model's uv8, 
    // we can convert it back to world space and use it as a much better extrude direction  
    smoothNormalWS = _OutlineUseBakedSmoothNormal ? 
    ConvertNormalTSToNormalTargetSpace(input.uv8, vertexNormalInput.tangentWS,vertexNormalInput.bitangentWS, vertexNormalInput.normalWS) :
    smoothNormalWS;

    float depthBias = (1+pow(saturate(1-dot(smoothNormalWS, _LightDirection)),4)) * _NiloToonSelfShadowDepthBias * 1; // * _NiloToonSelfShadowDepthBias

    // depth bias
    positionWS += -_LightDirection * depthBias;
    // normal bias
    //positionWS += smoothNormalWS * -0.001; //can't increase more, else finger shadow will become too thin


    output.positionCS = lerp(output.positionCS,TransformWorldToHClip(positionWS), 1);//sin(_Time.y * 10) > 0);
    */
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ZOffset
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // originally created to push eyebrow over hair / face expression mesh (e.g >///<) over face like a alpha blend decal/sticker
#if NiloToonForwardLitPass
    if(_ZOffsetEnable)
    {
        float zoffset = -_ZOffset;

        #if _ZOFFSETMAP
            float zOffsetTex2DlodExplicitMipLevel = 0;
            float zOffsetMultiplierByTex = dot(_ZOffsetMaskMapChannelMask,tex2Dlod(_ZOffsetMaskTex, float4(input.uv,0,zOffsetTex2DlodExplicitMipLevel)));
            zoffset *= zOffsetMultiplierByTex;
        #endif

        output.positionCS = NiloGetNewClipPosWithZOffsetVS(output.positionCS, zoffset);        
    }
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Vertex color
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if NeedVertexColorInFrag
    output.color = input.color;
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SH (indirect from lightprobe) (moved to vertex shader for performance reason, it is ok due to low frequency result data)
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [calculate SH in vertex shader to save some cycles]
    // If we call SampleSH(0), this will hide all 3D feeling by ignoring all detail SH.
    // We default only use the constant term, = SampleSH(0)
    // because we just want to get some average envi indirect color only.
    // Hardcode 0 can enable compiler optimization to remove no-op,
    // but here we don't hardcode 0, instead we use a uniform variable(_IndirectLightFlatten) to control the normal,
    // which allow more flexibility for user
#if NiloToonIsAnyLitColorPass
    // prepare normal for SampleSH(...)
    half3 normalWSForSH = lightingNormalWS_faceArea.xyz;
    normalWSForSH *= 1-_IndirectLightFlatten; // make the normal become 0 when _IndirectLightFlatten is 1

    half3 SH = SampleSH(normalWSForSH) * _GlobalIndirectLightMultiplier;
    output.SH_fogFactor = half4(SH, fogFactor);
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // All additional lights (moved to vertex shader for performance reason, it is ok due to low frequency result data)
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if NiloToonIsAnyLitColorPass
    #if NeedCalculateAdditionalLight
        half3 additionalLightNormalWS = lightingNormalWS_faceArea.xyz;

        // Returns the number of lights affecting the object being renderer.
        // These lights are culled per-object(per renderer) in the forward renderer of URP.
        int additionalLightsCount = GetAdditionalLightsCount();
        for (int i = 0; i < additionalLightsCount; ++i)
        {
            // Similar to GetMainLight(), but it takes a for-loop index. This figures out the
            // per-object light index and samples the light buffer accordingly to initialized the
            // Light struct. If ADDITIONAL_LIGHT_CALCULATE_SHADOWS is defined it will also compute shadows.
            int perObjectLightIndex = GetPerObjectLightIndex(i);
            Light light = GetAdditionalPerObjectLight(perObjectLightIndex, positionWS); // use original positionWS for lighting

            // still no shadowmap for additional light(point light) in URP 10.4.0 (2020.3 LTS), so not supported
            // TODO: support it for URP 11 when Unity 2021 LTS is ready?
            /*
            if(_ReceiveSelfShadowMapping)
            {
                light.shadowAttenuation = AdditionalLightShadow(perObjectLightIndex, perObjectLightIndex, 0, 0);         
            }
            */

            // Different function used to shade additional lights.
            output.additionalLightSum += CalculateAdditiveSingleAdditionalLight(additionalLightNormalWS, light);
        }

        // extra control from NiloToon's Volume classes
        output.additionalLightSum = min(output.additionalLightSum,_GlobalAdditionalLightMaxContribution) * _GlobalAdditionalLightMultiplier;
    #endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Average Shadow Attenuation
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // use LOAD_TEXTURE2D instead of tex2dLOD for simplify uv code and also for better performance
    // _NiloToonAverageShadowMapRT is a nx1 texture, so LOAD index is (charID,0)
    output.normalWS_averageShadowAttenuation.w = LOAD_TEXTURE2D(_NiloToonAverageShadowMapRT,float2(_AverageShadowMapRTSampleIndex,0)).r; // floating point RT, so r channel
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Detail texture uv
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if _DETAIL
    // if we calculate UV in the vertex shader and use it directly in fragment shader without modifying it
    // GPU will have a chance to prefetch the texture before entering fragment shader
    // *atlease for PowerVR it is true
    output.detailUV = (_DetailUseSecondUv ? input.uv2 : input.uv) * _DetailMapsScaleTiling.xy + _DetailMapsScaleTiling.zw;
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Face's depth texture ZOffset
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // for face vertices, use ZOffset to push back depth write to _CameraDepthTexture, 
    // doing this can:
    // - prevent face cast self 2D depth texture shadow on face's artifact
    // - make hair easier to cast 2D depth texture shadow on face
#if NiloToonDepthOnlyOrDepthNormalPass && _ISFACE
    float cameraDepthTextureZOffsetMask = 1;
    #if NeedFaceMaskArea
        cameraDepthTextureZOffsetMask = lightingNormalWS_faceArea.w;
    #endif
    // zoffset should be always greater or equal to depthDiffThreshold, to avoid face cast 2D depth texture self shadow
    output.positionCS = NiloGetNewClipPosWithZOffsetVS(output.positionCS, -FACE_AREA_DEPTH_TEXTURE_ZOFFSET * cameraDepthTextureZOffsetMask); 
#endif

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Remove perspective camera distortion
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if NiloToonIsAnyLitColorPass || NiloToonDepthOnlyOrDepthNormalPass || NiloToonExtraThickOutlinePass
    output.positionCS = NiloDoPerspectiveRemoval(output.positionCS,positionWS,_HeadBonePositionWS,_PerspectiveRemovalRadius,_PerspectiveRemovalAmount, _PerspectiveRemovalStartHeight, _PerspectiveRemovalEndHeight);
#endif

    return output;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Above is vertex shader section, below is fragment shader section
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step1: if DEBUG, run these DEBUG functions and early exit)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
half4 Get_NILOTOON_FORCE_MINIMUM_FRAGMENT_SHADER_result(Varyings input)
{
    half3 debugColor = tex2D(_BaseMap, input.uv).rgb;
    #if NiloToonIsAnyOutlinePass
        debugColor *= 0.25;
    #endif
    return half4(debugColor,1);   
}
half4 Get_NILOTOON_DEBUG_SHADING_result(Varyings input, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
#if _NILOTOON_DEBUG_SHADING
    // example of switch case in hlsl:
    // https://github.com/SickheadGames/HL2GLSL/blob/master/tests/HL2GLSL/FlowControl.hlsl
    switch(_GlobalToonShadeDebugCase)
    {
        case 0:     return half4(surfaceData.albedo, surfaceData.alpha);
        case 1:     return 1;
        case 2:     return surfaceData.occlusion;
        case 3:     return half4(surfaceData.emission,1);
        case 4:     return half4(lightingData.normalWS * 0.5 + 0.5,1);
        case 5:     return half4(input.uv,0,1);
        case 6:     return input.color.r;
        case 7:     return input.color.g;
        case 8:     return input.color.b;
        case 9:     return input.color.a;
        case 10:    return half4(input.color.rgb,1);
        case 11:    return half4(surfaceData.specular.rgb,1);
        case 12:    return half4(input.uv8,1);
        case 13:    return half4(surfaceData.albedo * dot(lightingData.normalWS,lightingData.viewDirectionWS), surfaceData.alpha);
    }
#endif

    return 1;    
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step2: prepare data structs for lighting calculation)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
half4 GetFinalBaseColor(Varyings input)
{
    half4 color = tex2D(_BaseMap, input.uv);
#if _ALPHAOVERRIDEMAP
    color.a = dot(tex2D(_AlphaOverrideTex, input.uv),_AlphaOverrideTexChannelMask);
#endif
    color *= _BaseColor; // edit rgba, since _BaseColor is per material, using _BaseColor.a to control alpha should be intentional
    //color.rgb *= _PerCharacterBaseColorTint * _GlobalVolumeBaseColorTintColor; // edit rgb only, since they are not per material, edit alpha per character/globally should be not intended
    return color;
}
half3 GetFinalEmissionColor(Varyings input, half3 baseColor)
{
#if _EMISSION
    float2 uv = input.uv * _EmissionMapTilingXyOffsetZw.xy + _EmissionMapTilingXyOffsetZw.zw;
    half3 emissionResult = tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb * _EmissionIntensity; // alpha is ignored
    emissionResult *= lerp(1,baseColor,_MultiplyBaseColorToEmissionColor); // let user optionally mix base color to emission color
    return emissionResult;
#else
    return 0; // default emission value is black when turn off
#endif
}
half GetFinalOcculsion(Varyings input)
{
#if _OCCLUSIONMAP
    half4 texValue = tex2D(_OcclusionMap, input.uv);
    half occlusionValue = dot(texValue, _OcclusionMapChannelMask);
    occlusionValue = invLerpClamp(_OcclusionRemapStart, _OcclusionRemapEnd, occlusionValue); // should remap first,
    occlusionValue = lerp(1, occlusionValue, _OcclusionStrength * _GlobalOcclusionStrength); // then apply per material and per volume fadeout.
    return occlusionValue;
#else
    return 1; // default occulusion value is 1 when turn off
#endif
}
half GetFinalSmoothness(Varyings input)
{
    half smoothnessResult = _Smoothness;
#if _SMOOTHNESSMAP
    half4 texValue = tex2D(_SmoothnessMap, input.uv);
    half smoothnessMultiplierByTexture = dot(texValue, _SmoothnessMapChannelMask);
    smoothnessMultiplierByTexture = _SmoothnessMapInputIsRoughnessMap ? 1-smoothnessMultiplierByTexture : smoothnessMultiplierByTexture;
    smoothnessMultiplierByTexture = invLerpClamp(_SmoothnessMapRemapStart, _SmoothnessMapRemapEnd, smoothnessMultiplierByTexture); // remap
    smoothnessResult *= smoothnessMultiplierByTexture; // apply
#endif
    return smoothnessResult;
}
half3 GetFinalSpecularRGB(Varyings input, half3 baseColor)
{
#if _SPECULARHIGHLIGHTS
    half4 texValue = tex2D(_SpecularMap, input.uv);
    half specularValue = dot(texValue, _SpecularMapChannelMask);
    specularValue = invLerpClamp(_SpecularMapRemapStart, _SpecularMapRemapEnd, specularValue); // should remap first,
    half3 specularResult = _SpecularColor * (specularValue * _SpecularIntensity);// then apply intensity / color
    specularResult *= lerp(1,baseColor,_MultiplyBaseColorToSpecularColor); // let user optionally mix base color to specular color
    #if _SPECULARHIGHLIGHTS_TEX_TINT
        specularResult *= lerp(1,tex2D(_SpecularColorTintMap, input.uv),_SpecularColorTintMapUsage);
    #endif
    return specularResult;
#else
    return 0; // default specular value is 0 when turn off
#endif
}
half3 GetFinalNormalTS(Varyings input)
{
#if _NORMALMAP
    // Not using UnpackNormal(...) for mobile & switch now
    // because we want to unify mobile and non mobile detail normalmap rendering, since performance differernce is small
    // honestly no one will care 1 more MUL in 2021, even for mobile
    return UnpackNormalScale(tex2D(_BumpMap,input.uv), _BumpScale);
#else
    return half3(0,0,1); //default value of normal map when turn off, pointing out in tangent space, if converted back to world space it will be the same as raw vertex normal
#endif
}
void DoClipTestToTargetAlphaValue(half alpha) 
{
#if _ALPHATEST_ON
    clip(alpha - _Cutoff);
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// Copy and simplify from URP10.2.2's LitInput.hlsl's detail map logic - START
// this section only exist #if _DETAIL
#if _DETAIL
    // Used for scaling detail albedo. Main features:
    // - Depending if detailAlbedo brightens or darkens, scale magnifies effect.
    // - No effect is applied if detailAlbedo is 0.5.
    half3 ScaleDetailAlbedo(half3 detailAlbedo, half scale)
    {
        // detailAlbedo = detailAlbedo * 2.0h - 1.0h;
        // detailAlbedo *= _DetailAlbedoMapScale;
        // detailAlbedo = detailAlbedo * 0.5h + 0.5h;
        // return detailAlbedo * 2.0f;

        // A bit more optimized
        return 2.0h * detailAlbedo * scale - scale + 1.0h;
    }
    half3 ApplyDetailAlbedo(float2 detailUv, half3 albedo, half detailMask)
    {
        half3 detailAlbedo = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUv).rgb;
        detailAlbedo = ScaleDetailAlbedo(detailAlbedo, _DetailAlbedoMapScale);
        detailAlbedo *= 0.5 / _DetailAlbedoWhitePoint;
        return albedo * LerpWhiteTo(detailAlbedo, detailMask); // apply detail albedo's method is just 1 simple multiply
    }
    half3 ApplyDetailNormal(float2 detailUv, half3 normalTS, half detailMask)
    {
        // Not using UnpackNormal(...) for mobile & switch now
        // because we want to unify mobile and non mobile detail normalmap rendering, since performance differernce is small
        // honestly no one will care 1 more MUL in 2021, even for mobile
        half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv), _DetailNormalMapScale);

        // With UNITY_NO_DXT5nm unpacked vector is not normalized for BlendNormalRNM
        // For visual consistancy we should do normalize() in all cases,
        // but here we only normalize #if UNITY_NO_DXT5nm, for performance reason
        #if UNITY_NO_DXT5nm
            detailNormalTS = normalize(detailNormalTS);
        #endif

        // TODO: detailMask should lerp the angle of the quaternion rotation, not the normals
        return lerp(normalTS, BlendNormalRNM(normalTS, detailNormalTS), detailMask); 
    }
#endif
// Copy and simplify from URP10.2.2's LitInput.hlsl's detail map logic - END
///////////////////////////////////////////////////////////////////////////////////////////////////////////

ToonSurfaceData InitializeSurfaceData(Varyings input)
{
    ToonSurfaceData output;

    // albedo(Base Color) & alpha
    half4 baseColorFinal = GetFinalBaseColor(input);
    ApplyExternalAssetSupportLogicToBaseColor(baseColorFinal);
    ApplyCustomUserLogicToBaseColor(baseColorFinal);
    output.albedo = baseColorFinal.rgb;
    output.alpha = baseColorFinal.a;

    // alpha clip and dither fadeout
    DoClipTestToTargetAlphaValue(output.alpha);// let clip() early exit asap once alpha value is known
#if _NILOTOON_DITHER_FADEOUT
    NiloDoDitherFadeoutClip(input.positionCS.xy, _DitherOpacity);
#endif

    // occlusion
    output.occlusion = GetFinalOcculsion(input);

    // smoothness
    output.smoothness = GetFinalSmoothness(input);

    // normalTS
    output.normalTS = GetFinalNormalTS(input);

    // Detail albedo and normal (only enable in non-DEBUG)
#if _DETAIL && !_NILOTOON_DEBUG_SHADING
    half detailMask = dot(_DetailMaskChannelMask, SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, input.uv));
    output.albedo = ApplyDetailAlbedo(input.detailUV, output.albedo, detailMask);
    output.normalTS = ApplyDetailNormal(input.detailUV, output.normalTS, detailMask);
#endif

    ///////////////////////////////////////////////////////////
    // after Detail albedo and normal,
    // do all functions that require detail albedo and normal
    ///////////////////////////////////////////////////////////
    // emission
    output.emission = GetFinalEmissionColor(input, output.albedo);

    // specular & roughness
    output.specular = GetFinalSpecularRGB(input, output.albedo);

    return output;
}
ToonLightingData InitializeLightingData(Varyings input, ToonSurfaceData surfaceData)
{
    ToonLightingData lightingData;
    lightingData.uv = input.uv;
    lightingData.positionWS = input.positionWS;
    lightingData.viewDirectionWS = normalize(GetCameraPositionWS() - lightingData.positionWS);  

    half3 normalWS = input.normalWS_averageShadowAttenuation.xyz;

#if VaryingsHasTangentWS
    // we have to do this when an odd number of dimensions in transform scale are negative.
    half sgn = input.tangentWS.w * unity_WorldTransformParams.w; // should be either +1 or -1

    // no need to normalize bitangentWS if you only use normalWS, 
    // since we normalize normalWS at the end when we assign normalWS's result to lightingData. (see LitForwardPass.hlsl)
    half3 bitangentWS = sgn * cross(normalWS, input.tangentWS.xyz);

    lightingData.TBN_WS = half3x3(input.tangentWS.xyz, bitangentWS, normalWS);
    lightingData.viewDirectionTS = TransformWorldToTangent(lightingData.viewDirectionWS,lightingData.TBN_WS);
#endif

    // if any normalmap is enabled, convert normalTS in normalmap to normalWS
#if _NORMALMAP || _DETAIL     
    normalWS = TransformTangentToWorld(surfaceData.normalTS,lightingData.TBN_WS); // apply normalmapped result normalWS (rotation-only matrix's transpose equals inverse)
#endif

    // In theory we should re-normalize all directions vector after interpolation.
    // Here even _NORMALMAP is false, we still normalzie() to ensure correctness.
    // Not normalize() will affect specular result greatly!
    // The only case we want to skip normalize() is on mobile / switch
    lightingData.normalWS = NormalizeNormalPerPixel(normalWS);

    // material default is not face
    lightingData.isFaceArea = 0;

    // toggle "_ISFACE" will affect face lighting and shadowing
    // if is face: override normalWS by user defined face forward direction & face area mask, in vertex shader
    // if is not face: don't edit normal, use mesh's normal directly
#if _ISFACE
    // normalWS face area edit already done in vertex shader
    // so here we don't need to edit normalWS, passing isFaceArea to ToonLightingData struct is enough
    #if _FACE_MASK_ON
        lightingData.isFaceArea = input.isFaceArea;
    #else
        lightingData.isFaceArea = 1;
    #endif
#endif
    

    // toggle "_IsSkin" will affect skin lighting color
    lightingData.isSkinArea = _IsSkin;
#if _SKIN_MASK_ON
    lightingData.isSkinArea *= dot(tex2D(_SkinMaskMap, input.uv), _SkinMaskMapChannelMask);             
#endif

    // input.positionCS(: SV_POSITION) in fragment shader is in window space
    // x = [0, RT width]
    // y = [0, RT height]
    lightingData.SV_POSITIONxy = input.positionCS.xy;

    // note for future XR development:
    // ref code that may help fixing VR problem: https://docs.unity3d.com/Manual/SinglePassStereoRendering.html
    //lightingData.screenUV = input.screenPos.xy / input.screenPos.w;
    //lightingData.screenUV = UnityStereoTransformScreenSpaceTex(lightingData.screenUV);
    
    // [why not just pass abs(positionVS.z) from vertex shader? it seems it is also linearEyeDepth]
    // because we want lightingData.selfLinearEyeDepth having the same format as Convert_SV_PositionZ_ToLinearViewSpaceDepth(tex2D(_CameraDepthTexture))
    // recalcuate selfLinearEyeDepth from positionCS.z provided much better precision when doing depth texture shadow depth comparsion logic
    // a Samsung A70 mobile precision test @ 2021-3-23 confirmed depth texture shadow precision improved a lot using this line instead of abs(positionVS.z) from vertex shader  
    lightingData.selfLinearEyeDepth = Convert_SV_PositionZ_ToLinearViewSpaceDepth(input.positionCS.z);

    lightingData.SH = input.SH_fogFactor.xyz;

#if NeedCalculateAdditionalLight
    lightingData.additionalLightSum = input.additionalLightSum;
#endif

    lightingData.averageShadowAttenuation = input.normalWS_averageShadowAttenuation.w;

    // if no one use lightingData.normalVS, unity's shader compiler will remove this line's calculation,
    // same as URP's VertexPositionInputs and VertexNormalInputs struct
    lightingData.normalVS = mul((half3x3)UNITY_MATRIX_V, lightingData.normalWS).xyz;

    lightingData.reflectionVectorVS = reflect(-lightingData.viewDirectionWS,lightingData.normalWS); // see URP Lighting.hlsl

    lightingData.NdotV = saturate(dot(lightingData.normalWS,lightingData.viewDirectionWS));
    return lightingData;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step3: override surfaceData.albedo)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// [Dynamic Eye]
// currently using a simple method only
// (not HDRP's method: https://github.com/Unity-Technologies/Graphics/blob/c6ae7599b33ca48852eddd592b3e40f33f2dd982/com.unity.render-pipelines.high-definition/Runtime/Material/Eye/EyeUtils.hlsl)
#if _DYNAMIC_EYE
half3 CalculateDynamicEyeColor(float2 inputUV, float3 inputViewDirTS)
{
    // scale uv using eye center as pivot 
    float2 uv = _DynamicEyeSize * (inputUV - 0.5) + 0.5;

    // eye Pupil Alpha
    float eyePupilAlpha = dot(tex2D(_DynamicEyePupilMaskTex, uv),_DynamicEyePupilMaskTexChannelMask);

    // inner eye color (eye pupil)
    float2 offset = -0.73 * inputViewDirTS * _DynamicEyePupilDepthScale * eyePupilAlpha + uv;
    float2 normalizeResult = normalize((offset - 0.5) * 0.5);
    float2 innerEyeUV = lerp(offset, 0.5 + normalizeResult, ((0.8 / _DynamicEyeSize * _DynamicEyePupilSize ) * (1 - 2 * _DynamicEyeSize * length(inputUV - 0.5))));
    half3 innerEyeColor = tex2D(_DynamicEyePupilMap, innerEyeUV) *_DynamicEyePupilColor;

    // outer eye color (eye white)
    float2 outerEyeUV = inputUV * _DynamicEyeWhiteMap_ST.xy + _DynamicEyeWhiteMap_ST.zw;
    half3 outerEyeColor = tex2D(_DynamicEyeWhiteMap, outerEyeUV);

    // combine eye color (inner or outer by mask)
    half finalPupilMask = saturate(eyePupilAlpha / _DynamicEyePupilMaskSoftness);
    half3 combinedEyeColor = lerp(outerEyeColor, innerEyeColor, finalPupilMask);

    return combinedEyeColor * _DynamicEyeFinalTintColor * _DynamicEyeFinalBrightness;
}
#endif
void ApplyDynamicEye(inout ToonSurfaceData surfaceData, Varyings varyings, ToonLightingData lightingData)
{
#if _DYNAMIC_EYE
    surfaceData.albedo = CalculateDynamicEyeColor(varyings.uv, lightingData.viewDirectionTS);
#endif
}

// [Mat Cap(alpha blend)]
void ApplyMatCapAlphaBlend(inout ToonSurfaceData surfaceData, Varyings varyings, ToonLightingData lightingData)
{
#if _MATCAP_BLEND
    half matCapAlphaBlendFinalUsage = _MatCapAlphaBlendUsage;

    // mask by an optional mask texture
    // (decided to not use shader_feature for this mask section, else too much shader_feature is used)
    half matCapAlphaBlendMask = dot(tex2D(_MatCapAlphaBlendMaskMap, varyings.uv),_MatCapAlphaBlendMaskMapChannelMask);
    matCapAlphaBlendMask = invLerpClamp(_MatCapAlphaBlendMaskMapRemapStart, _MatCapAlphaBlendMaskMapRemapEnd, matCapAlphaBlendMask);
    matCapAlphaBlendFinalUsage *= matCapAlphaBlendMask;

    half2 matCapBlendUV = lightingData.normalVS.xy * 0.5 * _MatCapAlphaBlendUvScale + 0.5;
    half4 matCapTextureReadRGBA = tex2D(_MatCapAlphaBlendMap, matCapBlendUV) *_MatCapAlphaBlendTintColor;

    // do [alpha as mask]
    matCapAlphaBlendFinalUsage *= lerp(1,matCapTextureReadRGBA.a,_MatCapAlphaBlendMapAlphaAsMask); // allow MatCap texture's alpha channel as mask also
    surfaceData.albedo = lerp(surfaceData.albedo,matCapTextureReadRGBA.rgb,matCapAlphaBlendFinalUsage);
#endif
}

// [Mat Cap(additive)]
void ApplyMatCapAdditive(inout ToonSurfaceData surfaceData, Varyings varyings, ToonLightingData lightingData)
{
#if _MATCAP_ADD
    // read matcap texture
    float2 matCapAddUV = lightingData.normalVS.xy * (0.5 * _MatCapAdditiveUvScale) + 0.5;
    half4 matCapTextureReadRGBA = tex2D(_MatCapAdditiveMap, matCapAddUV);

    half4 matCapAdditiveRGBA = _MatCapAdditiveColor; // contains alpha also

    // intensity slider
    matCapAdditiveRGBA.rgb *= _MatCapAdditiveIntensity; // only affect rgb
    
    // mask by an optional mask texture
    // (decided to not use shader_feature for this mask section, else too much shader_feature is used)
    half matCapAdditiveMask = dot(tex2D(_MatCapAdditiveMaskMap, varyings.uv),_MatCapAdditiveMaskMapChannelMask);
    matCapAdditiveMask = invLerpClamp(_MatCapAdditiveMaskMapRemapStart, _MatCapAdditiveMaskMapRemapEnd, matCapAdditiveMask);
    matCapAdditiveRGBA.rgb *= matCapAdditiveMask; // only affect rgb

    // mix RGBA with matcap texture
    half4 result = matCapTextureReadRGBA * matCapAdditiveRGBA;

    // do [alpha as mask]
    half alphaAsMask = lerp(1,result.a,_MatCapAdditiveMapAlphaAsMask); // allow MatCap texture's alpha channel as mask also
    result.rgb *= alphaAsMask;

    surfaceData.albedo += result.rgb;
#endif
}

// [Environment Reflections]
void ApplyEnvironmentReflections(inout ToonSurfaceData surfaceData, Varyings varyings, ToonLightingData lightingData)
{
#if _ENVIRONMENTREFLECTIONS
    half smoothness = saturate(_EnvironmentReflectionSmoothnessMultiplier * surfaceData.smoothness);
    half roughness = 1-smoothness; 
    half3 environmentReflection = GlossyEnvironmentReflection(lightingData.reflectionVectorVS, roughness, surfaceData.occlusion) * _EnvironmentReflectionColor * _EnvironmentReflectionBrightness;

    half applyIntensity = _EnvironmentReflectionUsage;

    // mask by an optional mask texture
    // (decided to not use shader_feature for this mask section, else too much shader_feature is used)
    half mask = dot(tex2D(_EnvironmentReflectionMaskMap, varyings.uv),_EnvironmentReflectionMaskMapChannelMask);
    mask = invLerpClamp(_EnvironmentReflectionMaskMapRemapStart, _EnvironmentReflectionMaskMapRemapEnd, mask);
    applyIntensity *= mask; // only affect rgb

    // NdotV as mask (fresnel effect)
    applyIntensity *= lerp(1,1-lightingData.NdotV,_EnvironmentReflectionFresnelEffect);

    // apply to albedo
    //surfaceData.albedo = lerp(surfaceData.albedo,environmentReflection,applyArea);
    surfaceData.albedo *= lerp(1,environmentReflection,applyIntensity);
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step4: calculate lighting & final color)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// This function contains no lighting logic, it just pass lighting results data around.
// The job done in this function is "do shadow mapping depth test positionWS offset"
half3 ShadeAllLights(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    ///////////////////////////////////////////////////////////////////
    // Indirect light
    ///////////////////////////////////////////////////////////////////
    half3 indirectResult = ShadeGI(surfaceData, lightingData);

    ///////////////////////////////////////////////////////////////////
    // Main light
    ///////////////////////////////////////////////////////////////////
    //----------------------------------------------------------------------------
    // Light struct is provided by URP to abstract light shader variables.
    // It contains light's
    // - direction
    // - color
    // - distanceAttenuation 
    // - shadowAttenuation
    //
    // URP takes different shading approaches depending on light and platform.
    // You should never reference light shader variables in your shader, instead use the 
    // -GetMainLight()
    // -GetLight()
    // funcitons to fill this Light struct.
    //----------------------------------------------------------------------------

    // Main light is the brightest directional light.
    // It is shaded outside the light loop and it has a specific set of variables and shading path
    // so we can be as fast as possible in the case when there's only a single directional light
    // You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
    Light mainLight = GetMainLight();

    // [_ReceiveSelfShadowMappingPosOffset]
    // this uniform will control the offset distance(depth bias) of the self shadow comparsion position, 
    // doing this is usually for hiding ugly self shadow for shadow sensitive area like face
#if _NILOTOON_RECEIVE_URP_SHADOWMAPPING && _RECEIVE_URP_SHADOW
    float materialDepthBias = lerp(_ReceiveSelfShadowMappingPosOffset,_ReceiveSelfShadowMappingPosOffsetForFaceArea,lightingData.isFaceArea);
    float3 selfShadowTestPosWS = lightingData.positionWS + mainLight.direction * (materialDepthBias+_GlobalReceiveSelfShadowMappingPosOffset);

    // compute the cascade shadow coords in the fragment shader instead of vertex shader now due to this change
    // https://forum.unity.com/threads/shadow-cascades-weird-since-7-2-0.828453/#post-5516425
    float4 selfShadowCoord = TransformWorldToShadowCoord(selfShadowTestPosWS);

    // self shadow
    mainLight.shadowAttenuation = MainLightRealtimeShadow(selfShadowCoord);
    mainLight.shadowAttenuation = lerp(1,mainLight.shadowAttenuation, _ReceiveURPShadowMappingAmount * _GlobalReceiveShadowMappingAmount);
#endif 

    half3 mainLightResult = ShadeMainLight(surfaceData, lightingData, mainLight);

    ///////////////////////////////////////////////////////////////////
    // additional light
    ///////////////////////////////////////////////////////////////////
    half3 additionalLightResult = 0;
#if NeedCalculateAdditionalLight
    // default weaker occlusion for additional light
    half directOcclusion = lerp(1, surfaceData.occlusion, 0.5); // hardcode 50% usage
    additionalLightResult = lightingData.additionalLightSum * surfaceData.albedo * directOcclusion;
#endif

    ///////////////////////////////////////////////////////////////////
    // Emission
    ///////////////////////////////////////////////////////////////////
    half3 emissionResult = 0;
#if _EMISSION
    emissionResult = ShadeEmission(surfaceData, lightingData);
#endif

    ///////////////////////////////////////////////////////////////////
    // Composite all lighting result
    ///////////////////////////////////////////////////////////////////
    return CompositeAllLightResults(indirectResult, mainLightResult, additionalLightResult, emissionResult, surfaceData, lightingData);
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step5: outline color edit)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void ApplyOutlineColorOverrideByTexture(inout half3 originalSurfaceColor, ToonLightingData lightingData)
{
#if _OVERRIDE_OUTLINECOLOR_BY_TEXTURE
    half4 outlineColorOverrideTexSampleValue = tex2D(_OverrideOutlineColorTex, lightingData.uv) * _OverrideOutlineColorTexTintColor;
    outlineColorOverrideTexSampleValue.a = lerp(outlineColorOverrideTexSampleValue.a,1,_OverrideOutlineColorTexIgnoreAlphaChannel);
    originalSurfaceColor = lerp(originalSurfaceColor, outlineColorOverrideTexSampleValue.rgb, outlineColorOverrideTexSampleValue.a * _OverrideOutlineColorByTexIntensity);
#endif
}

// [Second Pass Extrude Cull front Outline]
void ApplySurfaceToOutlineColorEditIfOutlinePass(inout half3 originalSurfaceColor, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
#if NiloToonIsAnyOutlinePass
    originalSurfaceColor *= _OutlineTintColor * _PerCharacterOutlineColorTint * _GlobalOutlineTintColor;
    originalSurfaceColor *= lerp(_OutlineOcclusionAreaTintColor, 1, surfaceData.occlusion);
    originalSurfaceColor = lerp(originalSurfaceColor, _OutlineReplaceColor, _OutlineUseReplaceColor);

    // override by texture
    ApplyOutlineColorOverrideByTexture(originalSurfaceColor, lightingData);

    // override by per char script gameplay effect
    originalSurfaceColor = lerp(originalSurfaceColor, _PerCharacterOutlineColorLerp.rgb, _PerCharacterOutlineColorLerp.a);
#endif
}

void ApplySurfaceToScreenSpaceOutlineColorEditIfSurfacePass(inout half3 originalSurfaceColor, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // this function will only affect ForwardLit pass's surface pixels!
    // while outline pass will only use ApplySurfaceToOutlineColorEditIfOutlinePass(...), but not this function
#if NiloToonForwardLitPass && _SCREENSPACE_OUTLINE && _NILOTOON_GLOBAL_ENABLE_SCREENSPACE_OUTLINE

    // if _ZWrite is off (= 0), screen space outline is disabled. 
    // because if _ZWrite is off (= 0), this material should be a transparent material,
    // and transparent material won't write to _CameraDepthTexture,
    // which makes screen space outline not correct (screen space outline rely on _CameraDepthTexture and _CameraNormalsTexture),
    // so disable screen space outline automatically if _Zwrite is off 
    if(_ZWrite)
    {
        // outline width
        float finalOutlineWidth = lerp(_ScreenSpaceOutlineWidth, _ScreenSpaceOutlineWidthIfFace, lightingData.isFaceArea) * _GlobalScreenSpaceOutlineWidthMultiplierForChar;

        // depth sensitivity
        float finalDepthSensitivity = max(0,lerp(_ScreenSpaceOutlineDepthSensitivity, _ScreenSpaceOutlineDepthSensitivityIfFace, lightingData.isFaceArea) + _GlobalScreenSpaceOutlineDepthSensitivityOffsetForChar);
        // depth sensitivity texture apply
        half4 depthSensitivityTexValue = tex2D(_ScreenSpaceOutlineDepthSensitivityTex, lightingData.uv);
        half depthSensitivityMultiplierByTex = dot(depthSensitivityTexValue, _ScreenSpaceOutlineDepthSensitivityTexChannelMask);
        depthSensitivityMultiplierByTex = invLerpClamp(_ScreenSpaceOutlineDepthSensitivityTexRemapStart, _ScreenSpaceOutlineDepthSensitivityTexRemapEnd, depthSensitivityMultiplierByTex); // should remap first,
        finalDepthSensitivity *= depthSensitivityMultiplierByTex;

        // normals sensitivity
        float finalNormalsSensitivity = max(0,lerp(_ScreenSpaceOutlineNormalsSensitivity, _ScreenSpaceOutlineNormalsSensitivityIfFace, lightingData.isFaceArea) + _GlobalScreenSpaceOutlineNormalsSensitivityOffsetForChar);
        // normals sensitivity texture apply
        half4 normalsSensitivityTexValue = tex2D(_ScreenSpaceOutlineNormalsSensitivityTex, lightingData.uv);
        half normalsSensitivityMultiplierByTex = dot(normalsSensitivityTexValue, _ScreenSpaceOutlineNormalsSensitivityTexChannelMask);
        normalsSensitivityMultiplierByTex = invLerpClamp(_ScreenSpaceOutlineNormalsSensitivityTexRemapStart, _ScreenSpaceOutlineNormalsSensitivityTexRemapEnd, normalsSensitivityMultiplierByTex); // should remap first,
        finalNormalsSensitivity *= normalsSensitivityMultiplierByTex;
        //----------------------------------------------------------------------------------------------------------------------------------------
        float isScreenSpaceOutlineArea = IsScreenSpaceOutline(lightingData.SV_POSITIONxy, 
            finalOutlineWidth, 
            finalDepthSensitivity, 
            finalNormalsSensitivity, 
            lightingData.selfLinearEyeDepth, 
            _GlobalScreenSpaceOutlineDepthSensitivityDistanceFadeoutStrengthForChar,
            _CurrentCameraFOV);
        
        isScreenSpaceOutlineArea *= _GlobalScreenSpaceOutlineIntensityForChar; // intensity control
        originalSurfaceColor *= lerp(1,_ScreenSpaceOutlineTintColor * _GlobalScreenSpaceOutlineTintColorForChar,isScreenSpaceOutlineArea);
        originalSurfaceColor *= lerp(_ScreenSpaceOutlineOcclusionAreaTintColor, 1, surfaceData.occlusion);

        originalSurfaceColor = lerp(originalSurfaceColor, _ScreenSpaceOutlineReplaceColor, _ScreenSpaceOutlineUseReplaceColor * isScreenSpaceOutlineArea);
        
        // override by texture
        half3 originalSurfaceColorBeforeOverrideByTexture = originalSurfaceColor;
        ApplyOutlineColorOverrideByTexture(originalSurfaceColor, lightingData);
        originalSurfaceColor = lerp(originalSurfaceColorBeforeOverrideByTexture, originalSurfaceColor, isScreenSpaceOutlineArea);       
    }
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step6: per volume and per character color edit)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// [Volume]
void ApplyVolumeEffectColorEdit(inout half3 color)
{
    //////////////////////////////////////////////////////////////////////////////////
    // (not lighting, usually for cinematic needs like cut scene)
    //////////////////////////////////////////////////////////////////////////////////
    color *= _GlobalVolumeMulColor;
    color = lerp(color,_GlobalVolumeLerpColor.rgb,_GlobalVolumeLerpColor.a);
}
// [Per Character script]
void ApplyPerCharacterEffectColorEdit(inout half3 color, ToonLightingData lightingData)
{
    //////////////////////////////////////////////////////////////////////////////////
    // (not lighting, usually for gameplay needs like charcater selection)
    //////////////////////////////////////////////////////////////////////////////////
    // mul add
    color.rgb = color.rgb * _PerCharEffectTintColor + _PerCharEffectAddColor;

    // desaturate
    color = lerp(color,Luminance(color), _PerCharEffectDesaturatePercentage);

    // lerp
    color.rgb = lerp(color.rgb,_PerCharEffectLerpColor.rgb,_PerCharEffectLerpColor.a);

    // rim light (outline pass don't need this)
#if NiloToonForwardLitPass
    // Use normalWS from ToonLightingData, not Varying input, 
    // because ToonLightingData's normalWS is normalmap applied & normalized.
    // But using normalWS from Varying is ok also, it is just shader design choice
    half NdotV = lightingData.NdotV;
    half rim = 1-NdotV;
    // pow(x,4)
    rim*=rim;
    rim*=rim;

    // apply(additive)
    color.rgb += rim * _PerCharEffectRimColor * (1-lightingData.isFaceArea); // rim light not show on face because it looks ugly
#endif

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step7: fog)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void ApplyFog(inout half3 color, Varyings input)
{
    // Mix the pixel color with fog color. 
    // You can optionally use MixFogColor to override the fog color with a custom one.
    color = MixFog(color, input.SH_fogFactor.w);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions (Step8: override final output alpha)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void ApplyOverrideOutputAlpha(inout half outputAlpha)
{
    // not worth an if() here, so use a?b:c
    outputAlpha = _EditFinalOutputAlphaEnable ? (_ForceFinalOutputAlphaEqualsOne ? 1.0 : outputAlpha) : outputAlpha;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// only NiloToonCharacter.shader will be able to call this function by using
// #pragma fragment FragmentShaderAllWork
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
half4 FragmentShaderAllWork(Varyings input, half facing : VFACE) : SV_TARGET
{
    // flip normalWS by VFace
    // TODO: recheck if this fix is correct or not
    input.normalWS_averageShadowAttenuation.xyz *= facing;

    // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
    //------------------------------------------------------------------------------------------------------------------------------
    UNITY_SETUP_INSTANCE_ID(input);                     // in non OpenGL and non PSSL, MACRO will turn into -> UnitySetupInstanceID(input.instanceID);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);    // in non OpenGL and non PSSL, MACRO will turn into -> unity_StereoEyeIndex = input.stereoTargetEyeIndexAsRTArrayIdx;
    //------------------------------------------------------------------------------------------------------------------------------

    //////////////////////////////////////////////////////////////////////////////////////////
    // insert a performance debug minimum shader early exit section here
    //////////////////////////////////////////////////////////////////////////////////////////
    // exit asap, to maximize performance difference
    // doing this can create a net GPU time difference between "Unlit/Texture" vs "full fragment shader"
    // which reflect the cost of this shader quite correctly on target device
#if _NILOTOON_FORCE_MINIMUM_SHADER
    return Get_NILOTOON_FORCE_MINIMUM_FRAGMENT_SHADER_result(input);
#endif

    //////////////////////////////////////////////////////////////////////////////////////////
    // prepare all data struct for lighting function
    //////////////////////////////////////////////////////////////////////////////////////////
    ToonSurfaceData surfaceData = InitializeSurfaceData(input);
    ToonLightingData lightingData = InitializeLightingData(input, surfaceData);
    return half4((half3)surfaceData.albedo, 1.f);
    //////////////////////////////////////////////////////////////////////////////////////////
    // insert debug shading early exit section here
    //////////////////////////////////////////////////////////////////////////////////////////
#if _NILOTOON_DEBUG_SHADING
    return Get_NILOTOON_DEBUG_SHADING_result(input, surfaceData, lightingData);
#endif

    //////////////////////////////////////////////////////////////////////////////////////////
    // apply struct ToonSurfaceData's edit (using lightingData's data also)
    //////////////////////////////////////////////////////////////////////////////////////////
    ApplyDynamicEye(surfaceData, input, lightingData);
    ApplyEnvironmentReflections(surfaceData, input, lightingData);
    ApplyMatCapAlphaBlend(surfaceData, input, lightingData);
    ApplyMatCapAdditive(surfaceData, input, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // apply all lighting calculation
    //////////////////////////////////////////////////////////////////////////////////////////    
    half3 color = ShadeAllLights(surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // apply outline color calculation
    //////////////////////////////////////////////////////////////////////////////////////////  
    ApplySurfaceToOutlineColorEditIfOutlinePass(color, surfaceData, lightingData);
    ApplySurfaceToScreenSpaceOutlineColorEditIfSurfacePass(color, surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // apply per volume and per character color edit
    //////////////////////////////////////////////////////////////////////////////////////////  
    ApplyVolumeEffectColorEdit(color);
    ApplyPerCharacterEffectColorEdit(color, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // apply fog (with extend logic functions before and after fog)
    //////////////////////////////////////////////////////////////////////////////////////////
    ApplyExternalAssetSupportLogicBeforeFog(color, surfaceData, lightingData);
    ApplyCustomUserLogicBeforeFog(color, surfaceData, lightingData);
    ApplyFog(color, input);
    ApplyExternalAssetSupportLogicAfterFog(color, surfaceData, lightingData);
    ApplyCustomUserLogicAfterFog(color, surfaceData, lightingData);

    //////////////////////////////////////////////////////////////////////////////////////////
    // override output alpha
    //////////////////////////////////////////////////////////////////////////////////////////
    ApplyOverrideOutputAlpha(surfaceData.alpha);

    return half4(color, surfaceData.alpha);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions 
// (only for ShadowCaster pass, DepthOnly and NiloToonSelfShadowCaster pass to use only)
// (not used in other pass)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void BaseColorAlphaClipTest(Varyings input)
{
    // if _AlphaClip is off, there is no reason to call GetFinalBaseColor()
    // so here we use #if _ALPHATEST_ON to avoid calling GetFinalBaseColor() as an optimization
#if _ALPHATEST_ON
    DoClipTestToTargetAlphaValue(GetFinalBaseColor(input).a);
#endif
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// fragment shared functions 
// (only for DepthNormal pass to use only)
// (not used in other pass)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float4 BaseColorAlphaClipTest_AndDepthNormalColorOutput(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    BaseColorAlphaClipTest(input);

    return float4(PackNormalOctRectEncode(TransformWorldToViewDir(input.normalWS_averageShadowAttenuation.xyz, true)), 0.0, 0.0);
}