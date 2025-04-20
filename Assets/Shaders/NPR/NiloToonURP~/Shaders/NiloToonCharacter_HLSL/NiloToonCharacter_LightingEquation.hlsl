// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// calculate main light's shadow area's color, 
// main light's light color is NOT considered in this function yet!
// this function only apply hsv edit then multiply tint color to rawAlbedo, then return a shadow color
half3 CalculateLightIndependentSelfShadowAlbedoColor(ToonSurfaceData surfaceData, ToonLightingData lightingData, half finalShadowArea)
{
    half3 rawAlbedo = surfaceData.albedo;
    half isFace = lightingData.isFaceArea;
    half isSkin = lightingData.isSkinArea;
    float2 uv = lightingData.uv;

    // if inside LitToShadowTransitionArea, later we edit hsv and tint extra color
    half isLitToShadowTransitionArea = saturate((1-abs(finalShadowArea-0.5)*2)*_LitToShadowTransitionAreaIntensity);

    // [hsv]
    half HueOffset = _SelfShadowAreaHueOffset + _LitToShadowTransitionAreaHueOffset * isLitToShadowTransitionArea;
    half SaturationBoost = _SelfShadowAreaSaturationBoost + _LitToShadowTransitionAreaSaturationBoost * isLitToShadowTransitionArea;
    half ValueMul = _SelfShadowAreaValueMul * lerp(1,_LitToShadowTransitionAreaValueMul, isLitToShadowTransitionArea);

    half3 originalColorHSV; // for output from ApplyHSVChange(...)
    half3 result = ApplyHSVChange(rawAlbedo, HueOffset, SaturationBoost, ValueMul, originalColorHSV);

    // [suppress hsv result's 0/low saturation color's random hue artifact due to GPU texture compression]
    half3 fallbackColor = rawAlbedo * _LowSaturationFallbackColor.rgb;
    result = lerp(fallbackColor,result, lerp(1,saturate(originalColorHSV.y * 5),_LowSaturationFallbackColor.a)); //only 0~20% saturation area affected, 0% saturation area use 100% fallback

    // [tint]
    result *= _SelfShadowTintColor;

    // [lit to shadow area transition tint]
    result *= lerp(1,_LitToShadowTransitionAreaTintColor, isLitToShadowTransitionArea);

    ////////////////////////////////////////////
    // override if skin
    ////////////////////////////////////////////
    // skin can optionally completely override to just a simple single color tint
    result = lerp(result, rawAlbedo * _SkinShadowTintColor, isSkin * _OverrideBySkinShadowTintColor);

    ////////////////////////////////////////////
    // override if face
    ////////////////////////////////////////////
#if _ISFACE
    // face optionally completely override to just a simple single color tint
    result = lerp(result, rawAlbedo * _FaceShadowTintColor, isFace * _OverrideByFaceShadowTintColor); 
#endif

    ////////////////////////////////////////////
    // override by user's shadow color texture
    ////////////////////////////////////////////
#if _OVERRIDE_SHADOWCOLOR_BY_TEXTURE
    half4 shadowColorOverrideTexSampleValue = tex2D(_OverrideShadowColorTex, uv) * _OverrideShadowColorTexTintColor;
    shadowColorOverrideTexSampleValue.a = lerp(shadowColorOverrideTexSampleValue.a,1,_OverrideShadowColorTexIgnoreAlphaChannel);
    result = lerp(result, shadowColorOverrideTexSampleValue.rgb, shadowColorOverrideTexSampleValue.a * _OverrideShadowColorByTexIntensity);
#endif
    return result;
}

half3 ShadeGI(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // occlusion, force target area become shadow
    // separated control for direct/indirect occlusion
    half indirectOcclusion = 1;
#if _OCCLUSIONMAP
    // default weaker occlusion for indirect
    indirectOcclusion = lerp(1, surfaceData.occlusion, 0.5); // hardcode 50% usage
#endif
    half3 indirectLight = lightingData.SH * indirectOcclusion;

    // max() can prevent result completely black, if lightprobe was not baked and no direct light is active
    return max(indirectLight, _GlobalIndirectLightMinColor) * surfaceData.albedo; 
}

