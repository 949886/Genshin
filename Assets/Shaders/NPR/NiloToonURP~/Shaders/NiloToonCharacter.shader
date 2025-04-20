// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// Known issue:
// 1)LWGUI text(float) field under foldout group can't be focused/getting highlight in material inspector: 
// https://github.com/Jason-Ma-233/JasonMaToonRenderPipeline/issues/3
// 2)Using too much Title per section will break the material GUI line space

/*
You can extend this shader by writing additional code inside "NiloToonCharacter_ExtendFunctionsForUserCustomLogic.hlsl",
without worrying about merge conflict in future updates, 
because "NiloToonCharacter_ExtendFunctionsForUserCustomLogic.hlsl" 
is just an almost empty .hlsl file with empty functions for you to fill in extra code.
You can use those empty functions to apply your global effect, similar to character-only postprocess (e.g. add fog of war/scan line...).
If you need us to expose more empty functions at another shading timing, please contact nilotoon@gmail.com

If you really need to edit the shader, usually just by editing "NiloToonCharacter_LightingEquation.hlsl" alone can control most of the visual result,
but editing this file directly may make your future update(merge) difficult.

This shader includes 7 passes, each pass will be activated if needed:
0.ForwardLit        pass    (always render, a regular color pass, this pass will always render to URP's _CameraColorTexture RT)
1.Outline           pass    (only render if user turn it on in NiloToonAllInOneRendererFeature(default on). If render is needed, this pass will always render to URP's _CameraColorTexture RT)
2.ExtraThickOutline pass    (only render if user turn it on in NiloToonPerCharacterRenderController(default off). If render is needed, this pass will always render to URP's _CameraColorTexture RT)
3.ShadowCaster      pass    (only for rendering to URP's shadow map RT's depth buffer, this pass won't be used if all your characters don't cast URP shadow)
4.DepthOnly         pass    (only for rendering to URP's depth texture RT _CameraDepthTexture's depth buffer, this pass won't be used if your project don't render URP's offscreen depth prepass)
5.DepthNormals      pass    (only for rendering to URP's normal texture RT _CameraNormalsTexture's rendering, this pass won't be used if your project don't render URP's offscreen depth normal prepass)
6.SelfShadowCaster  pass    (only for rendering NiloToon's _NiloToonCharSelfShadowMapRT's depth buffer, this pass won't be used if your project don't enable NiloToon's character self shadow in NiloToonAllInOneRendererFeature)

Because most of the time, user use NiloToon for unique characters/dynamic objects like character weapons, so all lightmap-related code is removed for simplicity.
For batching, we only rely on SRP batcher, which is the most practical batching method in URP for rendering lots of unique material SkinnedMeshRenderer characters.
GPU instancing is default not enabled (due to adding more multi_compile for not much gain), 
because in most cases, we don't need GPU instancing unless you are rendering lots of lowpoly characters with the same material or need to support VR.

In this shader, sometimes we choose "conditional move (a?b:c)" or "static uniform branching (if(_Uniform))" over "shader_feature & multi_compile" for some of the togglable ALU only(pure calculation) features, 
because:
    - we want to avoid this shader's build time takes too long (2^n)
    - we want to avoid shader size and memory usage becomes too large easily (2^n), 2GB memory iOS mobile will crash easily if you use too much multi_compile
    - we want to avoid rendering spike/hiccup when a new shader variant was seen by the camera first time ("create GPU program" in profiler)
    - we want to avoid increasing ShaderVarientCollection's keyword combination complexity
    - we want to avoid breaking SRP batcher's batching because SRP batcher is per shader variant batching, not per shader

    All modern GPU(include the latest high-end mobile devices) can handle "static uniform branching" with "almost" no performance cost (if register pressure is not the bottleneck).
    Usually, there exist 4 cases of branching, here we sorted them by cost, from lowest cost to highest cost,
    and you usually only need to worry about the last one!

    case 1 - compile time constant if():
        // absolutely 0 performance cost for any platform, unity's shader compiler will treat the false side of if() as dead code and remove it completely
        // shader compiler is very good at dead code removal
        #define SHOULD_RUN_FANCY_CODE 0
        if(SHOULD_RUN_FANCY_CODE) {...}

    case 2 - static uniform branching if():
        // reasonable low performance cost (except OpenGLES2, OpenGLES2 doesn't have branching and will always run both paths and discard the false path)
        // since OpenGLES2 is not the main focus anymore in 2021, we will use static uniform branching if() in NiloToonURP when suitable
        CBUFFER_START(UnityPerMaterial)
            float _ShouldRunFancyCode; // usually controlled by a [Toggle] in material inspector, or material.SetFloat() in C#
        CBUFFER_END
        if(_ShouldRunFancyCode) {...}

    case 3 - dynamic branching if() without divergence inside a wavefront/warp: 
        bool shouldRunFancyCode = (some shader calculation); // all pixels inside a wavefront/warp(imagine it is a group of maximum 64 pixels) all goes into the same path, so no divergence.
        if(shouldRunFancyCode) {...}

    case 4 - dynamic branching if() WITH divergence inside a wavefront/warp: 
        // this is the only case that will make GPU really slow! You will want to avoid it as much as possible
        bool shouldRunFancyCode = (some shader calculation); // pixels inside a wavefront/warp goes into a different path, even it is 63 vs 1 within a 64 thread group, still = divergence!
        if(shouldRunFancyCode) {...} 

    Here are some resources about the cost of if() / branching / divergence in shader:
    - https://stackoverflow.com/questions/37827216/do-conditional-statements-slow-down-shaders
    - https://stackoverflow.com/questions/5340237/how-much-performance-do-conditionals-and-unused-samplers-textures-add-to-sm2-3-p/5362006#5362006
    - https://twitter.com/bgolus/status/1235351597816795136
    - https://twitter.com/bgolus/status/1235254923819802626?s=20
    - https://www.shadertoy.com/view/wlsGDl?fbclid=IwAR1ByDhQBck8VO0AMPS5XpbtBPSzSN9Mh8clW4itRgDIpy5ROcXW1Iyf86g

    [TLDR] 
    Just remember(even for mobile platform): 
    - if() itself is not evil, you CAN use it if you know there is no divergence inside a wavefront/warp, still, it is not free on mobile.
    - "a ? b : c" is just a conditional move(movc / cmov) in assembly code, don't worry using it if you have calculated b and c already
    - Don't try to optimize if() or "a ? b : c" by replacing them by lerp(b,c,step())..., "a ? b : c" is always faster if you have calculated b and c already
    - branching itself is not evil, still it is not free, but sometimes we can use branching to help GPU run faster if the skipped task is heavy!
    - but, divergence is evil! If you want to use if(condition){...}else{...}, make sure the condition is the same within as many groups of 64 pixels as possible

    [Note from the developer (1)]
    Using shader permutation(multi_compile/shader_feature) is still the fastest way to skip shader calculation,
    because once the code doesn't exist, it will enable many compiler optimizations. 
    If you need the best GPU performance, and you can accept long build time and huge memory usage, you can use multi_compile/shader_feature more.

    NiloToon's character shader will always prefer shader permutation if it can skip any texture read, 
    because the GPU hardware has very strong ALU(pure calculation) power growth since 2015 (including mobile), 
    but relatively weak growth in memory bandwidth(usually means buffer/texture read).
    (https://community.arm.com/developer/tools-software/graphics/b/blog/posts/moving-mobile-graphics#siggraph2015)

    And when GPU is waiting for receiving texture fetch, it won't become idle, 
    GPU will still continue any available ALU work(latency hiding) until there is truely nothing to calculate anymore, 
    also bandwidth is the biggest source of heat generation (especially on mobile without active cooling = easier overheat/thermal throttling). 
    So we should try our best to keep memory bandwidth usage low (since more ALU is ok, but more texture read is not ok),
    the easiest way is to remove texture read using shader permutation.

    But if the code is ALU only(pure calculation), and calculation is simple on both paths on the if & else side, NiloToonURP will prefer "a ? b : c". 
    The rest will be static uniform branching (usually means heavy ALU only code inside an if()).

    [Note from the developer (2)]
    If you are working on a game project, not a generic tool, you will always want to pack 4data (occlusion/specular/smoothness/any mask.....) into 1 RGBA texture(for fragment), 
    and pack 4data (outlineWidth/ZOffset/face area mask....) into another RGBA texture(for vertex), to reduce the number of texture read without changing visual result(if we ignore texture compression).
    But since NiloToonURP is a generic tool that is used by different person/team/company, 
    we know it is VERY important for all users to be able to apply this shader to any model easily/fast/without effort,
    and we know that it is almost not practical if we force regular user to pack their texture into a special format just for this shader,
    so we decided we will keep every texture separated, even it is VERY slow compared to the packed texture method.
    That is a sad decision in terms of performance, but a good decision for ease of use. 
    If user don't need the best performance, this decision is actually a plus to them since it is much more flexible when using this shader.  

    [About multi_compile or shader_feature's _vertex and _fragment suffixes]
    In unity 2020.3, unity added _vertex, _fragment suffixes to multi_compile and shader_feature
    https://docs.unity3d.com/2020.3/Documentation/Manual/SL-MultipleProgramVariants.html (Using stage-specific keyword directives)
    
    Originally(in NiloToonURP 0.1.2 or before) this shader is using _vertex, _fragment suffixes to help reduce compilation time in 2020.3, 
    but adding these suffixes will make builds in 2020.2 or below losing all multi_compile or shader_feature when using these suffixes,
    so in 0.1.3 or later, this shader no longer use _vertex and _fragment suffixes to help reduce compilation time, in order to support 2019.4 or above correctly

    The only disadvantage of NOT using _vertex and _fragment suffixes is only compilation time, not build size/memory usage:
    https://docs.unity3d.com/2020.3/Documentation/Manual/SL-MultipleProgramVariants.html (Stage-specific keyword directives)
    "Unity identifies and removes duplicates afterwards, so this redundant work does not affect build sizes or runtime performance; 
    however, if you have a lot of stages and/or variants, the time wasted during shader compilation can be significant."
*/ 
Shader "Universal Render Pipeline/NiloToon/NiloToon_Character"
{
    Properties
    {
        // [about naming]
        // All properties will try to follow URP Lit shader's naming convention if possible,
        // so switching your URP lit material's shader to NiloToon shader will preserve most of the original properties if defined in this shader.
        // For URP Lit shader's naming convention, see URP's Lit.shader (search "Lit t:shader" in the project window, use "Search: In Packages")

        // [about HDR color picker]
        // All color properties in this shader are HDR, because we don't want to limit user's creativity, even if HDR color makes no sense at all.
        // If user want to make a 100% non-sense color choice, for example, an emissive shadow, just let them do it! 
        // because why not? It is NPR, unlike PBR, there is no right or wrong, everything is permitted and valid if it looks good.
        // *Adding [HDR] will force unity to treat the color as linear, be careful.

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Base
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Header(Base Color)]
        [MainTexture]_BaseMap("_BaseMap (Albedo) (Default White)", 2D) = "white" {} // Not using [Tex], in order to preserve tiling and offset GUI
        [HDR][MainColor]_BaseColor("_BaseColor (Default White) (Can control alpha)", Color) = (1,1,1,1)

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Render States (can't use LWGUI's group, because of using [Enum(UnityEngine.Rendering.XXX)])
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////               
        [Header(Polygon Face Culling)]
        // https://docs.unity3d.com/ScriptReference/Rendering.CullMode.html
        [Enum(UnityEngine.Rendering.CullMode)]_Cull("_Cull (Default Back) (If not using Back, maybe you should disable Outline)", Float) = 2

        [Header(Blending State)]
        // https://docs.unity3d.com/ScriptReference/Rendering.BlendMode.html
        // this section will only affect ForwardLit pass
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("_SrcBlend (Use One for opaque)/(Use SrcAlpha for transparent).  (Default One)", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("_DstBlend (Use Zero for opaque)/(Use OneMinusSrcAlpha for transparent).  (Default Zero)", Float) = 0

        [Header(ZWrite)]
        [ToggleUI]_ZWrite("_ZWrite (Should turn off if rendering semi-transparent) (Default On) ", Float) = 1

        // Not expose ZTest to avoid confusion because in 99.9% of situations custom ZTest is not useful. (ZTest default is LEqual)
        [Header(ZTest)]
        // https://docs.unity3d.com/ScriptReference/Rendering.CompareFunction.html
        [HideInInspector][Enum(UnityEngine.Rendering.CompareFunction)]_ZTest("_ZTest (Default LEqual)", Float) = 4 // 4 is LEqual

        [Header(ColorMask)]
        // not using [Enum(UnityEngine.Rendering.ColorWriteMask)]
        // https://docs.unity3d.com/ScriptReference/Rendering.ColorWriteMask.html,
        // because we can't select RGB if we use Unity's ColorWriteMask.
        // So here we define 2 custom enum
        // 15 = binary 1111 (RGBA)
        // 14 = binary 1110 (RGB_)
        // *ColorMask RGB is useful if user don't want to pollute RT's alpha channel
        [Enum(RGBA,15,RGB,14)]_ColorMask("_ColorMask (Set to RGB if you don't want to pollute RenderTexture's alpha channel) (Default RGBA)", Float) = 15 // 15 is RGBA (binary 1111)

        // ***currently this Stencil section is NOT being used.***
        [Header(Stencil)]
        // https://docs.unity3d.com/Manual/SL-Stencil.html
        // https://docs.unity3d.com/ScriptReference/Rendering.CompareFunction.html
        [HideInInspector]_StencilRef("_StencilRef (Default 0)", Range(0,255)) = 0
        [HideInInspector][Enum(UnityEngine.Rendering.CompareFunction)]_StencilComp("_StencilComp (Default Disabled)", Float) = 0
        
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Skin
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // note: no shader_feature keyword is used for _IsSkin, since the increase in ALU and register pressure is very small in Skin section

        // Group name added extra spaces to line up (Default XXX) in material GUI 
        [Main(_IsSkinGroup,_)]_IsSkin("Is Skin?                                                                (Default Off)", Float) = 0 

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_IsSkinGroup, #######################################################################)]
        [Title(_IsSkinGroup, You can turn on this group for skin materials)]
        [Title(_IsSkinGroup, so skin area can use a better set of lighting settings automatically)]
        [Title(_IsSkinGroup, #######################################################################)]
        [Title(_IsSkinGroup, If the model combined skin and other parts into 1 material)]
        [Title(_IsSkinGroup, You can enable an Optional Skin Mask Texture to affect valid skin area only)]
        [Title(_IsSkinGroup, #######################################################################)]
        [Title(_IsSkinGroup, )] // space line

        [Title(_IsSkinGroup, Optional Skin Mask Texture)]
        [SubToggle(_IsSkinGroup,_SKIN_MASK_ON)]_UseSkinMaskMap("_UseSkinMaskMap (allow defining each fragment is skin or not) (Default Off)", Float) = 0
        [Tex(_IsSkinGroup)][NoScaleOffset]_SkinMaskMap("_SkinMaskMap (Use 1 channel) (White = is skin, Black = not skin) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_IsSkinGroup)]_SkinMaskMapChannelMask("_SkinMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Face
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI 
        [Main(_IsFaceGroup,_ISFACE)]_IsFace("Is Face?                                                               (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_IsFaceGroup, #######################################################################)]
        [Title(_IsFaceGroup, You can turn on this group for face materials)]
        [Title(_IsFaceGroup, so face area can use a better set of lighting and outline settings automatically)]
        [Title(_IsFaceGroup, #######################################################################)]
        [Title(_IsFaceGroup, If the model combined face and other parts into 1 material)]
        [Title(_IsFaceGroup, You can enable an Optional Face Mask Texture to affect valid face area only)]
        [Title(_IsFaceGroup, #######################################################################)]
        [Title(_IsFaceGroup, )] // space line

        [Title(_IsFaceGroup, Optional Face Mask Texture)]
        [SubToggle(_IsFaceGroup,_FACE_MASK_ON)]_UseFaceMaskMap("_UseFaceMaskMap (allow defining each vertex is face or not) (Default Off)", Float) = 0
        [Tex(_IsFaceGroup)][NoScaleOffset]_FaceMaskMap("_FaceMaskMap (Use 1 channel) (White = is face, Black = not face) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_IsFaceGroup)]_FaceMaskMapChannelMask("_FaceMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ZOffset
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_ZOffsetGroup,_)]_ZOffsetEnable("ZOffset                                                                (Default On)", Float) = 1 // default is ON to backward support old materials using old version

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_ZOffsetGroup, #######################################################################)]
        [Title(_ZOffsetGroup, Offset vertex Clip space depth value in terms of world space unit)] 
        [Title(_ZOffsetGroup, Useful for rendering eyebrow on top of hair or rendering transparent expression over cheek)]
        [Title(_ZOffsetGroup, #######################################################################)]
        [Title(_ZOffsetGroup, You can enable an Optional ZOffset Mask Texture to select which vertices to apply ZOffset)]
        [Title(_ZOffsetGroup, #######################################################################)]
        [Title(_ZOffsetGroup, )] // space line

        [Sub(_ZOffsetGroup)]_ZOffset("_ZOffset (Default 0)", Range(-1,1)) = 0.0 // +-1m (view space unit) should be more than enough
        [Title(_ZOffsetGroup, Optional ZOffset Mask Texture)]
        [SubToggle(_ZOffsetGroup,_ZOFFSETMAP)]_UseZOffsetMaskTex("_UseZOffsetMaskTex (Default Off)", Float) = 0
        [Tex(_ZOffsetGroup)][NoScaleOffset]_ZOffsetMaskTex("_ZOffsetMaskTex (Use 1 channel) (White = apply ZOffset, Black is ignore ZOffset) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_ZOffsetGroup)]_ZOffsetMaskMapChannelMask("_ZOffsetMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better
        
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Alpha Override
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_AlphaOverrideGroup, _ALPHAOVERRIDEMAP)]_UseAlphaOverrideTex("Alpha Override                                               (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_AlphaOverrideGroup, #######################################################################)]
        [Title(_AlphaOverrideGroup, Replace _BaseMap alpha channel by the following texture)]
        [Title(_AlphaOverrideGroup, #######################################################################)]
        [Title(_AlphaOverrideGroup, )] // space line

        [Tex(_AlphaOverrideGroup)][NoScaleOffset]_AlphaOverrideTex("_AlphaOverrideTex (Use 1 channel) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_AlphaOverrideGroup)]_AlphaOverrideTexChannelMask("_AlphaOverrideTexChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Alpha Clipping
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI 
        [Main(_AlphaClippingGroup,_ALPHATEST_ON)]_AlphaClip("Alpha Clipping                                                (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_AlphaClippingGroup, #######################################################################)]
        [Title(_AlphaClippingGroup, Clip Discard a pixel if pixel alpha value if lower than Cutoff)]
        [Title(_AlphaClippingGroup, #######################################################################)]
        [Title(_AlphaClippingGroup, )] // space line

        [Sub(_AlphaClippingGroup)]_Cutoff("_Cutoff (Default 0.5)", Range(0.0, 1.0)) = 0.5

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Final Output Alpha
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_FinalOutputAlphaGroup,_)]_EditFinalOutputAlphaEnable("Edit Final Output Alpha                             (Default On)", Float) = 1 // default is ON to backward support old materials using old version

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_FinalOutputAlphaGroup, #######################################################################)]
        [Title(_FinalOutputAlphaGroup, When rendering to RenderTexture you can force alpha write to that RenderTexture equals 1)]
        [Title(_FinalOutputAlphaGroup, Useful if you need to use result RenderTexture alpha channel as transparent texture alpha or mask)]
        [Title(_FinalOutputAlphaGroup, #######################################################################)]
        [Title(_FinalOutputAlphaGroup, )] // space line

        [SubToggle(_FinalOutputAlphaGroup, _)]_ForceFinalOutputAlphaEqualsOne("_ForceFinalOutputAlphaEqualsOne(usually turn On for opaque if needed) (Default Off)", Float) = 0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Surface define note
        //
        // URP's channel packing rule:
        // (https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@11.0/manual/lit-shader.html#channel-packing)
        // - Red    = Metallic
        // - Green  = Occlusion
        // - Blue   = None
        // - Alpha  = Smoothness
        //
        // But in this NiloToon character shader, all texture sampling are isolated, for ease of use reason (but harms performance)
        // search [Note from the developer (2)] for a more detail explaination
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Normal Map (Bump Map)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_NormalMapGroup,_NORMALMAP)]_UseNormalMap("Normal Map                                                      (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_NormalMapGroup, #######################################################################)]
        [Title(_NormalMapGroup, Tangent space normal map same as URP Lit shader)]
        [Title(_NormalMapGroup, #######################################################################)]
        [Title(_NormalMapGroup, )] // space line

        [Tex(_NormalMapGroup)][NoScaleOffset][Normal]_BumpMap("_BumpMap (a.k.a NormalMap)", 2D) = "bump" {}
        [Sub(_NormalMapGroup)]_BumpScale("_BumpScale (Default 1)", Float) = 1.0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Smoothness 
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_SmoothnessGroup,_,2)]_SmoothnessGroup("Smoothness", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_SmoothnessGroup, #######################################################################)]
        [Title(_SmoothnessGroup, Similar to URP Lit shader Smoothness which affects Reflection or Highlights sharpness of)]
        [Title(_SmoothnessGroup, GGX Specular and Environment Reflections)]
        [Title(_SmoothnessGroup, #######################################################################)]
        [Title(_SmoothnessGroup, Smoothness equals One minus Roughness)] 
        [Title(_SmoothnessGroup, #######################################################################)]
        [Title(_SmoothnessGroup, )] // space line

        [Sub(_SmoothnessGroup)]_Smoothness("_Smoothness (Default 0.5)", Range(0,1)) = 0.5

        [Title(_SmoothnessGroup, Optional Smoothness Texture)]
        [SubToggle(_SmoothnessGroup,_SMOOTHNESSMAP)]_UseSmoothnessMap("_UseSmoothnessMap (Default Off)", Float) = 0
        [Tex(_SmoothnessGroup)][NoScaleOffset]_SmoothnessMap("_SmoothnessMap (Use 1 channel only)(White = smooth, Black = rough)(Default White)", 2D) = "white" {}
        [SubToggle(_SmoothnessGroup,_)]_SmoothnessMapInputIsRoughnessMap("_SmoothnessMapInputIsRoughnessMap (One minus _SmoothnessMap data?)", Float) = 0
        [RGBAChannelMaskToVec4(_SmoothnessGroup)]_SmoothnessMapChannelMask("_SmoothnessMapChannelMask (Default A, same as URP Lit.shader's convention)", Vector) = (0,0,0,1) // use A as default value because it is URP Lit.shader's default smoothness channel (https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@11.0/manual/lit-shader.html)
        [MinMaxSlider(_SmoothnessGroup,_SmoothnessMapRemapStart,_SmoothnessMapRemapEnd)]_SmoothnessMapRemapMinMaxSlider("Range remap (Default 0~1)", Range(0.0,1.0)) = 1.0
        [HideInInspector]_SmoothnessMapRemapStart("_SmoothnessMapRemapStart", Range(0.0,1.0)) = 0.0
        [HideInInspector]_SmoothnessMapRemapEnd("_SmoothnessMapRemapEnd", Range(0.0,1.0)) = 1.0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Environment Reflections
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_EnvironmentReflectionGroup,_ENVIRONMENTREFLECTIONS)]_ReceiveEnvironmentReflection("Environment Reflections                         (Default Off) (Experimental)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_EnvironmentReflectionGroup, #######################################################################)]
        [Title(_EnvironmentReflectionGroup, Display scene Reflection Probe result)]
        [Title(_EnvironmentReflectionGroup, If the reflection is black you can try rebake reflection probe in scene)]
        [Title(_EnvironmentReflectionGroup, #######################################################################)]
        [Title(_EnvironmentReflectionGroup, )] // space line

        [Title(_EnvironmentReflectionGroup,Apply Intensity)]
        [Sub(_EnvironmentReflectionGroup)]_EnvironmentReflectionUsage("_EnvironmentReflectionUsage (Default 1)", Range(0,1)) = 1

        [Title(_EnvironmentReflectionGroup,Color and Brightness)]
        [Sub(_EnvironmentReflectionGroup)]_EnvironmentReflectionBrightness("_EnvironmentReflectionBrightness (Default 1)", Range(0,32)) = 1
        [Sub(_EnvironmentReflectionGroup)][HDR]_EnvironmentReflectionColor("_EnvironmentReflectionColor (Default White)", Color) = (1,1,1)

        [Title(_EnvironmentReflectionGroup,Style)]
        [Sub(_EnvironmentReflectionGroup)]_EnvironmentReflectionSmoothnessMultiplier("_EnvironmentReflectionSmoothnessMultiplier (Default 1)", Range(0,4)) = 1
        [Sub(_EnvironmentReflectionGroup)]_EnvironmentReflectionFresnelEffect("_EnvironmentReflectionFresnelEffect (Default 0.5)", Range(0,1)) = 0.5

        // don't have a separated shader_feature for Environment Reflections's mask texture, because usually a Environment Reflections mask texture is needed anyway
        [Title(_EnvironmentReflectionGroup, Optional Environment Reflections Mask Texture)]
        [Tex(_EnvironmentReflectionGroup)][NoScaleOffset]_EnvironmentReflectionMaskMap("_EnvironmentReflectionMaskMap (white is show, black is hide) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_EnvironmentReflectionGroup)]_EnvironmentReflectionMaskMapChannelMask("_EnvironmentReflectionMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better   
        [MinMaxSlider(_EnvironmentReflectionGroup,_EnvironmentReflectionMaskMapRemapStart,_EnvironmentReflectionMaskMapRemapEnd)]_EnvironmentReflectionMaskMapRemapMinMaxSlider("Range remap (Default 0~1)", Range(0.0,1.0)) = 1.0
        [HideInInspector]_EnvironmentReflectionMaskMapRemapStart("_EnvironmentReflectionMaskMapRemapStart", Range(0.0,1.0)) = 0.0
        [HideInInspector]_EnvironmentReflectionMaskMapRemapEnd("_EnvironmentReflectionMaskMapRemapEnd", Range(0.0,1.0)) = 1.0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // MatCap (Alpha Blend)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_MatCapAlphaBlendGroup,_MATCAP_BLEND)]_UseMatCapAlphaBlend("Mat Cap (alpha blend)                               (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_MatCapAlphaBlendGroup, #######################################################################)]
        [Title(_MatCapAlphaBlendGroup, Useful for changing material visual to any target matcap texture)]
        [Title(_MatCapAlphaBlendGroup, #######################################################################)]
        [Title(_MatCapAlphaBlendGroup, )] // space line

        [Tex(_MatCapAlphaBlendGroup)][NoScaleOffset]_MatCapAlphaBlendMap("_MatCapAlphaBlendMap (Default White)", 2D) = "white" {}
        [Sub(_MatCapAlphaBlendGroup)]_MatCapAlphaBlendUsage("_MatCapAlphaBlendUsage (Default 1)", Range(0,1)) = 1.0
        [Sub(_MatCapAlphaBlendGroup)]_MatCapAlphaBlendTintColor("_MatCapAlphaBlendTintColor (Can edit alpha) (Default White)", Color) = (1,1,1,1)

        [Sub(_MatCapAlphaBlendGroup)]_MatCapAlphaBlendMapAlphaAsMask("_MatCapAlphaBlendMapAlphaAsMask (Default 0)", Range(0,1)) = 0
        [Sub(_MatCapAlphaBlendGroup)]_MatCapAlphaBlendUvScale("_MatCapAlphaBlendUvScale", Range(0,8)) = 1

        // don't have a separated shader_feature for matcap's mask texture, because usually a matcap mask texture is needed anyway
        [Title(_MatCapAlphaBlendGroup, Optional MatCap(alpha blend) Mask Texture)]
        [Tex(_MatCapAlphaBlendGroup)][NoScaleOffset]_MatCapAlphaBlendMaskMap("_MatCapAlphaBlendMaskMap (white is show, black is hide) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_MatCapAlphaBlendGroup)]_MatCapAlphaBlendMaskMapChannelMask("_MatCapAlphaBlendMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better   
        [MinMaxSlider(_MatCapAlphaBlendGroup,_MatCapAlphaBlendMaskMapRemapStart,_MatCapAlphaBlendMaskMapRemapEnd)]_MatCapAlphaBlendMaskMapRemapMinMaxSlider("Range remap (Default 0~1)", Range(0.0,1.0)) = 1.0
        [HideInInspector]_MatCapAlphaBlendMaskMapRemapStart("_MatCapAlphaBlendMaskMapRemapStart", Range(0.0,1.0)) = 0.0
        [HideInInspector]_MatCapAlphaBlendMaskMapRemapEnd("_MatCapAlphaBlendMaskMapRemapEnd", Range(0.0,1.0)) = 1.0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // MatCap (Additive)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_MatCapAdditiveGroup,_MATCAP_ADD)]_UseMatCapAdditive("Mat Cap (additive)                                       (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_MatCapAdditiveGroup, #######################################################################)]
        [Title(_MatCapAdditiveGroup, Useful for adding matcap rim light or matcap specular highlight)]
        [Title(_MatCapAdditiveGroup, #######################################################################)]
        [Title(_MatCapAdditiveGroup, )] // space line

        [Tex(_MatCapAdditiveGroup)][NoScaleOffset]_MatCapAdditiveMap("_MatCapAdditiveMap (Default White)", 2D) = "white" {}
        [Sub(_MatCapAdditiveGroup)]_MatCapAdditiveIntensity("_MatCapAdditiveIntensity (Default 1)", Range(0,100)) = 1
        [Sub(_MatCapAdditiveGroup)][HDR]_MatCapAdditiveColor("_MatCapAdditiveColor (Default White)", Color) = (1,1,1,1)

        [Sub(_MatCapAdditiveGroup)]_MatCapAdditiveMapAlphaAsMask("_MatCapAdditiveMapAlphaAsMask (Default 0)", Range(0,1)) = 0
        [Sub(_MatCapAdditiveGroup)]_MatCapAdditiveUvScale("_MatCapAdditiveUvScale", Range(0,8)) = 1

        // don't have a separated shader_feature for matcap's mask texture, because usually a matcap mask texture is needed anyway
        [Title(_MatCapAdditiveGroup, Optional MatCap(additive) Mask Texture)]
        [Tex(_MatCapAdditiveGroup)][NoScaleOffset]_MatCapAdditiveMaskMap("_MatCapAdditiveMaskMap (white is show, black is hide) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_MatCapAdditiveGroup)]_MatCapAdditiveMaskMapChannelMask("_MatCapAdditiveMaskMapChannelMask (Default G)", Vector) = (0,1,0,0) // use G as default value because if input is rgb grayscale texture, g is 1 bit better   
        [MinMaxSlider(_MatCapAdditiveGroup,_MatCapAdditiveMaskMapRemapStart,_MatCapAdditiveMaskMapRemapEnd)]_MatCapAdditiveMaskMapRemapMinMaxSlider("Range remap (Default 0~1)", Range(0.0,1.0)) = 1.0
        [HideInInspector]_MatCapAdditiveMaskMapRemapStart("_MatCapAdditiveMaskMapRemapStart", Range(0.0,1.0)) = 0.0
        [HideInInspector]_MatCapAdditiveMaskMapRemapEnd("_MatCapAdditiveMaskMapRemapEnd", Range(0.0,1.0)) = 1.0
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Dynamic Eye
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Main(_DynamicEyeGroup,_DYNAMIC_EYE)]_EnableDynamicEyeFeature("Dynamic Eye                                                    (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_DynamicEyeGroup, #######################################################################)]
        [Title(_DynamicEyeGroup, Useful if material is realistic sphere eye balls)]
        [Title(_DynamicEyeGroup, You can ignore this section if this material is not realistic sphere eye balls)]
        [Title(_DynamicEyeGroup, #######################################################################)]
        [Title(_DynamicEyeGroup, )] // space line

        [Title(_DynamicEyeGroup, Overall)]
        [Sub(_DynamicEyeGroup)]_DynamicEyeSize("_DynamicEyeSize (Default 2.2)", Range(0.1,8)) = 2.2
        [Sub(_DynamicEyeGroup)]_DynamicEyeFinalBrightness("_DynamicEyeFinalBrightness (Default 2)", Range(0,8)) = 2
        [Sub(_DynamicEyeGroup)]_DynamicEyeFinalTintColor("_DynamicEyeFinalTintColor (Default white)", Color) = (1,1,1)

        [Title(_DynamicEyeGroup, Eye pupil)]
        [Tex(_DynamicEyeGroup)]_DynamicEyePupilMap("_DynamicEyePupilMap (Default white)", 2D) = "white" {}
        [Tex(_DynamicEyeGroup)]_DynamicEyePupilMaskTex("_DynamicEyePupilMaskTex (Default white)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_DynamicEyeGroup)]_DynamicEyePupilMaskTexChannelMask("_DynamicEyePupilMaskTexChannelMask (Default A)", Vector) = (0,0,0,1)
        [Sub(_DynamicEyeGroup)]_DynamicEyePupilColor("_DynamicEyePupilColor (Default white)", Color) = (1,1,1)
        [Sub(_DynamicEyeGroup)]_DynamicEyePupilDepthScale("_DynamicEyePupilDepthScale (Default 0.4)", Range(0,1)) = 0.4
        [Sub(_DynamicEyeGroup)]_DynamicEyePupilSize("_DynamicEyePupilSize (Default -0.384)", Range(-1,1)) = -0.384
        [Sub(_DynamicEyeGroup)]_DynamicEyePupilMaskSoftness("_DynamicEyePupilMaskSoftness (Default 0.216)", Range(0,1)) = 0.216

        [Title(_DynamicEyeGroup, Eye white)]
        [Tex(_DynamicEyeGroup)]_DynamicEyeWhiteMap("_DynamicEyeWhiteMap (Default white)", 2D) = "white" {}

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Occlusion Map
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_OcclusionMapGroup,_OCCLUSIONMAP)]_UseOcclusion("Occlusion Map                                               (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_OcclusionMapGroup, #######################################################################)]
        [Title(_OcclusionMapGroup, Force area defined by a texture becomes always in shadow)]
        [Title(_OcclusionMapGroup, #######################################################################)]
        [Title(_OcclusionMapGroup, )] // space line

        [Title(_OcclusionMapGroup,Define)]
        [Tex(_OcclusionMapGroup)][NoScaleOffset]_OcclusionMap("_OcclusionMap (Use 1 channel) (White = no effect, Black = 100% occlusion) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_OcclusionMapGroup)]_OcclusionMapChannelMask("_OcclusionMapChannelMask (Default G)", Vector) = (0,1,0,0) // occlusion default accept g channel, same as URP
        [MinMaxSlider(_OcclusionMapGroup,_OcclusionRemapStart,_OcclusionRemapEnd)]_OcclusionRemapMinMaxSlider("Range remap (Default 0~1)", Range(0.0,1.0)) = 1.0
        [HideInInspector]_OcclusionRemapStart("_OcclusionRemapStart", Range(0.0,1.0)) = 0.0
        [HideInInspector]_OcclusionRemapEnd("_OcclusionRemapEnd", Range(0.0,1.0)) = 1.0

        [Title(_OcclusionMapGroup,Usage)]
        [Sub(_OcclusionMapGroup)]_OcclusionStrength("_OcclusionStrength (Default 1)", Range(0.0, 1.0)) = 1.0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Specular Highlights
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_SPECULARHIGHLIGHTS,_SPECULARHIGHLIGHTS)]_UseSpecular("Specular Highlights                                     (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_SPECULARHIGHLIGHTS, #######################################################################)]
        [Title(_SPECULARHIGHLIGHTS, Add PBR or NPR direct specular highlights to result)]
        [Title(_SPECULARHIGHLIGHTS, #######################################################################)]
        [Title(_SPECULARHIGHLIGHTS, )] // space line

        [Title(_SPECULARHIGHLIGHTS,Define Specular Area)]
        [Tex(_SPECULARHIGHLIGHTS)][NoScaleOffset]_SpecularMap("_SpecularMap (Use 1 channel) (White = full specular, Black = no specular) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_SPECULARHIGHLIGHTS)]_SpecularMapChannelMask("_SpecularMapChannelMask (Default B)", Vector) = (0,0,1,0)
        [MinMaxSlider(_SPECULARHIGHLIGHTS,_SpecularMapRemapStart,_SpecularMapRemapEnd)]_SpecularMapRemapMinMaxSlider("Range remap (Default 0~1)", Range(0,1)) = 1
        [HideInInspector]_SpecularMapRemapStart("_SpecularMapRemapStart", Range(0,1)) = 0
        [HideInInspector]_SpecularMapRemapEnd("_SpecularMapRemapEnd", Range(0,1)) = 1

        [Title(_SPECULARHIGHLIGHTS,Define Specular Method)]
        [SubToggle(_SPECULARHIGHLIGHTS, _)]_UseGGXDirectSpecular("_UseGGXDirectSpecular (usually turn Off for hair highlight) (turn On for PBR/realistic specular) (Default On)", Float) = 1

        [Title(_SPECULARHIGHLIGHTS, Define smoothness for GGX specular)]
        [Sub(_SPECULARHIGHLIGHTS)]_GGXDirectSpecularSmoothnessMultiplier("_GGXDirectSpecularSmoothnessMultiplier (Default 1)", Range(0,4)) = 1

        [Title(_SPECULARHIGHLIGHTS,Intensity and Color)]
        [Sub(_SPECULARHIGHLIGHTS)]_SpecularIntensity("_SpecularIntensity (Default 1)", Range(0,100)) = 1
        [Sub(_SPECULARHIGHLIGHTS)][HDR]_SpecularColor("_SpecularColor (Default White)", Color) = (1,1,1) // URP Lit.shader use _SpecColor, we ignore it and use our own name to avoid confusion
        [Sub(_SPECULARHIGHLIGHTS)]_MultiplyBaseColorToSpecularColor("_MultiplyBaseColorToSpecularColor (Default 0)", Range(0,1)) = 0    

        [Title(_SPECULARHIGHLIGHTS,Style)]
        [Sub(_SPECULARHIGHLIGHTS)]_SpecularAreaRemapUsage("_SpecularAreaRemapUsage (Default 0)", Range(0,1)) = 0.0
        [Sub(_SPECULARHIGHLIGHTS)]_SpecularAreaRemapMidPoint("_SpecularAreaRemapMidPoint (Default 0.1)", Range(0,1)) = 0.1
        [Sub(_SPECULARHIGHLIGHTS)]_SpecularAreaRemapRange("_SpecularAreaRemapRange (a.k.a softness) (Default 0.05)", Range(0,1)) = 0.05

        [Title(_SPECULARHIGHLIGHTS,Optional Extra Tint by Texture)]
        [SubToggle(_SPECULARHIGHLIGHTS,_SPECULARHIGHLIGHTS_TEX_TINT)]_UseSpecularColorTintMap("_UseSpecularColorTintMap (Default Off)", Float) = 0
        [Tex(_SPECULARHIGHLIGHTS)][NoScaleOffset]_SpecularColorTintMap("_SpecularColorTintMap (Default White)", 2D) = "white" {}
        [Sub(_SPECULARHIGHLIGHTS)]_SpecularColorTintMapUsage("_SpecularColorTintMapUsage (Default 1)", Range(0,1)) = 1


        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Kajiya-Kay Specular (for hair)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_KAJIYAKAY_SPECULAR,_KAJIYAKAY_SPECULAR)]_UseKajiyaKaySpecular("KajiyaKaySpecular                                       (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_KAJIYAKAY_SPECULAR, #######################################################################)]
        [Title(_KAJIYAKAY_SPECULAR, Useful if you want dynamic hair reflection)]
        [Title(_KAJIYAKAY_SPECULAR, require each hair UV all rotated to the same direction)]
        [Title(_KAJIYAKAY_SPECULAR, #######################################################################)]
        [Title(_KAJIYAKAY_SPECULAR, )] // space line

        [Sub(_KAJIYAKAY_SPECULAR)][HDR]_HairStrandSpecularMainColor("_HairStrandSpecularColor (Default White)", Color) = (1,1,1)
        [Sub(_KAJIYAKAY_SPECULAR)][HDR]_HairStrandSpecularSecondColor("_HairStrandSpecularSecondColor (Default White)", Color) = (1,1,1)
        [Sub(_KAJIYAKAY_SPECULAR)]_HairStrandSpecularMainExponent("_HairStrandSpecularMainExponent (Default 256)", Float) = 256
        [Sub(_KAJIYAKAY_SPECULAR)]_HairStrandSpecularSecondExponent("_HairStrandSpecularMainExponent (Default 128)", Float) = 128

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Emission
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_EMISSION,_EMISSION)]_UseEmission("Emission                                                            (Default Off)", Float) = 0 

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_EMISSION, #######################################################################)]
        [Title(_EMISSION, Add self Illumination or glow)]
        [Title(_EMISSION, Especially useful if URP bloom postprocess is active)]  
        [Title(_EMISSION, #######################################################################)]
        [Title(_EMISSION, Besides regular emission use case)] 
        [Title(_EMISSION, You can also enable it for eye highlight and let bloom postprocess do the diffusion filter similar to anime)] 
        [Title(_EMISSION, #######################################################################)]
        [Title(_EMISSION, )] // space line

        [Title(_EMISSION, Define Emission)]
        [Tex(_EMISSION)][NoScaleOffset]_EmissionMap("_EmissionMap (Default White)", 2D) = "white" {} // same as URP's Lit.shader
        [Sub(_EMISSION)]_EmissionMapTilingXyOffsetZw("_EmissionMapTilingXyOffsetZw (Default 1,1,0,0)", Vector) = (1,1,0,0)

        [Title(_EMISSION, Intensity and Color)]
        [Sub(_EMISSION)]_EmissionIntensity("_EmissionIntensity (Default 1)", Range(0,100)) = 1
        [Sub(_EMISSION)][HDR]_EmissionColor("_EmissionColor (Default Black)", Color) = (0,0,0) // same as URP's Lit.shader
        [Sub(_EMISSION)]_MultiplyBaseColorToEmissionColor("_MultiplyBaseColorToEmissionColor (Default 0)", Range(0,1)) = 0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Detail map (all following URP 10 Lit.shader naming)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_DETAIL,_DETAIL)]_UseDetailMap("Detail Maps                                                       (Default Off)", Float) = 0

        // Title used as a note
        // TODO: turn this into a good looking infobox 
        [Title(_DETAIL, #######################################################################)]
        [Title(_DETAIL, Mix another base color texture and normal texture into result)] 
        [Title(_DETAIL, #######################################################################)]
        [Title(_DETAIL, )] // space line

        [Title(_DETAIL, Define Detail UV)]
        [SubToggle(_DETAIL, _)]_DetailUseSecondUv("_DetailUseSecondUv (a.k.a uv2 in mesh) (Default Off)", Float) = 0

        [Title(_DETAIL, Define Apply Area)]
        [Tex(_DETAIL)][NoScaleOffset]_DetailMask("_DetailMask (White = apply, Black = no effect) (Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_DETAIL)]_DetailMaskChannelMask("_DetailMaskChannelMask (Default R)", Vector) = (1,0,0,0)

        [Title(_DETAIL, Detail Albedo Map)]
        [Tex(_DETAIL)][NoScaleOffset]_DetailAlbedoMap("_DetailAlbedoMap (only use rgb channel) (Default linearGrey 0.5)", 2D) = "linearGrey" {}
        [Sub(_DETAIL)]_DetailAlbedoWhitePoint("_DetailAlbedoWhitePoint (Default 0.5)", Range(0.01,1)) = 0.5
        [Sub(_DETAIL)]_DetailAlbedoMapScale("_DetailAlbedoMapScale (Default 1)", Range(0.0, 20)) = 1.0

        [Title(_DETAIL, Detail Normal Map)]
        [Tex(_DETAIL)][NoScaleOffset][Normal]_DetailNormalMap("_DetailNormalMap", 2D) = "bump" {} // reuse _DetailAlbedoMap's detail uv
        [Sub(_DETAIL)]_DetailNormalMapScale("_DetailNormalMapScale (Default 1)", Range(0.0, 20)) = 1.0

        [Title(_DETAIL, Detail Maps Shared Tiling and Offset)]
        [Sub(_DETAIL)]_DetailMapsScaleTiling("Detail Maps UV Tiling(xy) and Offset(zw), (Default 1,1,0,0)", Vector) = (1,1,0,0)

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Lighting Style
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Main(_LightingStyleGroup,_,2)]_LightingStyleGroup("Lighting Style", Float) = 0

        [Title(_LightingStyleGroup,Direct Light)]
        // in this section, default values were set by the author's art experience, you can edit it freely if these don't work for your project
        [Sub(_LightingStyleGroup)]_CelShadeMidPoint("_CelShadeMidPoint (Default 0)", Range(-1,1)) = 0
        [Sub(_LightingStyleGroup)]_CelShadeSoftness("_CelShadeSoftness (Default 0.05)", Range(0,1)) = 0.05
        [Sub(_LightingStyleGroup)]_MainLightIgnoreCelShade("_MainLightIgnoreCelShade (fake SSS) (Default 0)", Range(0,1)) = 0

        [Title(_LightingStyleGroup,Indirect Light)]
        [Sub(_LightingStyleGroup)]_IndirectLightFlatten("_IndirectLightFlatten (Default 1)", Range(0,1)) = 1

        [Title(_LightingStyleGroup, #######################################################################)]
        [Title(_LightingStyleGroup, Section below will only affect Face)]
        [Title(_LightingStyleGroup, #######################################################################)]
        [Title(_LightingStyleGroup, )] // space line

        [Title(_LightingStyleGroup, Override for face area only)]
        [SubToggle(_LightingStyleGroup,_)]_OverrideCelShadeParamForFaceArea("_OverrideCelShadeParamForFaceArea (on/off this section completely) (Default On)", Float) = 1
        // in this section, default values were set by the author's art experience, you can edit it freely if these don't work for your project
        [Sub(_LightingStyleGroup)]_CelShadeMidPointForFaceArea("_CelShadeMidPointForFaceArea (Default -0.3)", Range(-1,1)) = -0.3
        [Sub(_LightingStyleGroup)]_CelShadeSoftnessForFaceArea("_CelShadeSoftnessForFaceArea (Default 0.15)", Range(0,1)) = 0.15
        [Sub(_LightingStyleGroup)]_MainLightIgnoreCelShadeForFaceArea("_MainLightIgnoreCelShadeForFaceArea (fake SSS) (Default 0.5)", Range(0,1)) = 0.5 //face can be bright, dark = color is dirty for face!

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Calculate Base Color into Shadow Color
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Main(_SelfShadowGroup,_,2)]_SelfShadowGroup("Calculate Shadow Color from Base Color", Float) = 0

        [Title(_SelfShadowGroup, Shadow Color Style)]
        // in this section, default values were set by the author's art experience, you can edit it freely if these don't work for your project
        [Sub(_SelfShadowGroup)]_SelfShadowAreaHueOffset("_SelfShadowAreaHueOffset (Default 0)", Range(-1,1)) = 0
        [Sub(_SelfShadowGroup)]_SelfShadowAreaSaturationBoost("_SelfShadowAreaSaturationBoost (Default 0.5)", Range(0,1)) = 0.5
        [Sub(_SelfShadowGroup)]_SelfShadowAreaValueMul("_SelfShadowAreaValueMul (Default 0.7)", Range(0,1)) = 0.7
        [Sub(_SelfShadowGroup)][HDR]_SelfShadowTintColor("_SelfShadowTintColor (Default White)", Color) = (1,1,1)
        [Title(_SelfShadowGroup, Lit To Shadow Transition Area Define)]
        [Sub(_SelfShadowGroup)]_LitToShadowTransitionAreaIntensity("_LitToShadowTransitionAreaIntensity", Range(0,32)) = 1
        [Title(_SelfShadowGroup, Lit To Shadow Transition Area Color Style)]
        [Sub(_SelfShadowGroup)]_LitToShadowTransitionAreaHueOffset("_LitToShadowTransitionAreaHueOffset (Default 0.01)", Range(-1,1)) = 0.01
        [Sub(_SelfShadowGroup)]_LitToShadowTransitionAreaSaturationBoost("_LitToShadowTransitionAreaSaturationBoost (Default 0.5)", Range(0,1)) = 0.5
        [Sub(_SelfShadowGroup)]_LitToShadowTransitionAreaValueMul("_LitToShadowTransitionAreaValueMul (Default 1)", Range(0,1)) = 1
        [Sub(_SelfShadowGroup)][HDR]_LitToShadowTransitionAreaTintColor("_LitToShadowTransitionAreaTintColor (Default White)", Color) = (1,1,1)

        [Title(_SelfShadowGroup, Safeguard Fallback Color)]
        [Sub(_SelfShadowGroup)][HDR]_LowSaturationFallbackColor("_LowSaturationFallbackColor (Default H:222,S:25,V:50) (Default alpha as intensity = 100)", Color) = (0.3764706,0.4141177,0.5019608,1)

        [Title(_SelfShadowGroup, #######################################################################)]
        [Title(_SelfShadowGroup, If you enabled IsSkin toggle)]
        [Title(_SelfShadowGroup, you can optionally override skin shadow color to this color)]
        [Sub(_SelfShadowGroup)]_OverrideBySkinShadowTintColor("_OverrideBySkinShadowTintColor (Default 1)", Range(0,1)) = 1
        [Sub(_SelfShadowGroup)]_SkinShadowTintColor("_SkinShadowTintColor (Default 1,0.8,0.8)", Color) = (1,0.8,0.8)

        [Title(_SelfShadowGroup, If you enabled IsFace toggle)]
        [Title(_SelfShadowGroup, you can optionally override face shadow color to this color)]
        [Sub(_SelfShadowGroup)]_OverrideByFaceShadowTintColor("_OverrideByFaceShadowTintColor (Default 1)", Range(0,1)) = 1
        [Sub(_SelfShadowGroup)]_FaceShadowTintColor("_FaceShadowTintColor (Default 1,0.9,0.9)", Color) = (1,0.9,0.9)

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Override Shadow Color by texture
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_OverrideShadowColorByTextureGroup,_OVERRIDE_SHADOWCOLOR_BY_TEXTURE)]_UseOverrideShadowColorByTexture("Override Shadow Color by Texture   (Default Off)", Float) = 0        
        [Title(_OverrideShadowColorByTextureGroup, #######################################################################)]
        [Title(_OverrideShadowColorByTextureGroup, If you dont like the shadow color result from the above section)]
        [Title(_OverrideShadowColorByTextureGroup, you can optionally override final shadow color by a texture in this section)]
        [Title(_OverrideShadowColorByTextureGroup, #######################################################################)]
        [Title(_OverrideShadowColorByTextureGroup, )] // space line

        [Title(_OverrideShadowColorByTextureGroup, Usage)]
        [Sub(_OverrideShadowColorByTextureGroup)]_OverrideShadowColorByTexIntensity("_OverrideShadowColorByTexIntensity (Default 1)", Range(0,1)) = 1

        [Title(_OverrideShadowColorByTextureGroup, Define)]
        [Tex(_OverrideShadowColorByTextureGroup)][NoScaleOffset]_OverrideShadowColorTex("_OverrideShadowColorTex (rgb is shadow color, a is mask) (Default white)", 2D) = "white" {}
        [Sub(_OverrideShadowColorByTextureGroup)]_OverrideShadowColorTexTintColor("_OverrideShadowColorTexTintColor (Default White)", Color) = (1,1,1,1)
        [Sub(_OverrideShadowColorByTextureGroup)]_OverrideShadowColorTexIgnoreAlphaChannel("_OverrideShadowColorTexIgnoreAlphaChannel (Default 0)", Range(0,1)) = 0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Ramp Texture (lighting)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_RampTextureLightingGroup,_RAMP_LIGHTING)]_UseRampLightingTex("Ramp Texture (Lighting)                           (Default Off)", Float) = 0 
        [Tex(_RampTextureLightingGroup)][NoScaleOffset]_RampLightingTex("_RampLightingTex (only use rgb channel) (Default white)", 2D) = "white" {}
        [Sub(_RampTextureLightingGroup)]_RampLightingTexSampleUvY("_RampLightingTexSampleUvY (Default 0.5)", Range(0,1)) = 0.5

        [Title(_RampTextureLightingGroup, Override _RampLightingTexSampleUvY by a texture)]
        [Title(_RampTextureLightingGroup, useful if vertically packed different ramp tex into a single ramp tex atla)]
        [SubToggle(_RampTextureLightingGroup,_RAMP_LIGHTING_SAMPLE_UVY_TEX)]_UseRampLightingSampleUvYTex("_UseRampLightingSampleUvYTex (Default Off)", Float) = 0
        [Tex(_RampTextureLightingGroup)][NoScaleOffset]_RampLightingSampleUvYTex("_RampLightingSampleUvYTex (Use G channel) (Default Gray)", 2D) = "Gray" {}

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Ramp Texture (specular)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_RampTextureSpecularGroup,_RAMP_SPECULAR)]_UseRampSpecularTex("Ramp Texture (Specular)                         (Default Off) (Experimental)", Float) = 0 
        [Tex(_RampTextureSpecularGroup)][NoScaleOffset]_RampSpecularTex("_RampSpecularTex (only use rgb channel) (Default white)", 2D) = "white" {}
        [Sub(_RampTextureSpecularGroup)]_RampSpecularTexSampleUvY("_RampSpecularTexSampleUvY (Default 0.5)", Range(0,1)) = 0.5

        [Title(_RampTextureSpecularGroup, Override _RampSpecularTexSampleUvY by a texture)]
        [Title(_RampTextureSpecularGroup, useful if vertically packed different ramp tex into a single ramp tex atla)]
        [SubToggle(_RampTextureSpecularGroup,_RAMP_SPECULAR_SAMPLE_UVY_TEX)]_UseRampSpecularSampleUvYTex("_UseRampSpecularSampleUvYTex (Default Off)", Float) = 0
        [Tex(_RampTextureSpecularGroup)][NoScaleOffset]_RampSpecularSampleUvYTex("_RampSpecularSampleUvYTex (Use G channel) (Default Gray)", 2D) = "Gray" {}

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Depth Texture Rim Light And Shadow
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        [Main(_DepthTextureRimLightAndShadowGroup,_,2)]_DepthTextureRimLightAndShadowGroup("Depth Texture Rim Light and Shadow", Float) = 0

        [Title(_DepthTextureRimLightAndShadowGroup, Depth Texture Rim Light and Shadow Shape)]
        [Sub(_DepthTextureRimLightAndShadowGroup)]_DepthTexRimLightAndShadowWidthMultiplier("_DepthTexRimLightAndShadowWidthMultiplier (Default 1)", Range(0,4)) = 1

        [Title(_DepthTextureRimLightAndShadowGroup, Depth Texture Rim Light)]
        [Sub(_DepthTextureRimLightAndShadowGroup)]_DepthTexRimLightUsage("_DepthTexRimLightUsage (Default 1)", Range(0,1)) = 1       
        [Sub(_DepthTextureRimLightAndShadowGroup)][HDR]_DepthTexRimLightTintColor("_DepthTexRimLightTintColor (Default White)", Color) = (1,1,1)

        [Title(_DepthTextureRimLightAndShadowGroup, Depth Texture Shadow)]
        [Sub(_DepthTextureRimLightAndShadowGroup)]_DepthTexShadowUsage("_DepthTexShadowUsage (Default 1)", Range(0,1)) = 1       
        [Sub(_DepthTextureRimLightAndShadowGroup)][HDR]_DepthTexShadowTintColor("_DepthTexShadowTintColor (Default White)", Color) = (1,1,1)

        [Title(_DepthTextureRimLightAndShadowGroup, Depth Texture Shadow Show Area Define)]
        [Sub(_DepthTextureRimLightAndShadowGroup)]_DepthTexShadowThresholdOffset("_DepthTexShadowThresholdOffset (Default 0)", Range(-1,1)) = 0
        [Sub(_DepthTextureRimLightAndShadowGroup)]_DepthTexShadowFadeoutRange("_DepthTexShadowFadeoutRange (Default 1)", Range(0.01,10)) = 1

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // NiloToon Self Shadow Mapping
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_NiloToonSelfShadowMappingSettingGroup,_)]_EnableNiloToonSelfShadowMapping("Can Receive NiloToon Shadow?          (Default On)", Float) = 1

        [Title(_NiloToonSelfShadowMappingSettingGroup, Intensity)]
        [Sub(_NiloToonSelfShadowMappingSettingGroup)]_NiloToonSelfShadowIntensityForNonFace("_NiloToonSelfShadowIntensityForNonFace(Default 1)", Range(0,1)) = 1
        [Sub(_NiloToonSelfShadowMappingSettingGroup)]_NiloToonSelfShadowIntensityForFace("_NiloToonSelfShadowIntensityForFace(Default 0)", Range(0,1)) = 0

        [Title(_NiloToonSelfShadowMappingSettingGroup, Bias)]
        [Sub(_NiloToonSelfShadowMappingSettingGroup)]_NiloToonSelfShadowMappingDepthBias("_NiloToonSelfShadowMappingDepthBias(Default 0)", Range(0,0.2)) = 0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Can Receive URP Shadow?
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_RECEIVE_URP_SHADOW,_RECEIVE_URP_SHADOW)]_ReceiveURPShadowMapping("Can Receive URP Shadow?                      (Default On)", Float) = 1 // same as !_RECEIVE_SHADOWS_OFF

        [Title(_RECEIVE_URP_SHADOW, Usage)]
        [Sub(_RECEIVE_URP_SHADOW)]_ReceiveURPShadowMappingAmount("_ReceiveURPShadowMappingAmount (Default 1)", Range(0,1)) = 1
        [Sub(_RECEIVE_URP_SHADOW)][HDR]_URPShadowMappingTintColor("_URPShadowMappingTintColor (Default White)", Color) = (1,1,1)

        [Title(_RECEIVE_URP_SHADOW, Depth Bias     #increase to hide ugly shadow artifact if needed#)]
        [Sub(_RECEIVE_URP_SHADOW)]_ReceiveSelfShadowMappingPosOffset("_ReceiveShadowMappingPosOffset (a.k.a depth bias) (Default 0)", Range(0,1)) = 0
        [Sub(_RECEIVE_URP_SHADOW)]_ReceiveSelfShadowMappingPosOffsetForFaceArea("_ReceiveSelfShadowMappingPosOffsetForFaceArea (a.k.a depth bias) (Default 0.2)", Range(0,1)) = 0.2

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Traditional Outline
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_RENDER_OUTLINE,_)]_RenderOutline("Traditional Outline                                        (Default On)", Float) = 1

        [Title(_RENDER_OUTLINE, Smooth outline Mode)]
        [SubToggle(_RENDER_OUTLINE,_)]_OutlineUseBakedSmoothNormal("_OutlineUseBakedSmoothNormal (require having NiloToon's asset label to model asset) (Default On)", Float) = 1
        [SubToggle(_RENDER_OUTLINE,_)]_UnityCameraDepthTextureWriteOutlineExtrudedPosition("_UnityCameraDepthTextureWriteOutlineExtrudedPosition (Turn it off if you are having 2D rim light white line artifact) (Default On)", Float) = 1

        [Title(_RENDER_OUTLINE, Color)]
        [Sub(_RENDER_OUTLINE)][HDR]_OutlineTintColor("_OutlineTintColor (Default linear 0.25)", Color) = (0.25,0.25,0.25,1)
        [Sub(_RENDER_OUTLINE)][HDR]_OutlineOcclusionAreaTintColor("_OutlineOcclusionAreaTintColor (Default white)", Color) = (1,1,1,1)

        [Title(_RENDER_OUTLINE, Replace Color)]
        [Sub(_RENDER_OUTLINE)]_OutlineUseReplaceColor("_OutlineUseReplaceColor (Default 0)", Range(0,1)) = 0
        [Sub(_RENDER_OUTLINE)][HDR]_OutlineReplaceColor("_OutlineReplaceColor (Default white)", Color) = (1,1,1,1)

        [Title(_RENDER_OUTLINE,Outline Width)]
        [Sub(_RENDER_OUTLINE)]_OutlineWidth("_OutlineWidth (Default 1)", Range(0,32)) = 1
        [Sub(_RENDER_OUTLINE)]_OutlineWidthExtraMultiplier("_OutlineWidthExtraMultiplier (Default 1)", Range(0,32)) = 1

        [Title(_RENDER_OUTLINE,optional Outline Width controlled by Vertex Color)]
        [SubToggle(_RENDER_OUTLINE,_)]_UseOutlineWidthMaskFromVertexColor("_UseOutlineWidthMaskFromVertexColor (Default Off)", Float) = 0
        [RGBAChannelMaskToVec4(_RENDER_OUTLINE)]_OutlineWidthMaskFromVertexColor("_OutlineWidthMaskFromVertexColor (Default G)", Vector) = (0,1,0,0)

        [Title(_RENDER_OUTLINE,optional Outline Width controlled by Texture)]
        [SubToggle(_RENDER_OUTLINE,_OUTLINEWIDTHMAP)]_UseOutlineWidthTex("_UseOutlineWidthTex (Default Off)", Float) = 0
        [Tex(_RENDER_OUTLINE)][NoScaleOffset]_OutlineWidthTex("_OutlineWidthTex (white is 100% width, darker is reduce width) (Default white)", 2D) = "white" {}

        [Title(_RENDER_OUTLINE,Outline Z Offset for hiding ugly outline)]
        [Sub(_RENDER_OUTLINE)]_OutlineZOffset("_OutlineZOffset (View Space unit push away) (Default 0.0001)", Range(0,1)) = 0.0001
        [Sub(_RENDER_OUTLINE)]_OutlineZOffsetForFaceArea("_OutlineZOffsetForFaceArea (View Space unit push away) (Default 0.02)", Range(0,1)) = 0.02

        [Title(_RENDER_OUTLINE,optional Outline Z Offset controlled by Texture)]
        [SubToggle(_RENDER_OUTLINE,_OUTLINEZOFFSETMAP)]_UseOutlineZOffsetTex("_UseOutlineZOffsetTex (Default Off)", Float) = 0
        [Tex(_RENDER_OUTLINE)][NoScaleOffset]_OutlineZOffsetMaskTex("_OutlineZOffsetMask (black is apply 100% ZOffset, white is 0%) (Default Black)", 2D) = "black" {}
        [MinMaxSlider(_RENDER_OUTLINE,_OutlineZOffsetMaskRemapStart,_OutlineZOffsetMaskRemapEnd)]_OutlineZOffsetMaskRemapMinMaxSlider("Range remap (Default 0~1)", Range(0,1)) = 1
        [HideInInspector]_OutlineZOffsetMaskRemapStart("_OutlineZOffsetMaskRemapStart", Range(0,1)) = 0
        [HideInInspector]_OutlineZOffsetMaskRemapEnd("_OutlineZOffsetMaskRemapEnd", Range(0,1)) = 1

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Screen Space Outline
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_SCREENSPACE_OUTLINE,_SCREENSPACE_OUTLINE)]_RenderScreenSpaceOutline("Screen Space Outline                                  (Default Off) (Experimental)", Float) = 0
        
        [Title(_SCREENSPACE_OUTLINE, You need to enable AllowRenderScreenSpaceOutline in NiloToonAllInOneRendererFeature)]
        [Title(_SCREENSPACE_OUTLINE, This feature is VERY slow so it Will auto disabled on mobile)]
        [Title(_SCREENSPACE_OUTLINE, #######################################################################)]

        [Title(_SCREENSPACE_OUTLINE,Outline Width)]
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineWidth("_ScreenSpaceOutlineWidth (Default 1)", Range(0,10)) = 1
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineWidthIfFace("_ScreenSpaceOutlineWidthIfFace (Default 0)", Range(0,10)) = 0

        [Title(_SCREENSPACE_OUTLINE,Outline Depth Sensitivity)]
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineDepthSensitivity("_ScreenSpaceOutlineDepthSensitivity (Default 1)", Range(0,10)) = 1
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineDepthSensitivityIfFace("_ScreenSpaceOutlineDepthSensitivityIfFace (Default 1)", Range(0,10)) = 1

        // not writing shader_feature for this section, because there are many shader_feature already
        [Title(_SCREENSPACE_OUTLINE,Outline Depth Sensitivity Multiplier Texture)]
        [Tex(_SCREENSPACE_OUTLINE)][NoScaleOffset]_ScreenSpaceOutlineDepthSensitivityTex("_ScreenSpaceOutlineDepthSensitivityTex(Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineDepthSensitivityTexChannelMask("_ScreenSpaceOutlineDepthSensitivityTexChannelMask (Default G)", Vector) = (0,1,0,0)
        [MinMaxSlider(_SCREENSPACE_OUTLINE,_ScreenSpaceOutlineDepthSensitivityTexRemapStart,_ScreenSpaceOutlineDepthSensitivityTexRemapEnd)]_ScreenSpaceOutlineDepthSensitivityTexRemapMinMaxSlider("Range remap (Default 0~1)", Range(0,1)) = 1
        [HideInInspector]_ScreenSpaceOutlineDepthSensitivityTexRemapStart("_ScreenSpaceOutlineDepthSensitivityTexRemapStart", Range(0,1)) = 0
        [HideInInspector]_ScreenSpaceOutlineDepthSensitivityTexRemapEnd("_ScreenSpaceOutlineDepthSensitivityTexRemapEnd", Range(0,1)) = 1

        [Title(_SCREENSPACE_OUTLINE,Outline Normals Sensitivity)]
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineNormalsSensitivity("_ScreenSpaceOutlineNormalsSensitivity (Default 1)", Range(0,10)) = 1
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineNormalsSensitivityIfFace("_ScreenSpaceOutlineNormalsSensitivityIfFace (Default 1)", Range(0,10)) = 1

        // not writing shader_feature for this section, because there are many shader_feature already
        [Title(_SCREENSPACE_OUTLINE,Outline Normals Sensitivity Multiplier Texture)]
        [Tex(_SCREENSPACE_OUTLINE)][NoScaleOffset]_ScreenSpaceOutlineNormalsSensitivityTex("_ScreenSpaceOutlineNormalsSensitivityTex(Default White)", 2D) = "white" {}
        [RGBAChannelMaskToVec4(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineNormalsSensitivityTexChannelMask("_ScreenSpaceOutlineNormalsSensitivityTexChannelMask (Default G)", Vector) = (0,1,0,0)
        [MinMaxSlider(_SCREENSPACE_OUTLINE,_ScreenSpaceOutlineNormalsSensitivityTexRemapStart,_ScreenSpaceOutlineNormalsSensitivityTexRemapEnd)]_ScreenSpaceOutlineNormalsSensitivityTexRemapMinMaxSlider("Range remap (Default 0~1)", Range(0,1)) = 1
        [HideInInspector]_ScreenSpaceOutlineNormalsSensitivityTexRemapStart("_ScreenSpaceOutlineNormalsSensitivityTexRemapStart", Range(0,1)) = 0
        [HideInInspector]_ScreenSpaceOutlineNormalsSensitivityTexRemapEnd("_ScreenSpaceOutlineNormalsSensitivityTexRemapEnd", Range(0,1)) = 1

        [Title(_SCREENSPACE_OUTLINE,Outline Color)]
        [Sub(_SCREENSPACE_OUTLINE)][HDR]_ScreenSpaceOutlineTintColor("_ScreenSpaceOutlineTintColor (Default linear 0.1)", Color) = (0.1,0.1,0.1,1)
        [Sub(_SCREENSPACE_OUTLINE)][HDR]_ScreenSpaceOutlineOcclusionAreaTintColor("_ScreenSpaceOutlineOcclusionAreaTintColor (Default white)", Color) = (1,1,1)

        [Title(_SCREENSPACE_OUTLINE,Replace Final Outline Color)]
        [Sub(_SCREENSPACE_OUTLINE)]_ScreenSpaceOutlineUseReplaceColor("_ScreenSpaceOutlineUseReplaceColor (Default 0)", Range(0,1)) = 0
        [Sub(_SCREENSPACE_OUTLINE)][HDR]_ScreenSpaceOutlineReplaceColor("_ScreenSpaceOutlineReplaceColor (Default white)", Color) = (1,1,1,1)

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Override Outline Color by texture
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_OverrideOutlineColorByTextureGroup,_OVERRIDE_OUTLINECOLOR_BY_TEXTURE)]_UseOverrideOutlineColorByTexture("Override Outline Color by Texture      (Default Off)", Float) = 0        
        [Title(_OverrideOutlineColorByTextureGroup, #######################################################################)]
        [Title(_OverrideOutlineColorByTextureGroup, If you dont like the outline color result from the above sections)]
        [Title(_OverrideOutlineColorByTextureGroup, you can optionally override final outline color by a texture using this section)]
        [Title(_OverrideOutlineColorByTextureGroup, #######################################################################)]
        [Title(_OverrideOutlineColorByTextureGroup, )] // space line

        [Title(_OverrideOutlineColorByTextureGroup,Usage)]
        [Sub(_OverrideOutlineColorByTextureGroup)]_OverrideOutlineColorByTexIntensity("_OverrideOutlineColorByTexIntensity (Default 1)", Range(0,1)) = 1

        [Title(_OverrideOutlineColorByTextureGroup,Define)]
        [Tex(_OverrideOutlineColorByTextureGroup)][NoScaleOffset]_OverrideOutlineColorTex("_OverrideOutlineColorTex (rgb is outline color, a is mask) (Default white)", 2D) = "white" {}
        [Sub(_OverrideOutlineColorByTextureGroup)]_OverrideOutlineColorTexTintColor("_OverrideOutlineColorTexTintColor (Default White)", Color) = (1,1,1,1)
        [Sub(_OverrideOutlineColorByTextureGroup)]_OverrideOutlineColorTexIgnoreAlphaChannel("_OverrideOutlineColorTexIgnoreAlphaChannel (Default 0)", Range(0,1)) = 0

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Old Specular roughness settings (Not being used and Will be removed in future version)
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Group name added extra spaces to line up (Default XXX) in material GUI
        [Main(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE,_,2)]_OldSpecularRoughnessSettings("Old Specular roughness settings               (Not being used and Will be removed in future version)", Float) = 0
        // Not being used anymore and will be removed in future version
        [Title(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, #######################################################################)]
        [Title(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, Not being used anymore and will be removed in future version)]
        [Title(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, #######################################################################)]
        [Title(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, Please setup using Smoothness section instead)]
        [Title(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, #######################################################################)]
        [Sub(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE)]_Roughness("_Roughness (Default 0.5)", Range(0,1)) = 0.5
        [SubToggle(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, _)]_UseRoughnessDataFromSpecularMap("_UseRoughnessDataFromSpecularMap(Default Off)", Float) = 0
        // default roughness = A channel to match URP's design(albedo a / specular a)
        [RGBAChannelMaskToVec4(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE)]_SpecularMapRoughnessDataChannelMask("_SpecularMapRoughnessDataChannelMask (Default A)", Vector) = (0,0,0,1)
        [SubToggle(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE, _)]_FlipRoughnessDataFromSpecularMap("_FlipRoughnessDataFromSpecularMap(Default Off)", Float) = 0
        [MinMaxSlider(_OLD_SPECULARHIGHLIGHTS_WILL_DELETE,_SpecularMapRoughnessRemapStart,_SpecularMapRoughnessRemapEnd)]_SpecularMapRoughnessRemapMinMaxSlider("Range remap (Default 0~1)", Range(0,1)) = 1
        [HideInInspector]_SpecularMapRoughnessRemapStart("_SpecularMapRoughnessRemapStart", Range(0,1)) = 0
        [HideInInspector]_SpecularMapRoughnessRemapEnd("_SpecularMapRoughnessRemapEnd", Range(0,1)) = 1

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Set by script
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // everything inside your CBUFFER_START(UnityPerMaterial) must exist in this Properties{} section in order to make SRP batcher works
        // even properties that are only set by script and [HideInInspector]!
        // You can try comment out any line here and reimport the shader,
        // doing this will make SRP batching fail, you can check it by viewing .shader in the inspector

        // average shadow mapping
        [HideInInspector]_AverageShadowMapRTSampleIndex("_AverageShadowMapRTSampleIndex", Float) = -1

        // per character gameplay effect
        [HideInInspector]_PerCharEffectTintColor("_PerCharEffectTintColor", Color) = (1,1,1)
        [HideInInspector]_PerCharEffectAddColor("_PerCharEffectAddColor", Color) = (0,0,0)
        [HideInInspector]_PerCharEffectDesaturatePercentage("_PerCharEffectDesaturatePercentage", Range(0,1)) = 0
        [HideInInspector]_PerCharEffectLerpColor("_PerCharEffectLerpColor", Color) = (1,1,0,0)
        [HideInInspector]_PerCharEffectRimColor("_PerCharEffectRimColor", Color) = (0,0,0)
        [HideInInspector]_PerCharacterOutlineColorLerp("_PerCharacterOutlineColorLerp", Color) = (1,1,1,0)

        // per character set up
        [HideInInspector]_PerCharacterBaseColorTint("_PerCharacterBaseColorTint", Color) = (1,1,1)
        [HideInInspector]_PerCharacterOutlineWidthMultiply("_PerCharacterOutlineWidthMultiply", Float) = 1
        [HideInInspector]_PerCharacterOutlineColorTint("_PerCharacterOutlineColorTint", Color) = (1,1,1)

        // extra thick outline
        [HideInInspector]_ExtraThickOutlineWidth("_ExtraThickOutlineWidth", Range(0,100)) = 4
        [HideInInspector]_ExtraThickOutlineViewSpacePosOffset("_ExtraThickOutlineViewSpacePosOffset", Vector) = (0,0,0)
        [HideInInspector]_ExtraThickOutlineColor("_ExtraThickOutlineColor", Color) = (1,1,1,1)
        [HideInInspector]_ExtraThickOutlineZOffset("_ExtraThickOutlineZOffset", Float) = -0.1
        [HideInInspector]_ExtraThickOutlineMaxFinalWidth("_ExtraThickOutlineMaxFinalWidth", Float) = 100

        // face
        [HideInInspector]_FaceForwardDirection("_FaceForwardDirection", Vector) = (0,0,1)
        [HideInInspector]_FixFaceNormalAmount("_FixFaceNormalAmount", Range(0,1)) = 1

        // per char center
        [HideInInspector]_CharacterBoundCenterPosWS("_CharacterBoundCenterPosWS", Vector) = (0,0,0)

        // dither
        [HideInInspector]_DitherOpacity("_DitherOpacity", Range(0,1)) = 0

        // perspective removal
        [HideInInspector]_PerspectiveRemovalAmount("_PerspectiveRemovalAmount", Range(0,1)) = 0
        [HideInInspector]_PerspectiveRemovalRadius("_PerspectiveRemovalRadius", Float) = 1
        [HideInInspector]_HeadBonePositionWS("_HeadBonePositionWS", Vector) = (0,0,0)
        [HideInInspector]_PerspectiveRemovalStartHeight("_PerspectiveRemovalStartHeight", Float) = 0 // ground
        [HideInInspector]_PerspectiveRemovalEndHeight("_PerspectiveRemovalEndHeight", Float) = 1 // a point above ground and below character head
    }
    SubShader
    {       
        Tags 
        {
            // SRP introduced a new "RenderPipeline" tag in Subshader. This allows you to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your SubShader to only run in URP, set the tag to
            // "UniversalPipeline"

            // here "UniversalPipeline" tag is written because we only want this shader to run in URP.
            // If Universal render pipeline is not set in the graphics settings, this SubShader will fail.

            // One can add a SubShader below or fallback to Standard built-in to make this
            // material work with both Universal Render Pipeline and Builtin Unity Pipeline

            // the tag value is "UniversalPipeline", not "UniversalRenderPipeline", be careful!
            // see -> https://github.com/Unity-Technologies/Graphics/pull/1431/
            "RenderPipeline" = "UniversalPipeline"

            // [need ShaderModel 4.5 because of SRP-batcher]
            // URP's Lit.shader also require ShaderModel 4.5
            // ShaderModel 4.5 = OpenGL ES 3.1 capabilities (DX11 SM5.0 on D3D platforms, just without tessellation shaders)
            // Not supported on DX11 before SM5.0, OpenGL before 4.3 (i.e. Mac), OpenGL ES 2.0/3.0.
            // Supported on DX11+ SM5.0, OpenGL 4.3+, OpenGL ES 3.1, Metal, Vulkan, PS4/XB1 consoles.
            // Has compute shaders, random access texture writes, atomics and so on. No geometry or tessellation shaders.
            // https://docs.unity3d.com/Manual/SL-ShaderCompileTargets.html
            "ShaderModel"="4.5" 

            // explicit SubShader tag to avoid confusion
            "RenderType"="Opaque"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue"="Geometry"
        }

        // No LOD defined
        //LOD 300
    
        // We can extract duplicated hlsl code from all passes into this HLSLINCLUDE section. Less duplicated code = Less error
        HLSLINCLUDE

        // all Passes will need these keywords
        #pragma shader_feature_local _ALPHAOVERRIDEMAP //(can use _fragment suffix)
        #pragma shader_feature_local _ALPHATEST_ON //(can use _fragment suffix)
        #pragma multi_compile _ _NILOTOON_FORCE_MINIMUM_SHADER // can strip if you change a bool in NiloToonEditorShaderStripping.cs

        ENDHLSL

        // [#0 Pass - ForwardLit]
        // Shades GI, all lights, emission, and fog in a single pass.
        // Compared to the Builtin pipeline forward renderer, URP forward renderer will
        // render a scene with multiple lights(additional light) with fewer draw calls and less overdraw.
        Pass
        {               
            Name "ForwardLit"
            Tags
            {
                // "Lightmode" matches the "ShaderPassName" set in UniversalRenderPipeline.cs. 
                // SRPDefaultUnlit and passes with no LightMode tag are also rendered by Universal Render Pipeline

                // In this pass, 
                // "Lightmode" tag must be "UniversalForward" in order to render lit objects by URP's ForwardRenderer by default.
                "LightMode" = "UniversalForward"
            }

            // render state
            Cull [_Cull]
            ZWrite [_ZWrite]
            Blend [_SrcBlend] [_DstBlend]
            ColorMask [_ColorMask]

            // write the value [_ExtraThickOutlineStencilID] whenever the depth test passes. The stencil test is set to always pass.
            // the stencil write value will be used by extra thick outline pass later
            // https://docs.unity3d.com/Manual/SL-Stencil.html
            Stencil 
            {
                Ref [_ExtraThickOutlineStencilID]
                Comp always // passing depth test = passing stencil
                Pass replace // replace means write
            }

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Our Material Keywords (similar to URP's material keywords)
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            #pragma shader_feature_local _NORMALMAP // need tangentWS from vertex shader also, so shader_feature_local_fragment is not enough
            #pragma shader_feature_local _SMOOTHNESSMAP //(can use _fragment suffix)
            #pragma shader_feature_local _EMISSION //(can use _fragment suffix)
            #pragma shader_feature_local _OCCLUSIONMAP //(can use _fragment suffix)
            #pragma shader_feature_local _SPECULARHIGHLIGHTS //(can use _fragment suffix) // URP Lit.shader use _SPECULARHIGHLIGHTS_OFF to save a keyword, here we use an inverted keyword
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_TEX_TINT //(can use _fragment suffix) 
            #pragma shader_feature_local _RECEIVE_URP_SHADOW //(can use _fragment suffix) // URP Lit.shader use _RECEIVE_SHADOWS_OFF to save a keyword, here we use an inverted keyword
            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS //(can use _fragment suffix)
            
            // URP Lit.shader use _DETAIL_MULX2 and _DETAIL_SCALED, here we simplify them into a single keyword _DETAIL to reduce variant.
            // In this shader, we calculate detailUV in vertex shader, so shader_feature_local_fragment is not enough 
            #pragma shader_feature_local _DETAIL

            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Our Material keywords (NiloToon specific)
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            #pragma shader_feature_local _ISFACE // can affect vertex lighting, so shader_feature_local_fragment is not enough 
            #pragma shader_feature_local _FACE_MASK_ON // can affect vertex lighting, so shader_feature_local_fragment is not enough
            #pragma shader_feature_local _SKIN_MASK_ON //(can use _fragment suffix)

            #pragma shader_feature_local _ZOFFSETMAP // can't use shader_feature_local_vertex, else mobile build will not include this varient, not sure why. Now use shader_feature_local as a workaround          

            #pragma shader_feature_local _MATCAP_BLEND //(can use _fragment suffix)
            #pragma shader_feature_local _MATCAP_ADD //(can use _fragment suffix)
            #pragma shader_feature_local _MATCAP_MASK //(can use _fragment suffix)

            #pragma shader_feature_local _RAMP_LIGHTING //(can use _fragment suffix)
            #pragma shader_feature_local _RAMP_LIGHTING_SAMPLE_UVY_TEX //(can use _fragment suffix)
            #pragma shader_feature_local _RAMP_SPECULAR //(can use _fragment suffix)
            #pragma shader_feature_local _RAMP_SPECULAR_SAMPLE_UVY_TEX //(can use _fragment suffix)

            #pragma shader_feature_local _DYNAMIC_EYE //(can use _fragment suffix)

            #pragma shader_feature_local _KAJIYAKAY_SPECULAR // need tangentWS from vertex shader also, so shader_feature_local_fragment is not enough

            #pragma shader_feature_local _SCREENSPACE_OUTLINE //(can use _fragment suffix)

            #pragma shader_feature_local _OVERRIDE_SHADOWCOLOR_BY_TEXTURE //(can use _fragment suffix)

            #pragma shader_feature_local _OVERRIDE_OUTLINECOLOR_BY_TEXTURE //(can use _fragment suffix)

            #pragma multi_compile _ _NILOTOON_RECEIVE_URP_SHADOWMAPPING //(can use _fragment suffix)
            #pragma multi_compile _ _NILOTOON_ENABLE_DEPTH_TEXTURE_RIMLIGHT_AND_SHADOW //(can use _fragment suffix)
            #pragma multi_compile _ _NILOTOON_RECEIVE_SELF_SHADOW //(can use _fragment suffix)
            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)

            // [only allowed to be included if not mobile, since keeping shader memory usage low is important for mobile (reduce 50%)]
            // In Unity 2020, Conditionals can now affect #pragma directives
            // #pragma directive parsing is now done using the new preprocessor, which means preprocessor conditionals can be used to influence, which #pragma directives are selected.
            // https://forum.unity.com/threads/new-shader-preprocessor.790328/
            // (tested, doesn't work if #pragma multi_compile _ XXX, so we reply on NiloToonEditorShaderStripping.cs to strip it when building mobile)
            #pragma multi_compile _ _NILOTOON_GLOBAL_ENABLE_SCREENSPACE_OUTLINE //(can use _fragment suffix)

            // [Hardcode define _NILOTOON_ADDITIONAL_LIGHTS always enable, instead of using multi_compile, in order to reduce shader variant by 50%]
            // doing this will increase vertex shading and interpolation pressure, but reduce shader memory usage by 50%, 
            // not a bad trade since no texture sampling is involved, 
            // and shader can early exit when running addtional light forloop(count is 0)(uniform branching).     
            //#pragma multi_compile _ _NILOTOON_ADDITIONAL_LIGHTS // old code // multi_compile_vertex is not enough, because we still need to apply vertex light result in frag
            #define _NILOTOON_ADDITIONAL_LIGHTS 1

            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Our Material debug keywords (can strip when build)
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            #pragma multi_compile _ _NILOTOON_DEBUG_SHADING // multi_compile_fragment is not enough, because of uv8
   
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Universal Render Pipeline keywords (you can always copy this section from URP's Lit.shader)
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the URP Asset assigned in the GraphicsSettings at build time
            // e.g If you disabled AdditionalLights in the asset then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped. e.g variants with _MAIN_LIGHT_SHADOWS_CASCADE
            // but not _MAIN_LIGHT_SHADOWS are invalid and therefore stripped.
            // You can read ShaderPreprocessor.cs (which implements interface IPreprocessShaders) to view URP's shader stripping logic

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE //(can use _fragment suffix)
            //#pragma multi_compile_vertex _ _ADDITIONAL_LIGHT_SHADOWS // TODO: not supported now because we only use vertex additional light, and URP10 don't have point light shadow
            
            // [Hardcode define _SHADOWS_SOFT base on SHADER_API, instead of multi_compile, in order to reduce shader variant by 50%]
            //#pragma multi_compile _ _SHADOWS_SOFT // old code // (can use _fragment suffix)
            // https://docs.unity3d.com/ScriptReference/Rendering.BuiltinShaderDefine.html
            #ifndef SHADER_API_MOBILE 
                #define _SHADOWS_SOFT 1
            #endif

            //#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION // TODO: not supported now, it may ruin visual style if we include SSAO in lighting

            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            // Unity defined keywords
            //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            #pragma multi_compile_fog

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment FragmentShaderAllWork

            // because this pass is just a ForwardLit pass
            // define "NiloToonForwardLitPass" to inject code into VertexShaderAllWork()
            #define NiloToonForwardLitPass 1

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            ENDHLSL
        }
        
        // [#1 Pass - Outline]
        // Same as the above "ForwardLit" pass, but 
        // -vertex position are pushed(extrude) out a bit base on lighting normal / smoothed normal direction
        // -also color is tinted
        // -Cull Front instead of Cull Back because Cull Front is a must for all extrude mesh outline method
        Pass 
        {
            Name "Outline"
            Tags 
            {
                // [IMPORTANT] 
                // If you don't have a RendererFeature to render your custom pass, DON'T write
                //"LightMode" = "UniversalForward"
                // in your custom pass! else your custom pass will not be rendered by URP!

                // [Important CPU performance note]
                // If you need to add a custom pass to your shader (extra outline pass, planar shadow pass, XRay pass when blocked....etc),
                // Please do the following:

                // For shader:
                // (1) Add a new Pass{} in your .shader file, just like this Pass{} section
                // (2) Write "LightMode" = "YourAwesomeCustomPassLightModeTag" inside that new Pass's Tags{} section
                "LightMode" = "NiloToonOutline" // here we set "NiloToonOutline" as custom pass's "LightMode" value, but it can be any string, just pick one you like

                // For RendererFeature(C#):
                // (1) Create a new RendererFeature C# script (right click in project window -> Create/Rendering/Universal Render Pipeline/Renderer Feature)
                // (2) Add that new RendererFeature to your ForwardRenderer.asset
                // (3) Write context.DrawRenderers() with ShaderTagId = "YourAwesomeCustomPassLightModeTag" in RendererPass's Execute() method

                // If done correctly, URP will render your new Pass{} for your shader, in a SRP-batcher friendly way (usually in 1 big SRP batch containing lots of draw call)
            }

            // render state
            // TODO: we should find a way to flip Cull from the first pass, instead of hardcode "Cull Front"
            Cull Front // Cull Front is a must for the extra pass extrude mesh outline method. 
            ColorMask [_ColorMask]

            // write the value [_ExtraThickOutlineStencilID] whenever the depth test passes. The stencil test is set to always pass.
            // the stencil write value will be used by extra thick outline pass later
            // https://docs.unity3d.com/Manual/SL-Stencil.html
            Stencil 
            {
                Ref [_ExtraThickOutlineStencilID]
                Comp always // passing depth test = passing stencil
                Pass replace // replace means write
            }

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            // Similar but not the same comparing to all keywords from the above "ForwardLit" pass,
            // ignored some keywords if it is not that important for this outline pass, to reduce compiled shader variant count
            // for notes please see "ForwardLit" pass
            // ---------------------------------------------------------------------------------------------
            #pragma shader_feature_local _ZOFFSETMAP
            #pragma shader_feature_local _OUTLINEWIDTHMAP //(can use _vertex suffix)
            #pragma shader_feature_local _OUTLINEZOFFSETMAP //(can use _vertex suffix)

            #pragma shader_feature_local _OCCLUSIONMAP //(can use _fragment suffix) // needs to affect outline color

            #pragma shader_feature_local _ISFACE // can affect vertex lighting / outline, so shader_feature_local_fragment is not enough 
            #pragma shader_feature_local _FACE_MASK_ON // can affect vertex lighting / outline, so shader_feature_local_fragment is not enough

            #pragma shader_feature_local _OVERRIDE_OUTLINECOLOR_BY_TEXTURE //(can use _fragment suffix)
            // ---------------------------------------------------------------------------------------------
            #pragma multi_compile _ _NILOTOON_RECEIVE_URP_SHADOWMAPPING //(can use _fragment suffix)
            #pragma multi_compile _ _NILOTOON_DEBUG_SHADING // multi_compile_fragment is not enough, because of uv8
            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)

            // ---------------------------------------------------------------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE //(can use _fragment suffix)
            #define _NILOTOON_ADDITIONAL_LIGHTS 1
            //#pragma multi_compile_vertex _ _ADDITIONAL_LIGHT_SHADOWS // not supported if vertex additional light

            #ifndef SHADER_API_MOBILE 
                #define _SHADOWS_SOFT 1
            #endif
            // ---------------------------------------------------------------------------------------------
            #pragma multi_compile_fog
            // ---------------------------------------------------------------------------------------------

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment FragmentShaderAllWork

            // because this is an Outline pass, 
            // define "NiloToonSelfOutlinePass" to inject outline related code into both VertexShaderAllWork() and FragmentShaderAllWork()
            #define NiloToonSelfOutlinePass 1

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            ENDHLSL
        }

        // [#2 Pass - extra thick Outline]
        // Same as the above "Outline" pass, but extra thick and output only a single color(ignore fog)
        Pass 
        {
            Name "ExtraThickOutline"
            Tags 
            {
                // for notes on "LightMode" = "xxx", please see the above "Outline" Pass{}
                "LightMode" = "NiloToonExtraThickOutline"
            }

            // render state
            ZTest [_ExtraThickOutlineZTest]
            ZWrite Off // ZWrite On is also reasonable, we just pick ZWrite Off because semi-transparent color(alpha) is possible
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask [_ColorMask]

            // only draw if stencil value is NOT [_ExtraThickOutlineStencilID]
            // https://docs.unity3d.com/Manual/SL-Stencil.html
            Stencil 
            {
                Ref [_ExtraThickOutlineStencilID]
                Comp notEqual
                Pass replace // write [_ExtraThickOutlineStencilID] to prevent later fragment shader redraw the same pixel, because outline color can be semi-transparent
            }          

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment ExtraThickOutlineFragmentFunction // because code is too simple, we define the method within this Pass{} section

            // because this is an Outline pass, 
            // define "NiloToonExtraThickOutlinePass" to inject outline related code into VertexShaderAllWork()
            #define NiloToonExtraThickOutlinePass 1

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            half4 ExtraThickOutlineFragmentFunction(Varyings input) : SV_TARGET
            {
#if _NILOTOON_DITHER_FADEOUT
                NiloDoDitherFadeoutClip(input.positionCS.xy, _DitherOpacity);
#endif
                return _ExtraThickOutlineColor;
            }

            ENDHLSL
        }
 
        // ShadowCaster pass. Used for rendering URP's shadow maps
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            // more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible (possible if _AlphaClip is off)            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull [_Cull]

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            // the only keywords we need in this pass = _AlphaClip, which is already defined inside the HLSLINCLUDE block above
            // (so no need to write any multi_compile or shader_feature in this pass)

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading

            // [important]
            // because it is a ShadowCaster pass, define "NiloToonShadowCasterPass" to inject "remove shadow mapping artifact" code into VertexShaderAllWork().
            // We don't want to do outline extrude here because if we do it, the whole mesh will always receive self shadow, 
            // so don't #define ToonShaderIsOutline here
            #define NiloToonShadowCasterPass 1

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            ENDHLSL
        }

        // DepthOnly pass. Used for rendering URP's offscreen depth prepass (you can search DepthOnlyPass.cs in URP package)
        // When URP's depth texture is on, and if CopyDepthPass is not possible due to MSAA for example, 
        // URP will perform this offscreen depth prepass for this toon shader to draw depth into _CameraDepthTexture
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            // more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible (possible if _AlphaClip is off)            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull [_Cull]

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            // keywords we need in this pass = _AlphaClip, which is already defined inside the HLSLINCLUDE block above
            #pragma shader_feature_local _OUTLINEWIDTHMAP //(can use _vertex suffix)

            // for push back zoffset depth write of face vertices, to hide face depth texture self shadow artifact
            #pragma shader_feature_local _ISFACE
            #pragma shader_feature_local _FACE_MASK_ON

            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading

            // [important]
            // because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderAllWork()
            // if depth write is correct, outline area will process depth of field correctly also.
            #define NiloToonDepthOnlyOrDepthNormalPass 1
            // note: 
            // if we render ExtraThickOutline, this pass should write ExtraThickOutline area to depth texture also
            // but since ExtraThickOutline's color can be semi-transparent, we just keep it simple and don't do the depth write handling

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            ENDHLSL
        }


        // [This pass is used when drawing to a _CameraNormalsTexture texture]
        // Starting from URP 10.0.x, URP can generate a normal texture called _CameraNormalsTexture. 
        // To render to this texture in your custom shader, add a Pass{} with the name and LightMode = DepthNormals. 
        // For example, see the implementation in URP's Lit.shader
        // *this pass is almost a direct copy of DepthOnly pass, but with the following changes:
        // - Name changed to DepthNormals
        // - LightMode changed to DepthNormals
        // - removed ColorMask 0
        // - #pragma fragment point to a function returning PackNormalOctRectEncode()   
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            // more explicit render state to avoid confusion
            ZWrite On // one of the goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible (possible if _AlphaClip is off)            
            //ColorMask 0 // we NEED to write PackNormalOctRectEncode() rg data into color buffer, so don't write ColorMask!
            Cull [_Cull]

            HLSLPROGRAM

            //#pragma exclude_renderers ... // no need to exclude renderers, all platforms will run the same Pass
            #pragma target 4.5 // need ShaderModel 4.5 (= OpenGL ES 3.1 capabilities) because of SRP-batcher

            // keywords we need in this pass = _AlphaClip, which is already defined inside the HLSLINCLUDE block above
            #pragma shader_feature_local _OUTLINEWIDTHMAP //(can use _vertex suffix)

            // for push back zoffset depth write of face vertices, to hide face depth texture self shadow artifact
            #pragma shader_feature_local _ISFACE
            #pragma shader_feature_local _FACE_MASK_ON

            #pragma shader_feature_local _NORMALMAP

            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment BaseColorAlphaClipTest_AndDepthNormalColorOutput // we need to do Clip(), and output normal as color

            // [important]
            // because Outline area should write to depth also, define "ToonShaderIsOutline" to inject outline related code into VertexShaderAllWork()
            // if depth write is correct, outline area will process depth of field correctly also.
            #define NiloToonDepthOnlyOrDepthNormalPass 1 // currently we share DepthOnly pass's define, since these 2 pass are almost the same
            // note: 
            // if we render ExtraThickOutline, this pass should write ExtraThickOutline area to depth texture also
            // but since ExtraThickOutline's color can be semi-transparent, we just keep it simple and don't do the depth write handling

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"
            ENDHLSL
        }
        

        // NiloToonSelfShadowCaster pass. Used for rendering character's self shadow map (not related to URP's shadow map system)
        Pass
        {
            Name "NiloToonSelfShadowCaster"
            Tags{"LightMode" = "NiloToonSelfShadowCaster"}

            // more explicit render state to avoid confusion
            ZWrite On // the only goal of this pass is to write depth!
            ZTest LEqual // early exit at Early-Z stage if possible (possible if _AlphaClip is off)            
            ColorMask 0 // we don't care about color, we just want to write depth, ColorMask 0 will save some write bandwidth
            Cull [_Cull]

            HLSLPROGRAM

            // the only keywords we need in this pass = _AlphaClip, which is already defined inside the HLSLINCLUDE block above
            // (so no need to write any multi_compile or shader_feature in this pass)

            // to support GPU instancing and Single Pass Stereo rendering(VR), add the following section
            //------------------------------------------------------------------------------------------------------------------------------
            // #pragma multi_compile_instancing // disabled because not worth the memory usage and build time increase
            //------------------------------------------------------------------------------------------------------------------------------

            #pragma vertex VertexShaderAllWork
            #pragma fragment BaseColorAlphaClipTest // we only need to do Clip(), no need color shading

            // [important]
            // because it is a NiloToonSelfShadowCaster pass, define "NiloToonCharSelfShadowCasterPass" to inject "remove shadow mapping artifact" code into VertexShaderAllWork().
            // We don't want to do outline extrude here because if we do it, the whole mesh will always receive self shadow, 
            // so don't #define ToonShaderIsOutline here
            #define NiloToonCharSelfShadowCasterPass 1

            // all shader logic written inside this .hlsl, remember to write all #define BEFORE writing #include
            #include "NiloToonCharacter_HLSL/NiloToonCharacter_Shared.hlsl"

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}
