// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

Shader "Hidden/NiloToon/AnimePostProcess"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    sampler2D _NiloToonAverageShadowMapRT;

    float _TopLightDrawAreaHeight;
    float _BottomDarkenDrawAreaHeight;
    half _TopLightIntensity;
    half _TopLightDesaturate;
    half3 _TopLightTintColor;

    half _BottomDarkenIntensity;

    struct Attributes
    {
        float4 positionOS : POSITION;
        float2 uv         : TEXCOORD0;
    };
    struct Varyings
    {
        float4 positionCS   : SV_POSITION;
        half3 color         : TEXCOORD0;
    };

    Varyings ScreenVertFullscreenMesh(Attributes input)
    {
        // default (_TopLightDrawAreaHeight == 0.5) only render top half of the screen to save fill-rate
        input.positionOS.y -= 1;
        input.positionOS.y *= _TopLightDrawAreaHeight;
        input.positionOS.y += 1;

        Varyings output = (Varyings)0;
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

        // light color
        Light mainLight = GetMainLight();
        float3 lightColor = mainLight.color * float3(0.4, 0.3, 0.15) * .75; // tint orange to make it default looks better
        float lightLuminance = Luminance(mainLight.color);
        lightColor = lerp(lightColor, lightLuminance, _TopLightDesaturate);
        lightColor *= _TopLightTintColor;
        lightColor *= 1 / (1 + lightLuminance) * 3;

        ////////////////////////////////////
        //skylight screen
        ////////////////////////////////////
        float skyLightGradient = saturate(input.uv.y * 2 - 1);//linear gradient from top to middle

         // reserved the right most slot for camera (uv.x == 1)
        half averageShadowSampleValue = tex2Dlod(_NiloToonAverageShadowMapRT, float4(1,0,0,0)).r;

        float skyLightIntensity = 1.5 * _TopLightIntensity * averageShadowSampleValue; // for intensity, control this
        half3 col = skyLightGradient * lightColor * skyLightIntensity;

        output.color = col;
        return output;
    }
    half4 ScreenFrag(Varyings input) : SV_Target
    {
        return half4(input.color * input.color,1); // better fadeout curve than linear
    }

    Varyings MultiplyVertFullscreenMesh(Attributes input)
    {
        // default (_BottomDarkenDrawAreaHeight == 0.5) only render bottom half of the screen to save fill-rate
        input.positionOS.y += 1;
        input.positionOS.y *= _BottomDarkenDrawAreaHeight;
        input.positionOS.y -= 1;

        Varyings output = (Varyings)0;
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

        Light mainLight = GetMainLight();
        float3 lightColor = mainLight.color;
        float lightLuminance = Luminance(mainLight.color);
        
        ////////////////////////////////////
        //bottom darken
        ////////////////////////////////////
        half bottomDarkenGradient = input.uv.y; //linear gradient from bottom to middle

        half darkenTo = 0.9 / (1.0 + lightLuminance * 0.25);
        half3 col = lerp(1 , bottomDarkenGradient, saturate(darkenTo * _BottomDarkenIntensity));

        output.color = col;
        return output;       
    }
    half4 MultiplyFrag(Varyings input) : SV_Target
    {
        return half4(input.color,1);
    }

    ENDHLSL

    SubShader
    {
        ZTest Off ZWrite Off Cull Off

        // Pass 0
        Pass
        {
            Name "RenderAnimePostProcessScreen"

            Blend OneMinusDstColor One // screen

            HLSLPROGRAM
                #pragma vertex ScreenVertFullscreenMesh
                #pragma fragment ScreenFrag
            ENDHLSL
        }

        
        // Pass 1
        Pass
        {
            Name "RenderAnimePostProcessMultiply"

            Blend DstColor Zero // multiply

            HLSLPROGRAM
                #pragma vertex MultiplyVertFullscreenMesh
                #pragma fragment MultiplyFrag
            ENDHLSL
        }

    }
}