// Most important function: lighting equation for main direcional light
// Also this is the heaviest method!
half3 ShadeMainLight(ToonSurfaceData surfaceData, ToonLightingData lightingData, Light light)
{
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Common data
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // unused result will be removed by compiler, don't worry performance if you don't use it
    half3 N = lightingData.normalWS;
    half3 L = light.direction;

    half3 V = lightingData.viewDirectionWS;
    half3 H = normalize(L+V);

    half NoL = dot(N,L); // no need saturate() due to smoothstep()
    half NoV = saturate(dot(N,V));
    half NoH = dot(N,H);
    half VoV = saturate(dot(V,V));

    half orthographicCameraAmount = lerp(unity_OrthoParams.w,1,_PerspectiveRemovalAmount);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Lit
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // remapped N dot L
    // simplest 1 line cel shade, you can always replace this line by your method, like a grayscale ramp texture.
    // celShadeResult: 0 is in shadow, 1 is in light
    half smoothstepNoL = smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);

    // if you don't want direct lighting's NdotL cel shade effect looks too strong, set _MainLightIgnoreCelShade to a higher value
    half selfLightAttenuation = lerp(smoothstepNoL,1, _MainLightIgnoreCelShade);

#if _ISFACE
    half celShadeResultForFaceArea = smoothstep(_CelShadeMidPointForFaceArea-_CelShadeSoftnessForFaceArea,_CelShadeMidPointForFaceArea+_CelShadeSoftnessForFaceArea, NoL);
    half selfLightAttenuationForFaceArea = lerp(celShadeResultForFaceArea,1, _MainLightIgnoreCelShadeForFaceArea);
    // apply, mix with original selfLightAttenuation result
    selfLightAttenuation = lerp(selfLightAttenuation, selfLightAttenuationForFaceArea, _OverrideCelShadeParamForFaceArea * lightingData.isFaceArea);
#endif

    // occlusion, force target area become shadow
    // separated control for direct/indirect occlusion
#if _OCCLUSIONMAP
    half directOcclusion = surfaceData.occlusion; // hardcode 100% usage
    selfLightAttenuation *= directOcclusion;
#endif

#if _NILOTOON_RECEIVE_URP_SHADOWMAPPING
    // regular URP shadowmap but with sample position offset (extra depth bias), usually for avoiding ugly shadow map on face
    selfLightAttenuation *= light.shadowAttenuation;
