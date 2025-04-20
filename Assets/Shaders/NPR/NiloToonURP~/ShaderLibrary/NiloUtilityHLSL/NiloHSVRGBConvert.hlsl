// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// hsv<->rgb method's source: https://blog.csdn.net/mobilebbki399/article/details/50603461
// update from float to half for optimization because usually we use hsv for half color data

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

/////////////////////////////////////////////////////////////////////////////////////
// core functions
/////////////////////////////////////////////////////////////////////////////////////
half3 RGB2HSV(half3 c)
{
	half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	half4 p = lerp(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
	half4 q = lerp(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

	half d = q.x - min(q.w, q.y);
	half e = 1.0e-10;
	return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

half3 HSV2RGB(half3 c)
{
	half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	half3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

/////////////////////////////////////////////////////////////////////////////////////
// high level helper functions
/////////////////////////////////////////////////////////////////////////////////////

// saturationBoost and valueMul must be within 0~1 value
half3 ApplyHSVChange(half3 originalColor, half hueOffset, half saturationBoost, half valueMul)
{
	return ApplyHSVChange(originalColor,hueOffset,saturationBoost,0);
}
half3 ApplyHSVChange(half3 originalColor, half hueOffset, half saturationBoost, half valueMul, out half3 originalColorHSV)
{
    half3 HSV = RGB2HSV(originalColor);
    originalColorHSV = HSV;
    HSV.x += hueOffset;
    HSV.y = lerp(HSV.y, 1, saturationBoost);
    HSV.z *= valueMul;

    return HSV2RGB(HSV);
}

