// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

half3 ShiftTangent(half3 T, half uvX)
{
    //distort T without texture read
    return normalize(T-sin(uvX * 750)*0.015-0.4);
}
// https://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf - page 10 & 11
half StrandSpecular(half3 T, half3 H, half exponent)
{
    half dotTH = dot(T,H);
    half sinTH = sqrt(1-dotTH*dotTH);
    half dirAtten = smoothstep(-1,0,dotTH);
    return pow(sinTH,exponent);
}
/////////////////////////////////////////////////////////////////////////////////
// helper functions
/////////////////////////////////////////////////////////////////////////////////
half StrandSpecular(half3 T, half3 H, half exponent, half uvX)
{
    return StrandSpecular(ShiftTangent(T,uvX), H, exponent);
}
half StrandSpecular(half3 T, half3 V, half3 L, half exponent, half uvX)
{
    half3 H = normalize(L+V);
    return StrandSpecular(T, H, exponent, uvX);
}