#endif

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // "_CameraDepthTexture depth" vs "self depth" difference 2D rim light and 2D shadow
    // (if _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW is off, 2D rim light will fall back to classic NoV rim light)
    // (if _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW is off, 2D shadow don't have fallback)
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    half depthDiffShadow = 1;
#if NiloToonForwardLitPass
    #if _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Get _CameraDepthTexture linear depth at offseted screen position
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // for perspective camera, reduce width when camera move away, but clamp at max = 1 using 1/(1+x) if camera is very close to vertex
        // for orthographic camera, disable camera distance fix(only return a constant 0.7 to match perspective's result) since distance/depth will not affect polygon NDC xy position on screen
        float cameraDistanceFix = unity_OrthoParams.w ? 0.7 : rcp(lightingData.selfLinearEyeDepth+1); // no need to care orthographicCameraAmount, this line is already correct

        // allow width per material and global edit
        // group all float1 to calculate first for better performance
        float2 UvOffsetMultiplier = _GlobalAspectFix * (_DepthTexRimLightAndShadowWidthMultiplier * _GlobalDepthTexRimLightAndShadowWidthMultiplier * _GlobalFOVorOrthoSizeFix * cameraDistanceFix);
        #if _ISFACE
            // face area shadow width is smaller since it is for hair, smaller width is better
            UvOffsetMultiplier *= lerp(1,0.66666,lightingData.isFaceArea); 
        #endif
        float2 finalUVOffset = _GlobalMainLightDirVS.xy * UvOffsetMultiplier; 

        // [prepare depth data for finding the edge of character]
        // here we sample _CameraDepthTexture once only, and use it as both rim light and shadow's input, 
        // very nice performance win if compared to sample _CameraDepthTexture twice, but we lost the ability to edit width separately (e.g. rim and shadow separated width)
        // use LOAD instead of sample for better performance since we don't need mipmap of depth texture
        int2 loadTexPos = lightingData.SV_POSITIONxy + finalUVOffset * _CameraDepthTexture_TexelSize.zw;
        loadTexPos = min(loadTexPos,_CameraDepthTexture_TexelSize.zw-1); // clamp loadTexPos to prevent loading outside of _CameraDepthTexture's valid area
        float depthTextureRawSampleValue = LoadSceneDepth(loadTexPos); 
        float depthTextureLinearDepthVS = Convert_SV_PositionZ_ToLinearViewSpaceDepth(depthTextureRawSampleValue);

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Calculate depth texture screen space rim light
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        float depthTexRimLightDepthDiffThreshold = 0.05;
        float rimLightdepthDiffThreshold = saturate(depthTexRimLightDepthDiffThreshold + _GlobalDepthTexRimLightDepthDiffThresholdOffset);

        // counter/cancel face area ZOffset rendered in _CameraDepthTexture(DepthOnly pass)
        rimLightdepthDiffThreshold += FACE_AREA_DEPTH_TEXTURE_ZOFFSET * lightingData.isFaceArea; 

        // let rim light fadeout softly when depth difference is too small
        half depthDiffRimAttenuation = saturate((depthTextureLinearDepthVS - (lightingData.selfLinearEyeDepth + rimLightdepthDiffThreshold))*10);

        // TODO: write a better fwidth() method to produce anti-aliased 2D rim light, which worth the performance cost
        //      reference resources (need SDF input, which we don't have):
        //      - https://forum.unity.com/threads/antialiasing-circle-shader.432119/#post-2796401
        // the below example line = if fwidth() detected any difference within a 2x2 pixel block, replace depthDiffRimAttenuation 1 to 0.6666, replace depthDiffRimAttenuation 0 to 0.3333
        // but it doesn't look good, so disabled
        //depthDiffRimAttenuation = fwidth(depthDiffRimAttenuation) > 0 ? depthDiffRimAttenuation * 0.3333 + 0.333 : depthDiffRimAttenuation;

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // calculate depth texture screen space shadow
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // hardcode threshold to reduce material inspector complexity
        float depthTexShadowDepthDiffThreshold = 0.03;
        // face override using a smaller threshold, since depth a pushed in _CameraDepthTexture already
        #if _ISFACE
            depthTexShadowDepthDiffThreshold = lerp(depthTexShadowDepthDiffThreshold,0.01, lightingData.isFaceArea);
        #endif
        // user per material control (default 0)
        depthTexShadowDepthDiffThreshold += _DepthTexShadowThresholdOffset;

        // let shadow fadeout softly when depth difference is too small
        depthDiffShadow = saturate((depthTextureLinearDepthVS - (lightingData.selfLinearEyeDepth - depthTexShadowDepthDiffThreshold))*50 / _DepthTexShadowFadeoutRange);
        depthDiffShadow = lerp(1,depthDiffShadow,_DepthTexShadowUsage);
    #else
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // (if depth texture rim light not enabled)
        // fall back to this classic NoV rim
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // extract camera forward from V matrix, it works because V matrix's scale is always 1, 
        // so we can use Z basis vector inside the 3x3 part of V matrix as camera forward directly 
        // https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab
        // https://answers.unity.com/questions/192553/camera-forward-vector-in-shader.html
        // *use UNITY_MATRIX_I_V instead of unity_CameraToWorld, since unity_CameraToWorld is not flipped between PC & PCVR mode
        half3 neg_cameraViewForwardDirWS = UNITY_MATRIX_I_V._m02_m12_m22;

        // [fresnel]
        // - ortho camera use dot(N, -cameraForward) instead of dot(N,V), so rim result is the same no matter where the pixel is on screen 
        // - perspective camera use dot(N,V), as usual
        half NoVForRimOrtho = saturate(dot(N, neg_cameraViewForwardDirWS));
        half NoVForRimPerspective = NoV;
        half NoVForRimResult = lerp(NoVForRimPerspective,NoVForRimOrtho, orthographicCameraAmount);
        half NoVRimFresnelAttenuation = 1 - NoVForRimResult; 

        // *= NoL mask
        NoVRimFresnelAttenuation *= saturate(NoL) * 0.25 + 0.75;
        NoVRimFresnelAttenuation *= NoL > 0;

        // *= remove rim on face
        NoVRimFresnelAttenuation *= 1-lightingData.isFaceArea;

        // remap rim, try to match depth tex 2D rim light's result
        // use fwidth() to remove big area flat polygon's rim light pop
        half midPoint = 0.7;
        half width = 0.02;
        half fwidthFix = saturate(fwidth(NoVRimFresnelAttenuation) * 50);
        NoVRimFresnelAttenuation = smoothstep(midPoint-width,midPoint+width,NoVRimFresnelAttenuation) * fwidthFix;
    #endif
