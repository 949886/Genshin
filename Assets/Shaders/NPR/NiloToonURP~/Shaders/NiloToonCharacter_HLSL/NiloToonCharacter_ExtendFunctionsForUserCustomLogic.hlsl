// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// This file is intented for you to extend NiloToonCharacter shader with your own custom logic.
// Add whatever code you want in this file, there are empty functions below for you to override by your own method

// You can extend this shader by writing additional code here without worrying about merge conflict in future updates, 
// because this .hlsl is just an almost empty .hlsl file with empty functions for you to fill in extra code.
// You can use empty functions below to apply your global effect, similar to character-only postprocess (e.g. add fog of war/scan line...).
// If you need us to expose more empty functions at another shading timing, please contact nilotoon@gmail.com

// #pragma once is a safeguard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

// write your local/global uniforms, includes and texture/samplers here

// #include "YourCustomLogic.hlsl"

// sampler2D _YourGlobalTexture;
// float _YourGlobalUniform;

// sampler2D _YourLocalTexture;
// float _YourLocalUniform; // will break SRP batching, because it is not inside CBUFFER_START(UnityPerMaterial)

void ApplyCustomUserLogicToVertexAttributeAtVertexShaderStart(inout Attributes attrubute)
{
	// edit vertex Attributes by your custom logic here

	//attrubute.positionOS *= 0.5; // example code, make character mesh smaller
}

void ApplyCustomUserLogicToBaseColor(inout half4 baseColor)
{
	// edit baseColor by your custom logic here

	//baseColor *= half4(1,0,0,1); // example code, tint character with red color
}

void ApplyCustomUserLogicBeforeFog(inout half3 color, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // edit color by your custom logic here

    //color = 1-color; // example code, invert character color
}

void ApplyCustomUserLogicAfterFog(inout half3 color, ToonSurfaceData surfaceData, ToonLightingData lightingData)
{
    // edit color by your custom logic here

    //color *= half3(0,1,0); // example code , tint character with green color
}
