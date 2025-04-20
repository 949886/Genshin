// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

Shader "Universal Render Pipeline/NiloToon/NiloToon_Character Sticker(Additive)"
{
    Properties
    { 
        [MainTexture]_BaseMap("_BaseMap (Albedo) (Default White)", 2D) = "white" {}
        [HDR][MainColor]_BaseColor("_BaseColor (Default White)", Color) = (1,1,1,1)

        [Toggle(OVERRIDE_ALPHA)]_OverrideAlpha("_OverrideAlpha (Default Off)", Float) = 0
        _OverrideAlphaMap("_OverrideAlphaMap (Default White)", 2D) = "white" {}

        [Header(Polygon Face Culling)]
        // https://docs.unity3d.com/ScriptReference/Rendering.CullMode.html
        [Enum(UnityEngine.Rendering.CullMode)]_Cull("_Cull (Default Off)", Float) = 0

        [Header(ZOffset)]
        _ZOffset("_ZOffset (Default 0)", Range(-1,1)) = -0.1 // +-1m should be more than enough

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

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}     
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "AlphaTest+1" // renders right after all ZWrite On objects finished their rendering 
        }

        Pass
        {
            // https://docs.unity3d.com/ScriptReference/Rendering.BlendMode.html
            // https://docs.unity3d.com/Manual/SL-Blend.html
            // Blend SrcAlpha OneMinusSrcAlpha // Traditional transparency
            // Blend One OneMinusSrcAlpha // Premultiplied transparency
            // Blend One One // Additive
            // Blend OneMinusDstColor One // Soft Additive
            // Blend DstColor Zero // Multiplicative
            // Blend DstColor SrcColor // 2x Multiplicative
            Blend One One // Additive

            ColorMask RGB // because we don't want to pollute RT's alpha channel
            ZWrite Off
            Cull [_Cull] 

            HLSLPROGRAM

            #pragma shader_feature_local _ OVERRIDE_ALPHA //(can use _fragment suffix)  
            #pragma multi_compile_local _ _NILOTOON_DITHER_FADEOUT //(can use _fragment suffix)
            #pragma multi_compile_fog
            
            #pragma multi_compile _ _NILOTOON_FORCE_MINIMUM_SHADER // can strip if you change a bool in NiloToonEditorShaderStripping.cs

            #pragma vertex vert
            #pragma fragment frag

            #define NiloToonStickerAdditive 1
            #include "NiloToonCharacterSticker_HLSL/NiloToonCharacterSticker_Shared.hlsl"
                 
            ENDHLSL
        }
    }
}