#endif

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Char self shadow map
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    half selfShadowMapShadow = 1; // default no self shadow map effect

#if _NILOTOON_RECEIVE_SELF_SHADOW
    if(_EnableNiloToonSelfShadowMapping)
    {
        // matrix mul is heavy(= 3 dot()), but better than passing from Varyings due to interpolation cost 
        float4 positionSelfShadowCS = mul(_NiloToonSelfShadowWorldToClip, float4(lightingData.positionWS.xyz,1)); 

        // ortho camera shadow map can remove /w since positionSelfShadowCS.w is always 1
        //float3 positionSelfShadowNDC = positionSelfShadowCS.xyz / positionSelfShadowCS.w; // no need this line's /w
        float3 positionSelfShadowNDC = positionSelfShadowCS.xyz; // this line is enough

        // convert ndc.xy[-1,1] to uv[0,1]
        float2 shadowMapUV_XY = positionSelfShadowNDC.xy * 0.5 + 0.5;

        // calculate SAMPLE_TEXTURE2D_SHADOW(...)'s ndc.z compare value
        //---------------------------------------------------------
        float ndcZCompareValue = positionSelfShadowNDC.z;

        // if OpenGL, convert ndc.z [-1,1] to shadowmap's [0,1], because shadowmap always within 0~1 range, for any platform
        // if DirectX, do nothing, it is 0~1 range already
        ndcZCompareValue = UNITY_NEAR_CLIP_VALUE < 0 ? ndcZCompareValue * 0.5 + 0.5 : ndcZCompareValue;

        // +z compare bias in ndc.z [0,1] space, also apply DirectX's reverse depth to bias
        ndcZCompareValue += (_NiloToonGlobalSelfShadowDepthBias+_NiloToonSelfShadowMappingDepthBias) * UNITY_NEAR_CLIP_VALUE;
        //---------------------------------------------------------

        // if DirectX, flip uv's y (y = 1-y)
        // if OpenGL, do nothing
        #if UNITY_UV_STARTS_AT_TOP
        shadowMapUV_XY.y = 1 - shadowMapUV_XY.y;
        #endif

        float4 selfShadowmapUV = float4(shadowMapUV_XY,ndcZCompareValue,0); // packing for SAMPLE_TEXTURE2D_SHADOW

        // URP's 4 tap(mobile)/ 9 tap(non-mobile) soft shadow, reuse URP's _SHADOWS_SOFT keyword to avoid using more multi_compile, 
        // but it may be still too costly for mobile even it is just 4 tap
    #if _SHADOWS_SOFT
        ShadowSamplingData shadowData;
        shadowData.shadowOffset0 = float4(+_NiloToonSelfShadowParam.x,+_NiloToonSelfShadowParam.y,0,0);
        shadowData.shadowOffset1 = float4(-_NiloToonSelfShadowParam.x,+_NiloToonSelfShadowParam.y,0,0);
        shadowData.shadowOffset2 = float4(+_NiloToonSelfShadowParam.x,-_NiloToonSelfShadowParam.y,0,0);
        shadowData.shadowOffset3 = float4(-_NiloToonSelfShadowParam.x,-_NiloToonSelfShadowParam.y,0,0);
        shadowData.shadowmapSize = _NiloToonSelfShadowParam;
        selfShadowMapShadow = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(_NiloToonCharSelfShadowMapRT, sampler_NiloToonCharSelfShadowMapRT),selfShadowmapUV,shadowData);
        // (optional) sharpen shadow
        //selfShadowMapShadow = smoothstep(0.25,0.75,selfShadowMapShadow);
    #else
        // 1 sample only, let hardware do the 1 tap bilinear filter, which is 0 cost filtering
        selfShadowMapShadow = SAMPLE_TEXTURE2D_SHADOW(_NiloToonCharSelfShadowMapRT, sampler_NiloToonCharSelfShadowMapRT, selfShadowmapUV);
    #endif

        // fadeout shadow if reaching the end of shadow distance (always use 2m from start fade to end fade)
        float fadeTotalDistance = 2; // hardcode now, can expose to C# if needed
        selfShadowMapShadow = lerp(selfShadowMapShadow,1, saturate((1/fadeTotalDistance) * (abs(lightingData.selfLinearEyeDepth)-(_NiloToonSelfShadowRange-fadeTotalDistance))));       

        // use additional N dot ShadowLight's L to hide self shadowmap artifact
        // smoothstep values 0.1,0.2 are based on observation only just to hide the artifact, no meaning
        selfShadowMapShadow *= _NiloToonSelfShadowUseNdotLFix ? smoothstep(0.1,0.2,saturate(dot(lightingData.normalWS, _NiloToonSelfShadowLightDirection))) : 1;

        // let user control self shadow intensity per material
        // For non-face, intensity is default 1
        // For face, intensity is default 0, because most of the time shadow map on face is ugly
        // TODO: add global volume control?
        half selfShadowIntensity = lerp(_NiloToonSelfShadowIntensityForNonFace,_NiloToonSelfShadowIntensityForFace,lightingData.isFaceArea);
        selfShadowMapShadow = lerp(1,selfShadowMapShadow, selfShadowIntensity);
    }
#endif
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Lit
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
#if _RAMP_LIGHTING
    half rampUvX = (NoL * 0.5 + 0.5);
    rampUvX *= depthDiffShadow;
    rampUvX *= selfShadowMapShadow;
    #if _OCCLUSIONMAP
        rampUvX *= surfaceData.occlusion;
    #endif
    #if _NILOTOON_RECEIVE_URP_SHADOWMAPPING
        // regular URP shadowmap but with sample position offset (extra depth bias), usually for avoiding ugly shadow map on face
        selfLightAttenuation *= light.shadowAttenuation;
    #endif
    half rampLightingTexSamplingUvY;
    #if _RAMP_LIGHTING_SAMPLE_UVY_TEX
        rampLightingTexSamplingUvY = tex2D(_RampLightingSampleUvYTex, lightingData.uv).g;
    #else
        rampLightingTexSamplingUvY = _RampLightingTexSampleUvY;
    #endif
    // we need to sample ramp texture using clamp sampler, else uv.x == 0 may still sampled uv.x == 1's position
    half3 lightColorIndependentLitColor = surfaceData.albedo * SAMPLE_TEXTURE2D(_RampLightingTex,linear_clamp_sampler,half2(rampUvX, rampLightingTexSamplingUvY));
#else
    half finalShadowArea = selfLightAttenuation * depthDiffShadow * selfShadowMapShadow;
    half3 inSelfShadowAlbedoColor = CalculateLightIndependentSelfShadowAlbedoColor(surfaceData, lightingData, finalShadowArea);
    half3 lightColorIndependentLitColor = lerp(inSelfShadowAlbedoColor,surfaceData.albedo, finalShadowArea);
#endif

    // extra user defined color tint control to shadow area
#if NiloToonForwardLitPass
    #if _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW
        // make depth tex shadow a little bit darker
        // because depth tex shadow is similar to contact shadow, shadow caster and receiver position is close, which means shadow is strong
        // we want depth tex shadow to have a bit different to self shadow to produce richer shadow, so default * 0.85
        half3 finalDepthTexShadowTintColor = _DepthTexShadowTintColor * 0.85;
        #if _ISFACE
            // if face, override to constant high saturation red tint
            half3 faceDepthTexShadowTintColor = half3(1,0.85,0.85);
            finalDepthTexShadowTintColor = lerp(finalDepthTexShadowTintColor, faceDepthTexShadowTintColor, lightingData.isFaceArea);
        #endif
        lightColorIndependentLitColor *= lerp(finalDepthTexShadowTintColor,1,depthDiffShadow);
    #endif
    #if _NILOTOON_RECEIVE_URP_SHADOWMAPPING 
        lightColorIndependentLitColor *= lerp(_URPShadowMappingTintColor,1,light.shadowAttenuation);
    #endif
#endif

    // for all add light to use in the following code(specular,rim light, hair strand specular....), to reduce add light if in shadow
    half inShadow25PercentMul = lerp(lightingData.averageShadowAttenuation,1,0.25);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Specular
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if _SPECULARHIGHLIGHTS
    half3 specularLitAdd = surfaceData.specular;

    // allow user select simple NoV or GGX specular method
    half SpecularRawArea;
    if(_UseGGXDirectSpecular)
    {
        SpecularRawArea = GGXDirectSpecular_LequalsV_Optimized(NoV,VoV,1-saturate(surfaceData.smoothness * _GGXDirectSpecularSmoothnessMultiplier),0.04);// only support non-metal now, hardcord 0.04 F0
    }
    else
    {
        SpecularRawArea = NoV;
    }
    half specularRemapStartPoint = max(0,_SpecularAreaRemapMidPoint-_SpecularAreaRemapRange);
    half specularRemapEndPoint = min(1,_SpecularAreaRemapMidPoint+_SpecularAreaRemapRange);
    half remappedSpecularRawArea = smoothstep(specularRemapStartPoint,specularRemapEndPoint, SpecularRawArea);
    remappedSpecularRawArea = lerp(SpecularRawArea, remappedSpecularRawArea, _SpecularAreaRemapUsage); // allow user to cancel specular remap
    half3 specularResultRGBMultiplier = remappedSpecularRawArea;

    #if _RAMP_SPECULAR
    {
        // this section will override specularResultRGBMultiplier
        half rampSpecularTexSamplingUvY;
        #if _RAMP_SPECULAR_SAMPLE_UVY_TEX
            rampSpecularTexSamplingUvY = tex2D(_RampSpecularSampleUvYTex, lightingData.uv).g;
        #else
            rampSpecularTexSamplingUvY = _RampSpecularTexSampleUvY;
        #endif

        half rampUvX = saturate(remappedSpecularRawArea);
        specularResultRGBMultiplier = SAMPLE_TEXTURE2D(_RampSpecularTex,linear_clamp_sampler,half2(rampUvX, rampSpecularTexSamplingUvY));
    }
    #endif

    specularLitAdd *= specularResultRGBMultiplier;

    // max(0.25,x), to prevent 0 specular if Directional Light is off
    // saturate(x), to prevent over bright
    specularLitAdd *= saturate(max(0.25,light.color)) * _GlobalSpecularIntensityMultiplier; 
    // keep 25% specular in 0% direct light(in shadow) enviroment
    specularLitAdd *= lerp(lightingData.averageShadowAttenuation,1,_GlobalSpecularMinIntensity); 
#endif

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Kajiya-Kay specular for hair
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if _KAJIYAKAY_SPECULAR
    half3 kajiyaSpecularAdd = 0;
    half3 shiftedT = ShiftTangent(lightingData.TBN_WS[1], lightingData.uv.x);
    half3 HforStrandSpecular = normalize(half3(0,1,0) + V); // L+V, where L = (0,1,0) because it looks more stable
    kajiyaSpecularAdd += ((StrandSpecular(shiftedT, HforStrandSpecular,_HairStrandSpecularMainExponent))) * _HairStrandSpecularMainColor; //sharp
    kajiyaSpecularAdd += ((StrandSpecular(shiftedT, HforStrandSpecular,_HairStrandSpecularSecondExponent))) * _HairStrandSpecularSecondColor; //soft
    kajiyaSpecularAdd *=  0.02; // * 0.02 to allow _HairStrandSpecularMainColor & _HairStrandSpecularSecondColor's default value is white

    // not mul inShadow25PercentMul because it looks better in shadow area
    // ...

    // max(0.25,x), to prevent 0 specular if Directional Light is off
    // saturate(x), to prevent over bright
    kajiyaSpecularAdd *= saturate(max(0.25,light.color));       
#endif

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Composite final main light color
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // apply light color to the whole body at the final stage, it is better for toon shading style's need 
    // min(X,light.color) to prevent over bright, ideally we want to tonemap it, but for performance reason, just min looks good enough
    half3 result = min(_GlobalMainDirectionalLightMaxContribution, light.color * lightingData.averageShadowAttenuation) * lightColorIndependentLitColor * _GlobalMainDirectionalLightMultiplier;

    // darken direct light by URP shadow (control by volume)
#if _NILOTOON_RECEIVE_URP_SHADOWMAPPING
    // regular URP shadowmap but with sample position offset (extra depth bias), usually for avoiding ugly shadow map on face
    result *= lerp(_GlobalMainLightURPShadowAsDirectResultTintColor,1,light.shadowAttenuation);
#endif
    
    // apply all add light to lit pass (ignore outline pass)
#if NiloToonForwardLitPass && _SPECULARHIGHLIGHTS
    #if _RAMP_SPECULAR
    result = lerp(result,specularLitAdd, remappedSpecularRawArea * selfShadowMapShadow * lightingData.averageShadowAttenuation);
    #else
    result += specularLitAdd;
    #endif 
#endif
#if NiloToonForwardLitPass
    // _ZWrite is * to _DepthTexRimLightUsage, 
    // because if _ZWrite is off (=0), this material should be a transparent material,
    // and transparent material wont write to _CameraDepthTexture,
    // which makes depth texture rim light not correct,
    // so disable depth texture rim light automatically if _Zwrite is off 
    half3 rimLightColor = min(2,light.color) * _DepthTexRimLightTintColor * (_DepthTexRimLightUsage * _ZWrite); // min() to prevent over bright light.color
    rimLightColor = (0.05 + rimLightColor / 6.0); // rim light use light's color, + a small constant term to prevent 0% rim light when no light
    rimLightColor *= _GlobalRimLightMultiplier;
    
    #if _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW
    half rimAttenuation = depthDiffRimAttenuation;
    #else
    half rimAttenuation = NoVRimFresnelAttenuation;
    #endif

    rimAttenuation *= inShadow25PercentMul; // if in shadow area, reduce rim light

    result += rimAttenuation * rimLightColor;

    #if _KAJIYAKAY_SPECULAR
    result += kajiyaSpecularAdd;
    #endif
#endif

    return result;
}

half3 CalculateAdditiveSingleAdditionalLight(half3 N, Light light)
{
    ////////////////////////////////////////////////////////////////////////////////
    // there can be LOTs of additional lights, 
    // so additional lights use a very simple method for performance reason
    ////////////////////////////////////////////////////////////////////////////////

    half SphereNoL = dot(N,light.direction);
  
    half lightAttenuation = SphereNoL * 0.2 + 0.8; // 1/5 lambert, we want to hide 3D feel

    // distance and shadow
    // distance attenuation min(1,x) to prevent over bright if light too close to vertex
    lightAttenuation *= min(1,light.distanceAttenuation) * light.shadowAttenuation * 0.5; // default * 0.5 to make additional light weaker 

    return light.color * lightAttenuation;  
}

half3 ShadeEmission(ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // do nothing, just return.
    // this function is created incase we need to edit emission's equation in the future
    half3 emissionResult = surfaceData.emission;
    return emissionResult;
}

half3 CompositeAllLightResults(half3 indirectResult, half3 mainLightResult, half3 additionalLightSumResult, half3 emissionResult, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // [pick the highest between indirect and direct light]
    // character artist don't want the concept of indirect + direct light
    // because it will ruin the final color easily,
    // what character artist want is -> keep char's result same as albedo they draw if bright enough,
    // but in a dark enviroment, switch to use light probe to make character blend into enviroment
    half3 directLightResult = mainLightResult;
#if NeedCalculateAdditionalLight
    directLightResult += additionalLightSumResult;
#endif
    half3 finalLightResult = max(indirectResult, directLightResult); 

#if _EMISSION
    finalLightResult += emissionResult;
#endif

    return finalLightResult;
}
